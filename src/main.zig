const std = @import("std");
const config = @import("config.zig");
const task1 = @import("task1.zig");
const task2 = @import("task2.zig");
const task3 = @import("task3.zig");
const task4 = @import("task4.zig");
const task5 = @import("task5.zig");
const task6 = @import("task6.zig");
const task7 = @import("task7.zig");
const task8 = @import("task8.zig");
const task1011 = @import("task1011.zig");

pub fn main() !void {
    config.RuntimeInitialize();
    defer config.RuntimeDeinitialize();

    try std.fs.cwd().makePath("output");

    // try task1.Run();
    // try task2.Run();
    // try task3.Run();
    // try task4.Run();
    // try task5.Run();
    // try task6.Run();
    // try task7.Run();
    // try task8.Run();
    try task1011.Run();
}
