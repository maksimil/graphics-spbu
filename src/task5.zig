const raster = @import("raster.zig");
const config = @import("config.zig");
const render = @import("render.zig");
const std = @import("std");

const kTileWidth = 512;
const kTileHeight = 512;
const kHTiles = 2;
const kVTiles = 2;

const TileRasterizer = struct {
    r: raster.Raster,

    xoffset: i32,
    yoffset: i32,
    xsize: i32,
    ysize: i32,

    pub fn init(
        r: raster.Raster,
        xoffset: i32,
        yoffset: i32,
        xsize: i32,
        ysize: i32,
    ) @This() {
        return .{
            .r = r,
            .xoffset = xoffset,
            .yoffset = yoffset,
            .xsize = xsize,
            .ysize = ysize,
        };
    }

    pub fn GetPx(this: @This(), x: i32, y: i32) *render.RGBA {
        std.debug.assert(x >= 0);
        std.debug.assert(y >= 0);
        std.debug.assert(x < this.xsize);
        std.debug.assert(y < this.ysize);
        return this.r.GetPx(x + this.xoffset, y + this.yoffset);
    }

    pub fn DrawPx(this: @This(), x: i32, y: i32, rgba: render.RGBA) void {
        this.GetPx(x, y).* = rgba;
    }

    pub fn RasterizeLine(
        this: @This(),
        rasterizer: anytype,
        x0: i32,
        y0: i32,
        x1: i32,
        y1: i32,
        color: render.RGBA,
    ) void {
        std.debug.assert(x0 >= 0);
        std.debug.assert(y0 >= 0);
        std.debug.assert(x0 < this.xsize);
        std.debug.assert(y0 < this.ysize);

        std.debug.assert(x1 >= 0);
        std.debug.assert(y1 >= 0);
        std.debug.assert(x1 < this.xsize);
        std.debug.assert(y1 < this.ysize);

        this.r.RasterizeLine(
            rasterizer,
            x0 + this.xoffset,
            y0 + this.yoffset,
            x1 + this.xoffset,
            y1 + this.yoffset,
            color,
        );
    }
};

// fn SimpleIterative(r: TileRasterizer, x0: i32, y0: i32) !void {
// }

pub fn Run() !void {
    const raster_data = try config.allocator.alloc(
        render.RGBA,
        kVTiles * kHTiles * kTileWidth * kTileHeight,
    );
    defer config.allocator.free(raster_data);

    const r = raster.Raster.init(
        raster_data,
        kTileWidth * kVTiles,
        kTileHeight * kHTiles,
    );
    r.Clear(raster.RGBA_WHITE);

    const tile0 = TileRasterizer.init(
        r,
        0 * kTileWidth,
        0 * kTileHeight,
        kTileWidth,
        kTileHeight,
    );
    const tile1 = TileRasterizer.init(
        r,
        1 * kTileWidth,
        0 * kTileHeight,
        kTileWidth,
        kTileHeight,
    );
    const tile2 = TileRasterizer.init(
        r,
        0 * kTileWidth,
        1 * kTileHeight,
        kTileWidth,
        kTileHeight,
    );
    const tile3 = TileRasterizer.init(
        r,
        1 * kTileWidth,
        1 * kTileHeight,
        kTileWidth,
        kTileHeight,
    );

    const region = [_][2]i32{
        .{ 50, 50 },
        .{ 200, 100 },
        .{ 250, 75 },
        .{ 450, 200 },
        .{ 300, 400 },
        .{ 100, 300 },
    };

    for (0..4) |i| {
        const tile = ([_]TileRasterizer{ tile0, tile1, tile2, tile3 })[i];

        for (0..region.len) |j| {
            const p0 = region[j];
            const p1 = region[@mod(j + 1, region.len)];

            tile.RasterizeLine(
                raster.BresenhamRasterizer,
                p0[0],
                p0[1],
                p1[0],
                p1[1],
                raster.RGBA_BLACK,
            );
        }
    }

    try r.RenderOut("out.png");
}
