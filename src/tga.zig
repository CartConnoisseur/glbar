const std = @import("std");

pub const ImageType = enum(u8) {
    none = 0,

    colormapped = 1,
    truecolor = 2,
    grayscale = 3,

    colormapped_rle = 9,
    truecolor_rle = 10,
    grayscale_rle = 11,
};

pub const PixelOrder = enum(u8) {
    default = 0,
    reversed = 1,
};

pub const Header = struct {
    id: []const u8 = "",
    image_type: ImageType = ImageType.none,
    width: u16,
    height: u16,
    pixel_depth: u8 = 8,
    alpha_depth: u8 = 0,
    pixel_order_h: PixelOrder = PixelOrder.default,
    pixel_order_v: PixelOrder = PixelOrder.default,

    pub fn write(self: Header, writer: anytype) !void {
        try writer.writeByte(@truncate(@min(self.id.len, 255)));
        try writer.writeByte(0x00); // color map type
        try writer.writeByte(@intFromEnum(self.image_type));
        try writer.writeByteNTimes(0x00, 5); // color map specification

        if (self.id.len > 0) try writer.writeAll(self.id[0..@min(self.id.len, 255)]);

        // Image specification:
        try writeU16(writer, 0);
        try writeU16(writer, self.height);
        try writeU16(writer, self.width);
        try writeU16(writer, self.height);
        try writer.writeByte(self.pixel_depth);
        try writer.writeByte(self.alpha_depth | (@intFromEnum(self.pixel_order_h) << 4) | (@intFromEnum(self.pixel_order_v) << 5));
    }

    fn writeU16(writer: anytype, int: u16) !void {
        try writer.writeAll(&[_]u8{
            @truncate((int >> 0) & 0x00ff),
            @truncate((int >> 8) & 0x00ff),
        });
    }
};

const log = std.log.scoped(.@"glbar/tga");

