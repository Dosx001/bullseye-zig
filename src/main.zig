const log = @import("log.zig");
const std = @import("std");
const win = @import("window.zig");

pub const std_options = std.Options{
    .logFn = log.logger,
};

pub fn main() !void {
    log.init();
    defer log.deinit();
    win.init();
}
