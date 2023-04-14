const engine = @import("engine.zig");
const Bytes = @import("bytes.zig").Bytes;
const messages = @import("messages.zig");
extern fn JSLoad(u8, [*]u8, *const fn () void) void;
extern fn console_log(value: usize) void;

pub var data: [65536]u8 = undefined;

pub const Exit = struct { room: u8, flags: u8 };
pub var exits: [256][16]Exit = undefined;

var version: u8 = undefined;
pub var code_start: [*]u8 = undefined;

pub export var lists: [32][*]align(1) u16 = undefined;
var list_area: [0x800 * 2]u16 = undefined;

pub fn init(game_version: u8) void {
    version = game_version;
}

var game_engine: engine.Engine = undefined;
var game_data: Bytes = undefined;

pub fn load(part: u8) void {
    JSLoad(part, &data, loadComplete);
}

fn loadComplete() void {
    game_data = Bytes.init(&data);
    messages.init(version, game_data);
    setup();
    game_engine = engine.Engine.init(code_start);
    game_engine.run();
}

export fn setup() void {
    buildExitTable();
    buildListTable();
    var code_offset = if (version <= 2) game_data.getShort(26) else game_data.getShort(40);
    code_start = &data;
    code_start += code_offset;
}

const reverse = [_]u8{ 0x00, 0x04, 0x06, 0x07, 0x01, 0x08, 0x02, 0x03, 0x05, 0x0a, 0x09, 0x0c, 0x0b, 0xff, 0xff, 0x0f };

fn buildExitTable() void {
    var pos: u16 = if (version <= 2) game_data.getShort(4) else game_data.getShort(18);
    var room: u8 = 1;
    while (true) {
        var exit_no: u8 = game_data.getByte(pos);
        pos += 1;
        var dest: u8 = game_data.getByte(pos);
        pos += 1;
        if ((exit_no == 0) and (dest == 0)) break;
        var flags: u8 = (exit_no & 0x70) >> 4;
        var exit: u8 = exit_no & 0x0F;
        exits[room][exit] = Exit{ .flags = flags, .room = dest };
        if (((flags & 0x1) != 0) and (exit != 13) and (exit != 14)) {
            var reverse_exit = reverse[exit];
            if (exits[dest][reverse_exit].room == 0)
                exits[dest][reverse_exit] = Exit{ .flags = flags, .room = room };
        }
        if ((exit_no & 0x80) != 0) room += 1;
    }
}

fn buildListTable() void {
    var list_offset: u16 = if (version <= 2) 0x06 else 0x14;
    var n: u8 = 0;
    while (n < 32) : (n += 1) {
        var pos = game_data.getShort(list_offset + (n << 1));
        if (pos >= 0x8000) {
            pos -= 0x8000;
            lists[n] = &list_area;
        } else {
            lists[n] = @ptrCast([*]align(1) u16, &data);
        }
        lists[n] += pos;
    }
}
