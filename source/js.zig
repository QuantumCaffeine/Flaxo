const BufferedWriter = @import("BufferedWriter.zig");
var output_buffer: [1000]u8 = undefined;

pub extern fn console_log(value: usize) void;
pub extern fn log_char(char: u8) void;
pub extern fn read_input([*]u8, usize, *const fn (u16) void) void;
pub extern fn JSLoad(u8, [*]u8, *const fn (u16) void) void;
pub extern fn output_message([*]u8, usize) void;
pub extern fn log_message([*]u8, usize) void;
pub extern fn random_bits(u8) usize;
pub extern fn display_bitmap(u16, u16, u16) void;
pub extern fn toggle_image(u16, u16) void;

pub fn write(buffer: []u8) void {
    output_message(buffer.ptr, buffer.len);
}

var read_callback: *const fn([]u8) void = undefined;
var read_buffer: []u8 = undefined;

pub fn read(buffer: []u8, callback: *const fn([]u8) void) void {
    read_callback = callback;
    read_buffer = buffer;
    read_input(buffer.ptr, buffer.len, &readComplete);
}

fn readComplete(bytes_read: u16) void {
    read_callback(read_buffer[0..bytes_read]);
}

var load_callback: *const fn ([]u8) void = undefined;
var load_buffer: [*]u8 = undefined;

pub fn load(part: u8, buffer: [*]u8, callback: *const fn([]u8) void) void {
    load_callback = callback;
    load_buffer = buffer;
    JSLoad(part, buffer, &loadComplete);
}

fn loadComplete(size: u16) void {
    load_callback(load_buffer[0..size]);
}

pub const log = struct {
    pub fn write(n: usize) void {
        console_log(n);
    }
};

pub var output = BufferedWriter.init(&output_buffer, write);
