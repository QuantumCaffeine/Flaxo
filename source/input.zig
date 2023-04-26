const js = @import("js.zig");
pub var input_buffer: [256]u8 = undefined;

pub fn read() []u8 {
    const bytes_read = await async js.read(&input_buffer, input_buffer.len);
    return input_buffer[0..bytes_read];
}
