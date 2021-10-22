#version 150

bool allowAlpha;
bool hardEdge;
bool isAltas;

// 进行UV偏移计算
vec2 offsetUV(vec2 original, vec2 offset)
{
    vec2 uv = original + offset;
    if (isAltas) {
        // 这个式子会把纹理集中跑出原先纹理的uv值拽回去，并进行密铺
        vec2 fixedUV = (floor(original * 64) + fract(uv * 64)) / 64;
        if (hardEdge) {
            // 如果使用硬边缘，则在边缘处直接返回原uv值，这样边缘不会出现圆角
            return (fixedUV == uv) ? uv : original;
        }
        else {
            return fixedUV;
        }
    } else {
        return uv;
    }

}

// https://blog.csdn.net/liuyizhou95/article/details/83501756
vec3 rgb2hsv(vec3 c) {
    vec4 K = vec4(0.0, -1.0 / 3.0, 2.0 / 3.0, -1.0);
    vec4 p = mix(vec4(c.bg, K.wz), vec4(c.gb, K.xy), step(c.b, c.g));
    vec4 q = mix(vec4(p.xyw, c.r), vec4(c.r, p.yzx), step(p.x, c.r));
    float d = q.x - min(q.w, q.y);
    float e = 1.0e-10;
    vec3 hsv = vec3(abs(q.z + (q.w - q.y) / (6.0 * d + e)), d / (q.x + e), q.x);
    return hsv;
}

// 判断两种颜色的色相是否接近
bool isHueClose(vec4 color1, vec4 color2) {
    float hDiffer = abs(rgb2hsv(color1.rgb).x - rgb2hsv(color2.rgb).x);
    if (hDiffer < 0.02 || hDiffer > 0.98) {
        return true;
    } else {
        return false;
    }
}

vec4 getRoundCorner(sampler2D SamplerIn, vec2 texCoord, float vertexDistance, int type) {

    if (type == 1) {
        // 用于solid的设置
        allowAlpha = false;
        hardEdge = false;
        isAltas = true;
    } else if (type == 2) {
        // 用于cutout的设置
        allowAlpha = true;
        hardEdge = true;
        isAltas = true;
    } else if (type == 3) {
        // 用于cutout mipped的设置
        allowAlpha = true;
        hardEdge = true;
        isAltas = true;
    } else {
        allowAlpha = true;
        hardEdge = false;
        isAltas = false;
    }

    if (vertexDistance > 8 && vertexDistance < 1400) {
        // 大于1400的是GUI等乱七八糟的东西
        // 见 https://github.com/ShockMicro/Minecraft-Shaders/wiki/Isolating-certain-elements
        return texture(SamplerIn, texCoord);
    } else {
        vec2 size = textureSize(SamplerIn, 0); // 纹理尺寸
        vec2 texelCoord = texCoord * size;  // 去归一化的纹理坐标
        vec2 texelMiddle = floor(texelCoord) + vec2(0.5, 0.5); // 去归一化的像素中心点坐标
        if (distance(texelCoord, texelMiddle) < 0.5) {
            // 在像素内切圆里面就直接返回原本颜色
            return texture(SamplerIn, texCoord);
        } else {
            vec2 texMiddle = texelMiddle / size; // 归一化的像素中心点坐标
            vec2 directionMultiplier = 2 * floor(texelCoord - texelMiddle) + vec2(1.0); // 拐角方向，值为(-1,-1)(-1,1)(1,-1)(1,1)
            vec2 normalizedTexel = 1.0 / size; // 归一化的一像素大小

            vec2 directionTexel = directionMultiplier * normalizedTexel;
            // 在拐角相邻的三个像素和自身进行采样
            vec4 colors[4];
            colors[0] = texture(SamplerIn, texMiddle); // 自身
            colors[1] = texture(SamplerIn, offsetUV(texMiddle, vec2(directionTexel.x, 0))); // x相邻
            colors[2] = texture(SamplerIn, offsetUV(texMiddle, vec2(0, directionTexel.y))); // y相邻
            colors[3] = texture(SamplerIn, offsetUV(texMiddle, directionTexel)); // 对角

            // 统计自身颜色出现的次数
            int count = 1;
            for (int i = 1; i < 4; i++) {
                if (colors[0] == colors[i]) {
                    count++;
                }
            }

            // 先假定最终输出的颜色就是其自身的颜色
            vec4 finalColor = colors[0];

            // 如果自身颜色计数 > 1，则直接返回自身颜色
            if (count > 1) {
                return finalColor;
            } else {
                if (colors[1] == colors[2]) {
                    // 如果邻边的两个颜色相等，则返回其邻边颜色
                    float hDiffer = abs(rgb2hsv(colors[0].rgb).x - rgb2hsv(colors[1].rgb).x);
                    // 加点玄学的色相差距（可以把这个逻辑去掉看看潜影盒）
                    if (isAltas || colors[1].a == 0 || isHueClose(colors[0], colors[1])) {
                        finalColor = colors[1];
                    }
                } else if (colors[1] == colors[3] && colors[3].a != 0) {
                    // 如果一个邻边和对角颜色相等，则小范围地返回其对角颜色（但透明不行）
                    // 又是一个画圆的操作，所以要计算距离
                    if (distance(texelCoord, vec2(texelMiddle.x - directionMultiplier.x * 0.5, texelMiddle.y)) > 1.0) {
                        if (isAltas || isHueClose(colors[0], colors[3])) {
                            finalColor = colors[3];
                        }
                    }
                } else if (colors[2] == colors[3] && colors[3].a != 0) {
                    // 同上，只是换成y轴
                    if (distance(texelCoord, vec2(texelMiddle.x, texelMiddle.y - directionMultiplier.y * 0.5)) > 1.0) {
                        if (isAltas || isHueClose(colors[0], colors[3])) {
                            finalColor = colors[3];
                        }
                    }
                }
            }

            if (!allowAlpha && finalColor.a == 0) {
                finalColor = colors[0];
            }

            return finalColor;
        }
    }
}   