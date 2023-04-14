const Bytes = @import("bytes.zig").Bytes;
const io = @import("io.zig");

extern fn console_log(value: usize) void;

var message_table: [10000][]u8 = undefined;
var abbreviations: [162][16]u8 = undefined;
var num_messages: u16 = undefined;
var num_abbreviations: u16 = undefined;
var data: Bytes = undefined;
var version: u8 = undefined;

pub fn init(_version: u8, bytes: Bytes) void {
    @memset(@ptrCast([*]u8, &abbreviations), 0, 162 * 16);
    //mem.set(u8, @ptrCast([*]u8, &abbreviations), 0);
    version = _version;
    data = bytes;
    var pos: u16 = data.getShort(2);
    if (version == 2) pos -= 1;
    num_abbreviations = buildTable(pos, 0);
    pos = data.getShort(0);
    num_messages = buildTable(pos, num_abbreviations);
}

fn buildTable(start_pos: u16, table_start: u16) u16 {
    var pos = start_pos;
    var table_pos = table_start;
    while (data.getByte(pos) != 2) : ({
        table_pos += 1;
        pos += 1;
    }) {
        var start = pos;
        while (data.getByte(pos) > 2) : (pos += 1) {}
        message_table[table_pos] = data.data[start..pos];
    }
    return table_pos;
}

fn printMessage(message: u16, buffer: [*]u8, start_pos: u16) u16 {
    var ptr = start_pos;
    for (message_table[message]) |c| {
        if (c >= 0x5E) {
            var abbr = abbreviations[c - 0x5E];
            if (abbr[0] == 0) _ = printMessage(c - 0x5E, &abbr, 0);
            var abbr_pos: u8 = 0;
            while (abbr[abbr_pos] > 0) {
                buffer[ptr + abbr_pos] = abbr[abbr_pos];
                abbr_pos += 1;
            }
            ptr += abbr_pos;
        } else {
            switch (c) {
                0...2 => break,
                8 => buffer[ptr] = '\n',
                0x42 => buffer[ptr] = ' ',
                else => buffer[ptr] = c + 0x1D,
            }
            ptr += 1;
        }
    }
    buffer[ptr] = 0;
    return ptr;
}

pub fn print(n: u16) void {
    var message = n;
    if (version == 2) {
        if (message == 0) return;
        message -= 1;
    }
    io.extend(printMessage(message + num_abbreviations, &io.output_buffer, io.len));
    io.flush();
}
