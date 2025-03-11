const std = @import("std");
const config = @import("config.zig");
const render = @import("render.zig");

pub fn Run() !void {
    const file_name = "out.png";
    var data = [_]render.RGBA{.{ .r = 255, .g = 0, .b = 0, .a = 255 }};
    try render.render_to_file(file_name, 1, 1, &data);
}
