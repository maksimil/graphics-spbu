const std = @import("std");
const config = @import("config.zig");
const render = @import("render.zig");

const RGBA = render.RGBA;
const RGBA_WHITE = RGBA{ .r = 255, .g = 255, .b = 255, .a = 255 };
const RGBA_BLACK = RGBA{ .r = 0, .g = 0, .b = 0, .a = 255 };
const RGBA_RED = RGBA{ .r = 255, .g = 0, .b = 0, .a = 255 };

const Raster = struct {
    data: []render.RGBA,
    width: i32,
    height: i32,

    pub fn init(data: []render.RGBA, width: i32, height: i32) Raster {
        std.debug.assert(data.len == width * height);
        return @This(){ .data = data, .width = width, .height = height };
    }

    pub fn draw_px(this: @This(), x: i32, y: i32, rgba: RGBA) void {
        std.debug.assert(x >= 0);
        std.debug.assert(y >= 0);
        std.debug.assert(x < this.width);
        std.debug.assert(y < this.height);

        this.data[@intCast(x + y * this.width)] = rgba;
    }

    fn rasterize_line_I_VIII(
        this: @This(),
        x0: i32,
        y0: i32,
        x1: i32,
        y1: i32,
        color: RGBA,
    ) void {
        const dx = x1 - x0;
        const dy = y1 - y0;

        std.debug.assert(dx >= 0);
        std.debug.assert(dx >= @abs(dy));

        for (0..(@as(usize, @intCast(dx)) + 1)) |idx| {
            const i: i32 = @intCast(idx);
            const n = @divTrunc(i * dy, dx);
            this.draw_px(x0 + i, y0 + n, color);
        }
    }

    fn rasterize_line_II_III(
        this: @This(),
        x0: i32,
        y0: i32,
        x1: i32,
        y1: i32,
        color: RGBA,
    ) void {
        const dx = x1 - x0;
        const dy = y1 - y0;

        std.debug.assert(dy >= 0);
        std.debug.assert(dy >= @abs(dx));

        for (0..(@as(usize, @intCast(dy)) + 1)) |idx| {
            const i: i32 = @intCast(idx);
            const n = @divTrunc(i * dx, dy);
            this.draw_px(x0 + n, y0 + i, color);
        }
    }

    pub fn rasterize_line(
        this: @This(),
        x0: i32,
        y0: i32,
        x1: i32,
        y1: i32,
        color: RGBA,
    ) void {
        const dx = x1 - x0;
        const dy = y1 - y0;

        if (dx + dy >= 0) {
            if (dx - dy >= 0) {
                this.rasterize_line_I_VIII(x0, y0, x1, y1, color);
            } else {
                this.rasterize_line_II_III(x0, y0, x1, y1, color);
            }
        } else {
            if (dx - dy >= 0) {
                this.rasterize_line_II_III(x1, y1, x0, y0, color);
            } else {
                this.rasterize_line_I_VIII(x1, y1, x0, y0, color);
            }
        }
    }

    pub fn render_out(this: @This(), file_name: [:0]const u8) !void {
        try render.render_to_file(
            file_name,
            @intCast(this.width),
            @intCast(this.height),
            this.data,
        );
    }
};

fn DrawCross(raster: Raster, x0: i32, y0: i32, points: []const [2]i32) void {
    for (0..points.len) |i| {
        const x1 = points[i][0];
        const y1 = points[i][1];

        raster.rasterize_line(x0, y0, x1, y1, RGBA_BLACK);
    }

    raster.draw_px(x0, y0, RGBA_RED);
}

pub fn Run() !void {
    const file_name = "out.png";

    const width = 412;
    const height = 412;
    var data = [_]RGBA{RGBA_WHITE} ** (width * height);
    const raster = Raster.init(&data, width, height);

    // + cross
    {
        const x0 = 51 + 0 * 102;
        const y0 = 51 + 0 * 102;

        const points = [_][2]i32{
            .{ x0 + 50, y0 },
            .{ x0 - 50, y0 },
            .{ x0, y0 + 50 },
            .{ x0, y0 - 50 },
        };

        DrawCross(raster, x0, y0, &points);
    }

    // x cross
    {
        const x0 = 51 + 1 * 102;
        const y0 = 51 + 0 * 102;

        const points = [_][2]i32{
            .{ x0 + 50, y0 + 50 },
            .{ x0 + 50, y0 - 50 },
            .{ x0 - 50, y0 + 50 },
            .{ x0 - 50, y0 - 50 },
        };

        DrawCross(raster, x0, y0, &points);
    }

    // weird cross 1
    {
        const x0 = 51 + 2 * 102;
        const y0 = 51 + 0 * 102;

        const points = [_][2]i32{
            .{ x0 - 9, y0 - 50 },
            .{ x0 - 50, y0 - 30 },
            .{ x0 + 50, y0 - 47 },
            .{ x0 - 21, y0 + 50 },
            .{ x0 + 13, y0 + 50 },
        };

        DrawCross(raster, x0, y0, &points);
    }

    // weird cross 2
    {
        const x0 = 51 + 3 * 102;
        const y0 = 51 + 0 * 102;

        const points = [_][2]i32{
            .{ x0 - 50, y0 + 26 },
            .{ x0 - 50, y0 - 16 },
            .{ x0 + 50, y0 + 30 },
            .{ x0 + 50, y0 - 46 },
            .{ x0 + 19, y0 - 50 },
            .{ x0 - 32, y0 - 50 },
            .{ x0 + 31, y0 + 50 },
            .{ x0 - 2, y0 + 50 },
        };

        DrawCross(raster, x0, y0, &points);
    }

    try raster.render_out(file_name);
}
