#version 330 core

layout(location = 0) in uint char;
out uint vert_char;

void main() {
    vert_char = char;
}
