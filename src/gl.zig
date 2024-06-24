const c = @import("c.zig").c;
const std = @import("std");

const GLError = error{
    ShaderCompilationFailed,
    ProgramLinkingFailed,
};

const log = std.log.scoped(.@"glbar/gl");

pub fn createShader(allocator: std.mem.Allocator, src: [*c]const u8, shaderType: c.GLenum) !c.GLuint {
    const shader = c.glCreateShader(shaderType);
    log.info("Creating shader ({d})", .{shader});

    c.glShaderSource(shader, 1, &src, null);
    c.glCompileShader(shader);


    var length: c.GLsizei = undefined;
    c.glGetShaderiv(shader, c.GL_INFO_LOG_LENGTH, &length);

    if (length > 0) {
        const buf = try allocator.alloc(u8, @intCast(length));
        defer allocator.free(buf);

        c.glGetShaderInfoLog(shader, length, &length, @ptrCast(buf));
        log.warn("Shader info log:\n{s}", .{buf});
    }


    var status: c.GLint = undefined;
    c.glGetShaderiv(shader, c.GL_COMPILE_STATUS, &status);

    if (status != c.GL_TRUE) {
        log.err("Shader compilation failed", .{});
        return GLError.ShaderCompilationFailed;
    }

    return shader;
}

pub fn destroyShader(shader: c.GLuint) void {
    log.info("Destroying shader ({d})", .{shader});
    c.glDeleteShader(shader);
}

pub fn createProgram(allocator: std.mem.Allocator, shaders: []c.GLuint) !c.GLuint {
    const program = c.glCreateProgram();
    log.info("Creating program ({d})", .{program});

    for (shaders) |shader| {
        c.glAttachShader(program, shader);
    }

    c.glBindFragDataLocation(program, 0, "color");

    c.glLinkProgram(program);


    var length: c.GLsizei = undefined;
    c.glGetProgramiv(program, c.GL_INFO_LOG_LENGTH, &length);

    if (length > 0) {
        const buf = try allocator.alloc(u8, @intCast(length));
        defer allocator.free(buf);

        c.glGetProgramInfoLog(program, length, &length, @ptrCast(buf));
        log.warn("Program info log:\n{s}", .{buf});
    }


    var status: c.GLint = undefined;
    c.glGetProgramiv(program, c.GL_LINK_STATUS, &status);

    if (status != c.GL_TRUE) {
        log.err("Shader program linking failed", .{});
        return GLError.ProgramLinkingFailed;
    }


    return program;
}

pub fn destroyProgram(program: c.GLuint) void {
    log.info("Destroying program ({d})", .{program});
    c.glDeleteProgram(program);
}