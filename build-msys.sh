#!/usr/bin/env bash

set -Eeuo pipefail
IFS=$'\n\t'

if [[ -z "${DEVKITPRO:-}" && -d /opt/devkitpro ]]; then
    DEVKITPRO=/opt/devkitpro
fi
if [[ -z "${DEVKITARM:-}" && -d /opt/devkitpro/devkitARM ]]; then
    DEVKITARM=/opt/devkitpro/devkitARM
fi
export DEVKITPRO DEVKITARM

if [[ -d /opt/devkitpro/tools/bin ]]; then
    PATH="/opt/devkitpro/tools/bin:$PATH"
fi
if [[ -d /opt/devkitpro/devkitARM/bin ]]; then
    PATH="/opt/devkitpro/devkitARM/bin:$PATH"
fi
export PATH

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
PROJECT="${PROJECT:-$SCRIPT_DIR}"
BUILD_ROOT="${BUILD_ROOT:-$HOME/balatro3ds-build}"
DIST_DIR="${DIST_DIR:-$PROJECT/dist}"

LOVEPOTION_VERSION="${LOVEPOTION_VERSION:-3.0.2}"
LOVEPOTION_ID="${LOVEPOTION_ID:-8c7140b}"
LOVE_ZIP="$BUILD_ROOT/Nintendo.3DS-${LOVEPOTION_ID}.zip"
LOVE_URL="https://github.com/lovebrew/lovepotion/releases/download/${LOVEPOTION_VERSION}/Nintendo.3DS-${LOVEPOTION_ID}.zip"

GAME_DIR="$BUILD_ROOT/build/game"
METADATA="$BUILD_ROOT/build/metadata.smdh"
BASE_3DSX="$BUILD_ROOT/build/base.3dsx"
LOVE_FILE="$BUILD_ROOT/build/balatro.love"
FINAL_3DSX="$BUILD_ROOT/build/Balatro3DS.3dsx"
FONT_DIR="$GAME_DIR/resources/fonts"

die() {
    printf 'ERROR: %s\n' "$*" >&2
    exit 1
}

usage() {
    cat <<'EOF'
Usage: ./build-msys.sh [prepare|build|clean]

  prepare  Download/extract LovePotion and clone its source tree.
  build    Prepare dependencies, then build dist/Balatro3DS.3dsx (default).
  clean    Remove this script's external build directory and dist output.
EOF
}

require_command() {
    command -v "$1" >/dev/null 2>&1 || die "Required command not found: $1"
}

check_environment() {
    [[ -f "$PROJECT/main.lua" ]] || die "Project path is incorrect: $PROJECT"
    [[ -f "$PROJECT/resources/textures/1x/icon.png" ]] || die "Project icon not found"

    for tool in git curl unzip zip tar find tex3ds mkbcfnt smdhtool 3dsxtool; do
        require_command "$tool"
    done

    [[ -n "${DEVKITPRO:-}" ]] || die 'DEVKITPRO is not set. Run this from the devkitPro MSYS terminal.'
}

prepare_lovepotion() {
    mkdir -p "$BUILD_ROOT"

    if [[ ! -f "$BUILD_ROOT/lovepotion.elf" ]]; then
        printf 'Downloading LovePotion %s...\n' "$LOVEPOTION_VERSION"
        curl -fL --retry 3 -o "$LOVE_ZIP" "$LOVE_URL"
        unzip -o "$LOVE_ZIP" -d "$BUILD_ROOT"
    fi

    [[ -f "$BUILD_ROOT/lovepotion.elf" ]] || die "LovePotion ELF not found in $BUILD_ROOT"

    if [[ ! -d "$BUILD_ROOT/lovepotion/platform/ctr/romfs" ]]; then
        if [[ -e "$BUILD_ROOT/lovepotion" ]]; then
            die "Existing LovePotion checkout has no CTR romfs: $BUILD_ROOT/lovepotion"
        fi
        printf 'Cloning LovePotion source %s...\n' "$LOVEPOTION_VERSION"
        git clone --depth 1 --branch "$LOVEPOTION_VERSION" \
            https://github.com/lovebrew/lovepotion.git "$BUILD_ROOT/lovepotion"
    fi

    [[ -d "$BUILD_ROOT/lovepotion/platform/ctr/romfs" ]] || \
        die "LovePotion CTR romfs not found"
}

copy_project() {
    [[ "$BUILD_ROOT" == "$HOME/balatro3ds-build" ]] || \
        die "Refusing to clean unexpected BUILD_ROOT: $BUILD_ROOT"

    rm -rf "$GAME_DIR"
    mkdir -p "$GAME_DIR"

    tar --exclude=.git --exclude=dist --exclude=build-msys.sh -C "$PROJECT" -cf - . \
        | tar -C "$GAME_DIR" -xf -

    [[ -f "$GAME_DIR/main.lua" ]] || die 'Project copy did not contain main.lua'
}

convert_resources() {
    local file output

    while IFS= read -r -d '' file; do
        output="${file%.png}.t3x"
        tex3ds -f rgba "$file" -o "$output"
        rm -f "$file"
    done < <(find "$GAME_DIR" -type f -name '*.png' -print0)

    # These fonts are not used by the current game and make the package much larger.
    rm -f \
        "$FONT_DIR/GoNotoCJKCore.ttf" \
        "$FONT_DIR/GoNotoCurrent-Bold.ttf" \
        "$FONT_DIR/NotoSans-Bold.ttf" \
        "$FONT_DIR/NotoSansJP-Bold.ttf" \
        "$FONT_DIR/NotoSansKR-Bold.ttf" \
        "$FONT_DIR/NotoSansTC-Bold.ttf"

    [[ -f "$FONT_DIR/m6x11plus.ttf" ]] || die 'English font not found'
    rm -f "$FONT_DIR/m6x11plus.bcfnt"
    mkbcfnt "$FONT_DIR/m6x11plus.ttf" -o "$FONT_DIR/m6x11plus.bcfnt"
    [[ -f "$FONT_DIR/m6x11plus.bcfnt" ]] || die 'English font conversion failed'
    rm -f "$FONT_DIR/m6x11plus.ttf"

    # NotoSansSC-Bold.ttf is intentionally retained. The current mkbcfnt build
    # crashes on the complete CJK font, and the game can load the TTF directly.
    [[ -f "$FONT_DIR/NotoSansSC-Bold.ttf" ]] || die 'Simplified Chinese font not found'

    local remaining
    remaining="$(find "$GAME_DIR" -type f \( -name '*.png' -o \( -name '*.ttf' ! -name 'NotoSansSC-Bold.ttf' \) \) -print -quit)"
    [[ -z "$remaining" ]] || die "Unconverted resource remains: $remaining"
}

build_package() {
    mkdir -p "$BUILD_ROOT/build" "$DIST_DIR"

    smdhtool --create \
        'Balatro3DS' \
        'A Remake of Balatro for the 3DS' \
        'Gazpacho' \
        "$PROJECT/resources/textures/1x/icon.png" \
        "$METADATA"

    3dsxtool \
        "$BUILD_ROOT/lovepotion.elf" \
        "$BASE_3DSX" \
        --smdh="$METADATA" \
        --romfs="$BUILD_ROOT/lovepotion/platform/ctr/romfs"

    rm -f "$LOVE_FILE" "$FINAL_3DSX"
    (cd "$GAME_DIR" && zip -qr "$LOVE_FILE" .)
    unzip -t "$LOVE_FILE" >/dev/null
    cat "$BASE_3DSX" "$LOVE_FILE" > "$FINAL_3DSX"

    [[ -s "$FINAL_3DSX" ]] || die 'Final 3DSX was not created'
    cp -f "$FINAL_3DSX" "$DIST_DIR/Balatro3DS.3dsx"

    printf '\nBuild complete:\n%s\n' "$DIST_DIR/Balatro3DS.3dsx"
    ls -lh "$DIST_DIR/Balatro3DS.3dsx" "$LOVE_FILE"
}

clean() {
    [[ "$BUILD_ROOT" == "$HOME/balatro3ds-build" ]] || \
        die "Refusing to clean unexpected BUILD_ROOT: $BUILD_ROOT"
    rm -rf "$BUILD_ROOT" "$DIST_DIR"
    printf 'Removed %s and %s\n' "$BUILD_ROOT" "$DIST_DIR"
}

main() {
    local action="${1:-build}"

    case "$action" in
        prepare)
            check_environment
            prepare_lovepotion
            ;;
        build)
            check_environment
            prepare_lovepotion
            copy_project
            convert_resources
            build_package
            ;;
        clean)
            clean
            ;;
        -h|--help|help)
            usage
            ;;
        *)
            usage >&2
            exit 2
            ;;
    esac
}

main "$@"
