const std = @import("std");
const render = @import("render.zig");

const RGBA = render.RGBA;

pub const RGBA_WHITE = RGBA{ .r = 255, .g = 255, .b = 255, .a = 255 };
pub const RGBA_BLACK = RGBA{ .r = 0, .g = 0, .b = 0, .a = 255 };
pub const RGBA_RED = RGBA{ .r = 255, .g = 0, .b = 0, .a = 255 };

pub const Raster = struct {
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
