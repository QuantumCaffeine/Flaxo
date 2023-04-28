#!/usr/bin/bash
zig build-lib ./source/l9.zig -target wasm32-freestanding -dynamic -fstage1 -O Debug --export-table --stack 1024 -mcpu generic+bulk_memory+tail_call
mv l9.wasm ./demo
rm l9.wasm.o
