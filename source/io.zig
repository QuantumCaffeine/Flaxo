extern fn output_message([*]u8, u16) void;

pub var output_buffer: [1000]u8 = undefined;
pub var len: u16 = 0;

pub fn printChar(char: u8) void {
    output_buffer[len] = char;
    len += 1;
}

pub fn printNumber(n: u16) void {
    var num = n;
    var digit_value: u8 = 1;
    while (10 * digit_value <= num) digit_value *= 10;
    while (digit_value > 0) {
        var digit: u8 = @truncate(u8, num / digit_value);
        printChar(digitToAscii(digit));
        num -= digit * digit_value;
        digit_value /= 10;
    }
}

fn digitToAscii(n: u8) u8 {
    return n + 48;
}

pub fn extend(length: u16) void {
    len = length;
}

pub fn flush() void {
    output_message(&output_buffer, len);
    len = 0;
}
