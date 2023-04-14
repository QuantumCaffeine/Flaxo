const mem = @import("std").mem;
pub var vars: [256]u16 = undefined;

pub fn clearVars() void {
    //@memset(@ptrCast([*]u8, &vars), 0, 512);
    mem.set(u16, &vars, 0);
}
