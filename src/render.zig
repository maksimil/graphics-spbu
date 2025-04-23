const config = @import("config.zig");
const c_modules = config.c_modules;

pub const RGBA = extern struct { r: u8, g: u8, b: u8, a: u8 };

pub const RenderError = error{
    FileNotOpened,
    FileNotClosed,
    PngNotCreated,
    InfoNotCreated,
};

// pixels is in row major format
pub fn RenderToFile(
    file_name: [:0]const u8,
    width: u32,
    height: u32,
    pixels: []RGBA,
) !void {
    var row_pointers = try config.allocator.alloc([*]u8, height);
    defer config.allocator.free(row_pointers);

    for (0..height) |i| {
        row_pointers[i] = @ptrCast(&pixels[i * width]);
    }

    const fp = c_modules.fopen(file_name, "w");
    if (fp == null) {
        return RenderError.FileNotOpened;
    }

    var png: c_modules.png_structp = c_modules.png_create_write_struct(
        c_modules.PNG_LIBPNG_VER_STRING,
        null,
        null,
        null,
    );

    if (png == null) {
        return RenderError.PngNotCreated;
    }

    var info: c_modules.png_infop = c_modules.png_create_info_struct(png);

    if (info == null) {
        return RenderError.InfoNotCreated;
    }

    defer c_modules.png_destroy_write_struct(&png, &info);

    c_modules.png_init_io(png, fp);
    c_modules.png_set_IHDR(
        png,
        info,
        width,
        height,
        8,
        c_modules.PNG_COLOR_TYPE_RGBA,
        c_modules.PNG_INTERLACE_NONE,
        c_modules.PNG_COMPRESSION_TYPE_DEFAULT,
        c_modules.PNG_FILTER_TYPE_DEFAULT,
    );
    c_modules.png_write_info(png, info);

    c_modules.png_write_image(png, @ptrCast(row_pointers.ptr));

    c_modules.png_write_end(png, null);

    if (c_modules.fclose(fp) != 0) {
        return RenderError.FileNotClosed;
    }
}
