#!/usr/bin/env bash
#
# Credits to:
#   https://github.com/talhaHavadar/dotfiles/blob/main/dot/bin/contained/container.scripts/snapshot.sh
#
# snapshot — build Debian *.orig tarball(s) for packages whose upstream lives in
# a subdirectory (or several) of an upstream git monorepo, with gbp +
# pristine-tar.
#
# It handles packages that need:
#   * multiple gbp components (extra orig-<component> tarballs from sibling
#     subdirectories of the monorepo), and
#   * debian/copyright Files-Excluded / Files-Excluded-<component> repacking.
#
# Behaviour is driven by a small per-package config (default debian/snapshot.conf,
# or any path via -c). Run it from the packaging repo root.
#
# Because mk-origtargz / gbp / pristine-tar are Debian tools, run this INSIDE a
# Debian-tools container (e.g. `contained`), e.g. from the packaging repo:
#     contained -i -- bash
#     /work/snapshot create -u 7.3.0
# (`contained` bind-mounts the parent dir, so this script next to the repo is
#  visible as /work/snapshot and ../foo.orig.tar.* persists to the host.)
#
# Usage:
#     snapshot [-c CONFIG] <create|orig|verify> [options]
#
#   create   Create a NEW upstream snapshot from a git ref (default: the conf's
#            UPSTREAM_REF) and import it onto the upstream branch with
#            pristine-tar, then add a changelog entry. Version is
#            <marketing>~git<UTCdate>.<sha10>[+ds].
#               -u, --upstream-version <X.Y.Z>  marketing/base version (required
#                                               unless set in the conf)
#               -r, --ref <git-ref>             upstream ref (tag/branch/commit)
#                   --no-import                  only write ../*.orig*, no gbp
#
#   orig     (Re)generate the orig tarball(s) for the TOPMOST changelog version
#            into ../, for a review build. Prefers committed pristine-tar (exact,
#            offline); falls back to re-deriving from upstream.
#
#   verify   Independently re-derive the orig tarball(s) from upstream at the
#            commit encoded in the topmost changelog version and compare their
#            CONTENT against what the repo would build (pristine-tar / upstream
#            branch). Reports PASS/FAIL per tarball.
#
set -euo pipefail

PROG=${0##*/}
log() { printf '>> %s\n' "$*" >&2; }
warn() { printf '!! %s\n' "$*" >&2; }
die() {
    printf '!! %s\n' "$*" >&2
    exit 1
}

# ---------------------------------------------------------------------------
# Config + repo facts
# ---------------------------------------------------------------------------

CONFIG_FILE="debian/snapshot.conf" # overridable with -c <path>

# Settable by the config file or the environment; no upstream-specific defaults.
# `:=` keeps an inherited env value and only applies the default when unset/empty,
# so precedence is: config file > environment > built-in default.
: "${UPSTREAM_URL:=}"            # upstream monorepo git URL (required; falls back
# to the Repository: field of debian/upstream/metadata if neither config nor env
# sets it)
: "${UPSTREAM_REF:=develop}"     # default ref `create` snapshots
: "${UPSTREAM_REMOTE:=upstream}" # cosmetic: shown in logs / the dch entry
: "${MAIN_SUBDIR:=}"             # subdir feeding the main tarball; empty = whole repo
# (non-monorepo). Monorepo example: projects/clr
: "${COMPONENTS:=}" # space/newline list of  name:subdir  pairs
: "${COMPRESSION:=xz}"           # xz | gzip
: "${REPACK_SUFFIX:=}" # repack suffix override (e.g. +dfsg); empty -> derive from
# the current changelog's upstream version, falling back to +ds
: "${SEP:=~}"                    # ~ -> snapshot BEFORE <marketing>; + -> after
: "${REV:=-1}"                   # Debian revision used by `create`'s dch
: "${DIST:=UNRELEASED}"          # changelog distribution used by `create`'s dch
: "${UPSTREAM_VERSION:=}"        # marketing/base version; may be set per-run with -u
: "${SHA_ABBREV:=10}"            # length of the git short hash embedded in versions
: "${DEBIAN_BRANCH:=}"           # default: read from debian/gbp.conf

load_config() {
    [ -f debian/changelog ] || die "run from the packaging repo root (no debian/changelog here)"
    if [ -f "$CONFIG_FILE" ]; then
        # shellcheck disable=SC1090
        . "$CONFIG_FILE"
    elif [ "$CONFIG_FILE" != "debian/snapshot.conf" ]; then
        die "config not found: $CONFIG_FILE"
    fi
    PKG=${PKG:-$(dpkg-parsechangelog -SSource)}
    if [ -z "$UPSTREAM_URL" ] && [ -f debian/upstream/metadata ]; then
        UPSTREAM_URL=$(sed -n 's/^Repository:[[:space:]]*//p' debian/upstream/metadata | head -1)
        [ -n "$UPSTREAM_URL" ] && log "UPSTREAM_URL from debian/upstream/metadata: ${UPSTREAM_URL}"
    fi
    [ -n "$UPSTREAM_URL" ] || die "UPSTREAM_URL is not set (config $CONFIG_FILE, env, or debian/upstream/metadata Repository:)"
    # MAIN_SUBDIR is optional: empty -> the whole upstream repo is the source
    # (non-monorepo); set it to a path -> only that subtree (monorepo).
    if [ -z "$DEBIAN_BRANCH" ] && [ -f debian/gbp.conf ]; then
        DEBIAN_BRANCH=$(sed -n 's/^[[:space:]]*debian-branch[[:space:]]*=[[:space:]]*//p' debian/gbp.conf | head -1)
    fi
    case "$COMPRESSION" in
    xz) EXT="xz" ;;
    gz | gzip)
        COMPRESSION="gzip"
        EXT="gz"
        ;;
    *) die "unsupported COMPRESSION: $COMPRESSION (use xz or gzip)" ;;
    esac
    # Sanity: warn if the conf components disagree with gbp.conf components.
    if [ -f debian/gbp.conf ]; then
        local gbpcomps confcomps
        gbpcomps=$(sed -n "s/.*components[[:space:]]*=[[:space:]]*\[\(.*\)\].*/\1/p" debian/gbp.conf |
            tr -d "[:space:]'\"" | tr ',' '\n' | sort -u | grep -v '^$' || true)
        confcomps=$(for p in $COMPONENTS; do printf '%s\n' "${p%%:*}"; done | sort -u | grep -v '^$' || true)
        if [ "$gbpcomps" != "$confcomps" ]; then
            warn "components in debian/gbp.conf [$(echo "$gbpcomps" | paste -sd, -)] != config [$(echo "$confcomps" | paste -sd, -)]"
        fi
    fi
}

# Does debian/copyright exclude anything for the main tarball or any component?
needs_repack_suffix() {
    [ -f debian/copyright ] || return 1
    grep -qE '^Files-Excluded:' debian/copyright && return 0
    local p name
    for p in $COMPONENTS; do
        name=${p%%:*}
        grep -qE "^Files-Excluded-${name}:" debian/copyright && return 0
    done
    return 1
}

# ---------------------------------------------------------------------------
# Upstream git scratch repo (keeps the packaging repo clean)
# ---------------------------------------------------------------------------
SCRATCH=""
# Create the upstream scratch repo once, in the CURRENT shell (never inside a
# $(...) command substitution, or the path would be lost to the subshell).
init_scratch() {
    [ -n "$SCRATCH" ] && return 0
    SCRATCH=$(mktemp -d)
    git -C "$SCRATCH" init -q
    git -C "$SCRATCH" remote add origin "$UPSTREAM_URL"
}
cleanup() {
    [ -n "$SCRATCH" ] && rm -rf "$SCRATCH"
    [ -n "${TMPOUT:-}" ] && rm -rf "$TMPOUT"
    return 0 # never let trap cleanup clobber the script's exit status
}
trap cleanup EXIT

# Resolve a ref (branch/tag) to a full commit sha, fetching it shallowly.
# Requires init_scratch to have run in the caller's shell first.
fetch_ref_commit() {
    local ref=$1
    git -C "$SCRATCH" fetch -q --depth 1 origin "$ref"
    git -C "$SCRATCH" rev-parse FETCH_HEAD
}

# Resolve a (possibly abbreviated) sha to a full commit, fetching/deepening the
# configured branch until it is reachable.  Full 40-char shas are fetched direct.
resolve_sha_commit() {
    local sha=$1 full d
    if printf '%s' "$sha" | grep -qiE '^[0-9a-f]{40}$'; then
        if git -C "$SCRATCH" fetch -q --depth 1 origin "$sha" 2>/dev/null; then
            git -C "$SCRATCH" rev-parse FETCH_HEAD
            return 0
        fi
    fi
    for d in 1 100 1000 10000 100000; do
        git -C "$SCRATCH" fetch -q --depth "$d" origin "$UPSTREAM_REF" 2>/dev/null || true
        if full=$(git -C "$SCRATCH" rev-parse --verify -q "${sha}^{commit}" 2>/dev/null); then
            printf '%s' "$full"
            return 0
        fi
    done
    die "could not resolve commit $sha on $UPSTREAM_REMOTE/$UPSTREAM_REF (deepened to 100000)"
}

# ---------------------------------------------------------------------------
# Tarball construction
# ---------------------------------------------------------------------------
# build_origs <commit> <upstream-version> <outdir>
#   main tarball : content of $MAIN_SUBDIR, top dir <pkg>-<ver>/ (dpkg strips it)
#   component    : content of <subdir>,     top dir <name>/      (== component
#                  name, which is what dpkg-source expects — independent of the
#                  monorepo subdir name)
build_origs() {
    local commit=$1 uv=$2 outdir=$3 raw p name sub maintree
    mkdir -p "$outdir"
    local td
    td=$(mktemp -d)

    # Empty MAIN_SUBDIR -> archive the whole repo tree (non-monorepo upstream).
    maintree="$commit"
    [ -n "$MAIN_SUBDIR" ] && maintree="${commit}:${MAIN_SUBDIR}"
    log "main  <- ${MAIN_SUBDIR:-<whole repo>}  (${PKG}_${uv}.orig.tar.${EXT})"
    raw="$td/main.tar"
    git -C "$SCRATCH" archive --format=tar --prefix="${PKG}-${uv}/" -o "$raw" "$maintree"
    mk-origtargz --repack --compression "$COMPRESSION" \
        --package "$PKG" --version "$uv" \
        --copyright-file debian/copyright --directory "$outdir" "$raw" >&2

    for p in $COMPONENTS; do
        name=${p%%:*}
        sub=${p#*:}
        log "comp  ${name} <- ${sub}  (${PKG}_${uv}.orig-${name}.tar.${EXT})"
        raw="$td/${name}.tar"
        git -C "$SCRATCH" archive --format=tar --prefix="${name}/" -o "$raw" "${commit}:${sub}"
        mk-origtargz --repack --compression "$COMPRESSION" \
            --package "$PKG" --version "$uv" --component "$name" \
            --copyright-file debian/copyright --directory "$outdir" "$raw" >&2
    done
    rm -rf "$td"
}

# A content fingerprint of a tarball: "sha256  relpath" lines, sorted, with the
# single top-level directory stripped so prefix naming is irrelevant.
tarball_manifest() {
    local tb=$1 d
    d=$(mktemp -d)
    tar -C "$d" -xf "$tb"
    (cd "$d" && find . -type f -print0 | sort -z | xargs -0 sha256sum) |
        sed -E 's#  \./[^/]+/#  #' | sort -k2
    rm -rf "$d"
}

# ---------------------------------------------------------------------------
# changelog version parsing
# ---------------------------------------------------------------------------
# echoes:  UPSTREAM_VER  BASE  DATE  SHA   (BASE/DATE/SHA empty if not a snapshot)
parse_changelog_version() {
    local full ver up core rest base date sha
    full=$(dpkg-parsechangelog -SVersion)
    ver=${full#*:} # strip epoch
    up=${ver%-*}   # strip Debian revision (upstream has no '-')
    core=${up%%+*} # strip +ds / +dfsg... repack suffix
    if printf '%s' "$core" | grep -qE "${SEP}git[0-9]{8}\."; then
        base=${core%%"${SEP}"git*}
        rest=${core#*"${SEP}"git} # <date>.<sha>
        date=${rest%%.*}
        sha=${rest##*.}
    fi
    printf '%s\t%s\t%s\t%s\n' "$up" "${base:-}" "${date:-}" "${sha:-}"
}

# ---------------------------------------------------------------------------
# Subcommands
# ---------------------------------------------------------------------------

cmd_create() {
    local ref="$UPSTREAM_REF" do_import=1
    while [ $# -gt 0 ]; do
        case "$1" in
        -u | --upstream-version)
            UPSTREAM_VERSION=$2
            shift 2
            ;;
        -r | --ref)
            ref=$2
            shift 2
            ;;
        --no-import)
            do_import=0
            shift
            ;;
        *) die "create: unknown arg: $1" ;;
        esac
    done
    [ -n "$UPSTREAM_VERSION" ] || die "marketing version required: -u <X.Y.Z> (or UPSTREAM_VERSION in config)"

    init_scratch
    local commit date sha uv uvorig
    commit=$(fetch_ref_commit "$ref")
    sha=$(git -C "$SCRATCH" rev-parse --short="$SHA_ABBREV" "$commit")
    date=$(TZ=UTC0 git -C "$SCRATCH" show -s --date=format-local:%Y%m%d --format=%cd "$commit")
    uv="${UPSTREAM_VERSION}${SEP}git${date}.${sha}"
    uvorig="$uv"
    if needs_repack_suffix; then
        local suffix="$REPACK_SUFFIX"
        if [ -z "$suffix" ]; then
            # Derive the repack suffix the package already ships (e.g. +dfsg/+ds)
            # from the current changelog: "7.2.4+dfsg" -> "+dfsg". Fall back to
            # +ds for a first-ever repack whose changelog has no suffix yet.
            local up
            up=$(parse_changelog_version | cut -f1)
            suffix="${up#"${up%%+*}"}"
            [ -n "$suffix" ] || suffix="+ds"
            log "repack suffix (derived from changelog): ${suffix}"
        fi
        uvorig="${uv}${suffix}"
    fi
    log "ref ${ref} -> commit ${commit}"
    log "upstream version: ${uvorig}"

    TMPOUT=$(mktemp -d)
    build_origs "$commit" "$uvorig" "$TMPOUT"

    if [ "$do_import" -eq 0 ]; then
        cp -v "$TMPOUT"/* .. >&2
        log "wrote orig tarball(s) to ../ (no import)"
        return 0
    fi

    # gbp reads `components` from debian/gbp.conf and auto-picks orig-<c> tarballs
    gbp import-orig --no-interactive --pristine-tar --merge-mode=replace \
        ${DEBIAN_BRANCH:+--debian-branch="$DEBIAN_BRANCH"} \
        --upstream-version="$uvorig" \
        "$TMPOUT/${PKG}_${uvorig}.orig.tar.${EXT}"

    dch --newversion "${uvorig}${REV}" --distribution "$DIST" \
        "New upstream snapshot ${uv} (${UPSTREAM_REMOTE}/${ref} ${sha})."
    log "imported + changelog entry added. Review, then: git diff --stat && debcommit"
}

cmd_orig() {
    local up base date sha
    IFS=$'\t' read -r up base date sha < <(parse_changelog_version)
    log "topmost changelog upstream version: ${up}"

    # 1) Prefer pristine-tar / upstream branch via gbp (exact, offline).
    if gbp export-orig --pristine-tar 2>/dev/null; then
        log "regenerated ../${PKG}_${up}.orig*.tar.* via gbp export-orig (pristine-tar/upstream branch)"
        ls -1 ../"${PKG}_${up}".orig*.tar.* 2>/dev/null >&2 || true
        return 0
    fi

    # 2) Fall back to re-deriving from upstream (needs the encoded commit).
    [ -n "$sha" ] || die "no pristine-tar/upstream tree and version is not a snapshot ($up); cannot regenerate"
    warn "pristine-tar unavailable; re-deriving ${up} from ${UPSTREAM_REMOTE}/${UPSTREAM_REF}"
    init_scratch
    local commit
    commit=$(resolve_sha_commit "$sha")
    log "resolved ${sha} -> ${commit}"
    build_origs "$commit" "$up" ".."
    log "wrote ../${PKG}_${up}.orig*.tar.${EXT}"
}

cmd_verify() {
    local up base date sha
    IFS=$'\t' read -r up base date sha < <(parse_changelog_version)
    [ -n "$sha" ] || die "topmost version ($up) is not a snapshot; nothing to verify against upstream"
    log "verifying ${PKG} ${up}  (commit ${sha}, ${date})"

    # Reference = what the repo would build (pristine-tar / upstream branch).
    # gbp export-orig may emit into --tarball-dir or into ../, so collect from both.
    local refdir f
    refdir=$(mktemp -d)
    gbp export-orig --pristine-tar --tarball-dir="$refdir" >/dev/null 2>&1 || true
    for f in ../"${PKG}_${up}".orig*.tar.*; do [ -e "$f" ] && mv "$f" "$refdir/"; done
    ls "$refdir"/"${PKG}_${up}".orig*.tar.* >/dev/null 2>&1 ||
        die "cannot obtain reference orig(s) via gbp export-orig (push pristine-tar/upstream?)"

    # Candidate = independently re-derived from upstream at the encoded commit.
    init_scratch
    local newdir commit
    newdir=$(mktemp -d)
    commit=$(resolve_sha_commit "$sha")
    log "resolved ${sha} -> ${commit}"
    build_origs "$commit" "$up" "$newdir"

    local rc=0 tb base comp newtb label
    for tb in "$refdir/${PKG}_${up}".orig*.tar.*; do
        [ -e "$tb" ] || continue
        base=$(basename "$tb")           # <pkg>_<up>.orig[-<comp>].tar.<ext>
        comp=${base#"${PKG}_${up}.orig"} # ".tar.<ext>"  or  "-<comp>.tar.<ext>"
        comp=${comp%.tar.*}              # ""            or  "-<comp>"
        label=${comp:-(main)}
        newtb=$(ls "$newdir/${PKG}_${up}.orig${comp}".tar.* 2>/dev/null | head -1)
        if [ -z "$newtb" ]; then
            warn "FAIL ${label}: re-derived tarball missing"
            rc=1
            continue
        fi
        if diff -q <(tarball_manifest "$tb") <(tarball_manifest "$newtb") >/dev/null; then
            log "PASS ${label}: content matches upstream@${sha}"
        else
            warn "FAIL ${label}: content DIFFERS from upstream@${sha}"
            diff <(tarball_manifest "$tb") <(tarball_manifest "$newtb") | head -20 >&2 || true
            rc=1
        fi
    done
    rm -rf "$refdir" "$newdir"
    [ "$rc" -eq 0 ] && log "VERIFY OK" || warn "VERIFY FAILED"
    return "$rc"
}

usage() {
    cat >&2 <<EOF
${PROG} — build Debian *.orig tarball(s) from an upstream git monorepo subdir.

Usage: ${PROG} [-c CONFIG] <create|orig|verify> [options]
       (default CONFIG: debian/snapshot.conf)

  create  -u <X.Y.Z> [-r <ref>] [--no-import]
            Snapshot the upstream ref (default UPSTREAM_REF), version
            <X.Y.Z>${SEP}git<UTCdate>.<sha10>[+ds], and gbp import-orig it.
  orig      Regenerate orig(s) for the top changelog version into ../
            (pristine-tar first, else re-derive from upstream).
  verify    Re-derive orig(s) from upstream@<commit-in-version> and compare
            content against the repo's orig(s); PASS/FAIL per tarball.

Config (debian/snapshot.conf or -c <path>): UPSTREAM_URL, MAIN_SUBDIR,
  COMPONENTS="name:subdir ...", UPSTREAM_REF, COMPRESSION, SEP, DEBIAN_BRANCH.
EOF
    exit "${1:-0}"
}

main() {
    # leading global options
    while [ $# -gt 0 ]; do
        case "$1" in
        -c | --config)
            CONFIG_FILE=$2
            shift 2
            ;;
        -h | --help | help) usage 0 ;;
        --)
            shift
            break
            ;;
        -*) die "unknown global option: $1 (try -h)" ;;
        *) break ;;
        esac
    done
    [ $# -ge 1 ] || usage 1
    local sub=$1
    shift
    case "$sub" in
    create)
        load_config
        cmd_create "$@"
        ;;
    orig)
        load_config
        cmd_orig "$@"
        ;;
    verify)
        load_config
        cmd_verify "$@"
        ;;
    *) die "unknown subcommand: $sub (try: create | orig | verify)" ;;
    esac
}
main "$@"
