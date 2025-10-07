#version 150
in vec2 Position;      // Provided in 0..1
out vec2 texCoord;

void main() {
    // Fullscreen quad in NDC
    gl_Position = vec4(Position * 2.0 - 1.0, 0.0, 1.0);

    // Screen UVs
    texCoord = vec2(Position.x, Position.y);
}