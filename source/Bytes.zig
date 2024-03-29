const js = @import("js.zig");
const Bytes = @This();

data: []u8,
pos: u16 = 0,

pub fn init(data: []u8) Bytes {
    const result = Bytes{ .data = data };
    return result;
}

pub fn getPtr(self: Bytes, comptime T: type, pos: u16) [*]align(1) T {
    const result: [*]align(1) T = @ptrCast(self.data.ptr + pos);
    return result;
}

pub fn getSinglePtr(self: Bytes, comptime T: type, pos: u16) *align(1) T {
    const result: *align(1) T = @ptrCast(self.data.ptr + pos);
    return result;
}

pub fn getSlice(self: Bytes, start: usize, end: usize) []u8 {
    return self.data[start..end];
}

pub fn readSlice(self: *Bytes, length: u16) []u8 {
    const slice = self.data[self.pos..self.pos+length];
    self.pos += length;
    return slice;
}

pub fn get(self: Bytes, comptime T: type, pos: u16) T {
    const ptr = self.getPtr(T, pos);
    return ptr[0];
}

pub fn getBig(self: Bytes, comptime T: type, pos: u16) T {
    return @byteSwap(self.get(T, pos));
}

pub fn set(self: *Bytes, comptime T: type, pos: u16, value: T) void {
    self.getPtr(T, pos)[0] = value;
}

pub fn read(self: *Bytes, comptime T: type) T {
    const result = self.get(T, self.pos);
    self.pos += @sizeOf(T);
    return result;
}

pub fn readString(self: *Bytes) []u8 {
    const start = self.pos;
    while (self.data[self.pos] != 0) self.pos += 1;
    const end = self.pos;
    self.pos += 1;
    return self.data[start..end];
}

pub fn readBig(self: *Bytes, comptime T: type) T {
    const result = self.read(T);
    return @byteSwap(result);
}

pub fn write(self: *Bytes, comptime T: type, value: T) void {
    self.set(T, self.pos, value);
    self.pos += @sizeOf(T);
}

pub fn writeBig(self: *Bytes, comptime T: type, value: T) void {
    self.set(T, self.pos, @byteSwap(value));
    self.pos += @sizeOf(T);
}

pub fn peek(self: *Bytes, comptime T: type) T {
    return self.get(T, self.pos);
}

pub fn seek(self: *Bytes, pos: u16) void {
    self.pos = pos;
}

pub fn seekBy(self: *Bytes, offset: i16) void {
    self.pos += @bitCast(offset);
}

pub fn eof(self: *Bytes) bool {
    return self.pos >= self.data.len;
}
