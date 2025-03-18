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
            const n = @divFloor(2 * i * dy + dx, 2 * dx);
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
            const n = @divFloor(2 * i * dx + dy, 2 * dy);
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

    pub fn rasterize_circle(this: @This(), x0: i32, y0: i32, r: i32, color: RGBA) void {
        var dx: i32 = 0;
        var dy: i32 = r;
        var v: i32 = 4 * r * r - 1;

        while (dy >= dx) {
            this.draw_px(x0 + dx, y0 + dy, color);
            this.draw_px(x0 - dx, y0 + dy, color);
            this.draw_px(x0 + dx, y0 - dy, color);
            this.draw_px(x0 - dx, y0 - dy, color);

            this.draw_px(x0 + dy, y0 + dx, color);
            this.draw_px(x0 - dy, y0 + dx, color);
            this.draw_px(x0 + dy, y0 - dx, color);
            this.draw_px(x0 - dy, y0 - dx, color);

            v -= 8 * dx + 4;

            if (v < 4 * dy * (dy - 1)) {
                dy -= 1;
            }

            dx += 1;
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

fn DrawCircles(raster: Raster, x0: i32, y0: i32, radii: []const i32) void {
    raster.draw_px(x0, y0, RGBA_RED);

    for (0..radii.len) |i| {
        raster.rasterize_circle(x0, y0, radii[i], RGBA_BLACK);
    }
}

fn DrawCircleDDA(raster: Raster, x0: i32, y0: i32, r: i32, color: RGBA) void {
    var dx: i32 = 0;
    var dy: f32 = @floatFromInt(r);

    while (dy >= @as(f32, @floatFromInt(dx))) {
        const int_dy: i32 = @intFromFloat(@round(dy));
        raster.draw_px(x0 + dx, y0 + int_dy, color);
        raster.draw_px(x0 - dx, y0 + int_dy, color);
        raster.draw_px(x0 + dx, y0 - int_dy, color);
        raster.draw_px(x0 - dx, y0 - int_dy, color);

        raster.draw_px(x0 + int_dy, y0 + dx, color);
        raster.draw_px(x0 - int_dy, y0 + dx, color);
        raster.draw_px(x0 + int_dy, y0 - dx, color);
        raster.draw_px(x0 - int_dy, y0 - dx, color);

        dy += -@as(f32, @floatFromInt(dx)) / dy;
        dx += 1;
    }
}

fn DrawCirclesDDA(raster: Raster, x0: i32, y0: i32, radii: []const i32) void {
    raster.draw_px(x0, y0, RGBA_RED);

    for (0..radii.len) |i| {
        DrawCircleDDA(raster, x0, y0, radii[i], RGBA_BLACK);
    }
}

fn DrawCircleParametric(raster: Raster, x0: i32, y0: i32, r: i32, color: RGBA) void {
    const angle_step = std.math.pi / @as(f32, @floatFromInt(4 * r));
    const r_float: f32 = @floatFromInt(r);

    for (0..@as(usize, @intCast(r))) |i| {
        const angle = angle_step * @as(f32, @floatFromInt(i));
        const dx = r_float * std.math.sin(angle);
        const dy = r_float * std.math.cos(angle);

        const int_dx: i32 = @intFromFloat(@round(dx));
        const int_dy: i32 = @intFromFloat(@round(dy));
        raster.draw_px(x0 + int_dx, y0 + int_dy, color);
        raster.draw_px(x0 - int_dx, y0 + int_dy, color);
        raster.draw_px(x0 + int_dx, y0 - int_dy, color);
        raster.draw_px(x0 - int_dx, y0 - int_dy, color);

        raster.draw_px(x0 + int_dy, y0 + int_dx, color);
        raster.draw_px(x0 - int_dy, y0 + int_dx, color);
        raster.draw_px(x0 + int_dy, y0 - int_dx, color);
        raster.draw_px(x0 - int_dy, y0 - int_dx, color);
    }
}

fn DrawCirclesParametric(raster: Raster, x0: i32, y0: i32, radii: []const i32) void {
    raster.draw_px(x0, y0, RGBA_RED);

    for (0..radii.len) |i| {
        DrawCircleParametric(raster, x0, y0, radii[i], RGBA_BLACK);
    }
}

pub fn Run() !void {
    const file_name = "out.png";

    const width = 409;
    const height = 409;
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

    // circle 1
    const radii = [_]i32{ 50, 40, 30, 20, 10, 5 };
    {
        const x0 = 51 + 0 * 102;
        const y0 = 51 + 1 * 102;

        DrawCircles(raster, x0, y0, &radii);
    }

    // circle 2
    {
        const x0 = 51 + 1 * 102;
        const y0 = 51 + 1 * 102;

        DrawCirclesDDA(raster, x0, y0, &radii);
    }

    // circle 3
    {
        const x0 = 51 + 2 * 102;
        const y0 = 51 + 1 * 102;

        DrawCirclesParametric(raster, x0, y0, &radii);
    }

    try raster.render_out(file_name);
}
