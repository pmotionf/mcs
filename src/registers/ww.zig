const std = @import("std");
const registers = @import("../registers.zig");

/// Registers written through CC-Link's "DevWw" device. Used as a "write"
/// register bank.
pub const Ww = packed struct(u256) {
    command: Command = .None,
    axis: u16 = 0,
    carrier: packed struct(u80) {
        target: packed union {
            f32: f32,
            u32: u32,
            i32: i32,
        } = .{ .u32 = 0 },
        id: u10 = 0,
        cas: bool = false,
        _: u5 = 0,
        speed: u16 = 0,
        acceleration: u16 = 0,
    } = .{},
    _112: u144 = 0,

    pub const Command = enum(i16) {
        None = 0x0,
        SetLineZero = 0x1,
        // "By Position" commands calculate carrier movement by constant hall
        // sensor position feedback, and is much more precise in destination.
        PositionMoveCarrierAxis = 0x12,
        PositionMoveCarrierLocation = 0x13,
        PositionMoveCarrierDistance = 0x14,
        // "By Speed" commands calculate carrier movement by constant hall
        // sensor speed feedback. It should mostly not be used, as the
        // destination position becomes far too imprecise. However, it is
        // meant to maintain a certain speed while the carrier is traveling,
        // and to avoid the requirement of having a known system position.
        SpeedMoveCarrierAxis = 0x15,
        SpeedMoveCarrierLocation = 0x16,
        SpeedMoveCarrierDistance = 0x17,
        IsolateForward = 0x18,
        IsolateBackward = 0x19,
        Calibration = 0x1A,
        RecoverCarrierAtAxis = 0x1C,
        SetCarrierIdAtAxis = 0x1D,
        PushAxisCarrierForward = 0x1E,
        PushAxisCarrierBackward = 0x1F,
        PullAxisCarrierForward = 0x20,
        PullAxisCarrierBackward = 0x21,
    };

    pub fn format(
        ww: Ww,
        comptime _: []const u8,
        _: std.fmt.FormatOptions,
        writer: anytype,
    ) !void {
        _ = try registers.nestedWrite("Ww", ww, 0, writer);
    }
};

test "Ww" {
    try std.testing.expectEqual(32, @sizeOf(Ww));
    try std.testing.expectEqual(
        32,
        @bitSizeOf(
            @FieldType(
                @FieldType(Ww, "carrier"),
                "target",
            ),
        ),
    );
}
