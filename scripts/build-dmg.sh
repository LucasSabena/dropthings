#!/usr/bin/env bash
# Legacy convenience wrapper. New releases should use scripts/release.sh
# which also signs, notarizes, and generates the Sparkle appcast.

set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
exec "$PROJECT_ROOT/scripts/release.sh" "$@"
