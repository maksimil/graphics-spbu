const std = @import("std");
const config = @import("config.zig");
const read_obj = @import("read_obj.zig");
const render = @import("render.zig");
const raster = @import("raster.zig");
const task5 = @import("task5.zig");

const kObjFilePath = "materials/african_head.obj";
const kWidth = 256;
const kHeight = 256;

const kFillColors = [_]render.RGBA{
    render.RGBA{ .r = 255, .g = 0, .b = 0, .a = 255 },
    render.RGBA{ .r = 0, .g = 255, .b = 0, .a = 255 },
    render.RGBA{ .r = 0, .g = 0, .b = 255, .a = 255 },
    render.RGBA{ .r = 255, .g = 255, .b = 0, .a = 255 },
    render.RGBA{ .r = 255, .g = 0, .b = 255, .a = 255 },
    render.RGBA{ .r = 0, .g = 255, .b = 255, .a = 255 },
};

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

    const data = try config.allocator.alloc(render.RGBA, kWidth * kHeight);
    defer config.allocator.free(data);

    const r = raster.Raster.init(data, kWidth, kHeight);
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
                raster.RGBA_BLACK,
            );
        }
    }

    const tiled = task5.TileRasterizer.init(r, 0, 0, kWidth, kHeight);

    for (0..kWidth) |xi| {
        for (0..kHeight) |yi| {
            const x: i32 = @intCast(xi);
            const y: i32 = @intCast(yi);

            if (std.meta.eql(r.GetPx(x, y).*, raster.RGBA_WHITE)) {
                const fill_idx =
                    config.prng.random().uintLessThan(usize, kFillColors.len);
                try task5.SimpleIterative(tiled, x, y, kFillColors[fill_idx]);
            }
        }
    }

    try r.RenderOut("out.png");
}
