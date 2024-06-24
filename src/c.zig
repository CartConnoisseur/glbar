pub const c = @cImport({
    @cInclude("X11/Xlib.h");
    @cInclude("X11/extensions/Xrender.h");
    @cInclude("epoxy/gl.h");
    @cInclude("epoxy/glx.h");
});