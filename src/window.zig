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
    c.gtk_css_provider_load_from_data(provider, @embedFile("styles.css"), -1);
    c.gtk_style_context_add_provider_for_display(
        c.gdk_display_get_default(),
        @ptrCast(provider),
        c.GTK_STYLE_PROVIDER_PRIORITY_USER,
    );
    const btn = c.gtk_button_new_with_label("Bullseye");
    c.gtk_widget_set_size_request(btn, 100, 40);
    go.gSignalConnect(btn, "clicked", c.G_CALLBACK(clicked), null);
    c.gtk_window_set_child(win, btn);
    c.gtk_window_present(win);
}

fn clicked(_: [*c]c.GtkWidget, _: c.gpointer) callconv(.C) void {
    std.log.info("clicked", .{});
}
