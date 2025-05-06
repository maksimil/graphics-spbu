const std = @import("std");
const config = @import("config.zig");
const read_obj = @import("read_obj.zig");
const render = @import("render.zig");
const raster = @import("raster.zig");
const task7 = @import("task7.zig");

const kObjFilePath = "materials/african_head.obj";
const SpacePoint = read_obj.ObjVertex;

const kTileWidth = 512;
const kTileHeight = 512;
const kHTiles = 2;
const kVTiles = 1;

const VertexPair = struct { v0: usize, v1: usize };

const VertexPairSortCompare = struct {
    pub fn call(this: @This(), lhs: VertexPair, rhs: VertexPair) bool {
        _ = this;

        const eq = lhs.v0 == rhs.v0;

        return (eq and lhs.v1 < rhs.v1) or (!eq and lhs.v0 < rhs.v0);
    }
};

// projections are R^3 -> R^3

fn PerspectiveProject(point: SpacePoint) SpacePoint {
    return point;
}

fn CameraProject(point: SpacePoint) SpacePoint {
    return point;
}

fn ClipSpaceLine(
    p0: SpacePoint,
    p1: SpacePoint,
    width: i32,
    height: i32,
) ?task7.Edge {
    const x0 = ((p0.x + 1) / 2) * config.ToScalar(width - 1);
    const y0 = ((-p0.y + 1) / 2) * config.ToScalar(height - 1);
    const x1 = ((p1.x + 1) / 2) * config.ToScalar(width - 1);
    const y1 = ((-p1.y + 1) / 2) * config.ToScalar(height - 1);

    return task7.LiangBarskyClip(
        0,
        0,
        width - 1,
        height - 1,
        @intFromFloat(@round(x0)),
        @intFromFloat(@round(y0)),
        @intFromFloat(@round(x1)),
        @intFromFloat(@round(y1)),
    );
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

        // Perspective projection
        {
            const proj0 = PerspectiveProject(v0);
            const proj1 = PerspectiveProject(v1);
            const maybe_edge = ClipSpaceLine(proj0, proj1, kTileWidth, kTileHeight);

            if (maybe_edge) |edge| {
                r.RasterizeLine(
                    raster.BresenhamRasterizer,
                    edge.x0 + 0 * kTileWidth,
                    edge.y0,
                    edge.x1 + 0 * kTileWidth,
                    edge.y1,
                    raster.RGBA_BLACK,
                );
            }
        }

        // Camera projection
        {
            const proj0 = CameraProject(v0);
            const proj1 = CameraProject(v1);
            const maybe_edge = ClipSpaceLine(proj0, proj1, kTileWidth, kTileHeight);

            if (maybe_edge) |edge| {
                r.RasterizeLine(
                    raster.BresenhamRasterizer,
                    edge.x0 + 1 * kTileWidth,
                    edge.y0,
                    edge.x1 + 1 * kTileWidth,
                    edge.y1,
                    raster.RGBA_BLACK,
                );
            }
        }
    }

    try r.RenderOut("output/task1011.png");
}
