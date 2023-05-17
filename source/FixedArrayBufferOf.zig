pub fn FixedArrayBufferOf(comptime T: type, comptime max_size: usize) type {
    return struct {
        pos: usize = 0,
        data: [max_size]T = undefined,

        const Self = @This();

        pub fn append(self: *Self, value: T) void {
            self.data[self.pos] = value;
            self.pos += 1;
        }

        pub fn full(self: Self) bool {
            return self.pos == self.data.len;
        }

        pub fn get(self: Self) []const T {
            return self.data[0..self.pos];
        }
    };
}