const std = @import("std");
const config = @import("config.zig");
// const task1 = @import("task1.zig");
// const task2 = @import("task2.zig");
// const task3 = @import("task3.zig");
// const task4 = @import("task4.zig");
const task5 = @import("task5.zig");

pub fn main() !void {
    config.RuntimeInitialize();
    defer config.RuntimeDeinitialize();

    try task5.Run();
}
