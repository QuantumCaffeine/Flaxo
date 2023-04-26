
const Bytes = @import("Bytes.zig");
const Exit = @import("exits.zig").Exit;
const l9 = @import("l9.zig");
const io = @import("io.zig");
const js = @import("js.zig");
const Header = @import("Header.zig");

var code: Bytes = undefined;
var vars:[*]u16 = &l9.state.vars;
var call_stack: StackOf(u16, 400) = .{};

const ExecutionState = enum {
    Running,
    GetInput,
    GetCharInput,
    LoadGame,
    Save,
    Restore,
    Stopped
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
    code = Bytes.init(header.code);
}

pub fn run() void {
    var exec_state = ExecutionState.Running;
    while (true) {
        exec_state = switch (exec_state) {
            .Running => execute(),
            .GetInput => await async get_input(),
            .GetCharInput => get_char_input(),
            .LoadGame => blk: {
                const part = l9.state.lists[9][1];
                var frame: @Frame(load_part) = async load_part(part);
                await frame;
                break :blk .Running;
            },
            .Save => .Stopped,
            .Stopped => return,
            .Restore => .Stopped,
        };
    }
}

fn load_part(part: u8) void {
    var frame: @Frame(l9.load) = async l9.load(part);
    await frame;
}

fn get_input() ExecutionState {
    io.output.flush();
    var result: [4]u8 = [_]u8{0} ** 4;
    var word_no: u8 = 0;
    while (word_no < 3) : (word_no += 1) {
        const word = await async l9.parser.readWord();
        if (word) |value| {
            result[word_no] = value;
        } else break;
    }
    result[3] = word_no;
    for (result) |entry| {
        const variable = code.read(u8);
        vars[variable] = entry;
    }
    return .Running;
}

fn get_char_input() ExecutionState {
    return .Stopped;
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
        return code.pos +% @bitCast(u16, offset) - 1;
    } else return code.read(u16);
}

fn readTableAddress(table_start: u16, offset: u16) u16 {
    const table_entry = code.getPtr(u16, table_start)[offset];
    return table_entry;
}

fn handle_input(input_length: u16) void {
    io.log.write(input_length);
}

fn execute() ExecutionState {
    var in1:u16 = 0;
    var in2:u16 = 0;
    var out1:u8 = 0;
    var out2:u8 = 0;
    var address:u16 = 0;

    while (true) {
        const opcode = code.read(StandardOpcode);

        if (opcode.is_list) {
            executeListOpcode(@bitCast(ListOpcode, opcode));
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

        switch (opcode.value) {
            0x00, 0x0E => jump(address),
            0x01 => call(address),
            0x02 => ret(),
            0x03 => io.output.writeNumber(in1),
            0x04, 0x05 => l9.messages.print(in1, &io.output),
            0x06 => if (executeExtendedOpcode()) |new_state| return new_state,
            0x07 => return .GetInput,
            0x08, 0x09 => vars[out1] = in1,
            0x0A => vars[out1] += in1,
            0x0B => vars[out1] -= in1,
            0x0F => {
                const exit = l9.exits.get(in1, in2);
                vars[out1] = exit.flags;
                vars[out2] = exit.room;
            },
            0x10, 0x18 => jumpIf(in1 == in2, address),
            0x11, 0x19 => jumpIf(in1 != in2, address),
            0x12, 0x1A => jumpIf(in1 < in2, address),
            0x13, 0x1B => jumpIf(in1 > in2, address),
            else => return illegal(opcode.value),
        }
    }
}

fn executeListOpcode(opcode: ListOpcode) void {
    const in1 = code.read(u8);
    const in2 = code.read(u8);
    const list = l9.state.lists[opcode.list_num];
    switch (opcode.opcode) {
        0 => list[in1] = @truncate(u8, vars[in2]),
        1 => vars[in2] = list[vars[in1]],
        2 => vars[in2] = list[in1],
        3 => list[vars[in1]] = @truncate(u8, vars[in2]),
    }
}

fn executeExtendedOpcode() ?ExecutionState {
    const opcode = code.read(u8);
    switch (opcode) {
        0x01 => {
            const result = driver();
            if (result != .Running) return result;
        },
        0x02 => {
            const variable = code.read(u8);
            vars[variable] = 42;
        },
        0x03 => return .Save,
        0x04 => return .Restore,
        0x05 => l9.state.clearVars(),
        0x06 => call_stack.clear(),
        0xFA => printString(),
        else => return illegal(opcode),
    }
    return null;
}

fn driver() ExecutionState {
    const list = l9.state.lists[9];
    const opcode = list[0];
    const arg = list[1];
    switch (opcode) {
        0x01 => io.log.write(arg),
        0x03 => return .GetCharInput,
        0x0B => return .LoadGame,
        0x0C => list[1] = l9_random(),
        0x0E => list[1] = 0, //driver14
        0x16 => ram_save(arg),
        0x17 => ram_restore(arg),
        0x19, 0x20 => show_bitmap(),
        0x22 => {
            list[1] = 0;
            list[2] = 0;
        }, //checkfordisc
        else => {},
    }
    return .Running;
}

fn l9_random() u8 {
    return 7;
}

fn ram_save(slot: u16) void {
    _ = slot;
}

fn ram_restore(slot: u16) void {
    _ = slot;
}

fn show_bitmap() void {}

fn printString() void {
    io.log.write(205);
}

fn illegal(value: u8) ExecutionState {
    io.log.write(99);
    io.log.write(value);
    return .Stopped;
}
