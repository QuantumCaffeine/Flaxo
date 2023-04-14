//const std = @import("std");
const game = @import("game.zig");

export fn start(version: u8) void {
    game.init(version);
    game.load(1);
}
