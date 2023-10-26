const Bytes = @import("Bytes.zig");
const Header = @import("Header.zig");

const TableEntry = packed struct {
//const TableEntry = packed struct(u16) {
    exit: u4,
    flags: u3,
    last_exit: bool,
    dest: u8
};

pub const Exit = struct { room: u8, flags: u8 };

const reverse = [_]u8{ 0x00, 0x04, 0x06, 0x07, 0x01, 0x08, 0x02, 0x03, 0x05, 0x0A, 0x09, 0x0C, 0x0B, 0xFF, 0xFF, 0x0F };

var exits: [256][16]Exit = undefined;

pub fn init(header: Header) void {
    var r:usize = 0;
    while (r < 256) : (r += 1) {
        var e: usize = 0;
        while (e < 16) : (e += 1) {
            exits[r][e] = Exit{.room = 0, .flags = 0};
        } 
    }
    var table = Bytes.init(header.exit_table);
    var room: u8 = 1;
    while (true) {
        const entry = table.read(TableEntry);
        if (@as(u16, @bitCast(entry)) == 0) break;
        exits[room][entry.exit] = Exit{ .flags = entry.flags, .room = entry.dest };
        if ((entry.flags & 0x1) == 1) {
            const reverse_exit = reverse[entry.exit];
            if (reverse_exit != 0xFF and (exits[entry.dest][reverse_exit].room == 0))
                exits[entry.dest][reverse_exit] = Exit{ .flags = entry.flags, .room = room };
        }
        if (entry.last_exit) room += 1;
    }
}

pub fn get(room: u16, exit: u16) Exit {
    return exits[room][exit];
}
