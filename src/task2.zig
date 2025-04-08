const std = @import("std");
const config = @import("config.zig");
const render = @import("render.zig");
const raster = @import("raster.zig");

const Raster = raster.Raster;

fn DrawCross(r: Raster, x0: i32, y0: i32, points: []const [2]i32) void {
    for (0..points.len) |i| {
        const x1 = points[i][0];
        const y1 = points[i][1];

        r.rasterize_line(
            raster.BresenhamRasterizer,
            x0,
            y0,
            x1,
            y1,
            raster.RGBA_BLACK,
        );
    }

    r.draw_px(x0, y0, raster.RGBA_RED);
}

fn DrawCircles(r: Raster, x0: i32, y0: i32, radii: []const i32) void {
    r.draw_px(x0, y0, raster.RGBA_RED);

    for (0..radii.len) |i| {
        r.rasterize_circle(x0, y0, radii[i], raster.RGBA_BLACK);
    }
}

fn DrawCircleDDA(ra: Raster, x0: i32, y0: i32, r: i32, color: render.RGBA) void {
    var dx: i32 = 0;
    var dy: f32 = @floatFromInt(r);

    while (dy >= @as(f32, @floatFromInt(dx))) {
        const int_dy: i32 = @intFromFloat(@round(dy));
        ra.draw_px(x0 + dx, y0 + int_dy, color);
        ra.draw_px(x0 - dx, y0 + int_dy, color);
        ra.draw_px(x0 + dx, y0 - int_dy, color);
        ra.draw_px(x0 - dx, y0 - int_dy, color);

        ra.draw_px(x0 + int_dy, y0 + dx, color);
        ra.draw_px(x0 - int_dy, y0 + dx, color);
        ra.draw_px(x0 + int_dy, y0 - dx, color);
        ra.draw_px(x0 - int_dy, y0 - dx, color);

        dy += -@as(f32, @floatFromInt(dx)) / dy;
        dx += 1;
    }
}

fn DrawCirclesDDA(r: Raster, x0: i32, y0: i32, radii: []const i32) void {
    r.draw_px(x0, y0, raster.RGBA_RED);

    for (0..radii.len) |i| {
        DrawCircleDDA(r, x0, y0, radii[i], raster.RGBA_BLACK);
    }
}

fn DrawCircleParametric(ra: Raster, x0: i32, y0: i32, r: i32, color: render.RGBA) void {
    const angle_step = std.math.pi / @as(f32, @floatFromInt(4 * r));
    const r_float: f32 = @floatFromInt(r);

    for (0..@as(usize, @intCast(r))) |i| {
        const angle = angle_step * @as(f32, @floatFromInt(i));
        const dx = r_float * std.math.sin(angle);
        const dy = r_float * std.math.cos(angle);

        const int_dx: i32 = @intFromFloat(@round(dx));
        const int_dy: i32 = @intFromFloat(@round(dy));
        ra.draw_px(x0 + int_dx, y0 + int_dy, color);
        ra.draw_px(x0 - int_dx, y0 + int_dy, color);
        ra.draw_px(x0 + int_dx, y0 - int_dy, color);
        ra.draw_px(x0 - int_dx, y0 - int_dy, color);

        ra.draw_px(x0 + int_dy, y0 + int_dx, color);
        ra.draw_px(x0 - int_dy, y0 + int_dx, color);
        ra.draw_px(x0 + int_dy, y0 - int_dx, color);
        ra.draw_px(x0 - int_dy, y0 - int_dx, color);
    }
}

fn DrawCirclesParametric(r: Raster, x0: i32, y0: i32, radii: []const i32) void {
    r.draw_px(x0, y0, raster.RGBA_RED);

    for (0..radii.len) |i| {
        DrawCircleParametric(r, x0, y0, radii[i], raster.RGBA_BLACK);
    }
}

pub fn Run() !void {
    const file_name = "out.png";

    const width = 409;
    const height = 409;
    var data = [_]render.RGBA{raster.RGBA_WHITE} ** (width * height);
    const r = Raster.init(&data, width, height);

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

        DrawCross(r, x0, y0, &points);
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

        DrawCross(r, x0, y0, &points);
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

        DrawCross(r, x0, y0, &points);
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

        DrawCross(r, x0, y0, &points);
    }

    // circle 1
    const radii = [_]i32{ 50, 40, 30, 20, 10, 5 };
    {
        const x0 = 51 + 0 * 102;
        const y0 = 51 + 1 * 102;

        DrawCircles(r, x0, y0, &radii);
    }

    // circle 2
    {
        const x0 = 51 + 1 * 102;
        const y0 = 51 + 1 * 102;

        DrawCirclesDDA(r, x0, y0, &radii);
    }

    // circle 3
    {
        const x0 = 51 + 2 * 102;
        const y0 = 51 + 1 * 102;

        DrawCirclesParametric(r, x0, y0, &radii);
    }

    try r.render_out(file_name);
}
