const js = @import("js.zig");

pub fn write(number: usize) void {
    js.console_log(number);
}

pub fn writeString(string: []u8) void {
    js.log_message(string.ptr, string.len);
}