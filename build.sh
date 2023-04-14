#!/usr/bin/bash
zig build-lib ./source/flaxo.zig -target wasm32-freestanding -dynamic -rdynamic -O ReleaseSmall --export-table -mcpu generic
mv flaxo.wasm ./demo
rm flaxo.wasm.o
