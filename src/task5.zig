const raster = @import("raster.zig");
const config = @import("config.zig");
const render = @import("render.zig");
const std = @import("std");

const kTileWidth = 512;
const kTileHeight = 512;
const kHTiles = 2;
const kVTiles = 2;

pub const TileRasterizer = struct {
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

    pub fn GetWdith(this: @This()) i32 {
        return this.xsize;
    }

    pub fn GetHeight(this: @This()) i32 {
        return this.ysize;
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

pub fn SimpleIterative(
    r: TileRasterizer,
    x0: i32,
    y0: i32,
    fill_color: render.RGBA,
) !void {
    const inner_color = r.GetPx(x0, y0).*;

    var neighbours_list = std.ArrayList([2]i32).init(config.allocator);
    defer neighbours_list.deinit();

    try neighbours_list.append(.{ x0, y0 });
    r.DrawPx(x0, y0, fill_color);

    const max_size = 1024;
    var idx: usize = 0;

    while (neighbours_list.items.len > idx) {
        const size = neighbours_list.items.len - idx;
        for (0..size) |i| {
            const p = neighbours_list.items[idx + i];
            const x = p[0];
            const y = p[1];
            std.debug.assert(std.meta.eql(r.GetPx(x, y).*, fill_color));

            for (0..4) |j| {
                const x1 = x +
                    @as(i32, @intFromBool(j == 0)) -
                    @as(i32, @intFromBool(j == 2));
                const y1 = y +
                    @as(i32, @intFromBool(j == 1)) -
                    @as(i32, @intFromBool(j == 3));

                if (x1 >= 0 and x1 < r.GetWdith() and
                    y1 >= 0 and y1 < r.GetHeight() and
                    std.meta.eql(r.GetPx(x1, y1).*, inner_color))
                {
                    try neighbours_list.append(.{ x1, y1 });
                    r.DrawPx(x1, y1, fill_color);
                }
            }
        }

        if (neighbours_list.items.len >= max_size) {
            const range: [0][2]i32 = .{};
            try neighbours_list.replaceRange(0, idx + size, &range);
            idx = 0;
        } else {
            idx = idx + size;
        }
    }
}

pub fn LinedIterative(
    r: TileRasterizer,
    x0: i32,
    y0: i32,
    fill_color: render.RGBA,
) !void {
    const inner_color = r.GetPx(x0, y0).*;

    var neighbours_list = std.ArrayList([2]i32).init(config.allocator);
    defer neighbours_list.deinit();

    try neighbours_list.append(.{ x0, y0 });

    const max_size = 1024;
    var idx: usize = 0;

    while (neighbours_list.items.len > idx) {
        const size = neighbours_list.items.len - idx;
        for (0..size) |i| {
            const p = neighbours_list.items[idx + i];
            const x = p[0];
            const y = p[1];

            // --- fill the line ---

            var j: i32 = 0;
            while (x - j >= 0 and
                std.meta.eql(r.GetPx(x - j, y).*, inner_color))
            {
                r.DrawPx(x - j, y, fill_color);
                j += 1;
            }
            const xmin = x - j + 1;

            j = 1;
            while (x + j < r.GetWdith() and
                std.meta.eql(r.GetPx(x + j, y).*, inner_color))
            {
                r.DrawPx(x + j, y, fill_color);
                j += 1;
            }
            const xmax = x + j - 1;

            // --- move ---

            for (0..2) |l| {
                const y1 = ([_]i32{ y - 1, y + 1 })[l];

                if (y1 < 0 or y1 >= r.GetHeight()) {
                    continue;
                }

                var x1 = xmin;
                var flag = true;

                while (x1 <= xmax) {
                    if (flag and
                        std.meta.eql(r.GetPx(x1, y1).*, inner_color))
                    {
                        try neighbours_list.append(.{ x1, y1 });
                        flag = false;
                    } else if (!flag and
                        !std.meta.eql(r.GetPx(x1, y1).*, inner_color))
                    {
                        flag = true;
                    }

                    x1 += 1;
                }
            }
        }

        // --- cleanup ---

        if (neighbours_list.items.len >= max_size) {
            const range: [0][2]i32 = .{};
            try neighbours_list.replaceRange(0, idx + size, &range);
            idx = 0;
        } else {
            idx = idx + size;
        }
    }
}

fn InterscectingInterval(x0: i32, y0: i32, x1: i32, y1: i32, y: i32) [2]i32 {
    if (x0 <= x1) {
        return OrderedIntersectingInterval(x0, y0, x1, y1, y);
    } else {
        return OrderedIntersectingInterval(x1, y1, x0, y0, y);
    }
}

fn OrderedIntersectingInterval(x0: i32, y0: i32, x1: i32, y1: i32, y: i32) [2]i32 {
    const dy = y1 - y0;
    const dx = x1 - x0;

    std.debug.assert(dx >= 0);

    if (dx <= dy or dx <= -dy) {
        const n = @divFloor(2 * (y - y0) * dx + dy, 2 * dy);
        return .{ x0 + n, x0 + n };
    }

    var xlow: i32 = undefined;
    var xhigh: i32 = undefined;

    if (dy >= 0) {
        const n = y - y0;
        const ilow = -@divFloor(-dx * (2 * n - 1), 2 * dy);
        const ihigh = -@divFloor(-dx * (2 * n + 1), 2 * dy);

        xlow = x0 + ilow;
        xhigh = x0 + ihigh - 1;
    } else {
        std.debug.assert(dy < 0);

        const n = y0 - y;
        const ilow = -@divFloor(-dx * (2 * n - 1), -2 * dy);
        const ihigh = -@divFloor(-dx * (2 * n + 1), -2 * dy);

        xlow = x0 + ilow;
        xhigh = x0 + ihigh - 1;
    }

    if (y == y0) {
        xlow = x0;
    }

    if (y == y1) {
        xhigh = x1;
    }

    return .{ xlow, xhigh };
}

const EdgeInfo = struct {
    x0: i32,
    x1: i32,
    nonborder: bool,
};

fn GetEdgeInfo(points: []const [2]i32, y: i32, i: usize) ?EdgeInfo {
    const p = points[i];

    const next_p = points[@mod(i + 1, points.len)];

    if (next_p[1] == y) {
        // will be processed next
        return null;
    }

    if (p[1] != y) {
        // --- process as an edge to the next point ---

        if ((p[1] > y and next_p[1] < y) or
            (p[1] < y and next_p[1] > y))
        {
            const interval =
                InterscectingInterval(p[0], p[1], next_p[0], next_p[1], y);
            return .{
                .x0 = interval[0],
                .x1 = interval[1],
                .nonborder = false,
            };
        } else {
            return null;
        }
    } else {
        // --- process as a point ---

        // find previous edge
        var j: usize = 1;
        while (points[@mod(i + points.len - j, points.len)][1] == y) {
            j += 1;
        }
        const prev_i = @mod(i + points.len - j, points.len);

        const prev_edge = InterscectingInterval(
            points[prev_i][0],
            points[prev_i][1],
            points[@mod(prev_i + 1, points.len)][0],
            points[@mod(prev_i + 1, points.len)][1],
            y,
        );

        const next_edge = InterscectingInterval(
            next_p[0],
            next_p[1],
            p[0],
            p[1],
            y,
        );

        // construct the edge
        const full_edge = [2]i32{
            @min(prev_edge[0], next_edge[0]),
            @max(prev_edge[1], next_edge[1]),
        };

        const nonborder =
            (points[prev_i][1] > y and next_p[1] > y) or
            (points[prev_i][1] < y and next_p[1] < y);

        return .{
            .x0 = full_edge[0],
            .x1 = full_edge[1],
            .nonborder = nonborder,
        };
    }
}

fn FillBetweenEdges(
    r: TileRasterizer,
    y: i32,
    edge_points: []EdgeInfo,
    fill_color: render.RGBA,
) void {
    const SortStruct = struct {
        pub fn call(this: @This(), lhs: EdgeInfo, rhs: EdgeInfo) bool {
            _ = this;
            return lhs.x0 < rhs.x0;
        }
    };

    std.sort.pdq(
        EdgeInfo,
        edge_points,
        SortStruct{},
        SortStruct.call,
    );

    // if flag is set the interval (edge[i-1].x1, edge[i].x0) is filled
    var flag = false;

    for (0..edge_points.len) |i| {
        const this_edge = edge_points[i];

        if (flag) {
            const prev_edge = edge_points[i - 1];

            var x = prev_edge.x1 + 1;
            while (x <= this_edge.x0 - 1) {
                r.DrawPx(x, y, fill_color);
                x += 1;
            }
        }

        // if (!this_edge.nonborder) {
        //     flag = !flag;
        // }
        flag = flag == this_edge.nonborder;
    }
}

pub fn EdgePointsList(
    r: TileRasterizer,
    points: []const [2]i32,
    fill_color: render.RGBA,
) !void {
    const ymin, const ymax = blk: {
        var ymin: i32 = points[0][1];
        var ymax: i32 = points[0][1];

        for (1..points.len) |i| {
            if (points[i][1] < ymin) {
                ymin = points[i][1];
            }

            if (points[i][1] > ymax) {
                ymax = points[i][1];
            }
        }

        break :blk .{ ymin, ymax };
    };

    if (ymin == ymax)
        return;

    var edge_points = std.ArrayList(EdgeInfo).init(config.allocator);
    defer edge_points.deinit();

    var y = ymin;
    while (y <= ymax) {
        defer y += 1;

        for (0..points.len) |i| {
            const maybe_info = GetEdgeInfo(points, y, i);
            if (maybe_info) |info| {
                try edge_points.append(info);
            }
        }

        FillBetweenEdges(r, y, edge_points.items, fill_color);

        edge_points.clearRetainingCapacity();
    }
}

pub fn ActiveEdgeList(
    r: TileRasterizer,
    points: []const [2]i32,
    fill_color: render.RGBA,
) !void {
    const ymin, const ymax = blk: {
        var ymin: i32 = points[0][1];
        var ymax: i32 = points[0][1];

        for (1..points.len) |i| {
            if (points[i][1] < ymin) {
                ymin = points[i][1];
            }

            if (points[i][1] > ymax) {
                ymax = points[i][1];
            }
        }

        break :blk .{ ymin, ymax };
    };

    if (ymin == ymax)
        return;

    // edge is points[idx]->points[idx+1]
    var first_active: usize = 0;
    var sorted_edges = std.ArrayList(usize).init(config.allocator);
    defer sorted_edges.deinit();

    try sorted_edges.resize(points.len);
    for (0..points.len) |i| {
        sorted_edges.items[i] = i;
    }

    const SortStruct = struct {
        points: []const [2]i32,

        fn edge_min_y(this: @This(), i: usize) i32 {
            const y0 = this.points[i][1];
            const y1 = this.points[@mod(i + 1, this.points.len)][1];
            return @min(y0, y1);
        }

        pub fn call(this: @This(), lhs: usize, rhs: usize) bool {
            return this.edge_min_y(lhs) < this.edge_min_y(rhs);
        }
    };
    const sort_struct = SortStruct{ .points = points };
    std.sort.pdq(
        usize,
        sorted_edges.items,
        sort_struct,
        SortStruct.call,
    );

    std.debug.assert(points[sorted_edges.items[0]][1] == ymin);

    var edge_points = std.ArrayList(EdgeInfo).init(config.allocator);
    defer edge_points.deinit();

    var y = ymin;
    while (y <= ymax) {
        // --- process active edges ---

        var k = first_active;
        std.debug.assert(sort_struct.edge_min_y(sorted_edges.items[k]) <= y);
        while (k < sorted_edges.items.len) {
            defer k += 1;

            const i = sorted_edges.items[k];

            if (sort_struct.edge_min_y(i) > y) {
                break;
            }

            const maybe_info = GetEdgeInfo(points, y, i);
            if (maybe_info) |info| {
                try edge_points.append(info);
            }
        }

        FillBetweenEdges(r, y, edge_points.items, fill_color);

        edge_points.clearRetainingCapacity();

        // --- update first_active ---
        y += 1;

        while (sort_struct.edge_min_y(sorted_edges.items[first_active]) > y) {
            first_active += 1;
            std.debug.assert(first_active < sorted_edges.items.len);
        }
    }
}

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
        .{ 400, 300 },
        .{ 350, 300 },
        .{ 300, 400 },
        .{ 250, 250 },
        .{ 200, 250 },
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

    try SimpleIterative(tile0, 200, 200, raster.RGBA_RED);
    try LinedIterative(tile1, 200, 200, raster.RGBA_RED);
    try EdgePointsList(tile2, &region, raster.RGBA_RED);
    try ActiveEdgeList(tile3, &region, raster.RGBA_RED);

    try r.RenderOut("out.png");
}
