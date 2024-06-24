#version 420 core

precision highp float;

layout(binding = 0) uniform sampler2D char_atlas;
layout(binding = 1) uniform usampler2D char_map;

uniform vec3 text_color;


in vec2 tex_coords;
flat in uint char;

out vec4 color;

void main() {
    if (true) {
        uvec2 size = texelFetch(char_map, ivec2(0, char), 0).rg;
        uint offset = texelFetch(char_map, ivec2(1, char), 0).a;

        vec2 finalTexCoords = tex_coords * (vec2(size) / textureSize(char_atlas, 0));
        finalTexCoords += vec2(0.0, float(offset)) / textureSize(char_atlas, 0);
        finalTexCoords += vec2(1, 1) / textureSize(char_atlas, 0);

        vec4 sampled = vec4(1.0, 1.0, 1.0, texture(char_atlas, finalTexCoords).r);
        color = vec4(text_color, 1.0) * sampled;
    } else {
        color = vec4(1.0);
    }
}