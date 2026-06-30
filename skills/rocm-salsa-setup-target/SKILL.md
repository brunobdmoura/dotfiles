---
name: rocm-salsa-setup-target
description: Set up Salsa remotes for a ROCm package. tracking branch passed as argument when calling this rule
---

# Set up Salsa remotes for a ROCm package

Configure the standard Salsa git remotes for a ROCm Debian package and set the
tracking branch for the argument branch `target_branch`.

## Inputs

The first argument passed to the rule, called **target_branch**.
Derive the **package name** from `debian/changelog` (first line).

## Steps

Run these steps in order. After each `git` command, check the exit code and
report any error before continuing.

### 1 — `salsa` remote (rocm-team)

```bash
git remote get-url salsa 2>/dev/null
```

- If it already points to `git@salsa.debian.org:rocm-team/<package>.git` → nothing to do.
- If it exists but points elsewhere → `git remote set-url salsa git@salsa.debian.org:rocm-team/<package>.git`
- If it does not exist → `git remote add salsa git@salsa.debian.org:rocm-team/<package>.git`

### 2 — `salsa-bruno` remote (personal fork)

```bash
git remote get-url salsa-bruno 2>/dev/null
```

- If it already points to `git@salsa.debian.org:bruno-bdmoura/<package>.git` → nothing to do.
- If it exists but points elsewhere → `git remote set-url salsa-bruno git@salsa.debian.org:bruno-bdmoura/<package>.git`
- If it does not exist → `git remote add salsa-bruno git@salsa.debian.org:bruno-bdmoura/<package>.git`

### 3 — Fetch remotes

```bash
git fetch salsa
git fetch salsa-bruno
```

### 4 — Checkout Argument Branch

```bash
git checkout <target_branch>
```

### 5 — Ensure the personal fork exists on Salsa

Before pushing, ask the user to confirm the fork exists:

> "Please make sure your personal fork exists at https://salsa.debian.org/bruno-bdmoura/<package>.
> If it doesn't, create it by visiting https://salsa.debian.org/rocm-team/<package> and clicking Fork.
> Type 'done' (or anything) when ready."

Wait for the user to confirm before continuing.

### 6 — Push to personal fork

Push the branch so the remote tracking ref exists before setting upstream:

```bash
git push -u salsa-bruno <target_branch>
```

If the push fails, stop and report the error.

### 7 — Set upstream tracking branch

```bash
git branch --set-upstream-to=salsa-bruno/<target_branch>
```

## Done

Print a summary of all four remotes (`git remote -v`) so the user can verify.

Then print the fork URL for the user to open in a browser:

```
Fork: https://salsa.debian.org/bruno-bdmoura/<package>
```

