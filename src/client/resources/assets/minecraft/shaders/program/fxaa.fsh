#version 150
uniform sampler2D DiffuseSampler;
in vec2 texCoord;
out vec4 fragColor;

float luma(vec3 c) { return dot(c, vec3(0.299, 0.587, 0.114)); }
vec3 s(vec2 uv){ return texture(DiffuseSampler, uv).rgb; }

void main() {
    vec2 px = 1.0 / vec2(textureSize(DiffuseSampler, 0));

    vec3 m=s(texCoord), n=s(texCoord+vec2(0,-px.y)), s0=s(texCoord+vec2(0,px.y));
    vec3 e=s(texCoord+vec2(px.x,0)), w0=s(texCoord+vec2(-px.x,0));

    float lm=luma(m), lN=luma(n), lS=luma(s0), lE=luma(e), lW=luma(w0);
    float lMin=min(lm,min(min(lN,lS),min(lE,lW)));
    float lMax=max(lm,max(max(lN,lS),max(lE,lW)));
    float contrast=lMax-lMin;

    const float EDGE_THRESHOLD=0.083;
    if(contrast<EDGE_THRESHOLD){ fragColor=vec4(m,1.0); return; }

    vec2 dir = vec2(lW - lE, lN - lS);
    float dirReduce = max((lN + lS + lE + lW) * (0.25 * 0.5), 1e-4);
    float rcpDirMin = 1.0 / (min(abs(dir.x), abs(dir.y)) + dirReduce);
    dir = clamp(dir * rcpDirMin, vec2(-8.0), vec2(8.0)) * px;

    vec3 A = 0.5 * ( s(texCoord + dir*(1.0/3.0 - 0.5))
    + s(texCoord + dir*(2.0/3.0 - 0.5)) );

    vec3 B = A * 0.5 + 0.25 * ( s(texCoord + dir*-0.5)
    + s(texCoord + dir* 0.5) );

    float lB = luma(B);
    vec3 outRgb = (lB < lMin || lB > lMax) ? A : B;
    fragColor = vec4(outRgb, 1.0);
}