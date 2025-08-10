const go = @import("gobject.zig");
const std = @import("std");

const c = @cImport({
    @cInclude("gtk-4.0/gtk/gtk.h");
});

const Region = struct {
    x: c_int,
    y: c_int,
    width: c_int,
    height: c_int,
};

var index: usize = 0;
var regions: [10]Region = undefined;
var grid: [*c]c.GtkGrid = undefined;

pub fn init() void {
    const app = c.gtk_application_new("com.github.dosx001.bullseye", c.G_APPLICATION_DEFAULT_FLAGS);
    go.gSignalConnect(app, "activate", c.G_CALLBACK(activate), null);
    _ = c.g_application_run(@ptrCast(app), @intCast(std.os.argv.len), @ptrCast(std.os.argv.ptr));
    defer c.g_object_unref(app);
}

fn activate(app: [*c]c.GtkApplication, _: c.gpointer) callconv(.C) void {
    const display = c.gdk_display_get_default();
    defer c.g_object_unref(display);
    const monitors = c.gdk_display_get_monitors(display);
    const monitor: ?*c.GdkMonitor = @ptrCast(c.g_list_model_get_item(monitors, 0));
    defer c.g_object_unref(monitor);
    var rect: c.GdkRectangle = undefined;
    c.gdk_monitor_get_geometry(monitor, &rect);
    const provider = c.gtk_css_provider_new();
    const win: [*c]c.GtkWindow = @ptrCast(c.gtk_application_window_new(app));
    c.gtk_window_fullscreen(win);
    c.gtk_css_provider_load_from_data(provider, @embedFile("styles.css"), -1);
    c.gtk_style_context_add_provider_for_display(
        display,
        @ptrCast(provider),
        c.GTK_STYLE_PROVIDER_PRIORITY_USER,
    );
    regions[index] = .{ .x = 0, .y = 0, .width = rect.width, .height = rect.height };
    grid = @ptrCast(c.gtk_grid_new());
    inline for (0..9) |i| {
        const label = c.gtk_label_new("●");
        c.gtk_grid_attach(grid, label, @intCast(i % 3), @intCast(i / 3), 1, 1);
    }
    update_size();
    c.gtk_window_set_child(win, @ptrCast(grid));
    c.gtk_window_present(win);
}

fn update_size() void {
    const rect = regions[index];
    c.gtk_widget_set_margin_top(@ptrCast(grid), rect.y);
    c.gtk_widget_set_margin_start(@ptrCast(grid), rect.x);
    const fourth = @divFloor(rect.height, 4) - 2;
    const third = @divFloor(rect.width, 3) - 2;
    inline for (0..9) |i| {
        const child = c.gtk_grid_get_child_at(grid, @intCast(i % 3), @intCast(i / 3));
        switch (i) {
            3, 4, 5 => c.gtk_widget_set_size_request(child, third, fourth + fourth),
            else => c.gtk_widget_set_size_request(child, third, fourth),
        }
    }
}
