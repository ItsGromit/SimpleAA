#version 150

in vec2 Position;
out vec2 vUv;

void main() {
    // Position is in [0,1] range, use directly as UVs
    vUv = vec2(Position.x, Position.y);

    // Convert [0,1] to clip space [-1,1]
    gl_Position = vec4(Position * 2.0 - 1.0, 0.0, 1.0);
}