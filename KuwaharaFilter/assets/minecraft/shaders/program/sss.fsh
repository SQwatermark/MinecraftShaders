#version 150

uniform sampler2D DiffuseSampler;
uniform vec2 OutSize;

in vec2 texCoord;

out vec4 fragColor;

vec2 TexelSize;
vec4 MeanAndVariance[4];
ivec4 Range;

vec4 GetKernelMeanAndVariance(vec2 UV, ivec4 Range) {

    vec3 Mean;
    vec3 Variance;
    int Samples;

    for (int x = Range.x; x <= Range.y; x++)
    {
        for (int y = Range.z; y <= Range.w; y++)
        {
            vec2 Offset = vec2(x, y) * TexelSize;
            vec3 PixelColor = texture(DiffuseSampler ,UV + Offset).rgb;
            Mean += PixelColor;
            Variance += PixelColor * PixelColor;
            Samples++;
        }
    }
    Mean /= Samples;
    Variance = Variance / Samples - Mean * Mean;
    float TotalVariance = Variance.r + Variance.g + Variance.b;
    return vec4(Mean.r, Mean.g, Mean.b, TotalVariance);
}

void main() {

    TexelSize = 2.0 / OutSize;
    ivec2 radius = ivec2(5, 5);

    Range = ivec4(-radius.x, 0, -radius.y, 0);
    MeanAndVariance[0] = GetKernelMeanAndVariance(texCoord, Range);

    Range = ivec4(0, radius.x, -radius.y, 0);
    MeanAndVariance[1] = GetKernelMeanAndVariance(texCoord, Range);

    Range = ivec4(-radius.x, 0, 0, radius.y);
    MeanAndVariance[2] = GetKernelMeanAndVariance(texCoord, Range);

    Range = ivec4(0, radius.x, 0, radius.y);
    MeanAndVariance[3] = GetKernelMeanAndVariance(texCoord, Range);

    // 1
    vec3 FinalColor = MeanAndVariance[0].rgb;
    float MinimumVariance = MeanAndVariance[0].a;

    // 2
    for (int i = 1; i < 4; i++)
    {
        if (MeanAndVariance[i].a < MinimumVariance)
        {
            FinalColor = MeanAndVariance[i].rgb;
            MinimumVariance = MeanAndVariance[i].a;
        }
    }

	fragColor = vec4(FinalColor, 1.0);
}