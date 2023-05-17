#!/usr/bin/bash
zig build-lib ./source/l9.zig -target wasm32-freestanding -dynamic -rdynamic -O Debug --stack 100000 --export-table -mcpu generic+mutable_globals+bulk_memory+multivalue+extended_const+sign_ext
mv l9.wasm ./demo
rm l9.wasm.o
