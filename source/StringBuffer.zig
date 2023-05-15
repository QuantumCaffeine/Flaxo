buffer: [*]u8,
pos: usize = 0,
start: usize = 0,

const Self = @This();

pub fn init(buffer: [*]u8) Self {
    return Self{.buffer = buffer};
}

pub fn begin(self: *Self) void {
    self.start = self.pos;
}

pub fn append(self: *Self, value: usize) void {
    self.buffer[self.pos] = @truncate(u7, value);
    self.pos += 1;
}

pub fn appendSlice(self: *Self, value: []u8) void {
    for (value) |char| {
        self.append(char);
    }
}

pub fn end(self: *Self) []u8 {
    return self.buffer[self.start..self.pos];
}

pub fn empty(self: *Self) bool {
    return self.pos == self.start;
}
