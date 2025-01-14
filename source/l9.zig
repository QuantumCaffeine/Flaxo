const io = @import("js.zig");
const Header = @import("Header.zig");
var buffer: [65536]u8 = undefined;

pub var version:u8 = 0;
pub const messages = @import("messages.zig");
pub const exits = @import("exits.zig");
pub const state = @import("state.zig");
pub const engine = @import("engine.zig");
pub const parserV3 = @import("parserV3.zig");
pub const parserV1 = @import("parserV1.zig");
pub const dictionary = @import("dictionary.zig");
const WordList = @import("WordList.zig");

export fn start(in_version: u8) void {
    version = in_version;
    load(1);
}

var input_buffer: [256]u8 = undefined;

fn run() void {
    while (true) {
        switch(engine.run()) {
            .LoadGame => |part| {
                load(part);
                break;
            },
            .GetInput => {
                io.output.flush();
                io.read(input_buffer[0..input_buffer.len], &handle_input);
                break;
            },
            .GetCharInput => {},
            else => |value| {
                io.log.write(@intFromEnum(value));
                break;
            }
        }
    }
}

pub fn load(part:u8) void {
    io.load(part, &buffer, &handle_load);
}

fn handle_load(data: []u8) void {
    const header = Header.init(version, data);
    messages.init(header);
    exits.init(header);
    state.init(header);
    engine.init(header);
    if (version <= 2) parserV1.init(header)
    else parserV3.init(header);
    run();
}

fn handle_input(input: []u8) void {
    engine.handle_input(input);
    run();
}

