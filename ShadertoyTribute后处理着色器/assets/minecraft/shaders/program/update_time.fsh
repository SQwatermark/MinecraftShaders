#version 150

uniform sampler2D DiffuseSampler;
uniform float Time;

out vec4 fragColor;

in vec2 texCoord;

void main() {
    vec3 t = texture(DiffuseSampler, texCoord).rgb;
    // 减去0.1是防止暂停游戏时出现的可能和浮点数相关的玄学问题
    // 为什么有四个通道却只存储三个值，我也想知道为什么alpha通道一用就会在初始帧出问题
    // 理论运行时间是18.2小时，再多个通道也用不上吧。
    if (t.z - 0.1 > Time) {
        if (t.x == 1.0) {
            t.x = 0.0;
            if (t.y == 1.0) {
                t.y = 0.0;
            } else {
                t.y += 1.0 / 255.0;
            }
        } else {
            t.x += 1.0 / 255.0;
        }
    }
    t.z = Time;
    fragColor = vec4(t.xyz, 1.0);
}