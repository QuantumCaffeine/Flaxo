const js = @import("js.zig");
const BufferedWriter = @import("BufferedWriter.zig");

pub const file = @import("file.zig");
pub const input = @import("input.zig");
pub const log = @import("log.zig");

var output_buffer: [1000]u8 = undefined;
pub var output = BufferedWriter.init(&output_buffer, js.write);
