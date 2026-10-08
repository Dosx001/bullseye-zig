const log = @import("log.zig");
const std = @import("std");
const win = @import("window.zig");

pub const std_options = std.Options{
    .logFn = log.logger,
};

pub fn main(init: std.process.Init) !void {
    const io = init.io;
    log.init(io);
    defer log.deinit();
    win.init();
}
