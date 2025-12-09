#version 150

uniform sampler2D DiffuseSampler;

in vec2 vUv;
out vec4 fragColor;

const int   MAX_SEARCH_STEPS = 16;
const float EDGE_CUTOFF      = 0.01;

float edgeAt(vec2 uv, bool horizontal) {
    vec2 e = texture(DiffuseSampler, uv).rg;
    return horizontal ? e.r : e.g;
}

int limitFromSearch(float edgeStrength) {
    return int(floor(mix(3.0, float(MAX_SEARCH_STEPS), clamp(edgeStrength, 0.0, 1.0))));
}

int searchSteps(vec2 startUv, vec2 dir, bool horizontal, int limit) {
    vec2 texel = 1.0 / vec2(textureSize(DiffuseSampler, 0));
    vec2 uv = startUv;
    int steps = 0;

    for (int i = 0; i < MAX_SEARCH_STEPS; i++) {
        if (i >= limit) break;
        uv += dir * texel;

        vec2 sampleUv = clamp(uv, 0.0, 1.0);
        float e = edgeAt(sampleUv, horizontal);

        if (e < EDGE_CUTOFF) break;
        steps++;
    }
    return steps;
}

vec2 areaWeights(float edgeStrength, int dNeg, int dPos) {
    int totalLen = dNeg + dPos;
    if (totalLen < 2) return vec2(0.0);

    float lengthFactor = min(float(totalLen) / float(MAX_SEARCH_STEPS), 1.0);

    float baseWeight = edgeStrength * lengthFactor * 0.6;

    float totalFloat = float(totalLen);
    float wNeg = baseWeight * (float(dNeg) / totalFloat);
    float wPos = baseWeight * (float(dPos) / totalFloat);

    return vec2(wNeg, wPos);
}

void main() {
    vec2 texel = 1.0 / vec2(textureSize(DiffuseSampler, 0));
    vec2 tc = clamp(vUv, texel * 0.5, 1.0 - texel * 0.5);
    vec2 e = texture(DiffuseSampler, tc).rg;

    float edgeH = e.r;
    float edgeV = e.g;

    float wL = 0.0, wR = 0.0, wU = 0.0, wD = 0.0;

    if (edgeV > EDGE_CUTOFF) {
        int lim = limitFromSearch(edgeV);
        int dL = searchSteps(tc, vec2(-1.0, 0.0), false, lim);
        int dR = searchSteps(tc, vec2( 1.0, 0.0), false, lim);
        vec2 w = areaWeights(edgeV, dL, dR);
        wL = w.r;
        wR = w.g;
    }

    if (edgeH > EDGE_CUTOFF) {
        int lim = limitFromSearch(edgeH);
        int dU = searchSteps(tc, vec2(0.0, -1.0), true, lim);
        int dD = searchSteps(tc, vec2(0.0,  1.0), true, lim);
        vec2 w = areaWeights(edgeH, dU, dD);
        wU = w.r;
        wD = w.g;
    }
    fragColor = vec4(wL, wU, wR, wD);
}
