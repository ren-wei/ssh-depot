#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

case "$(uname -s)" in
  Darwin)
    exec "${script_dir}/install-for-macos.sh" "$@"
    ;;
  Linux)
    exec "${script_dir}/install-for-linux.sh" "$@"
    ;;
  *)
    echo "Unsupported operating system: $(uname -s)" >&2
    echo "Supported operating systems: macOS, Linux" >&2
    exit 1
    ;;
esac
