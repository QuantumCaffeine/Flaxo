const io = @import("io.zig");
const Header = @import("Header.zig");
var buffer: [65536]u8 = undefined;
var global_frame: @Frame(async_start) = undefined;

pub var version:u8 = 0;
pub const messages = @import("messages.zig");
pub const exits = @import("exits.zig");
pub const state = @import("state.zig");
pub const engine = @import("engine.zig");
pub const parser = @import("parser.zig");
const dictionary = @import("dictionary.zig");

export fn start(in_version:u8) void {
    version = in_version;
    global_frame = async async_start();
}

fn async_start() void {
    await async load(1);
    _ = async engine.run();
}

pub fn load(part:u8) void {
    var frame = async io.file.load(part, &buffer);
    var data = await frame;
    var header = Header.init(version, data);
    messages.init(header);
    exits.init(header);
    state.init(header);
    engine.init(header);
    parser.init(header);
    // var test_message: u16 = 0;
    // while (test_message < 4398) : (test_message += 1) {
    //     messages.printMessageV3(test_message, &io.output);
    //     io.output.flush();
    // }
}
