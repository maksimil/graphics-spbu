const std = @import("std");
const config = @import("config.zig");
const read_obj = @import("read_obj.zig");
const render = @import("render.zig");
const raster = @import("raster.zig");

const kObjFilePath = "materials/african_head.obj";
// const kTileWidth = 1024;
// const kTileHeight = 1024;
const kTileWidth = 128;
const kTileHeight = 128;
const kHTiles = 2;
const kVTiles = 2;

fn DrawLine(
    r: raster.Raster,
    method: anytype,
    tilex: i32,
    tiley: i32,
    v0: read_obj.ObjVertex,
    v1: read_obj.ObjVertex,
) void {
    const x0: i32 = @intFromFloat(@round((v0.z + 1.0) / 2.0 * (kTileWidth - 1)));
    const y0: i32 = @intFromFloat(@round((-v0.y + 1.0) / 2.0 * (kTileHeight - 1)));

    const x1: i32 = @intFromFloat(@round((v1.z + 1.0) / 2.0 * (kTileWidth - 1)));
    const y1: i32 = @intFromFloat(@round((-v1.y + 1.0) / 2.0 * (kTileHeight - 1)));

    if (v0.x >= 0.0 or v1.x >= 0.0) {
        r.rasterize_line(
            method,
            x0 + kTileWidth * tilex,
            y0 + kTileHeight * tiley,
            x1 + kTileWidth * tilex,
            y1 + kTileHeight * tiley,
            raster.RGBA_BLACK,
        );
    }
}

const VertexPair = struct { v0: usize, v1: usize };

const VertexPairSortCompare = struct {
    pub fn call(this: @This(), lhs: VertexPair, rhs: VertexPair) bool {
        _ = this;

        const eq = lhs.v0 == rhs.v0;

        return (eq and lhs.v1 < rhs.v1) or (!eq and lhs.v0 < rhs.v0);
    }
};

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

    const data = try config.allocator.alloc(
        render.RGBA,
        kVTiles * kHTiles * kTileWidth * kTileHeight,
    );
    defer config.allocator.free(data);

    const r = raster.Raster.init(data, kHTiles * kTileWidth, kVTiles * kTileHeight);
    r.clear(raster.RGBA_WHITE);

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

        const x0: i32 = @intFromFloat(@round((v0.z + 1.0) / 2.0 * (kTileWidth - 1)));
        const y0: i32 = @intFromFloat(@round((-v0.y + 1.0) / 2.0 * (kTileHeight - 1)));

        const x1: i32 = @intFromFloat(@round((v1.z + 1.0) / 2.0 * (kTileWidth - 1)));
        const y1: i32 = @intFromFloat(@round((-v1.y + 1.0) / 2.0 * (kTileHeight - 1)));

        if (v0.x >= 0.0 or v1.x >= 0.0) {
            r.rasterize_line(
                raster.BresenhamRasterizer,
                x0 + 0 * kTileWidth,
                y0 + 0 * kTileHeight,
                x1 + 0 * kTileWidth,
                y1 + 0 * kTileHeight,
                raster.RGBA_BLACK,
            );

            r.rasterize_line(
                raster.ModifiedBresenhamRasterizer,
                x0 + 1 * kTileWidth,
                y0 + 0 * kTileHeight,
                x1 + 1 * kTileWidth,
                y1 + 0 * kTileHeight,
                raster.RGBA_BLACK,
            );

            r.rasterize_line(
                raster.XiaolinWuRasterizer,
                x0 + 0 * kTileWidth,
                y0 + 1 * kTileHeight,
                x1 + 0 * kTileWidth,
                y1 + 1 * kTileHeight,
                raster.RGBA_BLACK,
            );
        }
    }

    try r.render_out("out.png");
}
