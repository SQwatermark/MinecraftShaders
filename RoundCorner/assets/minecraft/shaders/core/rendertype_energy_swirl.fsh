#version 150

#moj_import <fog.glsl>
#moj_import <round_corner.glsl>

uniform sampler2D Sampler0;

uniform vec4 ColorModulator;
uniform float FogStart;
uniform float FogEnd;

in float vertexDistance;
in vec4 vertexColor;
in vec2 texCoord0;

out vec4 fragColor;

void main() {
    vec4 color = getRoundCorner(Sampler0, texCoord0, vertexDistance, 0) * vertexColor * ColorModulator;
    if (color.a < 0.1) {
        discard;
    }
    fragColor = color * linear_fog_fade(vertexDistance, FogStart, FogEnd);
}
