const std = @import("std");
const config = @import("config.zig");
const read_obj = @import("read_obj.zig");
const render = @import("render.zig");
const raster = @import("raster.zig");
const task7 = @import("task7.zig");

const kObjFilePath = "materials/african_head.obj";
const Scalar = config.Scalar;
const Vec3 = read_obj.ObjVertex;

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

fn Dot(a: Vec3, b: Vec3) Scalar {
    return a.x * b.x + a.y * b.y + a.z * b.z;
}

fn Normalize(v: Vec3) Vec3 {
    const norm = @sqrt(Dot(v, v));
    return Vec3{ .x = v.x / norm, .y = v.y / norm, .z = v.z / norm };
}

const Basis = struct { bx: Vec3, by: Vec3, bz: Vec3 };

fn CameraBasis(view: Vec3) Basis {
    var bx: Vec3 = undefined;
    var by: Vec3 = undefined;
    var bz: Vec3 = undefined;

    bz.x = -view.x;
    bz.y = -view.y;
    bz.z = -view.z;
    bz = Normalize(bz);

    const alpha = @sqrt(bz.x * bz.x + bz.y * bz.y);
    std.debug.assert(alpha != 0);

    bx.x = -bz.y / alpha;
    bx.y = bz.x / alpha;
    bx.z = 0;

    by.x = -bz.z * bz.x / alpha;
    by.y = -bz.z * bz.y / alpha;
    by.z = alpha;

    const basis = Basis{ .bx = bx, .by = by, .bz = bz };

    return basis;
}

fn BasisTransform(origin: Vec3, basis: Basis, point: Vec3) Vec3 {
    const dr = Vec3{
        .x = point.x - origin.x,
        .y = point.y - origin.y,
        .z = point.z - origin.z,
    };

    return Vec3{
        .x = Dot(dr, basis.bx),
        .y = Dot(dr, basis.by),
        .z = Dot(dr, basis.bz),
    };
}

// projections are R^3 -> R^3

fn PerspectiveProject(
    point: Vec3,
    persepctive_view: Vec3,
    perspective_origin: Vec3,
    plane_distance: Scalar,
) Vec3 {
    const basis = CameraBasis(persepctive_view);
    var transformed = BasisTransform(perspective_origin, basis, point);

    std.debug.assert(transformed.z != 0);

    transformed.x = -transformed.x / transformed.z * plane_distance;
    transformed.y = -transformed.y / transformed.z * plane_distance;

    return transformed;
}

fn CameraProject(
    point: Vec3,
    persepctive_view: Vec3,
    perspective_origin: Vec3,
    alpha: Scalar,
) Vec3 {
    return PerspectiveProject(
        point,
        persepctive_view,
        perspective_origin,
        1 / @tan(alpha / 2),
    );
}

fn ClipSpaceLine(
    p0: Vec3,
    p1: Vec3,
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

    var objdata = try read_obj.ParseObj(objfile.reader().any());
    defer objdata.deinit();

    // rotate so that z is up
    for (0..objdata.vertices.items.len) |i| {
        const v = &objdata.vertices.items[i];
        const y = v.y;
        const z = v.z;
        v.y = -z;
        v.z = y;
    }

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
            const persepctive_view = Vec3{ .x = 0.5, .y = 1, .z = -0.3 };
            const perspective_origin = Vec3{ .x = -5, .y = -10, .z = 3 };
            const plane_distance: Scalar = 10;

            const proj0 = PerspectiveProject(
                v0,
                persepctive_view,
                perspective_origin,
                plane_distance,
            );
            const proj1 = PerspectiveProject(
                v1,
                persepctive_view,
                perspective_origin,
                plane_distance,
            );
            const maybe_edge = ClipSpaceLine(proj0, proj1, kTileWidth, kTileHeight);

            if (maybe_edge) |edge| {
                r.RasterizeLine(
                    raster.XiaolinWuRasterizer,
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
            const persepctive_view = Vec3{ .x = 0.5, .y = 1, .z = -0.3 };
            const perspective_origin = Vec3{ .x = -1, .y = -2, .z = 0.7 };
            const alpha: Scalar = std.math.pi / 3.0;

            const proj0 = CameraProject(
                v0,
                persepctive_view,
                perspective_origin,
                alpha,
            );
            const proj1 = CameraProject(
                v1,
                persepctive_view,
                perspective_origin,
                alpha,
            );
            const maybe_edge = ClipSpaceLine(proj0, proj1, kTileWidth, kTileHeight);

            if (maybe_edge) |edge| {
                r.RasterizeLine(
                    raster.XiaolinWuRasterizer,
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
