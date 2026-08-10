#!/usr/bin/env bash
# Entry point inside the test container: run the full suite.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/../.."
make lint unit integration
