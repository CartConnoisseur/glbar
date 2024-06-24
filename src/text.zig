const c = @import("c.zig").c;
const std = @import("std");
const gl = @import("gl.zig");
const tga = @import("tga.zig");

const freetype = @import("mach-freetype");

const Character = struct {
    width: u32,
    height: u32,
    bearing_x: i32,
    bearing_y: i32,
    advance_x: c_long,
    advance_y: c_long,
};

const log = std.log.scoped(.@"glbar/text");


var program: c.GLuint = undefined;
var uniform = struct {
    position: c.GLint = undefined,
    color: c.GLint = undefined,
    resolution: c.GLint = undefined,
    char_atlas: c.GLint = undefined,
    char_map: c.GLint = undefined,
}{};
var attr = struct {
    char: c.GLuint = undefined,
}{};

var vao: c.GLuint = undefined;
var vbo: c.GLuint = undefined;
var abo: c.GLuint = undefined;


const char_count = 128;

const char_atlas_width = 32;
var char_atlas_tex: c.GLuint = undefined;

const char_map_width = 2;
var char_map_tex: c.GLuint = undefined;

const buffer_elem_size = 2*@sizeOf(f32) + @sizeOf(u8);

var char_advances: [char_count]usize = undefined;


pub fn init(allocator: std.mem.Allocator) !void {
    c.glPixelStorei(c.GL_UNPACK_ALIGNMENT, 1);

    const lib = try freetype.Library.init();
    defer lib.deinit();

    const face = try lib.createFaceMemory(@embedFile("CaskaydiaMonoNerdFont-Regular.ttf"), 0);
    //const face = try lib.createFaceMemory(@embedFile("Comic Sans MS.ttf"), 0);
    defer face.deinit();

    try face.setCharSize(11 << 7, 0, 96, 0);


    var char_atlas = std.ArrayList(u8).init(allocator);
    defer char_atlas.deinit();

    var char_map = std.ArrayList(u32).init(allocator);
    defer char_map.deinit();

    try char_atlas.appendNTimes(0, char_atlas_width);

    for (0..char_count) |i| {
        try face.loadChar(@intCast(i), .{ .render = true });
        const glyph = face.glyph();
        const bitmap = glyph.bitmap();

        if (glyph.bitmap().buffer() == null) {
            log.warn("char {d} bitmap buf is null", .{i});
        }

        try char_map.append(bitmap.width());
        try char_map.append(bitmap.rows());
        try char_map.append(@bitCast(glyph.bitmapLeft()));
        try char_map.append(@bitCast(glyph.bitmapTop()));

        try char_map.append(@bitCast(@as(i32, @truncate(glyph.advance().x >> 6))));
        try char_map.append(@bitCast(@as(i32, @truncate(glyph.advance().y >> 6))));
        try char_map.append(0xffffffff);
        try char_map.append(@truncate(char_atlas.items.len / char_atlas_width));

        char_advances[i] = @bitCast(@as(isize, @truncate(glyph.advance().x >> 6)));


        if (bitmap.buffer() != null) {
            for (0..bitmap.rows()) |row| {
                const w = bitmap.width();
                try char_atlas.append(0);
                try char_atlas.appendSlice(bitmap.buffer().?[w*row..w*(row+1)]);
                try char_atlas.appendNTimes(0, char_atlas_width - w - 1);
            }

            try char_atlas.appendNTimes(0, char_atlas_width);
        }
    }

    const char_atlas_height = char_atlas.items.len / char_atlas_width;
    const char_map_height = char_map.items.len / char_map_width / 4;



    const file = try std.fs.cwd().createFile("char_atlas.tga", .{});
    defer file.close();

    const header = tga.Header {
        .image_type = tga.ImageType.grayscale,
        .width = char_atlas_width,
        .height = @intCast(char_atlas_height),
        .pixel_order_v = tga.PixelOrder.reversed,
    };

    try header.write(file.writer());

    const count = try file.write(char_atlas.items);
    log.info("wrote {d} bytes", .{count});



    c.glGenTextures(1, &char_atlas_tex);
    c.glBindTexture(c.GL_TEXTURE_2D, char_atlas_tex);
    c.glTexImage2D(c.GL_TEXTURE_2D, 0, c.GL_RED, char_atlas_width, @intCast(char_atlas_height), 0, c.GL_RED, c.GL_UNSIGNED_BYTE, char_atlas.items.ptr);

    c.glTexParameteri(c.GL_TEXTURE_2D, c.GL_TEXTURE_WRAP_S, c.GL_CLAMP_TO_EDGE);
    c.glTexParameteri(c.GL_TEXTURE_2D, c.GL_TEXTURE_WRAP_T, c.GL_CLAMP_TO_EDGE);
    c.glTexParameteri(c.GL_TEXTURE_2D, c.GL_TEXTURE_MIN_FILTER, c.GL_LINEAR);
    c.glTexParameteri(c.GL_TEXTURE_2D, c.GL_TEXTURE_MAG_FILTER, c.GL_LINEAR);

    c.glGenTextures(1, &char_map_tex);
    c.glBindTexture(c.GL_TEXTURE_2D, char_map_tex);
    c.glTexImage2D(c.GL_TEXTURE_2D, 0, c.GL_RGBA32UI, char_map_width, @intCast(char_map_height), 0, c.GL_RGBA_INTEGER, c.GL_UNSIGNED_INT, char_map.items.ptr);

    c.glTexParameteri(c.GL_TEXTURE_2D, c.GL_TEXTURE_WRAP_S, c.GL_CLAMP_TO_EDGE);
    c.glTexParameteri(c.GL_TEXTURE_2D, c.GL_TEXTURE_WRAP_T, c.GL_CLAMP_TO_EDGE);
    c.glTexParameteri(c.GL_TEXTURE_2D, c.GL_TEXTURE_MIN_FILTER, c.GL_NEAREST);
    c.glTexParameteri(c.GL_TEXTURE_2D, c.GL_TEXTURE_MAG_FILTER, c.GL_NEAREST);






    const vert = try gl.createShader(allocator, @embedFile("shaders/text.vsh"), c.GL_VERTEX_SHADER);
    defer gl.destroyShader(vert);

    const frag = try gl.createShader(allocator, @embedFile("shaders/text.fsh"), c.GL_FRAGMENT_SHADER);
    defer gl.destroyShader(frag);

    const geom = try gl.createShader(allocator, @embedFile("shaders/text.gsh"), c.GL_GEOMETRY_SHADER);
    defer gl.destroyShader(geom);

    var shaders = [_]c.GLuint{ vert, frag, geom };
    program = try gl.createProgram(allocator, &shaders);

    uniform.position = c.glGetUniformLocation(program, "position");
    uniform.color = c.glGetUniformLocation(program, "text_color");
    uniform.resolution = c.glGetUniformLocation(program, "resolution");
    uniform.char_atlas = c.glGetUniformLocation(program, "char_atlas");
    uniform.char_map = c.glGetUniformLocation(program, "char_map");

    attr.char = @bitCast(c.glGetAttribLocation(program, "char"));



    c.glGenVertexArrays(1, &vao);
    c.glGenBuffers(1, &vbo);
    c.glGenBuffers(1, &abo);

    c.glBindVertexArray(vao);
    c.glBindBuffer(c.GL_ARRAY_BUFFER, vbo);
    c.glBindBuffer(c.GL_ATOMIC_COUNTER_BUFFER, abo);


    c.glEnableVertexAttribArray(attr.char);
    c.glVertexAttribIPointer(attr.char, 1, c.GL_UNSIGNED_BYTE, 0, null);
    

    c.glBufferData(c.GL_ATOMIC_COUNTER_BUFFER, @sizeOf(c.GLuint), null, c.GL_DYNAMIC_DRAW);

    c.glBindBuffer(c.GL_ATOMIC_COUNTER_BUFFER, 0);
    c.glBindBuffer(c.GL_ARRAY_BUFFER, 0);
    c.glBindVertexArray(0);
}

pub fn deinit() void {
    c.glDeleteBuffers(1, &abo);
    c.glDeleteBuffers(1, &vbo);
    c.glDeleteVertexArrays(1, &vao);

    gl.destroyProgram(program);

    c.glDeleteTextures(1, &char_map_tex);
    c.glDeleteTextures(1, &char_atlas_tex);
}

pub fn drawCentered(display: *c.Display, window: c.Window, string: []const u8, pos_x: c.GLfloat, color: [3]f32) void {
    return draw(display, window, string, pos_x, -4 - (11*96/72), color);
}

pub fn draw(display: *c.Display, window: c.Window, string: []const u8, pos_x: c.GLfloat, pos_y: c.GLfloat, color: [3]f32) void {
    var window_width: c_uint = undefined;
    var window_height: c_uint = undefined;
    c.glXQueryDrawable(display, window, c.GLX_WIDTH, &window_width);
    c.glXQueryDrawable(display, window, c.GLX_HEIGHT, &window_height);


    c.glUseProgram(program);
    c.glUniform3f(uniform.color, color[0], color[1], color[2]);
    c.glUniform2ui(uniform.resolution, window_width, window_height);
    c.glUniform2f(uniform.position, pos_x, pos_y);


    c.glBindTextureUnit(0, char_atlas_tex);
    c.glUniform1i(uniform.char_atlas, 0);

    c.glBindTextureUnit(1, char_map_tex);
    c.glUniform1i(uniform.char_map, 1);


    c.glBindVertexArray(vao);
    c.glBindBuffer(c.GL_ARRAY_BUFFER, vbo);
    c.glBindBuffer(c.GL_ATOMIC_COUNTER_BUFFER, abo);


    var counter: c.GLuint = 0;
    c.glBufferSubData(c.GL_ATOMIC_COUNTER_BUFFER, 0, @sizeOf(c.GLuint), &counter);
    c.glBufferData(c.GL_ARRAY_BUFFER, @bitCast(string.len), string.ptr, c.GL_STATIC_DRAW);


    c.glDrawArrays(c.GL_POINTS, 0, @intCast(string.len));


    c.glBindBuffer(c.GL_ATOMIC_COUNTER_BUFFER, 0);
    c.glBindBuffer(c.GL_ARRAY_BUFFER, 0);
    c.glBindVertexArray(0);

    c.glBindTexture(c.GL_TEXTURE_2D, 0);
}

pub fn width(string: []const u8) usize {
    var w: usize = 0;

    for (string) |char| {
        w += char_advances[if (char >= char_count) 0 else char];
    }

    return w;
}