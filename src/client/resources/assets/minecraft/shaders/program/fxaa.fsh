#version 150
uniform sampler2D DiffuseSampler;
uniform sampler2D DepthSampler;

in vec2 texCoord;
out vec4 fragColor;

// --- Tunables (same as before) ---
const float EDGE_THRESHOLD      = 0.125;
const float EDGE_THRESHOLD_MIN  = 0.0312;
const float K_CHROMA            = 0.80;
const float SEARCH_CLAMP        = 4.0;
const float SUBPIX_MIN          = 0.0;
const float SUBPIX_MAX          = 0.08;
const float BLEND_T0 = EDGE_THRESHOLD_MIN;
const float BLEND_T1 = EDGE_THRESHOLD * 0.75;

// Depth soft gate (hysteresis)
const float GEO_T0 = 1.5;
const float GEO_T1 = 2.5;

vec3 srgbToLinear(vec3 c){
    bvec3 lo = lessThanEqual(c, vec3(0.04045));
    vec3 hi = pow((c + 0.055) / 1.055, vec3(2.4));
    vec3 loV = c / 12.92;
    return mix(hi, loV, vec3(lo));
}
vec3 toYUV(vec3 srgb){
    vec3 lin = srgbToLinear(srgb);
    float Y = dot(lin, vec3(0.2126, 0.7152, 0.0722));
    return vec3(Y, lin.b - Y, lin.r - Y);
}
vec3 sRGB(vec2 uv){ return texture(DiffuseSampler, uv).rgb; }
float sDepth(vec2 uv){ return texture(DepthSampler, uv).r; }

void main(){
    // IMPORTANT: separate texel sizes
    vec2 texelColor = 1.0 / vec2(textureSize(DiffuseSampler, 0));
    vec2 texelDepth = 1.0 / vec2(textureSize(DepthSampler, 0));

    // ---------- depth gate with its OWN texel size ----------
    float dM = sDepth(texCoord);
    float dN = sDepth(texCoord + vec2(0.0, -texelDepth.y));
    float dS = sDepth(texCoord + vec2(0.0,  texelDepth.y));
    float dE = sDepth(texCoord + vec2( texelDepth.x, 0.0));
    float dW = sDepth(texCoord + vec2(-texelDepth.x, 0.0));

    // Contrast & normalization — compute fwidth on the *depth we sampled here*
    float dMax   = max(max(abs(dN - dM), abs(dS - dM)),
                       max(abs(dE - dM), abs(dW - dM)));
    float dScale = max(1e-6, fwidth(dM));
    float geoScore = dMax / dScale;

    // Smooth 0..1 mask so there’s no per-line flip
    float geoMask = smoothstep(GEO_T0, GEO_T1, geoScore);

    vec3 cM = sRGB(texCoord);
    if (geoMask <= 0.0) { fragColor = vec4(cM, 1.0); return; }

    // ---------- color neighborhood uses COLOR texel size ----------
    vec3 cN = sRGB(texCoord + vec2(0.0, -texelColor.y));
    vec3 cS = sRGB(texCoord + vec2(0.0,  texelColor.y));
    vec3 cE = sRGB(texCoord + vec2( texelColor.x, 0.0));
    vec3 cW = sRGB(texCoord + vec2(-texelColor.x, 0.0));

    vec3 yuvM = toYUV(cM), yuvN = toYUV(cN), yuvS = toYUV(cS), yuvE = toYUV(cE), yuvW = toYUV(cW);

    float dYmax = max(max(abs(yuvN.x - yuvM.x), abs(yuvS.x - yuvM.x)),
                      max(abs(yuvE.x - yuvM.x), abs(yuvW.x - yuvM.x)));
    float dUmax = max(max(abs(yuvN.y - yuvM.y), abs(yuvS.y - yuvM.y)),
                      max(abs(yuvE.y - yuvM.y), abs(yuvW.y - yuvM.y)));
    float dVmax = max(max(abs(yuvN.z - yuvM.z), abs(yuvS.z - yuvM.z)),
                      max(abs(yuvE.z - yuvM.z), abs(yuvW.z - yuvM.z)));
    float dCmax = max(dUmax, dVmax);
    float edgeStrength = max(dYmax, K_CHROMA * dCmax);

    float lMax = max(max(max(yuvN.x, yuvS.x), max(yuvE.x, yuvW.x)), yuvM.x);
    float doAA = step(max(EDGE_THRESHOLD_MIN, EDGE_THRESHOLD * lMax), edgeStrength);
    float aaMask = geoMask * doAA;
    if (aaMask <= 0.0) { fragColor = vec4(cM, 1.0); return; }

    // Continuous direction (no axis snap) + COLOR texel size for stepping
    vec2 grad = vec2(yuvW.x - yuvE.x, yuvN.x - yuvS.x);
    vec2 dir  = normalize(grad + 1e-6) * texelColor * SEARCH_CLAMP;

    // Sharper 2-tap
    vec3 A = 0.5 * ( sRGB(texCoord + dir*(1.0/3.0 - 0.5))
    + sRGB(texCoord + dir*(2.0/3.0 - 0.5)) );

    // Classic 4-tap around the edge
    vec3 B = A * 0.5
    + 0.25 * ( sRGB(texCoord + dir*-0.5) + sRGB(texCoord + dir*0.5) );

    // NEW: small span extension along the edge (±1.0) to remove the “boxy” steps
    vec3 C = 0.25 * ( sRGB(texCoord + dir*-1.0)
    + sRGB(texCoord + dir*-0.5)
    + sRGB(texCoord + dir* 0.5)
    + sRGB(texCoord + dir* 1.0) );

    // Edge-strength-based weight (stable, no hard switch)
    float wAB = clamp((edgeStrength - BLEND_T0) / max(1e-6, (BLEND_T1 - BLEND_T0)), 0.0, 1.0);

    // Favor the smoother branch slightly (gives you the “second image” shape)
    // First mix: A↔B; Second: blend a little toward C
    vec3 fxaa = mix(A, B, 0.55 * wAB);
    fxaa = mix(fxaa, C, 0.35 * wAB);

    // (keep your existing subpixel dampening, but with SUBPIX_MAX lowered to ~0.08)
    float lC   = yuvM.x;
    float lAvg = (yuvN.x + yuvS.x + yuvE.x + yuvW.x + lC) * 0.2;
    float subpix = clamp((lAvg - lC) * (lAvg - lC) * 16.0, SUBPIX_MIN, SUBPIX_MAX);
    fxaa = mix(fxaa, cM, subpix);

    fragColor = vec4(mix(cM, fxaa, aaMask), 1.0);
}
