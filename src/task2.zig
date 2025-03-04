const std = @import("std");
const config = @import("config.zig");
const c_modules = config.c_modules;

const RunError = error{
    FileNotOpened,
    FileNotClosed,
    PngNotCreated,
    InfoNotCreated,
};

pub fn Run() !void {
    const file_name = "out.png";

    const fp = c_modules.fopen(file_name, "w");

    if (fp == null) {
        return RunError.FileNotOpened;
    }

    var png: c_modules.png_structp = c_modules.png_create_write_struct(
        c_modules.PNG_LIBPNG_VER_STRING,
        null,
        null,
        null,
    );

    if (png == null) {
        return RunError.PngNotCreated;
    }

    var info: c_modules.png_infop = c_modules.png_create_info_struct(png);

    if (info == null) {
        return RunError.InfoNotCreated;
    }

    c_modules.png_init_io(png, fp);
    c_modules.png_set_IHDR(
        png,
        info,
        1,
        1,
        8,
        c_modules.PNG_COLOR_TYPE_RGBA,
        c_modules.PNG_INTERLACE_NONE,
        c_modules.PNG_COMPRESSION_TYPE_DEFAULT,
        c_modules.PNG_FILTER_TYPE_DEFAULT,
    );
    c_modules.png_write_info(png, info);

    var color = [_]c_modules.png_byte{ 255, 0, 0, 255 };
    var colorp: [*c]u8 = @ptrCast(&color);
    c_modules.png_write_image(png, &colorp);

    c_modules.png_write_end(png, null);

    if (c_modules.fclose(fp) != 0) {
        return RunError.FileNotClosed;
    }

    c_modules.png_destroy_write_struct(&png, &info);

    try config.stdout.print("{any}\n", .{c_modules.PNG_LIBPNG_VER_STRING});
}
