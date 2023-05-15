#!/usr/bin/bash
zig build-lib ./source/l9.zig -target wasm32-freestanding -dynamic -fstage1 -O ReleaseSmall --export-table --stack 4096 -mcpu generic+bulk_memory+tail_call
mv l9.wasm ./demo
#rm l9.wasm.o
