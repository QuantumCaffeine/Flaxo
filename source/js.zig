pub extern fn console_log(value: usize) void;
pub extern fn log_char(char: u8) void;
pub extern fn read_input([*]u8, u16, fn (u16) void) callconv(.Inline) void;
pub extern fn JSLoad(u8, [*]u8, fn (u16) void) callconv(.Inline) void;
pub extern fn output_message([*]u8, usize) void;
pub extern fn log_message([*]u8, usize) void;
pub extern fn random_bits(u8) usize;
pub extern fn display_bitmap(u16, u16, u16) void;
pub extern fn toggle_image(u16, u16) void;

pub fn write(buffer: []u8) void {
    output_message(buffer.ptr, buffer.len);
}

var stored_frame: anyframe = undefined;
var chars_read: u16 = 0;

pub fn read(buffer: [*]u8, size: u16) u16 {
    suspend {
        stored_frame = @frame();
        read_input(buffer, size, read_complete);
    }
    return chars_read;
}

pub fn read_complete(bytes_read: u16) void {
    chars_read = bytes_read;
    resume stored_frame;
}
