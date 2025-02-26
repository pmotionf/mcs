const std = @import("std");
const registers = @import("../registers.zig");

const Direction = registers.Direction;

/// Registers written through CC-Link's "DevX" device. Used as a "read"
/// register bank.
pub const X = packed struct(u64) {
    cc_link_enabled: bool = false,
    command_ready: bool = false,
    command_received: bool = false,
    axis_cleared_carrier: bool = false,
    cleared_carrier: bool = false,
    _0x5: u1 = 0,
    servo_enabled: bool = false,
    emergency_stop_enabled: bool = false,
    paused: bool = false,
    _0x9: u1 = 0,
    motor_enabled: packed struct(u3) {
        axis1: bool = false,
        axis2: bool = false,
        axis3: bool = false,

        pub fn axis(self: @This(), a: u2) bool {
            return switch (a) {
                0 => self.axis1,
                1 => self.axis2,
                2 => self.axis3,
                3 => {
                    std.log.err(
                        "Invalid axis index 3 for `motor_enabled`",
                        .{},
                    );
                    unreachable;
                },
            };
        }
    } = .{},
    vdc_undervoltage_detected: bool = false,
    vdc_overvoltage_detected: bool = false,
    _0xF: u1 = 0,
    errors_cleared: bool = false,
    communication_error: packed struct(u2) {
        from_prev: bool = false,
        from_next: bool = false,

        pub fn to(self: @This(), dir: Direction) bool {
            return switch (dir) {
                .backward => self.to_prev,
                .forward => self.to_next,
            };
        }
    } = .{},
    inverter_overheat_detected: bool = false,
    overcurrent_detected: packed struct(u3) {
        axis1: bool = false,
        axis2: bool = false,
        axis3: bool = false,

        pub fn axis(self: @This(), a: u2) bool {
            return switch (a) {
                0 => self.axis1,
                1 => self.axis2,
                2 => self.axis3,
                3 => {
                    std.log.err(
                        "Invalid axis index 3 for `overcurrent_detected`",
                        .{},
                    );
                    unreachable;
                },
            };
        }
    } = .{},
    _0x17: u3 = 0,
    hall_alarm: packed struct(u6) {
        axis1: packed struct(u2) {
            back: bool = false,
            front: bool = false,
        } = .{},
        axis2: packed struct(u2) {
            back: bool = false,
            front: bool = false,
        } = .{},
        axis3: packed struct(u2) {
            back: bool = false,
            front: bool = false,
        } = .{},

        pub fn axis(self: @This(), a: u2) packed struct(u2) {
            back: bool,
            front: bool,
        } {
            return switch (a) {
                0 => .{
                    .back = self.axis1.back,
                    .front = self.axis1.front,
                },
                1 => .{
                    .back = self.axis2.back,
                    .front = self.axis2.front,
                },
                2 => .{
                    .back = self.axis3.back,
                    .front = self.axis3.front,
                },
                3 => {
                    std.log.err("Invalid axis index 3 for `hall_alarm`", .{});
                    unreachable;
                },
            };
        }
    } = .{},
    pulling_carrier: packed struct(u3) {
        axis1: bool = false,
        axis2: bool = false,
        axis3: bool = false,

        pub fn axis(self: @This(), a: u2) bool {
            return switch (a) {
                0 => self.axis1,
                1 => self.axis2,
                2 => self.axis3,
                3 => {
                    std.log.err(
                        "Invalid axis index 3 for `pulling_carrier`",
                        .{},
                    );
                    unreachable;
                },
            };
        }
    } = .{},
    control_loop_max_time_exceeded: bool = false,
    _0x24: u12 = 0,
    _0x30: u8 = 0,
    initial_data_processing_request: bool = false,
    initial_data_setting_complete: bool = false,
    error_status: bool = false,
    remote_ready: bool = false,
    _60: u4 = 0,

    pub fn format(
        x: X,
        comptime _: []const u8,
        _: std.fmt.FormatOptions,
        writer: anytype,
    ) !void {
        _ = try registers.nestedWrite("X", x, 0, writer);
    }
};

test "X" {
    try std.testing.expectEqual(8, @sizeOf(X));
}
