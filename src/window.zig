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

var controller: ?*c.GtkEventController = undefined;

pub fn init() void {
    const app = c.gtk_application_new("com.github.dosx001.bullseye", c.G_APPLICATION_DEFAULT_FLAGS);
    go.gSignalConnect(app, "activate", c.G_CALLBACK(activate), null);
    controller = c.gtk_shortcut_controller_new();
    shortcuts();
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
    c.gtk_widget_add_controller(@ptrCast(win), controller);
    c.gtk_window_set_child(win, @ptrCast(grid));
    c.gtk_window_present(win);
}

fn update_size() void {
    const rect = regions[index];
    c.gtk_widget_set_margin_top(@ptrCast(grid), rect.y);
    c.gtk_widget_set_margin_start(@ptrCast(grid), rect.x);
    const fourth = @divFloor(rect.height, 4);
    const third = @divFloor(rect.width, 3);
    inline for (0..9) |i| {
        const child = c.gtk_grid_get_child_at(grid, @intCast(i % 3), @intCast(i / 3));
        switch (i) {
            3, 4, 5 => c.gtk_widget_set_size_request(child, third, fourth + fourth),
            else => c.gtk_widget_set_size_request(child, third, fourth),
        }
    }
}

fn shortcuts() void {
    inline for ([_]u8{ 'j', 'k', 'h', 'l' }) |char| {
        const action = c.gtk_callback_action_new(move_region, c.GINT_TO_POINTER(char), null);
        const trigger = c.gtk_shortcut_trigger_parse_string(@ptrCast(&[2]u8{ char, 0 }));
        const shortcut = c.gtk_shortcut_new(trigger, action);
        c.gtk_shortcut_controller_add_shortcut(@ptrCast(controller), shortcut);
    }
    inline for ([_]u8{ 'q', 'r', 'u' }) |char| {
        const action = c.gtk_callback_action_new(switch (char) {
            'q' => quit,
            'r' => reset,
            'u' => undo,
            else => unreachable,
        }, null, null);
        const trigger = c.gtk_shortcut_trigger_parse_string(@ptrCast(&[2]u8{ char, 0 }));
        const shortcut = c.gtk_shortcut_new(trigger, action);
        c.gtk_shortcut_controller_add_shortcut(@ptrCast(controller), shortcut);
    }
    inline for ([_]u8{ 'w', 's', 'e', 'a', ' ', 'f', 'i', 'd', 'o' }) |char| {
        const action = c.gtk_callback_action_new(update_region, c.GINT_TO_POINTER(char), null);
        const trigger = c.gtk_shortcut_trigger_parse_string(if (char == ' ')
            "space"
        else
            @ptrCast(&[2]u8{ char, 0 }));
        const shortcut = c.gtk_shortcut_new(trigger, action);
        c.gtk_shortcut_controller_add_shortcut(@ptrCast(controller), shortcut);
    }
}

fn move_region(
    _: [*c]c.GtkWidget,
    _: ?*c.GVariant,
    user_data: c.gpointer,
) callconv(.C) c.gboolean {
    switch (c.GPOINTER_TO_INT(user_data)) {
        'j' => regions[index].y += 5,
        'k' => regions[index].y -= 5,
        'h' => regions[index].x -= 5,
        'l' => regions[index].x += 5,
        else => unreachable,
    }
    update_size();
    return 0;
}

fn quit(
    _: [*c]c.GtkWidget,
    _: ?*c.GVariant,
    _: c.gpointer,
) callconv(.C) c.gboolean {
    std.posix.exit(0);
    return 0;
}

fn reset(
    _: [*c]c.GtkWidget,
    _: ?*c.GVariant,
    _: c.gpointer,
) callconv(.C) c.gboolean {
    index = 0;
    regions[0].x = 0;
    regions[0].y = 0;
    update_size();
    return 0;
}

fn undo(
    _: [*c]c.GtkWidget,
    _: ?*c.GVariant,
    _: c.gpointer,
) callconv(.C) c.gboolean {
    if (index == 0) return 1;
    index -= 1;
    update_size();
    return 0;
}

fn update_region(
    _: [*c]c.GtkWidget,
    _: ?*c.GVariant,
    user_data: c.gpointer,
) callconv(.C) c.gboolean {
    if (regions.len == index + 1) return 0;
    const rect = regions[index];
    index += 1;
    const fourth = @divFloor(rect.height, 4);
    const third = @divFloor(rect.width, 3);
    regions[index] =
        switch (c.GPOINTER_TO_INT(user_data)) {
            'w' => .{
                .x = rect.x,
                .y = rect.y,
                .width = third,
                .height = fourth,
            },
            's' => .{
                .x = rect.x + third,
                .y = rect.y,
                .width = third,
                .height = fourth,
            },
            'e' => .{
                .x = rect.x + 2 * third,
                .y = rect.y,
                .width = third,
                .height = fourth,
            },
            'a' => .{
                .x = rect.x,
                .y = rect.y + fourth,
                .width = third,
                .height = 2 * fourth,
            },
            ' ' => .{
                .x = rect.x + third,
                .y = rect.y + fourth,
                .width = third,
                .height = 2 * fourth,
            },
            'f' => .{
                .x = rect.x + 2 * third,
                .y = rect.y + fourth,
                .width = third,
                .height = 2 * fourth,
            },
            'i' => .{
                .x = rect.x,
                .y = rect.y + 3 * fourth,
                .width = third,
                .height = fourth,
            },
            'd' => .{
                .x = rect.x + third,
                .y = rect.y + 3 * fourth,
                .width = third,
                .height = fourth,
            },
            else => .{
                .x = rect.x + 2 * third,
                .y = rect.y + 3 * fourth,
                .width = third,
                .height = fourth,
            },
        };
    update_size();
    return 0;
}
