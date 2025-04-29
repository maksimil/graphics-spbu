const std = @import("std");
pub const c_modules = @cImport({
    @cInclude("png.h");
});

// pub const Px = usize;
pub const Scalar = f64;
pub const kNan = std.math.nan(Scalar);

// runtime
pub var stdout: std.fs.File.Writer = undefined;
pub var stderr: std.fs.File.Writer = undefined;
var gpa: std.heap.GeneralPurposeAllocator(.{}) = undefined;
pub var allocator: std.mem.Allocator = undefined;
pub var prng: std.Random.DefaultPrng = undefined;

pub fn RuntimeInitialize() void {
    prng = std.Random.DefaultPrng.init(42);

    stdout = std.io.getStdOut().writer();
    stderr = std.io.getStdErr().writer();

    gpa = @TypeOf(gpa){};
    allocator = gpa.allocator();
}

pub fn RuntimeDeinitialize() void {
    stderr.print("allocator: {}\n", .{gpa.deinit()}) catch unreachable;
}

// --- utils ---

pub fn ScalarMod(x: Scalar, y: Scalar) Scalar {
    return x - y * @floor(x / y);
}

pub fn ToScalar(x: anytype) Scalar {
    return @as(Scalar, @floatFromInt(x));
}

pub fn Sqr(x: anytype) @TypeOf(x) {
    return x * x;
}

// 0 if x=0
pub fn Signi32(x: i32) i32 {
    const p: i32 = @intFromBool(x > 0);
    const n: i32 = @intFromBool(x < 0);
    return p - n;
}
