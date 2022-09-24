#!/usr/bin/bash

MODULES="lexer parser"

FILES=$(
    for module in $MODULES; do
        echo "spec/${module}_spec.rb"
    done
)

rspec $FILES --fail-fast
