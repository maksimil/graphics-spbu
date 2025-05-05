const std = @import("std");
const config = @import("config.zig");
const read_obj = @import("read_obj.zig");
const render = @import("render.zig");
const raster = @import("raster.zig");

const kObjFilePath = "materials/african_head.obj";
const kWidth = 256;
const kHeight = 256;

const Signi32 = config.Signi32;

const VertexPair = struct { v0: usize, v1: usize };

const VertexPairSortCompare = struct {
    pub fn call(this: @This(), lhs: VertexPair, rhs: VertexPair) bool {
        _ = this;

        const eq = lhs.v0 == rhs.v0;

        return (eq and lhs.v1 < rhs.v1) or (!eq and lhs.v0 < rhs.v0);
    }
};

fn SquareClipCode(
    xoffset: i32,
    yoffset: i32,
    xsize: i32,
    ysize: i32,
    x0: i32,
    y0: i32,
) u8 {
    const bit0: u8 = @intFromBool(y0 <= yoffset);
    const bit1: u8 = @intFromBool(y0 >= yoffset + ysize);
    const bit2: u8 = @intFromBool(x0 >= xoffset + xsize);
    const bit3: u8 = @intFromBool(x0 <= xoffset);
    return bit0 | (bit1 << 1) | (bit2 << 2) | (bit3 << 3);
}

fn PullX(x: i32, x0: i32, y0: i32, x1: i32, y1: i32) i32 {
    return config.DivRound(y1 * (x - x0) + y0 * (x1 - x), x1 - x0);
}

fn CohenSutherlandClip(
    xoffset: i32,
    yoffset: i32,
    xsize: i32,
    ysize: i32,
    x0_: i32,
    y0_: i32,
    x1_: i32,
    y1_: i32,
) ?Edge {
    var x0 = x0_;
    var y0 = y0_;
    var x1 = x1_;
    var y1 = y1_;

    var code0: u8 = undefined;
    var code1: u8 = undefined;

    code0 = SquareClipCode(xoffset, yoffset, xsize, ysize, x0, y0);
    code1 = SquareClipCode(xoffset, yoffset, xsize, ysize, x1, y1);

    if (code0 | code1 == 0) {
        return .{ .x0 = x0, .y0 = y0, .x1 = x1, .y1 = y1 };
    } else if (code0 & code1 == 0) {
        if (code0 & 1 == 1) {
            x0 = PullX(yoffset, y0, x0, y1, x1);
            y0 = yoffset;
        } else if (code0 & 2 == 2) {
            x0 = PullX(yoffset + ysize, y0, x0, y1, x1);
            y0 = yoffset + ysize;
        }

        if (code1 & 1 == 1) {
            x1 = PullX(yoffset, y0, x0, y1, x1);
            y1 = yoffset;
        } else if (code1 & 2 == 2) {
            x1 = PullX(yoffset + ysize, y0, x0, y1, x1);
            y1 = yoffset + ysize;
        }

        code0 = SquareClipCode(xoffset, yoffset, xsize, ysize, x0, y0);
        code1 = SquareClipCode(xoffset, yoffset, xsize, ysize, x1, y1);

        if (code0 & 4 == 4) {
            y0 = PullX(xoffset + xsize, x0, y0, x1, y1);
            x0 = xoffset + xsize;
        } else if (code0 & 8 == 8) {
            y0 = PullX(xoffset, x0, y0, x1, y1);
            x0 = xoffset;
        }

        if (code1 & 4 == 4) {
            y1 = PullX(xoffset + xsize, x0, y0, x1, y1);
            x1 = xoffset + xsize;
        } else if (code1 & 8 == 8) {
            y1 = PullX(xoffset, x0, y0, x1, y1);
            x1 = xoffset;
        }

        if (x0 == x1 and y0 == y1) {
            return null;
        } else {
            return .{ .x0 = x0, .y0 = y0, .x1 = x1, .y1 = y1 };
        }
    } else {
        return null;
    }
}

const Edge = struct { x0: i32, y0: i32, x1: i32, y1: i32 };

// clip by t/p_i <= q_i
fn ClipT(tlen: i32, p: []const i32, q: []const i32) [2]i32 {
    var tmin: i32 = @min(0, tlen);
    var tmax: i32 = @max(0, tlen);

    for (0..p.len) |i| {
        const pi = p[i];
        const qi = q[i];

        std.debug.assert(pi != 0);
        if (pi > 0) {
            tmax = @min(pi * qi, tmax);
        } else {
            tmin = @max(pi * qi, tmin);
        }
    }

    return .{ tmin, tmax };
}

fn SafeDivRound(x: i32, y: i32) i32 {
    if (y == 0) {
        return 0;
    } else {
        return config.DivRound(x, y);
    }
}

fn LiangBarskyClip(
    xoffset: i32,
    yoffset: i32,
    xsize: i32,
    ysize: i32,
    x0: i32,
    y0: i32,
    x1: i32,
    y1: i32,
) ?Edge {
    const dx = x1 - x0;
    const dy = y1 - y0;

    var u: i32 = undefined;
    var v: i32 = undefined;
    var tlen: i32 = undefined;

    if (dx == 0 or dy == 0) {
        u = @intFromBool(dx != 0);
        v = @intFromBool(dy != 0);
        tlen = dx + dy;
    } else {
        u = dy;
        v = dx;
        tlen = dx * dy;
    }

    var p: [4]i32 = undefined;
    var q: [4]i32 = undefined;

    var plen: usize = 0;

    if (u == 0) {
        if (x0 < xoffset or x0 > xoffset + xsize) {
            return null;
        }
    } else {
        p[plen] = u;
        q[plen] = xoffset + xsize - x0;
        p[plen + 1] = -u;
        q[plen + 1] = x0 - xoffset;
        plen += 2;
    }

    if (v == 0) {
        if (y0 < yoffset or y0 > yoffset + ysize) {
            return null;
        }
    } else {
        p[plen] = v;
        q[plen] = yoffset + ysize - y0;
        p[plen + 1] = -v;
        q[plen + 1] = y0 - yoffset;
        plen += 2;
    }

    const tmin, const tmax = ClipT(tlen, p[0..plen], q[0..plen]);

    if (tmin <= tmax) {
        return .{
            .x0 = x0 + SafeDivRound(tmin, u),
            .y0 = y0 + SafeDivRound(tmin, v),
            .x1 = x0 + SafeDivRound(tmax, u),
            .y1 = y0 + SafeDivRound(tmax, v),
        };
    } else {
        return null;
    }
}

fn CyrusBeckClip(
    region: []const [2]i32,
    x0: i32,
    y0: i32,
    x1: i32,
    y1: i32,
) ?Edge {
    const dx = x1 - x0;
    const dy = y1 - y0;

    var u: i32 = undefined;
    var v: i32 = undefined;
    var tlen: i32 = undefined;

    if (dx == 0 or dy == 0) {
        u = @intFromBool(dx != 0);
        v = @intFromBool(dy != 0);
        tlen = dx + dy;
    } else {
        u = dy;
        v = dx;
        tlen = dx * dy;
    }

    var tmin: i32 = @min(0, tlen);
    var tmax: i32 = @max(0, tlen);

    for (0..region.len) |i| {
        const p0 = region[i];
        const p1 = region[@mod(i + 1, region.len)];

        const rhs = p1[1] * p0[0] - p0[1] * p1[0] +
            (p0[1] - p1[1]) * x0 + (p1[0] - p0[0]) * y0;

        var p: i32 = 0;
        var q: i32 = 0;

        if (u != 0 and v != 0) {
            p = (p1[1] - p0[1]) * v + (p0[0] - p1[0]) * u;
            q = u * v;
        } else if (u != 0) {
            p = p1[1] - p0[1];
            q = u;
        } else if (v != 0) {
            p = p0[0] - p1[0];
            q = v;
        }

        if (p == 0) {
            if (rhs > 0) {
                return null;
            } else {
                continue;
            }
        }

        std.debug.assert(p != 0);
        std.debug.assert(q != 0);

        if (p * q < 0) {
            tmax = @min(tmax, config.DivRound(rhs * q, p));
        } else {
            tmin = @max(tmin, config.DivRound(rhs * q, p));
        }
    }

    if (tmin <= tmax) {
        return .{
            .x0 = x0 + SafeDivRound(tmin, u),
            .y0 = y0 + SafeDivRound(tmin, v),
            .x1 = x0 + SafeDivRound(tmax, u),
            .y1 = y0 + SafeDivRound(tmax, v),
        };
    } else {
        return null;
    }
}

pub fn DrawRegionBorder(
    r: anytype,
    rasterizer: anytype,
    points: []const [2]i32,
    color: render.RGBA,
) void {
    r.RasterizeLine(
        rasterizer,
        points[points.len - 1][0],
        points[points.len - 1][1],
        points[0][0],
        points[0][1],
        color,
    );

    for (0..points.len - 1) |i| {
        r.RasterizeLine(
            rasterizer,
            points[i][0],
            points[i][1],
            points[i + 1][0],
            points[i + 1][1],
            color,
        );
    }
}

fn MaybeRasterize(r: raster.Raster, maybe_edge: ?Edge) void {
    if (maybe_edge) |edge| {
        r.RasterizeLine(
            raster.ModifiedXiaolinWuRasterizer,
            edge.x0,
            edge.y0,
            edge.x1,
            edge.y1,
            raster.RGBA_BLACK,
        );
    }
}

pub fn Run() !void {
    const objfile =
        try std.fs.cwd().openFile(kObjFilePath, std.fs.File.OpenFlags{});
    defer objfile.close();

    const objdata = try read_obj.ParseObj(objfile.reader().any());
    defer objdata.deinit();

    var vertex_pairs = std.ArrayList(VertexPair).init(config.allocator);
    defer vertex_pairs.deinit();
    try vertex_pairs.ensureTotalCapacity(3 * objdata.faces.items.len);

    for (0..objdata.faces.items.len) |i| {
        const face = objdata.faces.items[i];

        var v0 = face[0];
        var v1 = face[1];
        var v2 = face[2];

        if (v0 > v2) std.mem.swap(usize, &v0, &v2);
        if (v1 > v2) std.mem.swap(usize, &v1, &v2);
        if (v0 > v1) std.mem.swap(usize, &v0, &v1);

        vertex_pairs.appendAssumeCapacity(.{ .v0 = v0, .v1 = v1 });
        vertex_pairs.appendAssumeCapacity(.{ .v0 = v1, .v1 = v2 });
        vertex_pairs.appendAssumeCapacity(.{ .v0 = v0, .v1 = v2 });
    }
    std.sort.pdq(
        VertexPair,
        vertex_pairs.items,
        VertexPairSortCompare{},
        VertexPairSortCompare.call,
    );

    const data = try config.allocator.alloc(render.RGBA, kWidth * kHeight);
    defer config.allocator.free(data);

    const r = raster.Raster.init(data, kWidth, kHeight);
    r.Clear(raster.RGBA_WHITE);

    DrawRegionBorder(r, raster.BresenhamRasterizer, &[_][2]i32{
        .{ 25, 25 },
        .{ 125, 25 },
        .{ 125, 125 },
        .{ 25, 125 },
    }, raster.RGBA_BLUE);

    DrawRegionBorder(r, raster.BresenhamRasterizer, &[_][2]i32{
        .{ 150, 50 },
        .{ 220, 50 },
        .{ 220, 150 },
        .{ 150, 150 },
    }, raster.RGBA_BLUE);

    const triangle_region = [_][2]i32{
        .{ 180, 200 },
        .{ 100, 150 },
        .{ 50, 200 },
    };
    DrawRegionBorder(
        r,
        raster.BresenhamRasterizer,
        &triangle_region,
        raster.RGBA_BLUE,
    );

    for (0..vertex_pairs.items.len) |i| {
        const vtx = vertex_pairs.items[i];

        if (i > 0) {
            const pvtx = vertex_pairs.items[i - 1];
            if (pvtx.v0 == vtx.v0 and pvtx.v1 == vtx.v1) {
                continue;
            }
        }

        const v0 = objdata.vertices.items[vtx.v0];
        const v1 = objdata.vertices.items[vtx.v1];

        const x0: i32 = @intFromFloat(@round((v0.z + 1.1) / 2.2 * (kWidth - 1)));
        const y0: i32 = @intFromFloat(@round((-v0.y + 1.1) / 2.2 * (kHeight - 1)));

        const x1: i32 = @intFromFloat(@round((v1.z + 1.1) / 2.2 * (kWidth - 1)));
        const y1: i32 = @intFromFloat(@round((-v1.y + 1.1) / 2.2 * (kHeight - 1)));

        if (v0.x >= 0.0 or v1.x >= 0.0) {
            r.RasterizeLine(
                raster.BresenhamRasterizer,
                x0,
                y0,
                x1,
                y1,
                raster.RGBA_RED,
            );

            MaybeRasterize(r, LiangBarskyClip(25, 25, 100, 100, x0, y0, x1, y1));
            MaybeRasterize(r, CohenSutherlandClip(150, 50, 70, 100, x0, y0, x1, y1));
            MaybeRasterize(r, CyrusBeckClip(&triangle_region, x0, y0, x1, y1));
        }
    }

    try r.RenderOut("output/task7.png");
}
