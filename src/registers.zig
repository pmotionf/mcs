pub const X = @import("registers/x.zig").X;
pub const Y = @import("registers/y.zig").Y;
pub const Wr = @import("registers/wr.zig").Wr;
pub const Ww = @import("registers/ww.zig").Ww;

const std = @import("std");

pub const Direction = enum(u1) {
    backward = 0,
    forward = 1,

    pub fn flip(self: @This()) @This() {
        return if (self == .backward) .forward else .backward;
    }
};

pub fn nestedWrite(
    name: []const u8,
    val: anytype,
    indent: usize,
    writer: anytype,
) !usize {
    var written_bytes: usize = 0;
    const ti = @typeInfo(@TypeOf(val));
    switch (ti) {
        .@"struct" => {
            try writer.writeBytesNTimes("    ", indent);
            written_bytes += 4 * indent;
            try writer.print("{s}: {{\n", .{name});
            written_bytes += name.len + 4;
            inline for (ti.@"struct".fields) |field| {
                if (field.name[0] == '_') {
                    continue;
                }
                written_bytes += try nestedWrite(
                    field.name,
                    @field(val, field.name),
                    indent + 1,
                    writer,
                );
            }
            try writer.writeBytesNTimes("    ", indent);
            written_bytes += 4 * indent;
            try writer.writeAll("},\n");
            written_bytes += 3;
        },
        .bool, .int => {
            try writer.writeBytesNTimes("    ", indent);
            written_bytes += 4 * indent;
            try writer.print("{s}: ", .{name});
            written_bytes += name.len + 2;
            try writer.print("{},\n", .{val});
            written_bytes += std.fmt.count("{},\n", .{val});
        },
        .float => {
            try writer.writeBytesNTimes("    ", indent);
            written_bytes += 4 * indent;
            try writer.print("{s}: ", .{name});
            written_bytes += name.len + 2;
            try writer.print("{d},\n", .{val});
            written_bytes += std.fmt.count("{d},\n", .{val});
        },
        .@"enum" => {
            try writer.writeBytesNTimes("    ", indent);
            written_bytes += 4 * indent;
            try writer.print("{s}: ", .{name});
            written_bytes += name.len + 2;
            try writer.print("{s},\n", .{@tagName(val)});
            written_bytes += std.fmt.count("{s},\n", .{@tagName(val)});
        },
        .@"union" => {
            try writer.writeBytesNTimes("    ", indent);
            written_bytes += 4 * indent;
            try writer.print("{s} (union): {{\n", .{name});
            written_bytes += name.len + 4;
            inline for (ti.@"union".fields) |field| {
                if (field.name[0] == '_') {
                    continue;
                }
                written_bytes += try nestedWrite(
                    field.name,
                    @field(val, field.name),
                    indent + 1,
                    writer,
                );
            }
            try writer.writeBytesNTimes("    ", indent);
            written_bytes += 4 * indent;
            try writer.writeAll("},\n");
            written_bytes += 3;
        },
        else => {
            unreachable;
        },
    }
    return written_bytes;
}

test nestedWrite {
    const example_x: X = .{};
    var result_buffer: [2048]u8 = undefined;
    var buf = std.io.fixedBufferStream(&result_buffer);
    const buf_writer = buf.writer();
    try std.testing.expectEqualStrings(
        \\hall_alarm: {
        \\    axis1: {
        \\        back: false,
        \\        front: false,
        \\    },
        \\    axis2: {
        \\        back: false,
        \\        front: false,
        \\    },
        \\    axis3: {
        \\        back: false,
        \\        front: false,
        \\    },
        \\},
        \\
    ,
        result_buffer[0..try nestedWrite(
            "hall_alarm",
            example_x.hall_alarm,
            0,
            buf_writer,
        )],
    );
}
