const Bytes = @This();

data: []u8,
pos: u16 = 0,

pub fn init(data: []u8) Bytes {
    return Bytes{ .data = data };
}

pub fn getPtr(self: Bytes, comptime T: type, pos: u16) [*]align(1) T {
    return @ptrCast([*]align(1) T, self.data.ptr + pos);
}

pub fn getSlice(self: Bytes, start: usize, end: usize) []u8 {
    return self.data[start..end];
}

pub fn get(self: Bytes, comptime T: type, pos: u16) T {
    return self.getPtr(T, pos)[0];
}

pub fn set(self: *Bytes, comptime T: type, pos: u16, value: T) void {
    self.getPtr(T, pos)[0] = value;
}

pub fn read(self: *Bytes, comptime T: type) T {
    const result = self.get(T, self.pos);
    self.pos += @sizeOf(T);
    return result;
}

pub fn readBig(self: *Bytes, comptime T: type) T {
    const result = self.read(T);
    return @byteSwap(result);
}

pub fn peek(self: *Bytes, comptime T: type) T {
    return self.get(T, self.pos);
}

pub fn seek(self: *Bytes, pos: u16) void {
    self.pos = pos;
}

pub fn seekBy(self: *Bytes, offset: i16) void {
    self.pos += @bitCast(u16, offset);
}

pub fn eof(self: *Bytes) bool {
    return self.pos >= self.data.len;
}
