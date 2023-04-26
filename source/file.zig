const js = @import("js.zig");

var bytes_loaded: u16 = 0;
var stored_frame: anyframe = undefined;

pub fn load(part: u8, buffer: [*]u8) []u8 {
    suspend {
        stored_frame = @frame();
        js.JSLoad(part, buffer, loadComplete);
    }
    return buffer[0..bytes_loaded];
}

fn loadComplete(size: u16) void {
    bytes_loaded = size;
    resume stored_frame;
}
