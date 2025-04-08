const std = @import("std");
const render = @import("render.zig");
const config = @import("config.zig");

const RGBA = render.RGBA;

pub const RGBA_WHITE = RGBA{ .r = 255, .g = 255, .b = 255, .a = 255 };
pub const RGBA_BLACK = RGBA{ .r = 0, .g = 0, .b = 0, .a = 255 };
pub const RGBA_RED = RGBA{ .r = 255, .g = 0, .b = 0, .a = 255 };

fn MixColors(a: RGBA, b: RGBA, a_ratio: config.Scalar) RGBA {
    return RGBA{
        .r = @intFromFloat(@round(a_ratio * config.ToScalar(a.r) +
            (1 - a_ratio) * config.ToScalar(b.r))),
        .g = @intFromFloat(@round(a_ratio * config.ToScalar(a.g) +
            (1 - a_ratio) * config.ToScalar(b.g))),
        .b = @intFromFloat(@round(a_ratio * config.ToScalar(a.b) +
            (1 - a_ratio) * config.ToScalar(b.b))),
        .a = @intFromFloat(@round(a_ratio * config.ToScalar(a.a) +
            (1 - a_ratio) * config.ToScalar(b.a))),
    };
}

pub const Raster = struct {
    data: []render.RGBA,
    width: i32,
    height: i32,

    pub fn init(data: []render.RGBA, width: i32, height: i32) Raster {
        std.debug.assert(data.len == width * height);
        return @This(){ .data = data, .width = width, .height = height };
    }

    pub fn clear(this: @This(), color: RGBA) void {
        for (0..@as(usize, @intCast(this.width * this.height))) |i| {
            this.data[i] = color;
        }
    }

    pub fn draw_px(this: @This(), x: i32, y: i32, rgba: RGBA) void {
        std.debug.assert(x >= 0);
        std.debug.assert(y >= 0);
        std.debug.assert(x < this.width);
        std.debug.assert(y < this.height);

        this.data[@intCast(x + y * this.width)] = rgba;
    }

    pub fn rasterize_line(
        this: @This(),
        rasterizer: anytype,
        x0: i32,
        y0: i32,
        x1: i32,
        y1: i32,
        color: RGBA,
    ) void {
        const dx = x1 - x0;
        const dy = y1 - y0;

        std.debug.assert(x0 >= 0);
        std.debug.assert(x0 < this.width);
        std.debug.assert(y0 >= 0);
        std.debug.assert(y0 < this.height);

        std.debug.assert(x1 >= 0);
        std.debug.assert(x1 < this.width);
        std.debug.assert(y1 >= 0);
        std.debug.assert(y1 < this.height);

        if (dx >= 0) {
            if (dy >= 0) {
                if (dx >= dy) {
                    rasterizer.call(dx, dy, MakePxDrawerType(1, 0, 0, 1){
                        .r = this,
                        .x0 = x0,
                        .y0 = y0,
                    }, color);
                } else {
                    rasterizer.call(dy, dx, MakePxDrawerType(0, 1, 1, 0){
                        .r = this,
                        .x0 = x0,
                        .y0 = y0,
                    }, color);
                }
            } else {
                if (dx >= -dy) {
                    rasterizer.call(dx, -dy, MakePxDrawerType(1, 0, 0, -1){
                        .r = this,
                        .x0 = x0,
                        .y0 = y0,
                    }, color);
                } else {
                    rasterizer.call(-dy, dx, MakePxDrawerType(0, 1, -1, 0){
                        .r = this,
                        .x0 = x0,
                        .y0 = y0,
                    }, color);
                }
            }
        } else {
            if (-dy >= 0) {
                if (-dx >= -dy) {
                    rasterizer.call(-dx, -dy, MakePxDrawerType(1, 0, 0, 1){
                        .r = this,
                        .x0 = x1,
                        .y0 = y1,
                    }, color);
                } else {
                    rasterizer.call(-dy, -dx, MakePxDrawerType(0, 1, 1, 0){
                        .r = this,
                        .x0 = x1,
                        .y0 = y1,
                    }, color);
                }
            } else {
                if (-dx >= dy) {
                    rasterizer.call(-dx, dy, MakePxDrawerType(1, 0, 0, -1){
                        .r = this,
                        .x0 = x1,
                        .y0 = y1,
                    }, color);
                } else {
                    rasterizer.call(dy, -dx, MakePxDrawerType(0, 1, -1, 0){
                        .r = this,
                        .x0 = x1,
                        .y0 = y1,
                    }, color);
                }
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

fn MakePxDrawerType(
    comptime xi: i32,
    comptime xn: i32,
    comptime yi: i32,
    comptime yn: i32,
) type {
    return struct {
        r: Raster,
        x0: i32,
        y0: i32,

        pub fn call(this: @This(), i: i32, n: i32, color: RGBA) void {
            this.r.draw_px(
                this.x0 + xi * i + xn * n,
                this.y0 + yi * i + yn * n,
                color,
            );
        }
    };
}

pub const BresenhamRasterizer = struct {
    pub fn call(x: i32, y: i32, pxdrawer: anytype, color: RGBA) void {
        std.debug.assert(x >= 0);
        std.debug.assert(y >= 0);
        std.debug.assert(y <= x);

        var i: i32 = 0;
        while (i <= x) {
            defer i += 1;

            const n = @divFloor(2 * i * y + x, 2 * x);
            pxdrawer.call(i, n, color);
        }
    }
};

// 0 if x=0
fn signi32(x: i32) i32 {
    const p: i32 = @intFromBool(x > 0);
    const n: i32 = @intFromBool(x < 0);
    return p - n;
}

pub const ModifiedBresenhamRasterizer = struct {
    pub fn call(x: i32, y: i32, pxdrawer: anytype, color: RGBA) void {
        std.debug.assert(x >= 0);
        std.debug.assert(y >= 0);
        std.debug.assert(y <= x);

        pxdrawer.call(0, 0, color);
        pxdrawer.call(x, y, color);

        config.stdout.print("{d}\n", .{@as(usize, @intCast(x))}) catch unreachable;

        var i: i32 = 1;
        while (i < x) {
            defer i += 1;

            const n = @divFloor(2 * i * y + x, 2 * x);
            const dn = signi32(i * y - n * x);
            const np = n + dn;

            const sat = blk: {
                break :blk 0.5;
            };

            pxdrawer.call(i, np, MixColors(color, RGBA_WHITE, sat));
            pxdrawer.call(i, n, color);
        }
    }
};
