const BufferedWriter = @This();
const io = @import("io.zig");

buffer: []u8,
unbufferedWrite: *const fn ([]u8) void,
pos: usize = 0,

pub fn init(buffer: []u8, unbufferedWriteFn: *const fn ([]u8) void) BufferedWriter {
    return BufferedWriter{ .buffer = buffer, .unbufferedWrite = unbufferedWriteFn };
}

pub fn writeChar(self: *BufferedWriter, char: u8) void {
    self.flushIfOverfull(self.pos + 1);
    self.buffer[self.pos] = char;
    self.pos += 1;
}

pub fn writeString(self: *BufferedWriter, string: []const u8) void {
    self.flushIfOverfull(self.pos + string.len);
    for (string, 0..) |char, i| {
        self.buffer[self.pos + i] = char;
    }
    self.pos += string.len;
}

pub fn writeNumber(self: *BufferedWriter, n: u16) void {
    self.flushIfOverfull(self.pos + 5);
    var num = n;
    var digit_value: u8 = 1;
    while (10 * digit_value <= num) digit_value *= 10;
    while (digit_value > 0) {
        const digit: u8 = @truncate(num / digit_value);
        self.writeChar(digitToAscii(digit));
        num -= digit * digit_value;
        digit_value /= 10;
    }
}

fn digitToAscii(n: u8) u8 {
    return n + 48;
}

fn flushIfOverfull(self: *BufferedWriter, new_len: usize) void {
    if (new_len > self.buffer.len) self.flush();
}

pub fn flush(self: *BufferedWriter) void {
    if (self.pos > 0) {
        self.unbufferedWrite(self.buffer[0..self.pos]);
        self.pos = 0;
    }
}
