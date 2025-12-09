#version 150

uniform sampler2D DiffuseSampler;
uniform sampler2D BlendTex;

in vec2 vUv;
out vec4 fragColor;

void main() {
    vec2 texel = 1.0 / vec2(textureSize(DiffuseSampler, 0));

    vec2 tc = clamp(vUv, texel * 0.5, 1.0 - texel * 0.5);

    vec4 color = texture(DiffuseSampler, tc);

    vec4 weights = texture(BlendTex, tc);

    float totalWeight = dot(weights, vec4(1.0));
    if (totalWeight < 0.01) {
        fragColor = color;
        return;
    }

    vec4 blended = color;
    float sum = 1.0;

    if(weights.x > 0.0) {
        vec2 coord = clamp(tc - vec2(texel.x, 0.0), 0.0, 1.0);
        vec4 texSample = texture(DiffuseSampler, coord);
        blended += texSample * weights.x;
        sum += weights.x;
    }
    if (weights.y > 0.0) {
        vec2 coord = clamp(tc - vec2(0.0, texel.y), 0.0, 1.0);
        vec4 texSample = texture(DiffuseSampler, coord);
        blended += texSample * weights.y;
        sum += weights.y;
    }
    if (weights.z > 0.0) {
        vec2 coord = clamp(tc + vec2(texel.x, 0.0), 0.0, 1.0);
        vec4 texSample = texture(DiffuseSampler, coord);
        blended += texSample * weights.z;
        sum += weights.z;
    }
    if (weights.w > 0.0) {
        vec2 coord = clamp(tc + vec2(0.0, texel.y), 0.0, 1.0);
        vec4 texSample = texture(DiffuseSampler, coord);
        blended += texSample * weights.w;
        sum += weights.w;
    }
    if(sum > 0.0) {
        blended /= sum;
    }

    fragColor = vec4(blended.rgb, color.a);

}
