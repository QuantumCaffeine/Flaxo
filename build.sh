#!/usr/bin/bash
zig build-lib ./source/flaxo.zig -target wasm32-freestanding -dynamic -rdynamic -O ReleaseSmall --global-base=1000 --initial-memory=1310720 --export-table -mcpu generic+mutable_globals+bulk_memory+multivalue+extended_const+sign_ext
mv flaxo.wasm ./demo
rm flaxo.wasm.o
