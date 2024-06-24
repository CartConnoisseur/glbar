const c = @import("c.zig").c;
const std = @import("std");
const x = @import("x.zig");
const gl = @import("gl.zig");
const text = @import("text.zig");
const Module = @import("Module.zig");

const freetype = @import("mach-freetype");
const harfbuzz = @import("mach-harfbuzz");

const log = std.log.scoped(.glbar);

pub const info = struct {
    pub const name = "aaaaaaaaaa";
};

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    // var tpa = std.heap.ThreadSafeAllocator{ .child_allocator = gpa.allocator() };
    const allocator = gpa.allocator();

    defer {
        const deinit_status = gpa.deinit();
        if (deinit_status == .leak) log.err("GPA deinit leak", .{});
    }

    // Shitty name
    const x_ret = try x.init();
    const display = x_ret.display;
    const window = x_ret.window;
    const context = x_ret.context;
    defer x.deinit(display, window, context);

    c.glClearColor(0, 0, 0, 0);
    c.glBlendFunc(c.GL_SRC_ALPHA, c.GL_ONE_MINUS_SRC_ALPHA);
    c.glEnable(c.GL_BLEND);
    //c.glPolygonMode(c.GL_FRONT_AND_BACK, c.GL_LINE);

    log.info("OpenGL Version: {s}", .{c.glGetString(c.GL_VERSION)});


    try text.init(allocator);
    defer text.deinit();


    // var child = std.process.Child.init(&[_][]const u8{"sh", "-c", "playerctl --player=cmus,firefox,%any -F metadata --format='{{title}} - {{artist}}'"}, allocator);
    // child.stdout_behavior = std.process.Child.StdIo.Pipe;
    // try child.spawn();
    
    // var stdout = std.ArrayList(u8).init(allocator);
    // defer stdout.deinit();

    // std.io.bufferedReader(child.stdout.?.reader()).reader().streamUntilDelimiter(stdout.writer(), '\n', null);
    // defer stdout.clearAndFree();
    // log.info("line: {s}", .{stdout.items});

    // _ = try child.wait();





    var window_width: c_uint = undefined;
    var window_height: c_uint = undefined;
    c.glXQueryDrawable(display, window, c.GLX_WIDTH, &window_width);
    c.glXQueryDrawable(display, window, c.GLX_HEIGHT, &window_height);

    const w: f32 = @floatFromInt(window_width);
    const h: f32 = @floatFromInt(window_height);




    const quad_vert = try gl.createShader(allocator, @embedFile("shaders/quad.vsh"), c.GL_VERTEX_SHADER);
    defer gl.destroyShader(quad_vert);

    const quad_frag = try gl.createShader(allocator, @embedFile("shaders/quad.fsh"), c.GL_FRAGMENT_SHADER);
    defer gl.destroyShader(quad_frag);

    var quad_shaders = [_]c.GLuint{ quad_vert, quad_frag };
    const quad_program = try gl.createProgram(allocator, &quad_shaders);
    defer gl.destroyProgram(quad_program);



    var quad_vao: c.GLuint = undefined;
    c.glGenVertexArrays(1, &quad_vao);
    defer c.glDeleteVertexArrays(1, &quad_vao);

    var quad_vbo: c.GLuint = undefined;
    c.glGenBuffers(1, &quad_vbo);
    defer c.glDeleteBuffers(1, &quad_vbo);

    c.glBindVertexArray(quad_vao);
    c.glBindBuffer(c.GL_ARRAY_BUFFER, quad_vbo);

    const quad_vertices = [_][2]f32 {
        [2]f32{ -w+16, -h    },
        [2]f32{ -w+16,  h-16 },
        [2]f32{  w-16, -h    },
        [2]f32{  w-16,  h-16 },
    };

    c.glBufferData(c.GL_ARRAY_BUFFER, @sizeOf(@TypeOf(quad_vertices)), &quad_vertices, c.GL_STATIC_DRAW);

    c.glEnableVertexAttribArray(0);
    c.glVertexAttribPointer(0, 2, c.GL_FLOAT, c.GL_FALSE, @sizeOf(f32) * 2, null);

    c.glBindBuffer(c.GL_ARRAY_BUFFER, 0);
    c.glBindVertexArray(0);


    var usage_module = Module{
        .allocator = allocator,
        .command = "vmstat -n 2 | awk '{printf \"%.0f%% %.2f GiB\\n\", 100-$15, (31998756-($4+$5+$6))/1024/1024};fflush()'",
        .name = "usage",
    };
    
    try usage_module.start();
    defer usage_module.stop();

    var music_module = Module{
        .allocator = allocator,
        .command = "playerctl --player=cmus,firefox,%any -F metadata --format='{{title}} - {{artist}}'",
        .name = "music",
    };
    
    try music_module.start();
    defer music_module.stop();


    var title_module = Module{
        .allocator = allocator,
        .command = "while true; do xdotool getactivewindow getwindowname; sleep 1; done",
        .name = "title",
    };
    
    try title_module.start();
    defer title_module.stop();


    var volume_module = Module{
        .allocator = allocator,
        .command = "while true; do pactl get-sink-volume @DEFAULT_SINK@ | grep 'Volume' | awk '{ print $5 }'; sleep 1; done",
        .name = "volume",
    };
    
    try volume_module.start();
    defer volume_module.stop();

    var time_module = Module{
        .allocator = allocator,
        .command = "while true; do date '+%H:%M'; sleep 1; done",
        .name = "time",
    };
    
    try time_module.start();
    defer time_module.stop();


    var event: c.XEvent = undefined;
    var running: bool = true;
    while (running) {
        while (c.XCheckWindowEvent(display, window, x.event_mask, &event) == c.True) {
            switch (event.type) {
                c.KeyPress => {
                    const keysym = c.XLookupKeysym(&event.xkey, 0);
                    if (keysym == c.XStringToKeysym("q")) running = false;
                },
                c.ButtonPress => {
                    log.info("button press: {any}", .{event.xbutton});
                    running = false;
                    return;
                },
                else => log.info("event: {any}", .{event.type}),
            }
        }

        c.glClear(c.GL_COLOR_BUFFER_BIT);

        c.glUseProgram(quad_program);
        c.glUniform3f(c.glGetUniformLocation(quad_program, "quadColor"), 0.1, 0.1, 0.1);
        c.glUniform2i(c.glGetUniformLocation(quad_program, "resolution"), @intCast(window_width), @intCast(window_height));

        c.glBindVertexArray(quad_vao);
        c.glBindBuffer(c.GL_ARRAY_BUFFER, quad_vbo);

        c.glDrawArrays(c.GL_TRIANGLE_STRIP, 0, 4);

        c.glBindBuffer(c.GL_ARRAY_BUFFER, 0);
        c.glBindVertexArray(0);


        const left = try std.fmt.allocPrint(allocator, "USAGE: {s} | MUSIC: {s}", .{usage_module.get(), music_module.get()});
        const center = try std.fmt.allocPrint(allocator, "{s}", .{title_module.get()});
        const right = try std.fmt.allocPrint(allocator, "VOL: {s} | TIME: {s}", .{volume_module.get(), time_module.get()});

        defer allocator.free(left);
        defer allocator.free(center);
        defer allocator.free(right);

        text.drawCentered(display, window, left, -w+16+24, [3]f32{1, 1, 1});
        text.drawCentered(display, window, center, -@as(c.GLfloat, @floatFromInt(text.width(center)))/2, [3]f32{1, 1, 1});
        text.drawCentered(display, window, right, w-16-24-@as(c.GLfloat, @floatFromInt(text.width(right))), [3]f32{1, 1, 1});
        // log.info("width: {d}", .{text.width(module.get())});


        c.glXSwapBuffers(display, window);
        c.glFinish();
    }
}