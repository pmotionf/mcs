const std = @import("std");
const registers = @import("../registers.zig");

/// Registers written through CC-Link's "DevWr" device. Used as a "read"
/// register bank.
pub const Wr = packed struct(u256) {
    command_response: CommandResponseCode = .NoError,
    _16: u48 = 0,
    carrier: packed struct(u192) {
        axis1: Carrier = .{},
        axis2: Carrier = .{},
        axis3: Carrier = .{},

        pub fn axis(self: @This(), a: u2) Carrier {
            return switch (a) {
                0 => self.axis1,
                1 => self.axis2,
                2 => self.axis3,
                3 => {
                    std.log.err(
                        "Invalid axis index 3 for `carrier`",
                        .{},
                    );
                    unreachable;
                },
            };
        }
    } = .{},

    pub const Carrier = packed struct(u64) {
        location: f32 = 0.0,
        id: u16 = 0,
        arrived: bool = false,
        auxiliary: bool = false,
        enabled: bool = false,
        /// Whether carrier is currently in quasi-enabled state. Quasi-enabled
        /// state occurs when carrier is first entering a module, before it
        /// has entered module enough to start servo control.
        quasi: bool = false,
        cas: packed struct {
            /// Whether carrier's CAS (collision avoidance system) is enabled.
            enabled: bool = false,
            /// Whether carrier's CAS (collision avoidance system) is triggered.
            triggered: bool = false,
        } = .{},
        _54: u2 = 0,
        state: State = .None,

        pub const State = enum(u8) {
            None = 0x0,

            WarmupProgressing,
            WarmupCompleted,

            PosMoveProgressing = 0x4,
            PosMoveCompleted,
            SpdMoveProgressing,
            SpdMoveCompleted,
            Auxiliary,
            AuxiliaryCompleted,

            ForwardCalibrationProgressing = 0xA,
            ForwardCalibrationCompleted,
            BackwardCalibrationProgressing,
            BackwardCalibrationCompleted,

            ForwardIsolationProgressing = 0x10,
            ForwardIsolationCompleted,
            BackwardIsolationProgressing,
            BackwardIsolationCompleted,
            ForwardRestartProgressing,
            ForwardRestartCompleted,
            BackwardRestartProgressing,
            BackwardRestartCompleted,

            PullForward = 0x1A,
            PullForwardCompleted,
            PullBackward,
            PullBackwardCompleted,

            Overcurrent = 0x1F,
        };
    };

    pub const CommandResponseCode = enum(i16) {
        NoError = 0,
        InvalidCommand = 1,
        CarrierNotFound = 2,
        HomingFailed = 3,
        InvalidParameter = 4,
        InvalidSystemState = 5,
        CarrierAlreadyExists = 6,
        InvalidAxis = 7,

        pub fn throwError(code: CommandResponseCode) !void {
            return switch (code) {
                .NoError => {},
                .InvalidCommand => return error.InvalidCommand,
                .CarrierNotFound => return error.CarrierNotFound,
                .HomingFailed => return error.HomingFailed,
                .InvalidParameter => return error.InvalidParameter,
                .InvalidSystemState => return error.InvalidSystemState,
                .CarrierAlreadyExists => return error.CarrierAlreadyExists,
                .InvalidAxis => return error.InvalidAxis,
            };
        }
    };

    pub fn format(
        wr: Wr,
        comptime _: []const u8,
        _: std.fmt.FormatOptions,
        writer: anytype,
    ) !void {
        _ = try registers.nestedWrite("Wr", wr, 0, writer);
    }
};

test "Wr" {
    try std.testing.expectEqual(32, @sizeOf(Wr));
}
