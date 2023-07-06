#!/usr/bin/bash

MODULES="lexer parser analyzer"

FILES=$(
    for module in $MODULES; do
        echo "spec/${module}_spec.rb"
    done
)

rspec $FILES --fail-fast