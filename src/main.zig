const std = @import("std");
const gtkc = @import("gtkc.zig");
const fs = std.fs;

var stick_idx: i32 = 1;
var last_deleted_idx: i32 = -1;
var max_notes: i32 = 100;
var ztickdir: fs.Dir = fs.Dir{ .fd = -1 };

fn add_note(stack: *gtkc.GtkWidget) callconv(.C) void {
    var stick_idx_before: i32 = -1;
    if (last_deleted_idx != -1) {
        stick_idx_before = stick_idx;
        stick_idx = last_deleted_idx;
        last_deleted_idx = -1;
    } else {
        stick_idx += 1;
    }
    const textbox_new = gtkc.gtk_text_view_new();
    const textbox1_buffer = gtkc.gtk_text_view_get_buffer(@ptrCast(textbox_new));
    gtkc.gtk_widget_set_hexpand(textbox_new, 1);
    gtkc.gtk_widget_set_vexpand(textbox_new, 1);
    const allocator = std.heap.page_allocator;
    const str = std.fmt.allocPrint(allocator, "Page{d}", .{stick_idx}) catch "format failed";
    _ = gtkc.gtk_text_buffer_create_tag(textbox1_buffer, str.ptr, null);
    _ = gtkc.gtk_stack_add_titled(@ptrCast(stack), @ptrCast(textbox_new), str.ptr, str.ptr);
    _ = gtkc.g_signal_connect_data(textbox1_buffer, "changed", @ptrCast(&write_note), textbox1_buffer, null, gtkc.G_CONNECT_SWAPPED);
    if (stick_idx_before != -1) {
        stick_idx = stick_idx_before;
    }
}

fn delete_note(stack: *gtkc.GtkWidget) callconv(.C) void {
    const widget = gtkc.gtk_stack_get_visible_child(@ptrCast(stack));
    const textbox1_buffer = gtkc.gtk_text_view_get_buffer(@ptrCast(widget));
    const tag_table = gtkc.gtk_text_buffer_get_tag_table(textbox1_buffer);
    var i: u8 = 1;
    var found: bool = false;
    const allocator = std.heap.page_allocator;
    // TODO: move this to function
    var str = std.fmt.allocPrint(allocator, "Page{d}", .{i}) catch "format failed";
    while (i <= max_notes) {
        str = std.fmt.allocPrint(allocator, "Page{d}", .{i}) catch "format failed";
        const name_tag = gtkc.gtk_text_tag_table_lookup(tag_table, str.ptr);
        if (name_tag != null) {
            found = true;
            break;
        }
        i += 1;
    }
    last_deleted_idx = i;
    _ = ztickdir.deleteFile(str) catch null;
    _ = gtkc.gtk_stack_remove(@ptrCast(stack), widget);
}

fn add_note_manually(stack: *gtkc.GtkWidget, buffer: *[4096]u8, size: c_int, index: i32) callconv(.C) void {
    stick_idx = index;
    const textbox_new = gtkc.gtk_text_view_new();
    const textbox1_buffer = gtkc.gtk_text_view_get_buffer(@ptrCast(textbox_new));
    gtkc.gtk_widget_set_hexpand(textbox_new, 1);
    gtkc.gtk_widget_set_vexpand(textbox_new, 1);
    const allocator = std.heap.page_allocator;
    const str = std.fmt.allocPrint(allocator, "Page{d}", .{stick_idx}) catch "format failed";
    _ = gtkc.gtk_text_buffer_create_tag(textbox1_buffer, str.ptr, null);
    _ = gtkc.gtk_stack_add_titled(@ptrCast(stack), @ptrCast(textbox_new), str.ptr, str.ptr);
    gtkc.gtk_text_buffer_set_text(textbox1_buffer, buffer, size);
    _ = gtkc.g_signal_connect_data(textbox1_buffer, "changed", @ptrCast(&write_note), textbox1_buffer, null, gtkc.G_CONNECT_SWAPPED);
}

fn write_note(textbufholder: *gtkc.GtkTextBuffer) callconv(.C) void {
    const textbuffer = @as(*gtkc.GtkTextBuffer, textbufholder);
    var start: gtkc.GtkTextIter = undefined;
    var end: gtkc.GtkTextIter = undefined;
    gtkc.gtk_text_buffer_get_start_iter(textbuffer, &start);
    gtkc.gtk_text_buffer_get_end_iter(textbuffer, &end);
    const text = gtkc.gtk_text_buffer_get_text(textbuffer, &start, &end, 0);

    const tag_table = gtkc.gtk_text_buffer_get_tag_table(textbuffer);
    var i: u8 = 1;
    var found: bool = false;
    const allocator = std.heap.page_allocator;
    var str = std.fmt.allocPrint(allocator, "Page{d}", .{i}) catch "format failed";
    // TODO: move this to function
    while (i <= max_notes) {
        str = std.fmt.allocPrint(allocator, "Page{d}", .{i}) catch "format failed";
        const name_tag = gtkc.gtk_text_tag_table_lookup(tag_table, str.ptr);
        if (name_tag != null) {
            found = true;
            break;
        }
        i += 1;
    }
    if (found) {
        const data_as_slice: []const u8 = std.mem.span(text);
        if (std.mem.startsWith(u8, data_as_slice, "")) {
            const file = ztickdir.createFile(
                str,
                .{ .read = true },
            ) catch return;
            defer file.close();
            _ = file.writeAll(data_as_slice) catch return;
        }
    }
}

fn on_activate(app: *gtkc.GtkApplication, data: gtkc.gpointer) callconv(.C) void {
    _ = data;

    const css_provider_create = gtkc.gtk_css_provider_new();
    const css_provider = gtkc.gtk_css_provider_new();
    const css_data_create_note = "button { background: linear-gradient(180deg, #4B91F7 0%, #367AF6 100%);    background-origin: border-box;   box-shadow: 0px 0.5px 1.5px rgba(54, 122, 246, 0.25), inset 0px 0.8px 0px -0.25px rgba(255, 255, 255, 0.2); border-color: #3498db; color: white; margin: 5px 5px 5px 50px;} button:hover{background:#367AF6;}";
    const css_data = "button {margin: 5px 50px 5px 5px;}";
    gtkc.gtk_css_provider_load_from_data(@ptrCast(css_provider), css_data, css_data.len);
    gtkc.gtk_css_provider_load_from_data(@ptrCast(css_provider_create), css_data_create_note, css_data_create_note.len);
    const window = gtkc.gtk_application_window_new(app);
    gtkc.gtk_window_set_default_size(@ptrCast(window), 400, 300);
    gtkc.gtk_window_set_title(@ptrCast(window), "ztick - tiny notes utility");
    gtkc.gtk_window_set_resizable(@ptrCast(window), 1);
    const button = gtkc.gtk_button_new_with_mnemonic("Create new note");
    const context = gtkc.gtk_widget_get_style_context(@ptrCast(button));
    _ = gtkc.gtk_style_context_add_provider(context, @ptrCast(css_provider_create), 800);
    const button_delete = gtkc.gtk_button_new_with_mnemonic("Delete this note");
    const context_delete_button = gtkc.gtk_widget_get_style_context(@ptrCast(button_delete));
    _ = gtkc.gtk_style_context_add_provider(context_delete_button, @ptrCast(css_provider), 800);
    const stack = gtkc.gtk_stack_new();
    const textbox1 = gtkc.gtk_text_view_new();
    const textbox1_buffer = gtkc.gtk_text_view_get_buffer(@ptrCast(textbox1));
    gtkc.gtk_widget_set_hexpand(textbox1, 1);
    gtkc.gtk_widget_set_vexpand(textbox1, 1);

    _ = gtkc.gtk_text_buffer_create_tag(textbox1_buffer, "Page1", null);
    const tag_table = gtkc.gtk_text_buffer_get_tag_table(textbox1_buffer);
    const name_tag = gtkc.gtk_text_tag_table_lookup(tag_table, "Page1");
    if (name_tag == null) {}

    const stack_sidebar = gtkc.gtk_stack_sidebar_new();
    _ = gtkc.gtk_stack_add_titled(@ptrCast(stack), @ptrCast(textbox1), "Page1", "Page1");
    _ = gtkc.gtk_stack_sidebar_set_stack(@ptrCast(stack_sidebar), @ptrCast(stack));
    _ = gtkc.g_signal_connect_data(button, "clicked", @ptrCast(&add_note), stack, null, gtkc.G_CONNECT_SWAPPED);
    _ = gtkc.g_signal_connect_data(button_delete, "clicked", @ptrCast(&delete_note), stack, null, gtkc.G_CONNECT_SWAPPED);

    _ = std.fs.cwd().makeDir(".ztick-data") catch null;
    ztickdir = std.fs.cwd().openDir(
        ".ztick-data",
        .{ .access_sub_paths = true },
    ) catch return;

    _ = ztickdir.createFile(
        "Page1",
        .{ .truncate = false },
    ) catch return;
    const file = ztickdir.openFile(
        "Page1",
        .{},
    ) catch return;
    defer file.close();

    var buffer: [4096]u8 = undefined;
    _ = file.seekTo(0) catch return;
    const bytes_read = file.readAll(&buffer) catch return;
    var size_u: c_int = 0;
    size_u = @intCast(bytes_read);
    gtkc.gtk_text_buffer_set_text(textbox1_buffer, &buffer, size_u);
    _ = gtkc.g_signal_connect_data(textbox1_buffer, "changed", @ptrCast(&write_note), textbox1_buffer, null, gtkc.G_CONNECT_SWAPPED);
    var i: u8 = 2;
    const allocator = std.heap.page_allocator;
    var str = std.fmt.allocPrint(allocator, "Page{d}", .{i}) catch "format failed";
    while (i <= max_notes) {
        str = std.fmt.allocPrint(allocator, "Page{d}", .{i}) catch "format failed";
        const file_local = ztickdir.openFile(
            str,
            .{},
        ) catch break;
        var buffer_local: [4096]u8 = undefined;
        _ = file_local.seekTo(0) catch break;
        const bytes_read_local = file_local.readAll(&buffer_local) catch break;
        var size_u_local: c_int = 0;
        size_u_local = @intCast(bytes_read_local);
        add_note_manually(stack, &buffer_local, size_u_local, i);
        i += 1;
    }

    const hpaned = gtkc.gtk_paned_new(0);
    gtkc.gtk_widget_set_size_request(hpaned, 200, -1);
    gtkc.gtk_paned_set_start_child(@ptrCast(hpaned), button_delete);
    gtkc.gtk_paned_set_resize_start_child(@ptrCast(hpaned), 0);
    gtkc.gtk_paned_set_shrink_start_child(@ptrCast(hpaned), 0);
    gtkc.gtk_widget_set_size_request(button_delete, 40, -1);

    gtkc.gtk_paned_set_end_child(@ptrCast(hpaned), button);
    gtkc.gtk_paned_set_resize_end_child(@ptrCast(hpaned), 0);
    gtkc.gtk_paned_set_shrink_end_child(@ptrCast(hpaned), 0);
    gtkc.gtk_widget_set_size_request(button, 20, -1);

    const box_main = gtkc.gtk_box_new(1, 1);
    const box_set = gtkc.gtk_box_new(0, 0);
    _ = gtkc.gtk_box_append(@ptrCast(box_set), stack_sidebar);
    _ = gtkc.gtk_box_append(@ptrCast(box_set), stack);
    _ = gtkc.gtk_box_append(@ptrCast(box_main), box_set);
    _ = gtkc.gtk_box_append(@ptrCast(box_main), hpaned);

    gtkc.gtk_window_set_child(@ptrCast(window), box_main);
    gtkc.gtk_window_present(@ptrCast(window));
}

pub fn main() !void {
    const app = gtkc.gtk_application_new("com.github", gtkc.G_APPLICATION_FLAGS_NONE);
    defer gtkc.g_object_unref(app);
    _ = gtkc.g_signal_connect_data(app, "activate", @ptrCast(&on_activate), null, null, 0);
    _ = gtkc.g_application_run(@ptrCast(app), 0, null);
}
