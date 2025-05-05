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

fn IsInsidePoly(
    border: []const [2]i32,
    point: [2]i32,
) bool {
    var inside = true;

    for (0..border.len) |i| {
        const border0 = border[i];
        const border1 = border[@mod(i + 1, border.len)];
        inside = IsInside(border0, border1, point);

        if (!inside) {
            return false;
        }
    }

    return true;
}

fn IntersectPQ(
    a0: [2]i32,
    b0: [2]i32,
    a1: [2]i32,
    b1: [2]i32,
) struct { p0: i32, p1: i32, q: i32 } {
    const x0, const y0 = a0;
    const x1, const y1 = a1;

    const dx0 = b0[0] - x0;
    const dy0 = b0[1] - y0;
    const dx1 = b1[0] - x1;
    const dy1 = b1[1] - y1;

    var q = dy0 * dx1 - dy1 * dx0;
    var p0 = -dy1 * (x1 - x0) + dx1 * (y1 - y0);
    var p1 = -dy0 * (x1 - x0) + dx0 * (y1 - y0);

    if (q < 0) {
        q = -q;
        p0 = -p0;
        p1 = -p1;
    }

    return .{ .p0 = p0, .p1 = p1, .q = q };
}

fn Intersect(
    a0: [2]i32,
    b0: [2]i32,
    a1: [2]i32,
    b1: [2]i32,
) struct { point: [2]i32, p0: i32, p1: i32, q: i32 } {
    const x0, const y0 = a0;

    const dx0 = b0[0] - x0;
    const dy0 = b0[1] - y0;

    const pq = IntersectPQ(a0, b0, a1, b1);

    const point = [2]i32{
        x0 + config.DivRound(pq.p0 * dx0, pq.q),
        y0 + config.DivRound(pq.p0 * dy0, pq.q),
    };

    return .{ .point = point, .p0 = pq.p0, .p1 = pq.p1, .q = pq.q };
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
                const intersection = Intersect(border0, border1, p0, p1).point;

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

fn FindIndex(comptime T: type, arr: []const T, f: anytype) ?usize {
    for (0..arr.len) |i| {
        if (f.call(arr[i])) {
            return i;
        }
    }
    return null;
}

fn WeilerAtherton(
    clip_region: []const [2]i32,
    figure: []const [2]i32,
) !std.ArrayList([2]i32) {
    const TaggedPoint = struct {
        point: [2]i32,
        vertex: usize,
        jump: bool,
        tag: usize,
    };

    var tag: usize = 1;

    var clip_list = std.ArrayList(TaggedPoint).init(config.allocator);
    defer clip_list.deinit();

    var figure_list = std.ArrayList(TaggedPoint).init(config.allocator);
    defer figure_list.deinit();

    try clip_list.ensureTotalCapacity(2 * clip_region.len);
    try figure_list.ensureTotalCapacity(2 * figure.len);

    for (0..clip_region.len) |i| {
        try clip_list.append(
            .{ .point = clip_region[i], .vertex = i, .jump = false, .tag = 0 },
        );
    }

    for (0..figure.len) |i| {
        try figure_list.append(
            .{ .point = figure[i], .vertex = i, .jump = false, .tag = 0 },
        );
    }

    for (0..clip_region.len) |i| {
        const clip0 = clip_region[i];
        const clip1 = clip_region[@mod(i + 1, clip_region.len)];

        for (0..figure.len) |j| {
            const fig0 = figure[j];
            const fig1 = figure[@mod(j + 1, figure.len)];

            const pq = IntersectPQ(clip0, clip1, fig0, fig1);

            if (pq.q != 0) {
                if (pq.p0 <= pq.q and pq.p0 > 0 and
                    pq.p1 <= pq.q and pq.p1 > 0)
                {
                    const point = [2]i32{
                        fig0[0] + config.DivRound((fig1[0] - fig0[0]) * pq.p1, pq.q),
                        fig0[1] + config.DivRound((fig1[1] - fig0[1]) * pq.p1, pq.q),
                    };

                    try clip_list.append(
                        .{ .point = point, .vertex = i, .jump = true, .tag = tag },
                    );
                    try figure_list.append(
                        .{ .point = point, .vertex = j, .jump = true, .tag = tag },
                    );
                    tag += 1;
                }
            }
        }
    }

    const TaggedPointSort = struct {
        region: []const [2]i32,

        pub fn call(this: @This(), lhs: TaggedPoint, rhs: TaggedPoint) bool {
            if (lhs.vertex != rhs.vertex) {
                return lhs.vertex < rhs.vertex;
            } else {
                const vertex = this.region[lhs.vertex];
                const lhs_dist =
                    @abs(lhs.point[0] - vertex[0]) +
                    @abs(lhs.point[1] - vertex[1]);
                const rhs_dist =
                    @abs(rhs.point[0] - vertex[0]) +
                    @abs(rhs.point[1] - vertex[1]);
                return lhs_dist < rhs_dist;
            }
        }
    };

    std.sort.pdq(
        TaggedPoint,
        clip_list.items,
        TaggedPointSort{ .region = clip_region },
        TaggedPointSort.call,
    );

    std.sort.pdq(
        TaggedPoint,
        figure_list.items,
        TaggedPointSort{ .region = figure },
        TaggedPointSort.call,
    );

    config.stdout.print(
        "{any}\n\n{any}\n\n",
        .{
            std.json.fmt(clip_list.items, .{ .whitespace = .indent_4 }),
            std.json.fmt(figure_list.items, .{ .whitespace = .indent_4 }),
        },
    ) catch unreachable;

    var points = std.ArrayList([2]i32).init(config.allocator);
    errdefer points.deinit();

    var i: usize = 0;
    var nlist: usize = 0;
    const lists = [_]std.ArrayList(TaggedPoint){ figure_list, clip_list };

    while (i < figure_list.items.len and
        !IsInsidePoly(clip_region, figure_list.items[i].point))
    {
        i += 1;
    }

    if (i == figure_list.items.len) {
        return points;
    }

    const j = i;

    try points.append(figure_list.items[i].point);
    i = @mod(i + 1, lists[nlist].items.len);

    while (!(nlist == 0 and i == j)) {
        const pt = lists[nlist].items[i];

        try points.append(pt.point);

        if (pt.jump) {
            nlist = 1 - nlist;
            i = FindIndex(TaggedPoint, lists[nlist].items, struct {
                tag: usize,

                pub fn call(this: @This(), v: TaggedPoint) bool {
                    return this.tag == v.tag;
                }
            }{ .tag = pt.tag }).?;

            if (nlist == 0 and i == j) {
                break;
            }
        }

        i = @mod(i + 1, lists[nlist].items.len);
    }

    return points;
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

    const region4 = [_][2]i32{
        .{ 100, 300 },
        .{ 200, 350 },
        .{ 210, 420 },
        .{ 50, 340 },
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
        task7.DrawRegionBorder(
            tile,
            raster.BresenhamRasterizer,
            &region4,
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

        var region4_clip = try SutherlandHodgman(&box_border, &region4);
        defer region4_clip.deinit();

        if (region4_clip.items.len > 1) {
            task7.DrawRegionBorder(
                tile0,
                raster.BresenhamRasterizer,
                region4_clip.items,
                raster.RGBA_RED,
            );
        }
    }

    {
        var region1_clip = try WeilerAtherton(&box_border, &region1);
        defer region1_clip.deinit();
        
        if (region1_clip.items.len > 1) {
            task7.DrawRegionBorder(
                tile1,
                raster.BresenhamRasterizer,
                region1_clip.items,
                raster.RGBA_RED,
            );
        }
        
        var region2_clip = try WeilerAtherton(&box_border, &region2);
        defer region2_clip.deinit();
        
        if (region2_clip.items.len > 1) {
            task7.DrawRegionBorder(
                tile1,
                raster.BresenhamRasterizer,
                region2_clip.items,
                raster.RGBA_RED,
            );
        }
        
        var region3_clip = try WeilerAtherton(&box_border, &region3);
        defer region3_clip.deinit();
        
        if (region3_clip.items.len > 1) {
            task7.DrawRegionBorder(
                tile1,
                raster.BresenhamRasterizer,
                region3_clip.items,
                raster.RGBA_RED,
            );
        }
        
        var region4_clip = try WeilerAtherton(&box_border, &region4);
        defer region4_clip.deinit();
        
        if (region4_clip.items.len > 1) {
            task7.DrawRegionBorder(
                tile1,
                raster.BresenhamRasterizer,
                region4_clip.items,
                raster.RGBA_RED,
            );
        }
    }

    try r.RenderOut("output/task8.png");
}
