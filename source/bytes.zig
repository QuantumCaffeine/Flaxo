pub const Bytes = struct {
    data: [*]u8,

    pub fn init(data: [*]u8) Bytes {
        return Bytes{ .data = data };
    }

    pub fn getByte(self: *Bytes, pos: u16) u8 {
        return self.data[pos];
    }

    pub fn setByte(self: *Bytes, pos: u16, value: u8) void {
        self.data[pos] = value;
    }

    pub fn getShort(self: *Bytes, pos: u16) u16 {
        //return self.data[pos] | (@as(u16, self.data[pos + 1]) << 8);
        return @ptrCast(*align(1) u16, &self.data[pos]).*;
    }

    fn setShort(self: *Bytes, pos: u16, value: u16) void {
        @ptrCast(*align(1) u16, &self.data[pos]).* = value;
    }
};
