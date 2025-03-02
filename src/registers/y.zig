const std = @import("std");
const registers = @import("../registers.zig");

const Direction = registers.Direction;

/// Registers written through CC-Link's "DevY" device. Used as a "write"
/// register bank.
pub const Y = packed struct(u64) {
    cc_link_enable: bool = false,
    start_command: bool = false,
    reset_command_received: bool = false,
    /// Clear carrier information at axis specified in "Ww" register.
    axis_clear_carrier: bool = false,
    /// Clear all carriers recognized by driver.
    clear_carrier: bool = false,
    axis_servo_release: bool = false,
    servo_release: bool = false,
    emergency_stop: bool = false,
    temporary_pause: bool = false,
    _0x9: u2 = 0,
    clear_errors: bool = false,
    _0xC: u1 = 0,
    prev_axis_isolate_link: bool = false,
    next_axis_isolate_link: bool = false,
    _0xF: u1 = 0,
    reset_pull_carrier: packed struct(u3) {
        axis1: bool = false,
        axis2: bool = false,
        axis3: bool = false,

        pub fn axis(self: @This(), local_axis: u2) bool {
            return switch (local_axis) {
                0 => self.axis1,
                1 => self.axis2,
                2 => self.axis3,
                3 => {
                    std.log.err(
                        "Invalid axis index 3 for `reset_pull_carrier`",
                        .{},
                    );
                    unreachable;
                },
            };
        }

        pub fn setAxis(
            self: *align(8:16:8) @This(),
            local_axis: u2,
            val: bool,
        ) void {
            switch (local_axis) {
                0 => self.axis1 = val,
                1 => self.axis2 = val,
                2 => self.axis3 = val,
                3 => {
                    std.log.err(
                        "Invalid axis index 3 for `reset_pull_carrier`",
                        .{},
                    );
                    unreachable;
                },
            }
        }
    } = .{},
    recovery_use_hall_sensor: packed struct(u2) {
        back: bool = false,
        front: bool = false,

        pub fn side(self: @This(), dir: Direction) bool {
            return switch (dir) {
                .backward => self.back,
                .forward => self.front,
            };
        }

        pub fn setSide(
            self: *align(8:19:8) @This(),
            dir: Direction,
            val: bool,
        ) void {
            switch (dir) {
                .backward => self.back = val,
                .forward => self.front = val,
            }
        }
    } = .{},
    _21: u43 = 0,

    pub fn format(
        y: Y,
        comptime _: []const u8,
        _: std.fmt.FormatOptions,
        writer: anytype,
    ) !void {
        _ = try registers.nestedWrite("Y", y, 0, writer);
    }
};

test "Y" {
    try std.testing.expectEqual(8, @sizeOf(Y));
}
