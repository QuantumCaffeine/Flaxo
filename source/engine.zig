const Bytes = @import("Bytes.zig");
const Exit = @import("exits.zig").Exit;
const l9 = @import("l9.zig");
const io = @import("js.zig");
const js = @import("js.zig");
const Header = @import("Header.zig");

var code: Bytes = undefined;
var vars:[*]u16 = &l9.state.vars;
var call_stack: StackOf(u16, 400) = .{};
var version: u8 = 0;

pub const ExecutionState = union(enum) {
    Running:void,
    GetInput:void,
    GetCharInput:void,
    LoadGame:u8,
    Save:void,
    Restore:void,
    Stopped:void
};

const StandardOpcode = packed struct {
//const StandardOpcode = packed struct(u8) {
    value: u5,
    rel_addr: bool,
    byte_const: bool,
    is_list: bool
};

const ListOpcode = packed struct {
//const ListOpcode = packed struct(u8) {
    list_num: u5,
    opcode: u2,
    is_list: bool
};

pub fn init(header: Header) void {
    seed = js.random_bits(32);
    code = Bytes.init(header.code);
    version = header.version;
}

pub fn handle_input(input: []u8) void {
    if (version <= 2) read_inputV1(input)
    else read_inputV3(input);
}

fn load_part(part: u8) void {
    var frame: @Frame(l9.load) = async l9.load(part);
    await frame;
}

fn read_inputV1(input: []u8) void {
    const words = l9.parserV1.parseWords(input);
    for (words) |value| {
        const variable = code.read(u8);
        vars[variable] = value;
    }
    const num_words: u8 = @truncate(words.len);
    code.seekBy(3 - num_words);
    const variable = code.read(u8);
    vars[variable] = num_words;
}

fn read_inputV3(input: []u8) void {
    l9.parserV3.start(input);
    read_input_wordV3();
}

fn read_input_wordV3() void {
    var list = Bytes.init(l9.state.lists[8]);
    const word = l9.parserV3.readWord();
    if (word) |word_type| {
        switch (word_type) {
            .Literal => |value| {
                list.writeBig(u16, value);
            },
            .Match => |matches| {
                for (matches.get()) |match| {
                    list.writeBig(u16, match);
                }
            }
        }
    }
    list.write(u16, 0);
    code.pos += 4;
}

fn get_char_input() ExecutionState {
    return .Running;
}

fn StackOf(comptime T: type, comptime size: u16) type {
    return struct {
        const Self = @This();
        stack: [size]T = undefined,
        pos: u16 = 0,

        fn push(self: *Self, value: T) void {
            self.stack[self.pos] = value;
            self.pos += 1;
        }

        fn pop(self: *Self) T {
            self.pos -= 1;
            return self.stack[self.pos];
        }

        fn clear(self: *Self) void {
            self.pos = 0;
        }
        fn empty(self: Self) bool {
            return self.pos == 0;
        }
    };
}


fn readConstant(byte_const: bool) u16 {
    return if (byte_const) code.read(u8) else code.read(u16);
}

fn readVariable() u16 {
    const variable = code.read(u8);
    return vars[variable];
}

fn jump(address: u16) void {
    code.seek(address);
}

fn jumpIf(condition: bool, address: u16) void {
    if (condition) jump(address);
}

fn call(address: u16) void {
    call_stack.push(code.pos);
    jump(address);
}

fn ret() void {
    code.seek(call_stack.pop());
}

fn readAddress(relative: bool) u16 {
    if (relative) {
        const offset = @as(i16, code.read(i8));
        return code.pos +% @as(u16, @bitCast(offset)) - 1;
    } else return code.read(u16);
}

fn readTableAddress(table_start: u16, offset: u16) u16 {
    const table_entry = code.getPtr(u16, table_start)[offset];
    return table_entry;
}

pub fn run() ExecutionState {
    var in1:u16 = 0;
    var in2:u16 = 0;
    var out1:u8 = 0;
    var out2:u8 = 0;
    var address:u16 = 0;

    var count: u16 = 0;
    while (count < 20000) : (count += 1) {
        const opcode = code.read(StandardOpcode);

        if (opcode.is_list) {
            executeListOpcode(@bitCast(opcode));
            continue;
        }
        switch (opcode.value) {
            0x00, 0x01 => {
                address = readAddress(opcode.rel_addr);
            },
            0x03, 0x04, 0x09, 0x0A, 0x0B => { 
                in1 = readVariable(); 
            },
            0x05, 0x08 => {
                in1 = readConstant(opcode.byte_const); 
            },
            0x10...0x13 => {
                in1 = readVariable();
                in2 = readVariable();
                address = readAddress(opcode.rel_addr);
            },
            0x18...0x1B => {
                in1 = readVariable();
                in2 = readConstant(opcode.byte_const);
                address = readAddress(opcode.rel_addr);
            },
            0x0E => {
                in1 = readConstant(opcode.byte_const);
                in2 = readVariable();
                address = readTableAddress(in1, in2);
            },
            0x0F => {
                in1 = readVariable();
                in2 = readVariable();
                out1 = code.read(u8);
                out2 = code.read(u8);
            },
            else => {}
        }

        switch(opcode.value) {
            0x08...0x0B => {
                out1 = code.read(u8);
            },
            else => {}
        }
        //io.log.write(opcode.value);
        switch (opcode.value) {
            0x00, 0x0E => jump(address),
            0x01 => call(address),
            0x02 => ret(),
            0x03 => io.output.writeNumber(in1),
            0x04, 0x05 => l9.messages.print(in1, &io.output),
            0x06 => if (executeExtendedOpcode()) |new_state| return new_state,
            0x07 => if (version <= 2 or l9.parserV3.empty) return .GetInput else read_input_wordV3(),
            0x08, 0x09 => vars[out1] = in1,
            0x0A => vars[out1] +%= in1,
            0x0B => vars[out1] -%= in1,
            0x0F => {
                const exit = l9.exits.get(in1, in2);
                vars[out1] = exit.flags;
                vars[out2] = exit.room;
            },
            0x10, 0x18 => jumpIf(in1 == in2, address),
            0x11, 0x19 => jumpIf(in1 != in2, address),
            0x12, 0x1A => jumpIf(in1 < in2, address),
            0x13, 0x1B => jumpIf(in1 > in2, address),
            0x14 => {
                in1 = code.read(u8);
                if (in1 > 0) in2 = code.read(u8);
                js.toggle_image(in1, in2);
            },
            0x15 => {
                in1 = code.read(u8); //clear image
            },
            0x16 => {
                in1 = code.read(u8); //draw image
            },
            0x17 => {
                const maxObject = readVariable();
                const attributeVar = code.read(u8);
                const parentVar = code.read(u8);
                nextObject(maxObject, attributeVar, parentVar);
            },
            0x1C => io.output.writeString(l9.parserV3.current_word),
            else => return illegal(opcode.value),
        }
    }
    return .Stopped;
}

fn executeListOpcode(opcode: ListOpcode) void {
    const in1 = code.read(u8);
    const in2 = code.read(u8);
    const list = l9.state.lists[opcode.list_num - 1];
    switch (opcode.opcode) {
        0 => list[in1] = @truncate(vars[in2]),
        1 => vars[in2] = list[vars[in1]],
        2 => vars[in2] = list[in1],
        3 => list[vars[in1]] = @truncate(vars[in2]),
    }
}

var seed: u32 = 42;

fn random() u32 {
    seed = seed *% 1021 +% 41;
    return seed;
}

fn executeExtendedOpcode() ?ExecutionState {
    const opcode = code.read(u8);
    switch (opcode) {
        0x01 => {//If V1, stop game.
            const result = driver();
            if (result != .Running) return result;
        },
        0x02 => {
            const variable = code.read(u8);
            vars[variable] = @truncate(random());
        },
        0x03 => return .Save,
        0x04 => return .Restore,
        0x05 => l9.state.clearVars(),
        0x06 => call_stack.clear(),
        0xFA => io.output.writeString(code.readString()),
        else => return illegal(opcode),
    }
    return null;
}

fn driver() ExecutionState {
    var list = Bytes.init(l9.state.lists[8]);
    const opcode = list.read(u8);
    const arg = list.peek(u8);
    switch (opcode) {
        0x03 => return .GetCharInput,
        0x0B => {
            return .{.LoadGame = arg};
            // switch(arg) {
            //     1 => return .LoadGame1,
            //     2 => return .LoadGame2,
            //     3 => return .LoadGame3,
            //     else => {} //If arg is zero, ask user for file name?
            // }
        }, 
        0x0C => list.write(u16, @truncate(random()>>16)),
        0x0E => list.write(u8, 0), // driver call 14
        0x16 => ram_save(arg),
        0x17 => ram_restore(arg),
        0x19 => lenslok_display(&list),
        0x20 => show_bitmap(&list),
        0x22 => list.write(u16, 0), //checkfordisc
        else => {},
    }
    return .Running;
}

var searchdepth: u16 = 0;
var numobjectfound: u16 = 0;
var object: u16 = 0;
var initAttribute: u16 = 0;
var scratch: [32]u8 = [_]u8{0}**32;
var object_stack = StackOf(u16, 64){};

fn initgetobj() void {
    numobjectfound = 0;
    object = 0;
    scratch = [_]u8{0}**32;
}

fn getParent(obj: u16) u8 {
    return l9.state.lists[1][obj];
}

fn getAttributes(obj: u16) u8 {
    return l9.state.lists[2][obj];
}

fn setScratch(entry: u16, value: u8) void {
    scratch[@as(u5, @truncate(entry))] = value;
}

fn setObjectOutput(attributeVar: u8, parentVar: u8, attribute: u16, parent: u16) void {
    vars[attributeVar] = attribute;
    vars[parentVar] = parent;
    vars[code.read(u8)] = object;
    vars[code.read(u8)] = numobjectfound;
    vars[code.read(u8)] = searchdepth;
}

fn nextObject(maxObject: u16, attributeVar: u8, parentVar: u8) void {
    var attribute = vars[attributeVar];
    var parent = vars[parentVar];
    while (true) {
        if (attribute == 0 and parent == 0) {
            object_stack.clear();
            searchdepth = 0;
            initgetobj();
            break;
        }
        if (numobjectfound == 0) initAttribute = attribute;
        while (true) {
            object += 1;
            if (parent == getParent(object)) {
                const testAttribute = getAttributes(object) & 0x1F;
                if (testAttribute != attribute) {
                    if (testAttribute == 0 or attribute == 0) continue;
                    if (attribute != 0x1F) {
                        setScratch(testAttribute, testAttribute);
                        continue;
                    }
                    attribute = testAttribute;
                }
                numobjectfound += 1;
                object_stack.push(object | (0x1F << 8));
                setObjectOutput(attributeVar, parentVar, attribute, parent);
                return;
            }
            if (object > maxObject) break;
        }
        if (initAttribute == 0x1F) {
            setScratch(attribute, 0);
            for (scratch) |attr| {
                if (attr != 0) object_stack.push(parent | (@as(u16, attr) << 8));
            }
        }
        if (!object_stack.empty()) {
            const next = object_stack.pop();
            parent = next & 0xFF;
            attribute = next >> 8;
        } else {
            parent = 0;
            attribute = 0;
        }
        numobjectfound = 0;
        if (attribute == 0x1F) searchdepth += 1;
        initgetobj();
        if (parent == 0) break;
    }
    object = 0;
    setObjectOutput(attributeVar, parentVar, 0, 0);
}

fn lenslok_display(list: *Bytes) void {
    io.output.writeString("\nLenslok code is ");
    io.output.writeChar(list.read(u8));
    io.output.writeChar(list.read(u8));
    io.output.writeChar('\n');
}

fn ram_save(slot: u16) void {
    _ = slot;
}

fn ram_restore(slot: u16) void {
    _ = slot;
}

fn show_bitmap(list: *Bytes) void {
    const pic = list.readBig(u16);
    const x = list.readBig(u16);
    const y = list.readBig(u16);
    js.display_bitmap(pic, x, y);
}

fn illegal(value: u8) ExecutionState {
    io.log.write(99);
    io.log.write(value);
    return .Stopped;
}
