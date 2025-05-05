const std = @import("std");
const config = @import("config.zig");
const raster = @import("raster.zig");
const render = @import("render.zig");
const task5 = @import("task5.zig");
const task7 = @import("task7.zig");

const kTileWidth = 512;
const kTileHeight = 512;
const kHTiles = 2;
const kVTiles = 1;

fn IsInside(
    border0: [2]i32,
    border1: [2]i32,
    point: [2]i32,
) bool {
    return point[0] * (border0[1] - border1[1]) +
        point[1] * (border1[0] - border0[0]) >=
        border0[1] * border1[0] - border0[0] * border1[1];
}

fn Intersect(
    border0: [2]i32,
    border1: [2]i32,
    point0: [2]i32,
    point1: [2]i32,
) [2]i32 {
    const p = border0[1] * border1[0] - border0[0] * border1[1] +
        border0[0] * point0[1] - point0[0] * border0[1] +
        point0[0] * border1[1] - border1[0] * point0[1];
    const q = (border0[1] - border1[1]) * (point1[0] - point0[0]) +
        (point1[1] - point0[1]) * (border1[0] - border0[0]);
    return .{
        point0[0] + config.DivRound(p * (point1[0] - point0[0]), q),
        point0[1] + config.DivRound(p * (point1[1] - point0[1]), q),
    };
}

fn SutherlandHodgman(
    clip_region: []const [2]i32,
    region: []const [2]i32,
) !std.ArrayList([2]i32) {
    var points_list = std.ArrayList([2]i32).init(config.allocator);
    defer points_list.deinit();

    var points_list_swap = std.ArrayList([2]i32).init(config.allocator);
    errdefer points_list_swap.deinit();

    try points_list.ensureTotalCapacity(3 * region.len);
    try points_list_swap.ensureTotalCapacity(3 * region.len);

    for (0..region.len) |i| {
        try points_list_swap.append(region[i]);
    }

    // for (0..1) |j| {
    for (0..clip_region.len) |j| {
        const border0 = clip_region[j];
        const border1 = clip_region[@mod(j + 1, clip_region.len)];

        for (0..points_list_swap.items.len) |i| {
            const p0 = points_list_swap.items[i];
            const p1 = points_list_swap.items[
                @mod(i + 1, points_list_swap.items.len)
            ];

            const p0_inside = IsInside(border0, border1, p0);
            const p1_inside = IsInside(border0, border1, p1);

            if (p0_inside and p1_inside) {
                try points_list.append(p1);
            } else if (p0_inside or p1_inside) {
                const intersection = Intersect(border0, border1, p0, p1);

                try points_list.append(intersection);

                if (p1_inside) {
                    try points_list.append(p1);
                }
            }
        }

        std.mem.swap(std.ArrayList([2]i32), &points_list, &points_list_swap);
        points_list.clearRetainingCapacity();
    }

    return points_list_swap;
}

pub fn Run() !void {
    const raster_data = try config.allocator.alloc(
        render.RGBA,
        kVTiles * kHTiles * kTileWidth * kTileHeight,
    );
    defer config.allocator.free(raster_data);

    const r = raster.Raster.init(
        raster_data,
        kTileWidth * kHTiles,
        kTileHeight * kVTiles,
    );
    r.Clear(raster.RGBA_WHITE);

    const box_x = 100;
    const box_y = 100;
    const box_w = 200;
    const box_h = 300;

    const box_border = [_][2]i32{
        .{ box_x, box_y },
        .{ box_x + box_w, box_y },
        .{ box_x + box_w, box_y + box_h },
        .{ box_x, box_y + box_h },
    };

    const region1 = [_][2]i32{
        .{ 70, 50 },
        .{ 120, 100 },
        .{ 150, 100 },
        .{ 350, 200 },
        .{ 50, 150 },
    };

    const region2 = [_][2]i32{
        .{ 200, 200 },
        .{ 250, 280 },
        .{ 150, 280 },
    };

    const region3 = [_][2]i32{
        .{ 50, 450 },
        .{ 100, 450 },
        .{ 70, 500 },
        .{ 40, 440 },
    };

    const tile0 = task5.TileRasterizer.init(
        r,
        0 * kTileWidth,
        0 * kTileHeight,
        kTileWidth,
        kTileHeight,
    );

    const tile1 = task5.TileRasterizer.init(
        r,
        1 * kTileWidth,
        0 * kTileHeight,
        kTileWidth,
        kTileHeight,
    );

    const tiles = [_]task5.TileRasterizer{ tile0, tile1 };

    for (0..2) |i| {
        const tile = tiles[i];
        task7.DrawRegionBorder(
            tile,
            raster.BresenhamRasterizer,
            &box_border,
            raster.RGBA_BLUE,
        );
        task7.DrawRegionBorder(
            tile,
            raster.BresenhamRasterizer,
            &region1,
            raster.RGBA_BLACK,
        );
        task7.DrawRegionBorder(
            tile,
            raster.BresenhamRasterizer,
            &region2,
            raster.RGBA_BLACK,
        );
        task7.DrawRegionBorder(
            tile,
            raster.BresenhamRasterizer,
            &region3,
            raster.RGBA_BLACK,
        );
    }

    {
        var region1_clip = try SutherlandHodgman(&box_border, &region1);
        defer region1_clip.deinit();

        if (region1_clip.items.len > 1) {
            task7.DrawRegionBorder(
                tile0,
                raster.BresenhamRasterizer,
                region1_clip.items,
                raster.RGBA_RED,
            );
        }

        var region2_clip = try SutherlandHodgman(&box_border, &region2);
        defer region2_clip.deinit();

        if (region2_clip.items.len > 1) {
            task7.DrawRegionBorder(
                tile0,
                raster.BresenhamRasterizer,
                region2_clip.items,
                raster.RGBA_RED,
            );
        }

        var region3_clip = try SutherlandHodgman(&box_border, &region3);
        defer region3_clip.deinit();

        if (region3_clip.items.len > 1) {
            task7.DrawRegionBorder(
                tile0,
                raster.BresenhamRasterizer,
                region3_clip.items,
                raster.RGBA_RED,
            );
        }
    }

    try r.RenderOut("output/task8.png");
}
