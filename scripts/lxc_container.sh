#!/bin/bash
set -e

PREFIX="daily"
NAME="generic"
PPA_LIST=""

BASHRC_PATH="/<path>/<to>/<bashrc>"
HOME_DIR="/<path>/<to>/<homedir>"=
PACKAGES="eza neovim tig"

usage() {
    echo "Usage: $0 --version <version> [--name <name>] [--prefix <prefix>] [--ppas \"<ppa-list>\"] [--bashrc <path>] [--home <path>]"
    echo "Example: $0 --version 24.04 --ppas \"ppa:neovim-ppa/unstable ppa:ondrej/php\""
    exit 1
}

while [[ "$#" -gt 0 ]]; do
    case $1 in
        --version) VERSION="$2"; shift ;;
        --name)    NAME="$2"; shift ;;
        --prefix)  PREFIX="$2"; shift ;;
        --ppas)    PPA_LIST="$2"; shift ;;
        --bashrc)  BASHRC_PATH="$2"; shift ;;
        --home)    HOME_DIR="$2"; shift ;;
        -h|--help) usage ;;
        *) echo "Unknown parameter passed: $1"; usage ;;
    esac
    shift
done

if [ -z "$VERSION" ]; then
    echo "Error: --version is required."
    usage
fi

LXC_NAME="${NAME}-${VERSION//./}"
LXC_EXEC="lxc exec $LXC_NAME -- "

echo "Starting deployment for container: $LXC_NAME (Ubuntu $VERSION)"

lxc list | grep -q -- "$LXC_NAME" && lxc delete "$LXC_NAME" --force
lxc launch ubuntu-${PREFIX}:${VERSION} $LXC_NAME
$LXC_EXEC cloud-init status --wait

lxc config device add $LXC_NAME shared_workspace disk source=$HOME_DIR path=/home/ubuntu/Workspace shift=true
lxc file push $BASHRC_PATH $LXC_NAME/home/ubuntu/.bashrc
$LXC_EXEC sudo chown -R ubuntu:ubuntu /home

if [ -n "$PPA_LIST" ]; then
    echo "Adding requested PPAs..."
    for ppa in $PPA_LIST; do
        $LXC_EXEC sudo add-apt-repository -y "$ppa"
    done
fi

$LXC_EXEC sudo apt update
$LXC_EXEC sudo apt install -y git build-essential devscripts fakeroot quilt tig
$LXC_EXEC sudo apt install -y $PACKAGES
$LXC_EXEC sudo apt clean

$LXC_EXEC su --login ubuntu
