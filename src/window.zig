const go = @import("gobject.zig");
const std = @import("std");

const c = @cImport({
    @cInclude("fcntl.h");
    @cInclude("gtk-4.0/gtk/gtk.h");
    @cInclude("linux/uinput.h");
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
var window: [*c]c.GtkWindow = undefined;

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
    window = @ptrCast(c.gtk_application_window_new(app));
    c.gtk_window_fullscreen(window);
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
    c.gtk_widget_add_controller(@ptrCast(window), controller);
    c.gtk_window_set_child(window, @ptrCast(grid));
    c.gtk_window_present(window);
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
        const action_l_click = c.gtk_callback_action_new(left_click, c.GINT_TO_POINTER(char), null);
        const trigger_l_click = c.gtk_shortcut_trigger_parse_string(if (char == ' ')
            "<Alt>space"
        else
            @ptrCast(&[_]u8{ '<', 'A', 'l', 't', '>', char, 0 }));
        const shortcut_l_click = c.gtk_shortcut_new(trigger_l_click, action_l_click);
        c.gtk_shortcut_controller_add_shortcut(@ptrCast(controller), shortcut_l_click);
        const action_r_click = c.gtk_callback_action_new(right_click, c.GINT_TO_POINTER(char), null);
        const trigger_r_click = c.gtk_shortcut_trigger_parse_string(if (char == ' ')
            "<Control>space"
        else
            @ptrCast(&[_]u8{ '<', 'C', 'o', 'n', 't', 'r', 'o', 'l', '>', char, 0 }));
        const shortcut_r_click = c.gtk_shortcut_new(trigger_r_click, action_r_click);
        c.gtk_shortcut_controller_add_shortcut(@ptrCast(controller), shortcut_r_click);
        const action_m_click = c.gtk_callback_action_new(middle_click, c.GINT_TO_POINTER(char), null);
        const trigger_m_click = c.gtk_shortcut_trigger_parse_string(if (char == ' ')
            "<Control><Alt>space"
        else
            @ptrCast(&[_]u8{ '<', 'C', 'o', 'n', 't', 'r', 'o', 'l', '>', '<', 'A', 'l', 't', '>', char, 0 }));
        const shortcut_m_click = c.gtk_shortcut_new(trigger_m_click, action_m_click);
        c.gtk_shortcut_controller_add_shortcut(@ptrCast(controller), shortcut_m_click);
        const action_move = c.gtk_callback_action_new(move_cursor, c.GINT_TO_POINTER(char), null);
        const trigger_move = c.gtk_shortcut_trigger_parse_string(if (char == ' ')
            "<Shift>space"
        else
            @ptrCast(&[_]u8{ '<', 'S', 'h', 'i', 'f', 't', '>', char, 0 }));
        const shortcut_move = c.gtk_shortcut_new(trigger_move, action_move);
        c.gtk_shortcut_controller_add_shortcut(@ptrCast(controller), shortcut_move);
    }
    for ([_]c_int{ c.BTN_LEFT, c.BTN_MIDDLE, c.BTN_RIGHT }) |btn| {
        const action = c.gtk_callback_action_new(cursor_click, c.GINT_TO_POINTER(btn), null);
        const trigger =
            c.gtk_shortcut_trigger_parse_string(switch (btn) {
                c.BTN_LEFT => "semicolon",
                c.BTN_MIDDLE => "<Alt>semicolon",
                c.BTN_RIGHT => "<Control>semicolon",
                else => unreachable,
            });
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
            'o' => .{
                .x = rect.x + 2 * third,
                .y = rect.y + 3 * fourth,
                .width = third,
                .height = fourth,
            },
            else => unreachable,
        };
    update_size();
    return 0;
}

fn emit(
    fd: c_int,
    ev_type: c_ushort,
    code: c_ushort,
    val: c_int,
) void {
    _ = c.write(
        fd,
        &c.input_event{
            .type = ev_type,
            .code = code,
            .value = val,
            .time = .{
                .tv_sec = 0,
                .tv_usec = 0,
            },
        },
        @sizeOf(c.input_event),
    );
}

fn uinput() c_int {
    const fd = c.open("/dev/uinput", c.O_WRONLY | c.O_NONBLOCK);
    if (fd < 0) {
        std.log.err("Failed to open /dev/uinput", .{});
        std.posix.exit(1);
    }
    _ = c.ioctl(fd, c.UI_SET_EVBIT, c.EV_KEY);
    const str = "bullseye";
    var name: [80]u8 = undefined;
    @memcpy(name[0..str.len], str);
    _ = c.ioctl(
        fd,
        c.UI_DEV_SETUP,
        &c.uinput_setup{ .name = name },
    );
    return fd;
}

fn mouse(
    region: c.gint,
    btn: c_ushort,
    click: bool,
) void {
    _ = c.gtk_widget_hide(@ptrCast(window));
    const fd = uinput();
    defer _ = c.close(fd);
    _ = c.ioctl(fd, c.UI_SET_KEYBIT, btn);
    _ = c.ioctl(fd, c.UI_SET_EVBIT, c.EV_ABS);
    _ = c.ioctl(fd, c.UI_SET_ABSBIT, c.ABS_X);
    _ = c.ioctl(fd, c.UI_SET_ABSBIT, c.ABS_Y);
    var abs_setup = c.uinput_abs_setup{
        .code = c.ABS_X,
        .absinfo = .{
            .minimum = 0,
            .maximum = regions[0].width - 1,
        },
    };
    _ = c.ioctl(fd, c.UI_ABS_SETUP, &abs_setup);
    abs_setup.code = c.ABS_Y;
    abs_setup.absinfo.maximum = regions[0].height - 1;
    _ = c.ioctl(fd, c.UI_ABS_SETUP, &abs_setup);
    _ = c.ioctl(fd, c.UI_DEV_CREATE);
    const sixth = @divFloor(regions[index].width, 6);
    const eighth = @divFloor(regions[index].height, 8);
    var position = [2]c_int{ regions[index].x, regions[index].y };
    switch (region) {
        'w' => {
            position[0] += sixth;
            position[1] += eighth;
        },
        's' => {
            position[0] += 3 * sixth;
            position[1] += eighth;
        },
        'e' => {
            position[0] += 5 * sixth;
            position[1] += eighth;
        },
        'a' => {
            position[0] += sixth;
            position[1] += 4 * eighth;
        },
        ' ' => {
            position[0] += 3 * sixth;
            position[1] += 4 * eighth;
        },
        'f' => {
            position[0] += 5 * sixth;
            position[1] += 4 * eighth;
        },
        'i' => {
            position[0] += sixth;
            position[1] += 7 * eighth;
        },
        'd' => {
            position[0] += 3 * sixth;
            position[1] += 7 * eighth;
        },
        'o' => {
            position[0] += 5 * sixth;
            position[1] += 7 * eighth;
        },
        else => unreachable,
    }
    std.time.sleep(500_000_000);
    while (c.g_main_context_iteration(c.g_main_context_default(), 0) == 1) {}
    emit(fd, c.EV_ABS, c.ABS_X, position[0]);
    emit(fd, c.EV_ABS, c.ABS_Y, position[1]);
    emit(fd, c.EV_SYN, c.SYN_REPORT, 0);
    if (click) {
        std.time.sleep(100_000_000);
        emit(fd, c.EV_KEY, btn, 1);
        emit(fd, c.EV_SYN, c.SYN_REPORT, 0);
        std.time.sleep(100_000_000);
        emit(fd, c.EV_KEY, btn, 0);
        emit(fd, c.EV_SYN, c.SYN_REPORT, 0);
    }
    std.time.sleep(500_000_000);
    _ = c.ioctl(fd, c.UI_DEV_DESTROY);
    std.posix.exit(0);
}

fn left_click(
    _: [*c]c.GtkWidget,
    _: ?*c.GVariant,
    data: c.gpointer,
) callconv(.C) c.gboolean {
    mouse(c.GPOINTER_TO_INT(data), c.BTN_LEFT, true);
    return 0;
}

fn right_click(
    _: [*c]c.GtkWidget,
    _: ?*c.GVariant,
    data: c.gpointer,
) callconv(.C) c.gboolean {
    mouse(c.GPOINTER_TO_INT(data), c.BTN_RIGHT, true);
    return 0;
}

fn middle_click(
    _: [*c]c.GtkWidget,
    _: ?*c.GVariant,
    data: c.gpointer,
) callconv(.C) c.gboolean {
    mouse(c.GPOINTER_TO_INT(data), c.BTN_MIDDLE, true);
    return 0;
}

fn move_cursor(
    _: [*c]c.GtkWidget,
    _: ?*c.GVariant,
    data: c.gpointer,
) callconv(.C) c.gboolean {
    mouse(c.GPOINTER_TO_INT(data), c.BTN_LEFT, false);
    return 0;
}

fn cursor_click(
    _: [*c]c.GtkWidget,
    _: ?*c.GVariant,
    data: c.gpointer,
) callconv(.C) c.gboolean {
    _ = c.gtk_widget_hide(@ptrCast(window));
    const fd = uinput();
    defer _ = c.close(fd);
    const btn: c_ushort = @intCast(c.GPOINTER_TO_INT(data));
    _ = c.ioctl(fd, c.UI_SET_KEYBIT, btn);
    _ = c.ioctl(fd, c.UI_DEV_CREATE);
    while (c.g_main_context_iteration(c.g_main_context_default(), 0) == 1) {}
    std.time.sleep(500_000_000);
    emit(fd, c.EV_KEY, btn, 1);
    emit(fd, c.EV_SYN, c.SYN_REPORT, 0);
    std.time.sleep(100_000_000);
    emit(fd, c.EV_KEY, btn, 0);
    emit(fd, c.EV_SYN, c.SYN_REPORT, 0);
    std.time.sleep(100_000_000);
    _ = c.ioctl(fd, c.UI_DEV_DESTROY);
    std.posix.exit(0);
    return 0;
}
