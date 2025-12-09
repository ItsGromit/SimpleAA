#version 150

uniform sampler2D DiffuseSampler;
uniform vec2 InSize;
uniform vec2 OutSize;
in vec2 vUv;
out vec4 fragColor;

const vec3  LUMA_WEIGHTS = vec3(0.500, 0.700, 0.300);
const float EDGE_THRESHOLD = 0.05;
const float EDGE_THRESHOLD_MIN = 0.0312;

float luma(vec3 c) {
    return dot(c, LUMA_WEIGHTS);
}

void main() {
    vec2 texel = 1.0 / vec2(textureSize(DiffuseSampler, 0));
    vec2 tc = clamp(vUv, texel, 1.0 - texel);
    vec3 C  = texture(DiffuseSampler, tc).rgb;

    vec2 tcL = clamp(tc - vec2(texel.x, 0.0), 0.0, 1.0);
    vec2 tcR = clamp(tc + vec2(texel.x, 0.0), 0.0, 1.0);
    vec2 tcU = clamp(tc - vec2(0.0, texel.y), 0.0, 1.0);
    vec2 tcD = clamp(tc + vec2(0.0, texel.y), 0.0, 1.0);

    float L   = luma(C);
    float LL = luma(texture(DiffuseSampler, tcL).rgb);
    float LR = luma(texture(DiffuseSampler, tcR).rgb);
    float LU = luma(texture(DiffuseSampler, tcU).rgb);
    float LD = luma(texture(DiffuseSampler, tcD).rgb);

    // Horizontal edge detection: compare up/down
    float dH = max(abs(LU - L), abs(L - LD));

    // Vertical edge detection: compare left/right
    float dV = max(abs(LL - L), abs(L - LR));

    // Threshold check
    float edgeH = step(EDGE_THRESHOLD, dH);
    float edgeV = step(EDGE_THRESHOLD, dV);

    fragColor = vec4(edgeH, edgeV, 0.0, 0.0);
}