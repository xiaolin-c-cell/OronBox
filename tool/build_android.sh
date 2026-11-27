#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/build_common.sh"

FORMAT="all"
ABIS=(arm64-v8a armeabi-v7a x86_64)
COMMON_ARGS=()

print_help() {
  cat <<EOF
Usage: $(basename "$0") [options]

Options:
  --format <apk|appbundle|all>  Only build the given package format (default: all)
  --abi <abi>                   Only build APKs for the given ABI:
                                arm64-v8a, armeabi-v7a, x86_64 (default: all)
                                Ignored for appbundle, which always contains every ABI
  --dev                         Allow a dirty worktree and append git metadata to the package version
  -h, --help                    Show this help
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --format)
      FORMAT="${2:?--format requires a value}"
      shift 2
      ;;
    --format=*)
      FORMAT="${1#*=}"
      shift
      ;;
    --abi)
      ABIS=("${2:?--abi requires a value}")
      shift 2
      ;;
    --abi=*)
      ABIS=("${1#*=}")
      shift
      ;;
    -h|--help)
      print_help
      exit 0
      ;;
    *)
      COMMON_ARGS+=("$1")
      shift
      ;;
  esac
done

case "${FORMAT}" in
  apk|appbundle|all) ;;
  *)
    log_error "Unknown format: ${FORMAT} (expected apk, appbundle or all)"
    exit 1
    ;;
esac

target_platform_for_abi() {
  case "$1" in
    arm64-v8a) echo "android-arm64" ;;
    armeabi-v7a) echo "android-arm" ;;
    x86_64) echo "android-x64" ;;
    *)
      log_error "Unknown ABI: $1 (expected arm64-v8a, armeabi-v7a or x86_64)"
      exit 1
      ;;
  esac
}

init_build "${COMMON_ARGS[@]}"
log_info "Building Android release packages for version ${VERSION} (format=${FORMAT}, abi=$(IFS=,; echo "${ABIS[*]}"))"

require_flutter
setup_android_signing
ensure_release_dir

DART_DEFINES=()
while IFS= read -r define; do
  DART_DEFINES+=("${define}")
done < <(flutter_release_defines)
BUILD_NUMBER="$(build_number_or_default)"

if [[ "${FORMAT}" == "apk" || "${FORMAT}" == "all" ]]; then
  TARGET_PLATFORMS=()
  for abi in "${ABIS[@]}"; do
    TARGET_PLATFORMS+=("$(target_platform_for_abi "${abi}")")
  done

  run_cmd flutter build apk \
    --release \
    --split-per-abi \
    --target-platform="$(IFS=,; echo "${TARGET_PLATFORMS[*]}")" \
    --obfuscate \
    --split-debug-info=symbols/android-apk \
    --build-name="${VERSION}" \
    --build-number="${BUILD_NUMBER}" \
    "${DART_DEFINES[@]}"

  ANDROID_APK_DIR="${PROJECT_ROOT}/build/app/outputs/flutter-apk"
  for abi in "${ABIS[@]}"; do
    copy_artifact \
      "${ANDROID_APK_DIR}/app-${abi}-release.apk" \
      "${RELEASE_DIR}/${APP_NAME}-${VERSION}-android-${abi}.apk"
  done

  archive_symbols_if_present \
    "${PROJECT_ROOT}/symbols/android-apk" \
    "${RELEASE_DIR}/${APP_NAME}-${VERSION}-android-apk.symbols.tar.gz"
fi

if [[ "${FORMAT}" == "appbundle" || "${FORMAT}" == "all" ]]; then
  run_cmd flutter build appbundle \
    --release \
    --obfuscate \
    --split-debug-info=symbols/android-appbundle \
    --build-name="${VERSION}" \
    --build-number="${BUILD_NUMBER}" \
    "${DART_DEFINES[@]}"

  copy_artifact \
    "${PROJECT_ROOT}/build/app/outputs/bundle/release/app-release.aab" \
    "${RELEASE_DIR}/${APP_NAME}-${VERSION}-android-appbundle.aab"

  archive_symbols_if_present \
    "${PROJECT_ROOT}/symbols/android-appbundle" \
    "${RELEASE_DIR}/${APP_NAME}-${VERSION}-android-appbundle.symbols.tar.gz"
fi

log_info "Android build complete"
