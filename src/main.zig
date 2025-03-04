const std = @import("std");
const config = @import("config.zig");
const task1 = @import("task1.zig");
const task2 = @import("task2.zig");

pub fn main() !void {
    config.RuntimeInitialize();
    defer config.RuntimeDeinitialize();

    try task2.Run();
}
