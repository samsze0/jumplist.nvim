#!/usr/bin/env bash

set -euo pipefail

# Fallback to "nvim"
NVIM_EXEC="${NVIM_EXEC:-nvim}"

MINI_TEST_DIR=".tests/mini.test"

# Test if mini.test exists in .tests, it not, clone it
if [ ! -d "$MINI_TEST_DIR" ]; then
    echo "Cloning MiniTest into $MINI_TEST_DIR..."
    # Clone the stable branch
    git clone https://github.com/echasnovski/mini.test $MINI_TEST_DIR --branch stable
fi

for nvim_exec in $NVIM_EXEC; do
    printf "\n======\n\n"
    $nvim_exec --version | head -n 1 && echo ''

    $nvim_exec --headless --noplugin \
        -c "set rtp+=$MINI_TEST_DIR" \
        -c "set rtp+=." \
        -c "lua require('mini.test').setup()" \
        -c "lua MiniTest.run({ execute = { reporter = MiniTest.gen_reporter.stdout({ group_depth = 1 }) } })"
done