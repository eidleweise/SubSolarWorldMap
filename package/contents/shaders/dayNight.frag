#version 440

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(binding = 1) uniform sampler2D dayTexture;
layout(binding = 2) uniform sampler2D nightTexture;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float subsolarLatitude;
    float subsolarLongitude;
};

const float PI = 3.14159265358979323846;
const float TWILIGHT_HALF_WIDTH = 0.035;

void main()
{
    float latitude = (0.5 - qt_TexCoord0.y) * PI;
    float longitude = (qt_TexCoord0.x - 0.5) * 2.0 * PI;
    float solarLatitude = radians(subsolarLatitude);
    float solarLongitude = radians(subsolarLongitude);

    float sunAltitudeCosine = sin(latitude) * sin(solarLatitude)
            + cos(latitude) * cos(solarLatitude)
            * cos(longitude - solarLongitude);
    float daylight = smoothstep(-TWILIGHT_HALF_WIDTH, TWILIGHT_HALF_WIDTH,
                                 sunAltitudeCosine);

    vec4 dayColor = texture(dayTexture, qt_TexCoord0);
    vec4 nightColor = texture(nightTexture, qt_TexCoord0);
    fragColor = mix(nightColor, dayColor, daylight) * qt_Opacity;
}
