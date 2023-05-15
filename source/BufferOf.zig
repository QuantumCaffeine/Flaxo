pub fn BufferOf(comptime T: type) type {
    return struct {
        buffer: [*]T = undefined,
        pos: usize = 0,

        const Self = @This();

        pub fn init(buffer: [*]T) Self {
            return Self{.buffer = buffer};
        }

        pub fn append(self: *Self, value: T) void {
            self.buffer[self.pos] = value;
            self.pos += 1;
        }

        pub fn tail(self: *Self) T {
            return self.buffer[self.pos - 1];
        }
    };
}
