#!/bin/sh
# Delivery chain check: plan -> R package -> compare. Run from anywhere.
#   sh verify/chain/run.sh                         python and Rscript from PATH
#   PY=/path/to/python DS_RLIB=/path/to/rlib sh verify/chain/run.sh
set -e
HERE=$(cd "$(dirname "$0")" && pwd)
PY=${PY:-python}
"$PY" -I "$HERE/chain.py" plan "$@"
Rscript "$HERE/chain.R"
"$PY" -I "$HERE/chain.py" compare "$@"
