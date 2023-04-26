const Bytes = @import("Bytes.zig");
const Header = @This();
const js = @import("js.zig");

version: u8,
data: []u8,
exit_table: []u8,
code: []u8,
list_table: [10]u16,
abbr_table: []u8 = undefined,
message_table: []u8 = undefined,
dictionary: []u8 = undefined,

//Size: 0x20
const HeaderV1 = packed struct {
    message_table: u16, //0x0D7D
    abbr_table: u16, //0x470E
    exit_table: u16, //0x0020
    dictionary_start: u16, //0x02D4
    dictionary_end: u16, //0x0B5C Seems to be 0x50 too low?
    lists: [8]u16,
    code_start: u16, //0x491C
    file_length: u16, //0x5EB9
    checksum: u16, //0xA9DA Seems to be an 11-bit checksum
};

//44-bytes header
const HeaderV4 = packed struct {
    file_length: u16,
    message_table_start: u16,
    message_table_length: u16,
    dictionary_start: u16,
    dictionary_length: u16,
    padding: u32,
    word_table: u16,
    padding: u16, //Seems to be 0 in Lancelot
    exit_table: u16,
    lists: [10]u16,
    code_start: u16,
    padding: u16, //Seems to be 0 in Lancelot
    //List 0 at 0x14 (dict_end?)
    //Code offset 40
};



pub fn init(version: u8, data: []u8) Header {
    var bytes = Bytes.init(data);
    if (version <= 2) {
        var header_data = bytes.get(HeaderV1, 0);
        var abbr_table_start = header_data.abbr_table;
        if (version == 2) abbr_table_start -= 1;
        //js.console_log(tester[0]);
        return Header{
            .version = version, //kfhu
            .data = data,
            .list_table = bytes.get([10]u16, 0x06),
            .abbr_table = data[abbr_table_start..],
            .message_table = data[header_data.message_table..],
            .exit_table = data[header_data.exit_table..],
            .code = data[header_data.code_start..],
            .dictionary = data[header_data.dictionary_start..],
        };
    } else {
        return Header{
            .version = version,
            .data = data,
            .list_table = bytes.get([10]u16, 0x0A), //data_u16[0xA .. 0xA + 32],
            .exit_table = data[bytes.get(u16, 18)..],
            .code = data[bytes.get(u16, 40)..],
            .dictionary = data[bytes.get(u16, 18)..],
        };
    }
}
