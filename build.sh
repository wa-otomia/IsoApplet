#!/usr/bin/env bash
# Build IsoApplet.cap inside a Docker container.
#
# All toolchains (JDK 8, Ant, JavaCard SDK) live inside the image.
# The host filesystem is untouched apart from the resulting ./out/IsoApplet.cap.
#
# Usage:
#   ./build.sh                       # default build (KEY_MAX_COUNT=16)
#   ./build.sh -k 32                 # KEY_MAX_COUNT=32
#   ./build.sh --key-max-count 64    # same, long form
#   ./build.sh -h                    # help
set -euo pipefail

KEY_MAX_COUNT=16

usage() {
    cat <<EOF
Usage: $(basename "$0") [options]

Options:
  -k, --key-max-count N    Override the maximum number of stored keys.
                           Default: 16. Must be a positive integer.
  -h, --help               Show this help.

Output:
  ./out/IsoApplet.cap
EOF
}

while [ $# -gt 0 ]; do
    case "$1" in
        -k|--key-max-count)
            KEY_MAX_COUNT="${2:?missing value for $1}"
            shift 2
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            echo "Unknown argument: $1" >&2
            usage >&2
            exit 1
            ;;
    esac
done

if ! [[ "${KEY_MAX_COUNT}" =~ ^[0-9]+$ ]] || [ "${KEY_MAX_COUNT}" -lt 1 ]; then
    echo "KEY_MAX_COUNT must be a positive integer (got '${KEY_MAX_COUNT}')" >&2
    exit 1
fi

cd "$(dirname "$0")"

# Make sure the JavaCard SDK submodule is populated before the Docker copy.
if [ ! -f ext/sdks/jc310r20210706_kit/lib/tools.jar ]; then
    echo "==> Initializing ext/sdks submodule"
    git submodule update --init --recursive
fi

IMAGE_TAG="isoapplet-builder:k${KEY_MAX_COUNT}"

echo "==> Building image ${IMAGE_TAG} (KEY_MAX_COUNT=${KEY_MAX_COUNT})"
docker build \
    --build-arg KEY_MAX_COUNT="${KEY_MAX_COUNT}" \
    --target builder \
    -t "${IMAGE_TAG}" \
    .

mkdir -p out
OUT_NAME="IsoApplet.cap"
if [ "${KEY_MAX_COUNT}" -ne 16 ]; then
    OUT_NAME="IsoApplet-k${KEY_MAX_COUNT}.cap"
fi

echo "==> Extracting ${OUT_NAME}"
docker run --rm -v "$(pwd)/out:/out" "${IMAGE_TAG}" \
    bash -c "cp /build/IsoApplet/IsoApplet.cap /out/${OUT_NAME} && ls -l /out/${OUT_NAME}"

echo
echo "Done. Artifact: $(pwd)/out/${OUT_NAME}"
