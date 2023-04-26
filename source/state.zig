const mem = @import("std").mem;
const Header = @import("Header.zig");
const js = @import("js.zig");

pub var vars: [256]u16 = undefined;
pub var lists: [32][]u8 = undefined;

var list_area: [0x800]u8 = undefined;

pub fn init(header: Header) void {
    for (header.list_table) |pos, n| {
        //js.console_log(pos);
        //js.console_log(n);
        lists[n] = if (pos >= 0x8000) list_area[pos - 0x8000 ..] else header.data[pos..];
    }
}

pub fn clearVars() void {
    mem.set(u16, &vars, 0);
}
