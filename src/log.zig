const std = @import("std");

const c = @cImport({
    @cInclude("libnotify/notify.h");
    @cInclude("syslog.h");
});

pub fn init() void {
    _ = c.notify_init("bullseye");
    if (@import("builtin").mode != .Debug) {
        c.notify_set_app_icon("/usr/share/icons/hicolor/128x128/apps/bullseye.png");
    } else {
        var gpa = std.heap.GeneralPurposeAllocator(.{}){};
        const allocator = gpa.allocator();
        const path = std.fs.selfExeDirPathAlloc(allocator) catch unreachable;
        defer allocator.free(path);
        const icon = std.fmt.allocPrint(
            allocator,
            "{s}pkg/assets/128x128.png",
            .{path[0 .. path.len - 11]},
        ) catch unreachable;
        defer allocator.free(icon);
        c.notify_set_app_icon(icon.ptr);
    }
}

pub fn deinit() void {
    c.notify_uninit();
}

pub fn logger(
    comptime level: std.log.Level,
    comptime scope: @TypeOf(.EnumLiteral),
    comptime format: []const u8,
    args: anytype,
) void {
    const scope_name = if (scope == .default) "" else "(" ++ @tagName(scope) ++ "): ";
    if (@import("builtin").mode == .Debug) {
        std.debug.lockStdErr();
        defer std.debug.unlockStdErr();
        const stderr = std.fs.File.stderr().deprecatedWriter();
        nosuspend stderr.print(
            @tagName(level) ++ "|" ++ scope_name ++ format ++ "\n",
            args,
        ) catch return;
    }
    var buf: [64]u8 = undefined;
    const msg = std.fmt.bufPrintZ(
        &buf,
        scope_name ++ format,
        args,
    ) catch return;
    if (@intFromEnum(level) < @intFromEnum(std.log.Level.info)) {
        const note = c.notify_notification_new("bullseye", msg.ptr, null);
        _ = c.notify_notification_show(note, null);
        _ = c.g_object_unref(note);
    }
    c.syslog(switch (level) {
        .err => c.LOG_ERR,
        .warn => c.LOG_WARNING,
        .info => c.LOG_INFO,
        .debug => c.LOG_DEBUG,
    }, "%s", msg.ptr);
}
