#version 150
uniform sampler2D DiffuseSampler;
uniform sampler2D DepthSampler;
in vec2 texCoord;
out vec4 fragColor;

// Tunables
const float FAR_START = 0.40;   // start smoothing (0..1 depth after linearization)
const float FAR_END   = 0.80;   // full smoothing by here
const float SIGMA_PX  = 0.70;   // kernel radius in pixels (0.6..1.2)
const float DEPTH_REJ = 6.0;    // larger -> stronger edge preservation

// sRGB -> linear
vec3 srgbToLinear(vec3 c) {
    bvec3 lo = lessThanEqual(c, vec3(0.04045));
    vec3 hi = pow((c + 0.055) / 1.055, vec3(2.4));
    vec3 loV = c / 12.92;
    return mix(hi, loV, vec3(lo));
}
vec3 linearToSrgb(vec3 c) {
    bvec3 lo = lessThanEqual(c, vec3(0.0031308));
    vec3 hi = 1.055 * pow(c, vec3(1.0/2.4)) - 0.055;
    vec3 loV = 12.92 * c;
    return mix(hi, loV, vec3(lo));
}

// Pack/Unpack YUV (Y=linear luma, U=B-Y, V=R-Y)
vec3 toYUV(vec3 srgb){
    vec3 lin = srgbToLinear(srgb);
    float Y = dot(lin, vec3(0.2126, 0.7152, 0.0722));
    return vec3(Y, lin.b - Y, lin.r - Y);
}
vec3 fromYUV(vec3 yuv){
    float Y = yuv.x;
    float B = yuv.y + Y;
    float R = yuv.z + Y;
    float G = (Y - 0.2126*R - 0.0722*B) / 0.7152;
    return linearToSrgb(clamp(vec3(R,G,B), 0.0, 1.0));
}

float depthAt(vec2 uv){ return texture(DepthSampler, uv).r; }
vec3  rgbAt(vec2 uv){ return texture(DiffuseSampler, uv).rgb; }

// Optional: linearize depth if your buffer is non-linear. If not sure, leave as is.
float linearize(float d){ return d; }

void main(){
    ivec2 sizeColor = textureSize(DiffuseSampler, 0);
    ivec2 sizeDepth = textureSize(DepthSampler, 0);
    vec2  texelC = 1.0 / vec2(sizeColor);
    vec2  texelD = 1.0 / vec2(sizeDepth);

    float dM = linearize(depthAt(texCoord));

    // Distance factor (soft ramp)
    float farMask = smoothstep(FAR_START, FAR_END, dM);
    if (farMask <= 0.0) {
        fragColor = vec4(rgbAt(texCoord), 1.0);
        return;
    }

    // Convert center to YUV
    vec3 yuvM = toYUV(rgbAt(texCoord));

    // 3x3 Gaussian in chroma only, depth-aware bilateral weighting
    float sigma = SIGMA_PX;
    float twoSigma2 = 2.0 * sigma * sigma;

    vec2 offsets[8] = vec2[8](
    vec2(-1,  0), vec2( 1,  0),
    vec2( 0, -1), vec2( 0,  1),
    vec2(-1, -1), vec2( 1, -1),
    vec2(-1,  1), vec2( 1,  1)
    );

    float wSum = 1.0;
    vec2  uvChroma = yuvM.yz;

    for (int i=0;i<8;i++){
        // use color texel for offsets (we blur the color target)
        vec2 uv = texCoord + offsets[i] * texelC * sigma;
        vec3 yuvS = toYUV(rgbAt(uv));

        // spatial weight (Gaussian)
        float r2 = dot(offsets[i], offsets[i]) * sigma * sigma;
        float wSpatial = exp(-r2 / twoSigma2);

        // depth rejection to avoid bleeding across silhouettes
        float dS = linearize(depthAt(uv));
        float wDepth = exp(-DEPTH_REJ * abs(dS - dM) / max(1e-5, fwidth(dM)));

        float w = wSpatial * wDepth;
        wSum += w;
        uvChroma += w * yuvS.yz;
    }

    uvChroma /= wSum;

    // Keep luma, replace chroma (U/V) — only in the far field
    vec3 yuvOut = vec3(yuvM.x, mix(yuvM.yz, uvChroma, farMask));
    vec3 rgbOut = fromYUV(yuvOut);

    fragColor = vec4(rgbOut, 1.0);
}
