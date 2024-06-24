#version 330 core

out vec4 color;
uniform vec3 quadColor;

void main() {
    color = vec4(quadColor, 1.0);
}  