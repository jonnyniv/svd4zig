const std = @import("std");
const builtin = @import("builtin");
const Io = std.Io;
const ArrayList = std.ArrayList;
const Allocator = std.mem.Allocator;
const AutoHashMap = std.AutoHashMap;
const warn = std.debug.warn;

/// Top Level
pub const Device = struct {
    alloc: Allocator,
    name: ArrayList(u8),
    version: ArrayList(u8),
    description: ArrayList(u8),
    cpu: ?Cpu,

    /// Bus Interface Properties
    /// Smallest addressable unit in bits
    address_unit_bits: ?u32,

    /// The Maximum data bit width accessible within a single transfer
    max_bit_width: ?u32,

    /// Start register default properties
    reg_default_size: ?u32,
    reg_default_reset_value: ?u32,
    reg_default_reset_mask: ?u32,
    peripherals: Peripherals,
    interrupts: Interrupts,

    const Self = @This();

    pub fn init(allocator: Allocator) !Self {
        var name = ArrayList(u8).empty;
        errdefer name.deinit(allocator);
        var version = ArrayList(u8).empty;
        errdefer version.deinit(allocator);
        var description = ArrayList(u8).empty;
        errdefer description.deinit(allocator);
        var peripherals = Peripherals.empty;
        errdefer peripherals.deinit(allocator);
        var interrupts = Interrupts.init(allocator);
        errdefer interrupts.deinit();

        return Self{
            .name = name,
            .alloc = allocator,
            .version = version,
            .description = description,
            .cpu = null,
            .address_unit_bits = null,
            .max_bit_width = null,
            .reg_default_size = null,
            .reg_default_reset_value = null,
            .reg_default_reset_mask = null,
            .peripherals = peripherals,
            .interrupts = interrupts,
        };
    }

    pub fn deinit(self: *Self) void {
        self.name.deinit(self.alloc);
        self.version.deinit(self.alloc);
        self.description.deinit(self.alloc);
        self.peripherals.deinit(self.alloc);
        self.interrupts.deinit();
    }

    pub fn format(self: Self, writer: *std.Io.Writer) std.Io.Writer.Error!void {
        const name = if (self.name.items.len == 0) "unknown" else self.name.items;
        const version = if (self.version.items.len == 0) "unknown" else self.version.items;
        const description = if (self.description.items.len == 0) "unknown" else self.description.items;

        try writer.print(
            \\pub const device_name = "{s}";
            \\pub const device_revision = "{s}";
            \\pub const device_description = "{s}";
            \\
        , .{ name, version, description });
        if (self.cpu) |the_cpu| {
            try writer.print("{f}\n", .{the_cpu});
        }
        // now print peripherals
        for (self.peripherals.items) |peripheral| {
            try writer.print("{f}\n", .{peripheral});
        }
        // now print interrupt table
        try writer.writeAll("pub const interrupts = struct {\n");
        var iter = self.interrupts.iterator();
        while (iter.next()) |entry| {
            const interrupt = entry.value_ptr.*;
            if (interrupt.value) |int_value| {
                try writer.print(
                    "pub const {s} = {};\n",
                    .{ interrupt.name.items, int_value },
                );
            }
        }
        try writer.writeAll("};");
        return;
    }
};

pub const Cpu = struct {
    name: ArrayList(u8),
    revision: ArrayList(u8),
    endian: ArrayList(u8),
    mpu_present: ?bool,
    fpu_present: ?bool,
    nvic_prio_bits: ?u32,
    vendor_systick_config: ?bool,

    const Self = @This();

    pub fn init(allocator: Allocator) !Self {
        var name: ArrayList(u8) = .{};
        errdefer name.deinit(allocator);
        var revision: ArrayList(u8) = .{};
        errdefer revision.deinit(allocator);
        var endian: ArrayList(u8) = .{};
        errdefer endian.deinit(allocator);

        return Self{
            .name = name,
            .revision = revision,
            .endian = endian,
            .mpu_present = null,
            .fpu_present = null,
            .nvic_prio_bits = null,
            .vendor_systick_config = null,
        };
    }

    pub fn deinit(self: *Self) void {
        self.name.deinit();
        self.revision.deinit();
        self.endian.deinit();
    }

    pub fn format(self: Self, writer: *std.Io.Writer) std.Io.Writer.Error!void {
        try writer.writeAll("\n");

        const name = if (self.name.items.len == 0) "unknown" else self.name.items;
        const revision = if (self.revision.items.len == 0) "unknown" else self.revision.items;
        const endian = if (self.endian.items.len == 0) "unknown" else self.endian.items;
        const mpu_present = self.mpu_present orelse false;
        const fpu_present = self.mpu_present orelse false;
        const vendor_systick_config = self.vendor_systick_config orelse false;
        try writer.print(
            \\pub const cpu = struct {{
            \\    pub const name = "{s}";
            \\    pub const revision = "{s}";
            \\    pub const endian = "{s}";
            \\    pub const mpu_present = {};
            \\    pub const fpu_present = {};
            \\    pub const vendor_systick_config = {};
            \\
        , .{ name, revision, endian, mpu_present, fpu_present, vendor_systick_config });
        if (self.nvic_prio_bits) |prio_bits| {
            try writer.print(
                \\    pub const nvic_prio_bits = {};
                \\
            , .{prio_bits});
        }
        try writer.writeAll("};");
        return;
    }
};

pub const Peripherals = ArrayList(Peripheral);

pub const Peripheral = struct {
    alloc: Allocator,
    name: ArrayList(u8),
    group_name: ArrayList(u8),
    description: ArrayList(u8),
    base_address: ?u32,
    address_block: ?AddressBlock,
    registers: Registers,

    const Self = @This();

    pub fn init(allocator: Allocator) !Self {
        var name: ArrayList(u8) = .{};
        errdefer name.deinit(allocator);
        var group_name: ArrayList(u8) = .{};
        errdefer group_name.deinit(allocator);
        var description: ArrayList(u8) = .{};
        errdefer description.deinit(allocator);
        var registers: Registers = .{};
        errdefer registers.deinit(allocator);

        return Self{
            .alloc = allocator,
            .name = name,
            .group_name = group_name,
            .description = description,
            .base_address = null,
            .address_block = null,
            .registers = registers,
        };
    }

    pub fn copy(self: Self, allocator: Allocator) !Self {
        var the_copy = try Self.init(allocator);
        errdefer the_copy.deinit();

        try the_copy.name.appendSlice(self.alloc, self.name.items);
        try the_copy.group_name.appendSlice(self.alloc, self.group_name.items);
        try the_copy.description.appendSlice(self.alloc, self.description.items);
        the_copy.base_address = self.base_address;
        the_copy.address_block = self.address_block;
        for (self.registers.items) |self_register| {
            try the_copy.registers.append(self.alloc, try self_register.copy(allocator));
        }

        return the_copy;
    }

    pub fn deinit(self: *Self) void {
        self.name.deinit(self.alloc);
        self.group_name.deinit(self.alloc);
        self.description.deinit(self.alloc);
        self.registers.deinit(self.alloc);
    }

    pub fn isValid(self: Self) bool {
        if (self.name.items.len == 0) {
            return false;
        }
        _ = self.base_address orelse return false;

        return true;
    }

    pub fn format(self: Self, writer: *std.Io.Writer) std.Io.Writer.Error!void {
        try writer.writeAll("\n");
        if (!self.isValid()) {
            try writer.writeAll("// Not enough info to print peripheral value\n");
            return;
        }
        const name = self.name.items;
        const description = if (self.description.items.len == 0) "No description" else self.description.items;
        const base_address = self.base_address.?;
        try writer.print(
            \\/// {s}
            \\pub const {s} = struct {{
            \\
            \\const base_address = 0x{x};
        , .{ description, name, base_address });
        // now print registers
        for (self.registers.items) |register| {
            try writer.print("{f}\n", .{register});
        }
        // and close the peripheral
        try writer.print("}};", .{});

        return;
    }
};

pub const AddressBlock = struct {
    alloc: Allocator,
    offset: ?u32,
    size: ?u32,
    usage: ArrayList(u8),

    const Self = @This();

    pub fn init(allocator: Allocator) !Self {
        var usage: ArrayList(u8) = .{};
        errdefer usage.deinit(allocator);

        return Self{
            .alloc = allocator,
            .offset = null,
            .size = null,
            .usage = usage,
        };
    }

    pub fn deinit(self: *Self) void {
        self.usage.deinit();
    }
};

pub const Interrupts = AutoHashMap(u32, Interrupt);

pub const Interrupt = struct {
    alloc: Allocator,
    name: ArrayList(u8),
    description: ArrayList(u8),
    value: ?u32,

    const Self = @This();

    pub fn init(allocator: Allocator) !Self {
        var name: ArrayList(u8) = .{};
        errdefer name.deinit(allocator);
        var description: ArrayList(u8) = .{};
        errdefer description.deinit(allocator);

        return Self{
            .alloc = allocator,
            .name = name,
            .description = description,
            .value = null,
        };
    }

    pub fn copy(self: Self, allocator: Allocator) !Self {
        var the_copy = try Self.init(allocator);

        try the_copy.name.append(self.alloc, self.name.items);
        try the_copy.description.append(self.alloc, self.description.items);
        the_copy.value = self.value;

        return the_copy;
    }

    pub fn deinit(self: *Self) void {
        self.name.deinit(self.alloc);
        self.description.deinit(self.alloc);
    }

    pub fn isValid(self: Self) bool {
        if (self.name.items.len == 0) {
            return false;
        }
        _ = self.value orelse return false;

        return true;
    }

    pub fn format(self: Self, writer: *std.Io.Writer) std.Io.Writer.Error!void {
        try writer.writeAll("\n");
        if (!self.isValid()) {
            try writer.writeAll("// Not enough info to print interrupt value\n");
            return;
        }
        const name = self.name.items;
        const description = if (self.description.items.len == 0) "No description" else self.description.items;
        try writer.print(
            \\/// {s}
            \\pub const {s} = {s};
            \\
        , .{ description, name, self.value.? });
    }
};

const Registers = ArrayList(Register);

pub const Register = struct {
    alloc: Allocator,
    periph_containing: ArrayList(u8),
    name: ArrayList(u8),
    display_name: ArrayList(u8),
    description: ArrayList(u8),
    address_offset: ?u32,
    size: u32,
    reset_value: u32,
    fields: Fields,

    access: Access = .ReadWrite,

    const Self = @This();

    pub fn init(allocator: Allocator, periph: []const u8, reset_value: u32, size: u32) !Self {
        var prefix: ArrayList(u8) = .{};
        errdefer prefix.deinit(allocator);
        try prefix.appendSlice(allocator, periph);
        var name: ArrayList(u8) = .{};
        errdefer name.deinit(allocator);
        var display_name: ArrayList(u8) = .{};
        errdefer display_name.deinit(allocator);
        var description: ArrayList(u8) = .{};
        errdefer description.deinit(allocator);
        var fields: Fields = .{};
        errdefer fields.deinit(allocator);

        return Self{
            .alloc = allocator,
            .periph_containing = prefix,
            .name = name,
            .display_name = display_name,
            .description = description,
            .address_offset = null,
            .size = size,
            .reset_value = reset_value,
            .fields = fields,
        };
    }

    pub fn copy(self: Self, allocator: Allocator) !Self {
        var the_copy = try Self.init(allocator, self.periph_containing.items, self.reset_value, self.size);

        try the_copy.name.appendSlice(self.alloc, self.name.items);
        try the_copy.display_name.appendSlice(self.alloc, self.display_name.items);
        try the_copy.description.appendSlice(self.alloc, self.description.items);
        the_copy.address_offset = self.address_offset;
        the_copy.access = self.access;
        for (self.fields.items) |self_field| {
            try the_copy.fields.append(self.alloc, try self_field.copy(allocator));
        }

        return the_copy;
    }

    pub fn deinit(self: *Self) void {
        self.periph_containing.deinit();
        self.name.deinit();
        self.display_name.deinit();
        self.description.deinit();

        self.fields.deinit();
    }

    pub fn isValid(self: Self) bool {
        if (self.name.items.len == 0) {
            return false;
        }
        _ = self.address_offset orelse return false;

        return true;
    }

    fn fieldsSortCompare(_: void, left: Field, right: Field) bool {
        if (left.bit_offset != null and right.bit_offset != null) {
            if (left.bit_offset.? < right.bit_offset.?) {
                return true;
            }
            if (left.bit_offset.? > right.bit_offset.?) {
                return false;
            }
        } else if (left.bit_offset == null) {
            return true;
        }

        return false;
    }

    fn alignedEndOfUnusedChunk(chunk_start: u32, last_unused: u32) u32 {
        // Next multiple of 8 from chunk_start + 1
        const next_multiple = (chunk_start + 8) & ~@as(u32, 7);
        return std.mem.min(u32, &[_]u32{ next_multiple, last_unused });
    }

    fn writeUnusedField(first_unused: u32, last_unused: u32, reg_reset_value: u32, out_stream: anytype) !void {
        // Fill unused bits between two fields
        // TODO: right now we have to manually chunk unused bits to 8-bit boundaries as a workaround
        // to this bug https://github.com/ziglang/zig/issues/2627
        var chunk_start = first_unused;
        var chunk_end = alignedEndOfUnusedChunk(chunk_start, last_unused);
        try out_stream.print("\n/// unused [{}:{}]", .{ first_unused, last_unused - 1 });
        while (chunk_start < last_unused) : ({
            chunk_start = chunk_end;
            chunk_end = alignedEndOfUnusedChunk(chunk_start, last_unused);
        }) {
            try out_stream.writeAll("\n");
            const chunk_width = chunk_end - chunk_start;
            const unused_value = Field.fieldResetValue(chunk_start, chunk_width, reg_reset_value);

            try out_stream.print("_unused{}: u{} = {},", .{ chunk_start, chunk_width, unused_value });
        }
    }

    pub fn format(self: Self, writer: *std.Io.Writer) std.Io.Writer.Error!void {
        try writer.writeAll("\n");
        if (!self.isValid()) {
            try writer.writeAll("// Not enough info to print register value\n");
            return;
        }
        const name = self.name.items;
        // const periph = self.periph_containing.items;
        const description = if (self.description.items.len == 0) "No description" else self.description.items;
        // print packed struct containing fields
        try writer.print(
            \\/// {s}
            \\pub const {s}_val = packed struct {{
        , .{ name, name });

        // Sort fields from LSB to MSB for next step
        std.mem.sort(Field, self.fields.items, {}, fieldsSortCompare);

        var last_uncovered_bit: u32 = 0;
        for (self.fields.items) |field| {
            if ((field.bit_offset == null) or (field.bit_width == null)) {
                try writer.writeAll("// Not enough info to print register\n");
                return;
            }

            const bit_offset = field.bit_offset.?;
            const bit_width = field.bit_width.?;
            if (last_uncovered_bit != bit_offset) {
                try writeUnusedField(last_uncovered_bit, bit_offset, self.reset_value, writer);
            }
            try writer.print("{f}", .{field});
            last_uncovered_bit = bit_offset + bit_width;
        }

        // Check if we need padding at the end
        if (last_uncovered_bit != 32) {
            try writeUnusedField(last_uncovered_bit, 32, self.reset_value, writer);
        }

        // close the struct and init the register
        try writer.print(
            \\
            \\}};
            \\/// {s}
            \\pub const {s} = Register({s}_val).init(base_address + 0x{x});
        , .{ description, name, name, self.address_offset.? });

        return;
    }
};

pub const Access = enum {
    ReadOnly,
    WriteOnly,
    ReadWrite,
};

pub const Fields = ArrayList(Field);

pub const Field = struct {
    alloc: Allocator,
    periph: ArrayList(u8),
    register: ArrayList(u8),
    register_reset_value: u32,
    name: ArrayList(u8),
    description: ArrayList(u8),
    bit_offset: ?u32,
    bit_width: ?u32,

    access: Access = .ReadWrite,

    const Self = @This();

    pub fn init(allocator: Allocator, periph_containing: []const u8, register_containing: []const u8, register_reset_value: u32) !Self {
        var periph: ArrayList(u8) = .{};
        try periph.appendSlice(allocator, periph_containing);
        errdefer periph.deinit(allocator);
        var register: ArrayList(u8) = .{};
        try register.appendSlice(allocator, register_containing);
        errdefer register.deinit(allocator);
        var name: ArrayList(u8) = .{};
        errdefer name.deinit(allocator);
        var description: ArrayList(u8) = .{};
        errdefer description.deinit(allocator);

        return Self{
            .alloc = allocator,
            .periph = periph,
            .register = register,
            .register_reset_value = register_reset_value,
            .name = name,
            .description = description,
            .bit_offset = null,
            .bit_width = null,
        };
    }

    pub fn copy(self: Self, allocator: Allocator) !Self {
        var the_copy = try Self.init(allocator, self.periph.items, self.register.items, self.register_reset_value);

        try the_copy.name.appendSlice(self.alloc, self.name.items);
        try the_copy.description.appendSlice(self.alloc, self.description.items);
        the_copy.bit_offset = self.bit_offset;
        the_copy.bit_width = self.bit_width;
        the_copy.access = self.access;

        return the_copy;
    }

    pub fn deinit(self: *Self) void {
        self.periph.deinit();
        self.register.deinit();
        self.name.deinit();
        self.description.deinit();
    }

    pub fn fieldResetValue(bit_start: u32, bit_width: u32, reg_reset_value: u32) u32 {
        const shifted_reset_value = reg_reset_value >> @intCast(bit_start);
        const reset_value_mask: u32 = @intCast((@as(u33, 1) << @intCast(bit_width)) - 1);

        return shifted_reset_value & reset_value_mask;
    }

    pub fn format(self: Self, writer: *std.Io.Writer) std.Io.Writer.Error!void {
        try writer.writeAll("\n");
        if (self.name.items.len == 0) {
            try writer.writeAll("// No name to print field value\n");
            return;
        }
        if ((self.bit_offset == null) or (self.bit_width == null)) {
            try writer.writeAll("// Not enough info to print field\n");
            return;
        }
        const name = self.name.items;
        const description = if (self.description.items.len == 0) "No description" else self.description.items;
        const start_bit = self.bit_offset.?;
        const end_bit = (start_bit + self.bit_width.? - 1);
        const bit_width = self.bit_width.?;
        const reg_reset_value = self.register_reset_value;
        const reset_value = fieldResetValue(start_bit, bit_width, reg_reset_value);
        try writer.print(
            \\/// {s} [{}:{}]
            \\/// {s}
            \\{s}: u{} = {},
        , .{
            name,
            start_bit,
            end_bit,
            // description
            description,
            // val
            name,
            bit_width,
            reset_value,
        });
        return;
    }
};

test "Field print" {
    const allocator = std.testing.allocator;
    const fieldDesiredPrint =
        \\
        \\/// RNGEN [2:2]
        \\/// RNGEN comment
        \\RNGEN: u1 = 1,
        \\
    ;

    var output_buffer = ArrayList(u8).init(allocator);
    defer output_buffer.deinit();
    var buf_stream = output_buffer.writer();

    var field = try Field.init(allocator, "PERIPH", "RND", 0b101);
    defer field.deinit();

    try field.name.appendSlice(allocator, "RNGEN");
    try field.description.appendSlice(allocator, "RNGEN comment");
    field.bit_offset = 2;
    field.bit_width = 1;

    try buf_stream.print("{}\n", .{field});
    std.testing.expect(std.mem.eql(u8, output_buffer.items, fieldDesiredPrint));
}

test "Register Print" {
    const allocator = std.testing.allocator;
    const registerDesiredPrint =
        \\
        \\/// RND
        \\const RND_val = packed struct {
        \\/// unused [0:1]
        \\_unused0: u2 = 1,
        \\/// RNGEN [2:2]
        \\/// RNGEN comment
        \\RNGEN: u1 = 1,
        \\/// unused [3:9]
        \\_unused3: u5 = 0,
        \\_unused8: u2 = 0,
        \\/// SEED [10:12]
        \\/// SEED comment
        \\SEED: u3 = 0,
        \\/// unused [13:31]
        \\_unused13: u3 = 0,
        \\_unused16: u8 = 0,
        \\_unused24: u8 = 0,
        \\};
        \\/// RND comment
        \\pub const RND = Register(RND_val).init(base_address + 0x100);
        \\
    ;

    var output_buffer = ArrayList(u8).init(allocator);
    defer output_buffer.deinit();
    var buf_stream = output_buffer.writer();

    var register = try Register.init(allocator, "PERIPH", 0b101, 0x20);
    defer register.deinit();
    try register.name.appendSlice(allocator, "RND");
    try register.description.appendSlice(allocator, "RND comment");
    register.address_offset = 0x100;
    register.size = 0x20;

    var field = try Field.init(allocator, "PERIPH", "RND", 0b101);
    defer field.deinit();

    try field.name.appendSlice(allocator, "RNGEN");
    try field.description.appendSlice(allocator, "RNGEN comment");
    field.bit_offset = 2;
    field.bit_width = 1;
    field.access = .ReadWrite; // write field will exist

    var field2 = try Field.init(allocator, "PERIPH", "RND", 0b101);
    defer field2.deinit();

    try field2.name.appendSlice(allocator, "SEED");
    try field2.description.appendSlice(allocator, "SEED comment");
    field2.bit_offset = 10;
    field2.bit_width = 3;
    field2.access = .ReadWrite;

    try register.fields.append(allocator, field);
    try register.fields.append(allocator, field2);

    try buf_stream.print("{}\n", .{register});
    std.testing.expectEqualSlices(u8, output_buffer.items, registerDesiredPrint);
}

test "Peripheral Print" {
    const allocator = std.testing.allocator;
    const peripheralDesiredPrint =
        \\
        \\/// PERIPH comment
        \\pub const PERIPH = struct {
        \\
        \\const base_address = 0x24000;
        \\/// RND
        \\const RND_val = packed struct {
        \\/// unused [0:1]
        \\_unused0: u2 = 1,
        \\/// RNGEN [2:2]
        \\/// RNGEN comment
        \\RNGEN: u1 = 1,
        \\/// unused [3:9]
        \\_unused3: u5 = 0,
        \\_unused8: u2 = 0,
        \\/// SEED [10:12]
        \\/// SEED comment
        \\SEED: u3 = 0,
        \\/// unused [13:31]
        \\_unused13: u3 = 0,
        \\_unused16: u8 = 0,
        \\_unused24: u8 = 0,
        \\};
        \\/// RND comment
        \\pub const RND = Register(RND_val).init(base_address + 0x100);
        \\};
        \\
    ;

    var output_buffer = ArrayList(u8).init(allocator);
    defer output_buffer.deinit();
    var buf_stream = output_buffer.writer();

    var peripheral = try Peripheral.init(allocator);
    defer peripheral.deinit();
    try peripheral.name.appendSlice(allocator, "PERIPH");
    try peripheral.description.appendSlice(allocator, "PERIPH comment");
    peripheral.base_address = 0x24000;

    var register = try Register.init(allocator, "PERIPH", 0b101, 0x20);
    defer register.deinit();
    try register.name.appendSlice(allocator, "RND");
    try register.description.appendSlice(allocator, "RND comment");
    register.address_offset = 0x100;
    register.size = 0x20;

    var field = try Field.init(allocator, "PERIPH", "RND", 0b101);
    defer field.deinit();

    try field.name.appendSlice(allocator, "RNGEN");
    try field.description.appendSlice(allocator, "RNGEN comment");
    field.bit_offset = 2;
    field.bit_width = 1;
    field.access = .ReadOnly; // since only register, write field will not exist

    var field2 = try Field.init(allocator, "PERIPH", "RND", 0b101);
    defer field2.deinit();

    try field2.name.appendSlice(allocator, "SEED");
    try field2.description.appendSlice(allocator, "SEED comment");
    field2.bit_offset = 10;
    field2.bit_width = 3;
    field2.access = .ReadWrite;

    try register.fields.append(allocator, field);
    try register.fields.append(allocator, field2);

    try peripheral.registers.append(allocator, register);

    try buf_stream.print("{}\n", .{peripheral});
    std.testing.expectEqualSlices(u8, peripheralDesiredPrint, output_buffer.items);
}
fn bitWidthToMask(width: u32) u32 {
    const max_supported_bits = 32;
    const width_to_mask = blk: {
        const mask_array: [max_supported_bits + 1]u32 = undefined;
        inline for (mask_array, 0..) |*item, i| {
            const i_use = if (i == 0) max_supported_bits else i;
            // This is needed to support both Zig 0.7 and 0.8
            const int_type_info =
                if (@hasField(builtin.TypeInfo.Int, "signedness"))
                    .{ .signedness = .unsigned, .bits = i_use }
                else
                    .{ .is_signed = false, .bits = i_use };

            item.* = std.math.maxInt(@Type(builtin.TypeInfo{ .Int = int_type_info }));
        }
        break :blk mask_array;
    };
    const width_to_mask_slice = width_to_mask[0..];

    return width_to_mask_slice[if (width > max_supported_bits) 0 else width];
}
