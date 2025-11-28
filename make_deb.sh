#!/bin/bash

set -e

PLATFORM=$1
PACKAGES="dropbear mmc-utils rsync dosfstools fdisk kbd"
WB_RELEASE=${WB_RELEASE:-stable}

if [ -z "$PLATFORM" ]; then
    echo "Usage: $0 6x/7x/8x [fit url]"
    exit 1
fi

IMAGE_URL=${2:-"http://fw-releases.wirenboard.com/fit_image/${WB_RELEASE}/${PLATFORM}/latest.fit"}

if ! which fpm || ! which dumpimage || ! which cpio; then
    # won't be used on CI after https://github.com/wirenboard/wirenboard/pull/163 is merged
    echo "Installing build deps"

    apt-get update && apt-get install -y ruby-rubygems u-boot-tools cpio
    gem install fpm
fi

TMP_DIR=$(mktemp -d)
cleanup() {
    rm -rf "$TMP_DIR"
}
trap cleanup EXIT

echo "Downloading FIT for platform wb$PLATFORM..."
FIT_FILE="$TMP_DIR/latest.fit"
wget -O "$FIT_FILE" "$IMAGE_URL"

echo "Gathering rootfs from FIT..."
ROOTFS_FILE="$TMP_DIR/rootfs.tar.gz"
dumpimage -T flat_dt -p 3 -o "$ROOTFS_FILE" "$FIT_FILE"

echo "Unpacking rootfs..."
ROOTFS_DIR="$TMP_DIR/rootfs"
mkdir "$ROOTFS_DIR"
tar -xf "$ROOTFS_FILE" -C "$ROOTFS_DIR"

echo "Add /etc/resolv.conf from host to rootfs..."
cp /etc/resolv.conf "$ROOTFS_DIR"/etc/resolv.conf

if [[ -n "$TESTING_SET" ]]; then
    echo "deb http://deb.wirenboard.com/all experimental.${TESTING_SET} main" > "$ROOTFS_DIR"/etc/apt/sources.list.d/${TESTING_SET}.list
fi

echo "Chrooting into rootfs in order to install more packages..."
"$ROOTFS_DIR"/chroot_this.sh sh -c " \
    apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get upgrade -y && \
    DEBIAN_FRONTEND=noninteractive apt-get install --no-install-recommends -y $PACKAGES"
FW_VERSION=$(cat "$ROOTFS_DIR"/etc/wb-fw-version)

echo "Creating initramfs directory..."
INITRAMFS_DIR="$TMP_DIR/initramfs"
mkdir "$INITRAMFS_DIR"
./create_initramfs.sh "$ROOTFS_DIR" "$INITRAMFS_DIR" "wb$PLATFORM"

echo "Archiving initramfs..."
INITRAMFS_FILE="$TMP_DIR/initramfs.cpio.gz"
{ pushd "$INITRAMFS_DIR" >/dev/null; find . -mindepth 1 | cpio -o -H newc | gzip -9; popd >/dev/null; } > "$INITRAMFS_FILE"

echo "Creating deb package..."
DEB_DIR="$TMP_DIR/deb"
BOOTLET_DIR="$DEB_DIR/usr/src/wb-initramfs/wb${PLATFORM}-bootlet"
mkdir -p "$BOOTLET_DIR"
cp "$INITRAMFS_FILE" "$BOOTLET_DIR/initramfs.cpio.gz"

DCH_VERSION="$(head -n1 debian/changelog | sed -r 's/.*\((.*)\).*/\1/')"
DEB_VERSION="$(source $ROOTFS_DIR/etc/os-release; echo $VERSION_ID)"
PKG_VERSION="${DCH_VERSION}-deb${DEB_VERSION}-${FW_VERSION}${VERSION_SUFFIX}"
echo "$PKG_VERSION" > "$BOOTLET_DIR/version"

PKG_NAME="wb-initramfs-wb$PLATFORM"
rm -f "$PKG_NAME"*.deb || true

fpm -s dir -t deb -n "$PKG_NAME" -v "$PKG_VERSION" \
    --architecture all \
    --description "Wiren Board initramfs image (wb${PLATFORM})" \
    --maintainer "Wiren Board team <info@wirenboard.com>" \
    --url "https://github.com/wirenboard/wb-initramfs" \
    -C "$DEB_DIR" .
