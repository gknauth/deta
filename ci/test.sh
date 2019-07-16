#!/usr/bin/env bash

set -euo pipefail

pushd /github/workspace
raco pkg install --auto --batch deta-lib/ deta-doc/ deta-test/
raco test -j 4 deta-test/
