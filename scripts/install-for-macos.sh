#!/usr/bin/env bash
set -euo pipefail

project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
flutter_version="$(tr -d '[:space:]' < "${project_root}/.flutter-version")"

flutter_dir="${FLUTTER_INSTALL_DIR:-/usr/local/src/flutter}"
install_parent="$(dirname "${flutter_dir}")"
link_dir="${FLUTTER_LINK_DIR:-/usr/local/bin}"

ensure_macos() {
  if [[ "$(uname -s)" != "Darwin" ]]; then
    echo "This installer currently supports macOS only." >&2
    exit 1
  fi
}

detect_archive() {
  case "$(uname -m)" in
    arm64)
      flutter_arch="arm64"
      archive_name="flutter_macos_arm64_${flutter_version}-stable.zip"
      ;;
    x86_64)
      flutter_arch="x64"
      archive_name="flutter_macos_${flutter_version}-stable.zip"
      ;;
    *)
      echo "Unsupported macOS CPU architecture: $(uname -m)" >&2
      exit 1
      ;;
  esac

  archive="/tmp/${archive_name}"
  archive_url="https://storage.googleapis.com/flutter_infra_release/releases/stable/macos/${archive_name}"
}

detect_sha256() {
  sha_file="${project_root}/.flutter-sha256-macos-${flutter_arch}"
  if [[ -n "${FLUTTER_SHA256:-}" ]]; then
    flutter_sha256="${FLUTTER_SHA256}"
    return
  fi

  if [[ -f "${sha_file}" ]]; then
    flutter_sha256="$(tr -d '[:space:]' < "${sha_file}")"
    return
  fi

  case "${flutter_arch}:${flutter_version}" in
    arm64:3.44.8)
      flutter_sha256="c3d6fe95078f7001d947a31d42527de91d5bfe62e4cf444a1493a2e8f1fb199d"
      ;;
    x64:3.44.8)
      flutter_sha256="b2f765234217327a5859d046c9f3b167387b61da5408b5866ed448d905877c66"
      ;;
    *)
      cat >&2 <<EOF
No SHA-256 checksum configured for Flutter ${flutter_version} on macOS ${flutter_arch}.

Add it to:
  ${sha_file}

Or rerun with:
  FLUTTER_SHA256=<expected_sha256> $0
EOF
      exit 1
      ;;
  esac
}

ensure_required_tools() {
  missing_tools=()
  for tool in curl git shasum unzip; do
    if ! command -v "${tool}" >/dev/null 2>&1; then
      missing_tools+=("${tool}")
    fi
  done

  if (( ${#missing_tools[@]} > 0 )); then
    echo "Missing required tools: ${missing_tools[*]}" >&2
    echo "Install Xcode Command Line Tools, then rerun this script:" >&2
    echo "  xcode-select --install" >&2
    exit 1
  fi

  if ! xcode-select -p >/dev/null 2>&1; then
    echo "Xcode Command Line Tools are not installed." >&2
    echo "Run this command, finish the installer, then rerun this script:" >&2
    echo "  xcode-select --install" >&2
    exit 1
  fi
}

install_flutter() {
  if [[ -x "${flutter_dir}/bin/flutter" ]]; then
    current_version="$("${flutter_dir}/bin/flutter" --version --no-version-check | sed -n 's/^Flutter \([^ ]*\).*/\1/p' | head -n 1)"
    if [[ "${current_version}" == "${flutter_version}" ]]; then
      echo "Flutter ${flutter_version} already installed at ${flutter_dir}."
      return
    fi

    cat >&2 <<EOF
Flutter is already installed at ${flutter_dir}, but its version is ${current_version:-unknown}.
Expected version: ${flutter_version}

Set FLUTTER_INSTALL_DIR to another directory, or move the existing SDK before rerunning.
EOF
    exit 1
  fi

  curl -fL "${archive_url}" -o "${archive}"
  echo "${flutter_sha256}  ${archive}" | shasum -a 256 -c -

  tmp_extract_dir="$(mktemp -d)"
  unzip -q "${archive}" -d "${tmp_extract_dir}"

  if [[ -e "${flutter_dir}" ]]; then
    echo "${flutter_dir} already exists but does not contain a runnable Flutter SDK." >&2
    rm -rf "${tmp_extract_dir}"
    exit 1
  fi

  sudo mkdir -p "${install_parent}"
  sudo mv "${tmp_extract_dir}/flutter" "${flutter_dir}"
  rmdir "${tmp_extract_dir}"
}

install_flutter_link() {
  sudo mkdir -p "${link_dir}"
  sudo ln -sfn "${flutter_dir}/bin/flutter" "${link_dir}/flutter"
  sudo ln -sfn "${flutter_dir}/bin/dart" "${link_dir}/dart"
}

verify_flutter() {
  "${link_dir}/flutter" --version --no-version-check
  "${link_dir}/flutter" doctor -v
}

ensure_macos
detect_archive
detect_sha256
ensure_required_tools
install_flutter
install_flutter_link
verify_flutter

cat <<EOF

Development environment is ready.

Flutter is installed at:
  ${flutter_dir}

The flutter command is linked at:
  ${link_dir}/flutter

The dart command is linked at:
  ${link_dir}/dart

Then from the project root:
  flutter pub get
  flutter analyze
  flutter test
EOF
