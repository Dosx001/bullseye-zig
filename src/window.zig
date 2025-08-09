const go = @import("gobject.zig");
const std = @import("std");

const c = @cImport({
    @cInclude("gtk-4.0/gtk/gtk.h");
});

pub fn init() void {
    const app = c.gtk_application_new("com.github.dosx001.bullseye", c.G_APPLICATION_DEFAULT_FLAGS);
    go.gSignalConnect(app, "activate", c.G_CALLBACK(activate), null);
    _ = c.g_application_run(@ptrCast(app), @intCast(std.os.argv.len), @ptrCast(std.os.argv.ptr));
    defer c.g_object_unref(app);
}

fn activate(app: [*c]c.GtkApplication, _: c.gpointer) callconv(.C) void {
    const provider = c.gtk_css_provider_new();
    const win: [*c]c.GtkWindow = @ptrCast(c.gtk_application_window_new(app));
    c.gtk_window_fullscreen(win);
    c.gtk_css_provider_load_from_data(provider, @embedFile("styles.css"), -1);
    c.gtk_style_context_add_provider_for_display(
        c.gdk_display_get_default(),
        @ptrCast(provider),
        c.GTK_STYLE_PROVIDER_PRIORITY_USER,
    );
    const grid: [*c]c.GtkGrid = @ptrCast(c.gtk_grid_new());
    for (0..9) |i| {
        const box = c.gtk_box_new(c.GTK_ORIENTATION_VERTICAL, 0);
        c.gtk_widget_set_size_request(box, 400, 400);
        const label = c.gtk_label_new("●");
        c.gtk_widget_set_margin_top(label, 190);
        c.gtk_box_append(@ptrCast(box), @ptrCast(label));
        c.gtk_grid_attach(grid, box, @intCast(i % 3), @intCast(i / 3), 1, 1);
    }
    c.gtk_window_set_child(win, @ptrCast(grid));
    c.gtk_window_present(win);
}
