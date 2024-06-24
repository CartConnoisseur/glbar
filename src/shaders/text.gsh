#version 460 core

layout(points) in;
layout(triangle_strip, max_vertices = 4) out;


layout(binding = 1) uniform usampler2D char_map;
layout(binding = 0) uniform atomic_uint cursor;

uniform uvec2 resolution;
uniform vec2 position;


in uint vert_char[];

out vec2 tex_coords;
flat out uint char;

void main() {
    char = vert_char[0];
    if (vert_char[0] >= 128) char = 0;
    
    uvec2 size = texelFetch(char_map, ivec2(0, char), 0).rg;
    uvec2 bearing = texelFetch(char_map, ivec2(0, char), 0).ba;
    uvec2 advance = texelFetch(char_map, ivec2(1, char), 0).rg;

    vec2 pos = position + vec2(atomicCounterAdd(cursor, advance.x), 0.0) + bearing;

    if (size == uvec2(0, 0)) return;
    
    tex_coords = vec2(0.0, 1.0);
    gl_Position = vec4((pos + vec2(0.0, -float(size.y))) / resolution, 0.0, 1.0);
    EmitVertex();

    tex_coords = vec2(0.0, 0.0);
    gl_Position = vec4(pos / resolution, 0.0, 1.0);
    EmitVertex();

    tex_coords = vec2(1.0, 1.0);
    gl_Position = vec4((pos + vec2(size.x, -float(size.y))) / resolution, 0.0, 1.0);
    EmitVertex();

    tex_coords = vec2(1.0, 0.0);
    gl_Position = vec4((pos + vec2(size.x, 0.0)) / resolution, 0.0, 1.0);
    EmitVertex();

    EndPrimitive();
}