#!/bin/bash
set -euo pipefail

if [[ $# -eq 0 ]]; then
    echo "Usage: $0 <pkg1> <pkg2> ..."
    exit 1
fi

info() {
    echo -e "\e[35m$1\e[0m"
}

PKGDIR_BASE="/mnt/PKGBUILDs"
BUILD_USER="aarchd-builder"

PKGS=("$@")

if ! id -u "$BUILD_USER" &>/dev/null; then
    useradd -m -s /bin/bash "$BUILD_USER"
fi

for user in root "$BUILD_USER"; do
    if ! grep -Fxq "$user ALL=(ALL) NOPASSWD: ALL" /etc/sudoers; then
        echo "$user ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers
    fi
done

pacman -Syu base-devel fakeroot git --needed --noconfirm
chown -R "$BUILD_USER:$BUILD_USER" "$PKGDIR_BASE"

declare -A DEP_MAP
declare -A VISITED
declare -A PKGNAME_TO_DIR
BUILD_ORDER=()

extract_pkgname() {
    local pkgdir="$1"
    (
        unset pkgname
        shopt -s extglob
        source "$pkgdir/PKGBUILD" &>/dev/null
        echo "${pkgname[@]:-}"
    )
}

extract_makedepends() {
    local pkgdir="$1"
    (
        unset makedepends
        shopt -s extglob
        source "$pkgdir/PKGBUILD" &>/dev/null
        echo "${makedepends[@]:-}"
    )
}

for pkg in "${PKGS[@]}"; do
    pkgdir="$PKGDIR_BASE/$pkg"
    if [[ ! -d "$pkgdir" ]]; then
        info "Package directory $pkgdir does not exist. Skipping..."
        exit 1
    fi

    for name in $(extract_pkgname "$pkgdir"); do
        PKGNAME_TO_DIR["$name"]="$pkg"
    done
done

for pkg in "${PKGS[@]}"; do
    pkgdir="$PKGDIR_BASE/$pkg"
    deps=($(extract_makedepends "$pkgdir"))

    intra_deps=()
    for dep in "${deps[@]}"; do
        if [[ -n "${PKGNAME_TO_DIR[$dep]:-}" ]]; then
            intra_deps+=("${PKGNAME_TO_DIR[$dep]}")
        fi
    done
    DEP_MAP["$pkg"]="${intra_deps[*]}"
done

topo_sort() {
    local pkg="$1"
    VISITED["$pkg"]=1

    for dep in ${DEP_MAP["$pkg"]}; do
        if [[ -z "${VISITED["$dep"]:-}" ]]; then
            topo_sort "$dep"
        fi
    done

    BUILD_ORDER+=("$pkg")
}

for pkg in "${PKGS[@]}"; do
    [[ -z "${VISITED["$pkg"]:-}" ]] && topo_sort "$pkg"
done

info "Build order: ${BUILD_ORDER[*]}"

for pkg in "${BUILD_ORDER[@]}"; do
    pkgdir="$PKGDIR_BASE/$pkg"
    info "Building package: $pkg"

    if [[ -f "$pkgdir/.noinstall" ]]; then
        sudo -u "$BUILD_USER" -H bash -c "cd '$pkgdir' && makepkg -scf --noconfirm"
    else
        sudo -u "$BUILD_USER" -H bash -c "cd '$pkgdir' && makepkg -scif --noconfirm"
    fi

    find "$pkgdir" -maxdepth 1 \( -name "*.pkg.tar.zst" -o -name "*.pkg.tar.zst.sig" \) -exec mv -v {} /mnt/pkgs/ \;
done

info "All done."
