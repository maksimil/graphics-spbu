const std = @import("std");
const config = @import("config.zig");
const read_obj = @import("read_obj.zig");
const render = @import("render.zig");
const raster = @import("raster.zig");

const kObjFilePath = "materials/african_head.obj";
const kTileWidth = 512;
const kTileHeight = 512;
// const kTileWidth = 128;
// const kTileHeight = 128;
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

    if (v0.x >= 0.0 or v1.x >= 0.0)
        r.rasterize_line(
            method,
            x0 + kTileWidth * tilex,
            y0 + kTileHeight * tiley,
            x1 + kTileWidth * tilex,
            y1 + kTileHeight * tiley,
            raster.RGBA_BLACK,
        );
}

pub fn Run() !void {
    const objfile =
        try std.fs.cwd().openFile(kObjFilePath, std.fs.File.OpenFlags{});
    defer objfile.close();

    const objdata = try read_obj.ParseObj(objfile.reader().any());
    defer objdata.deinit();

    const data = try config.allocator.alloc(render.RGBA, kVTiles * kHTiles * kTileWidth * kTileHeight);
    defer config.allocator.free(data);

    const r = raster.Raster.init(data, kHTiles * kTileWidth, kVTiles * kTileHeight);
    r.clear(raster.RGBA_WHITE);

    for (0..objdata.faces.items.len) |i| {
        const face = objdata.faces.items[i];
        const v0 = objdata.vertices.items[face[0]];
        const v1 = objdata.vertices.items[face[1]];
        const v2 = objdata.vertices.items[face[2]];

        DrawLine(r, raster.BresenhamRasterizer, 0, 0, v0, v1);
        DrawLine(r, raster.BresenhamRasterizer, 0, 0, v1, v2);
        DrawLine(r, raster.BresenhamRasterizer, 0, 0, v2, v0);

        DrawLine(r, raster.ModifiedBresenhamRasterizer, 1, 0, v0, v1);
        DrawLine(r, raster.ModifiedBresenhamRasterizer, 1, 0, v1, v2);
        DrawLine(r, raster.ModifiedBresenhamRasterizer, 1, 0, v2, v0);
    }

    try r.render_out("out.png");
}
