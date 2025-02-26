const Line = @This();

const std = @import("std");
const mdfunc = @import("mdfunc");
const cc_link = @import("cc_link.zig");
const Axis = @import("Axis.zig");
const Station = @import("Station.zig");
const Config = @import("Config.zig");

// The maximum number of stations is also the maximum number of lines, as
// there can be a minimum of one station per line.
pub const Index = Station.Index;
pub const Id = Station.Id;

index: Index,
id: Id,

/// Axes that make up line. Each axis contains both its own line index and
/// local station index.
axes: []Axis,

/// Stations that make up line.
stations: []Station,

x: []Station.X,
y: []Station.Y,
wr: []Station.Wr,
ww: []Station.Ww,

connection: []Range,

allocator: std.mem.Allocator,

const Range = struct {
    channel: cc_link.Channel,
    range: cc_link.Range,
};

pub fn init(
    allocator: std.mem.Allocator,
    result: *Line,
    line_index: Index,
    config: Config.Line,
) !void {
    result.index = line_index;
    result.id = line_index + 1;
    result.connection = try allocator.alloc(Range, config.ranges.len);
    errdefer allocator.free(result.connection);
    result.axes = try allocator.alloc(Axis, config.axes);
    errdefer allocator.free(result.axes);
    result.stations = try allocator.alloc(Station, (config.axes - 1) / 3 + 1);
    errdefer allocator.free(result.stations);
    result.x = try allocator.alloc(Station.X, result.stations.len);
    errdefer allocator.free(result.x);
    result.y = try allocator.alloc(Station.Y, result.stations.len);
    errdefer allocator.free(result.y);
    result.wr = try allocator.alloc(Station.Wr, result.stations.len);
    errdefer allocator.free(result.wr);
    result.ww = try allocator.alloc(Station.Ww, result.stations.len);
    errdefer allocator.free(result.ww);

    @memset(result.x, std.mem.zeroInit(Station.X, .{}));
    @memset(result.y, std.mem.zeroInit(Station.Y, .{}));
    @memset(result.wr, std.mem.zeroInit(Station.Wr, .{}));
    @memset(result.ww, std.mem.zeroInit(Station.Ww, .{}));

    var num_axes: usize = 0;

    for (config.ranges, 0..) |range, range_i| {
        result.connection[range_i] = .{
            .channel = range.channel,
            .range = .{
                .start = @intCast(range.start - 1),
                .end = @intCast(range.end - 1),
            },
        };
        for (0..range.end - range.start + 1) |station_i| {
            const start_num_axes = num_axes;
            for (0..3) |axis_i| {
                if (num_axes >= result.axes.len) break;
                result.axes[num_axes] = .{
                    .station = &result.stations[station_i],
                    .index = .{
                        .station = @intCast(axis_i),
                        .line = @intCast(num_axes),
                    },
                    .id = .{
                        .station = @intCast(axis_i + 1),
                        .line = @intCast(num_axes + 1),
                    },
                };
                num_axes += 1;
            }
            result.stations[station_i] = .{
                .line = result,
                .index = @intCast(station_i),
                .id = @intCast(station_i + 1),
                .x = &result.x[station_i],
                .y = &result.y[station_i],
                .wr = &result.wr[station_i],
                .ww = &result.ww[station_i],
                .axes = result.axes[start_num_axes..num_axes],
                .connection = .{
                    .channel = range.channel,
                    .index = @intCast(range.start - 1 + station_i),
                },
            };
        }
    }
    result.allocator = allocator;
}

pub fn deinit(self: *Line) void {
    self.allocator.free(self.axes);
    self.allocator.free(self.stations);
    self.allocator.free(self.x);
    self.allocator.free(self.y);
    self.allocator.free(self.wr);
    self.allocator.free(self.ww);
    self.allocator.free(self.connection);
    self.* = undefined;
}

/// Poll registers x and wr on the line
pub fn poll(line: Line) !void {
    var range_offset: usize = 0;
    for (line.connection) |range| {
        const path = try range.channel.openedPath();
        const range_len: usize =
            @as(usize, range.range.end - range.range.start) + 1;
        defer range_offset += range_len;

        const x_read_bytes = try mdfunc.receiveEx(
            path,
            0,
            0xFF,
            .DevX,
            @as(i32, range.range.start) * @bitSizeOf(Station.X),
            std.mem.sliceAsBytes(line.x[range_offset..][0..range_len]),
        );
        if (x_read_bytes != @sizeOf(Station.X) * range_len) {
            return cc_link.Error.UnexpectedReadSizeX;
        }

        const wr_read_bytes = try mdfunc.receiveEx(
            path,
            0,
            0xFF,
            .DevWr,
            @as(i32, range.range.start) * 16, // 16 from MELSEC manual.
            std.mem.sliceAsBytes(line.wr[range_offset..][0..range_len]),
        );
        if (wr_read_bytes != @sizeOf(Station.Wr) * range_len) {
            return cc_link.Error.UnexpectedReadSizeWr;
        }
    }
}

pub fn pollX(line: Line) (cc_link.Error || mdfunc.Error)!void {
    var range_offset: usize = 0;
    for (line.connection) |range| {
        const path = try range.channel.openedPath();
        const range_len: usize =
            @as(usize, range.range.end - range.range.start) + 1;
        defer range_offset += range_len;

        const read_bytes = try mdfunc.receiveEx(
            path,
            0,
            0xFF,
            .DevX,
            @as(i32, range.range.start) * @bitSizeOf(Station.X),
            std.mem.sliceAsBytes(line.x[range_offset..][0..range_len]),
        );
        if (read_bytes != @sizeOf(Station.X) * range_len) {
            return cc_link.Error.UnexpectedReadSizeX;
        }
    }
}

pub fn pollY(line: Line) (cc_link.Error || mdfunc.Error)!void {
    var range_offset: usize = 0;
    for (line.connection) |range| {
        const path = try range.channel.openedPath();
        const range_len: usize =
            @as(usize, range.range.end - range.range.start) + 1;
        defer range_offset += range_len;

        const read_bytes = try mdfunc.receiveEx(
            path,
            0,
            0xFF,
            .DevY,
            @as(i32, range.range.start) * @bitSizeOf(Station.Y),
            std.mem.sliceAsBytes(line.y[range_offset..][0..range_len]),
        );
        if (read_bytes != @sizeOf(Station.Y) * range_len) {
            return cc_link.Error.UnexpectedReadSizeY;
        }
    }
}

pub fn pollWr(line: Line) (cc_link.Error || mdfunc.Error)!void {
    var range_offset: usize = 0;
    for (line.connection) |range| {
        const path = try range.channel.openedPath();
        const range_len: usize =
            @as(usize, range.range.end - range.range.start) + 1;
        defer range_offset += range_len;

        const read_bytes = try mdfunc.receiveEx(
            path,
            0,
            0xFF,
            .DevWr,
            @as(i32, range.range.start) * 16, // 16 from MELSEC manual.
            std.mem.sliceAsBytes(line.wr[range_offset..][0..range_len]),
        );
        if (read_bytes != @sizeOf(Station.Wr) * range_len) {
            return cc_link.Error.UnexpectedReadSizeWr;
        }
    }
}

pub fn pollWw(line: Line) (cc_link.Error || mdfunc.Error)!void {
    var range_offset: usize = 0;
    for (line.connection) |range| {
        const path = try range.channel.openedPath();
        const range_len: usize =
            @as(usize, range.range.end - range.range.start) + 1;
        defer range_offset += range_len;

        const read_bytes = try mdfunc.receiveEx(
            path,
            0,
            0xFF,
            .DevWw,
            @as(i32, range.range.start) * 16, // 16 from MELSEC manual.
            std.mem.sliceAsBytes(line.ww[range_offset..][0..range_len]),
        );
        if (read_bytes != @sizeOf(Station.Ww) * range_len) {
            return cc_link.Error.UnexpectedReadSizeWw;
        }
    }
}

pub fn send(line: Line) (cc_link.Error || mdfunc.Error)!void {
    var range_offset: usize = 0;
    for (line.connection) |range| {
        const path = try range.channel.openedPath();
        const range_len: usize =
            @as(usize, range.range.end - range.range.start) + 1;
        defer range_offset += range_len;

        const ww_sent_bytes = try mdfunc.sendEx(
            path,
            0,
            0xFF,
            .DevWw,
            @as(i32, range.range.start) * 16, // 16 from MELSEC manual.
            std.mem.sliceAsBytes(line.ww[range_offset..][0..range_len]),
        );
        if (ww_sent_bytes != @sizeOf(Station.Ww) * range_len) {
            return cc_link.Error.UnexpectedSendSizeWw;
        }

        const y_sent_bytes = try mdfunc.sendEx(
            path,
            0,
            0xFF,
            .DevY,
            @as(i32, range.range.start) * @bitSizeOf(Station.Y),
            std.mem.sliceAsBytes(line.y[range_offset..][0..range_len]),
        );
        if (y_sent_bytes != @sizeOf(Station.Y) * range_len) {
            return cc_link.Error.UnexpectedSendSizeY;
        }
    }
}

pub fn sendY(line: Line) (cc_link.Error || mdfunc.Error)!void {
    var range_offset: usize = 0;
    for (line.connection) |range| {
        const path = try range.channel.openedPath();
        const range_len: usize =
            @as(usize, range.range.end - range.range.start) + 1;
        defer range_offset += range_len;

        const sent_bytes = try mdfunc.sendEx(
            path,
            0,
            0xFF,
            .DevY,
            @as(i32, range.range.start) * @bitSizeOf(Station.Y),
            std.mem.sliceAsBytes(line.y[range_offset..][0..range_len]),
        );
        if (sent_bytes != @sizeOf(Station.Y) * range_len) {
            return cc_link.Error.UnexpectedSendSizeY;
        }
    }
}

pub fn sendWw(line: Line) (cc_link.Error || mdfunc.Error)!void {
    var range_offset: usize = 0;
    for (line.connection) |range| {
        const path = try range.channel.openedPath();
        const range_len: usize =
            @as(usize, range.range.end - range.range.start) + 1;
        defer range_offset += range_len;

        const sent_bytes = try mdfunc.sendEx(
            path,
            0,
            0xFF,
            .DevWw,
            @as(i32, range.range.start) * 16, // 16 from MELSEC manual.
            std.mem.sliceAsBytes(line.ww[range_offset..][0..range_len]),
        );
        if (sent_bytes != @sizeOf(Station.Ww) * range_len) {
            return cc_link.Error.UnexpectedSendSizeWw;
        }
    }
}

/// Return the axis of the specified carrier, if found in the system. If the
/// carrier is split across two axes, then the auxiliary axis will be included
/// in the result tuple.
pub fn search(line: *const Line, carrier_id: u16) ?struct { Axis, ?Axis } {
    var result: struct { Axis, ?Axis } = .{ undefined, null };

    for (line.axes) |axis| {
        const station = axis.station;
        const wr = station.wr;
        if (wr.carrier.axis(axis.index.station).id == carrier_id) {
            result.@"0" = axis;

            if (axis.index.station == 2 and axis.id.line < line.axes.len) {
                const next_axis = line.axes[axis.index.line + 1];
                const next_station = next_axis.station;
                const next_wr = next_station.wr;

                if (next_wr.carrier.axis(
                    next_axis.index.station,
                ).id == carrier_id) {
                    result.@"1" = next_axis;
                }
            }

            break;
        }
    } else {
        return null;
    }

    // If there are two detected contiguous axes, determine which is primary
    // and auxiliary.
    if (result.@"1") |*aux| {
        const main: *Axis = &result.@"0";
        if (main.isAuxiliaryTo(aux.*)) {
            const temp = main.*;
            main.* = aux.*;
            aux.* = temp;
        }
    }

    return result;
}

test "Line search" {
    var line: Line = undefined;
    var _ranges: [1]Config.Line.Range = .{.{
        .channel = .cc_link_1slot,
        .start = 1,
        .end = 3,
    }};
    try Line.init(std.testing.allocator, &line, 0, .{
        .axes = 9,
        .ranges = &_ranges,
    });
    defer line.deinit();

    line.stations[1].wr.carrier.axis3 = .{
        .id = 1,
        .auxiliary = true,
        .enabled = true,
        .state = .NextAxisCompleted,
    };
    line.stations[2].wr.carrier.axis1 = .{
        .id = 1,
        .auxiliary = false,
        .enabled = true,
        .state = .PosMoveCompleted,
    };

    const _result = line.search(1);
    try std.testing.expect(_result != null);
    const result = _result.?;
    try std.testing.expect(result.@"1" != null);
    const main = result.@"0";
    const aux = result.@"1".?;
    try std.testing.expectEqual(7, main.id.line);
    try std.testing.expectEqual(6, aux.id.line);
}

test {
    var _ranges: [1]Config.Line.Range = .{.{
        .channel = .cc_link_1slot,
        .start = 1,
        .end = 2,
    }};
    var line: Line = undefined;
    try Line.init(std.testing.allocator, &line, 0, .{
        .axes = 6,
        .ranges = &_ranges,
    });
    defer line.deinit();

    line.stations[1].y.cc_link_enable = true;
    try std.testing.expectEqual(true, line.y[1].cc_link_enable);
}
