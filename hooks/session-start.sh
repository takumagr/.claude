#!/bin/bash
set -euo pipefail

# Install PaddleOCR (and PaddlePaddle) so it's available in every
# Claude Code on the web session. Only runs in remote environments.
if [ "${CLAUDE_CODE_REMOTE:-}" != "true" ]; then
  exit 0
fi

# Idempotent: skip the (heavy) install if it's already present.
if python3 -c "import paddle, paddleocr" >/dev/null 2>&1; then
  exit 0
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REQ_FILE="$SCRIPT_DIR/../requirements.txt"

# The base image ships PyYAML as a Debian package without a pip RECORD
# file, which makes pip fail to upgrade it. Ignore it so the rest of the
# dependency tree can install cleanly.
pip3 install --no-input --ignore-installed PyYAML -r "$REQ_FILE"
