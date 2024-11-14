#version 130


uniform sampler2D map_tex;
uniform sampler2D oob_tex;
const float map_scale = 0.25;

uniform sampler2D parallax1_tex;
uniform sampler2D parallax2_tex;
uniform sampler2D parallax3_tex;

// -----------------------------
// 	   Misc
// -----------------------------


uniform vec4 cameraTransform;     // position in the world (x, y, z, rotation radians)
const float horizonOffset = 0.5;
in vec2 tex_coord_;
uniform vec2 window_size;

uniform sampler2D tex_fg;

const float SCROLL_FACTOR1 = 0.4;
const float SCROLL_FACTOR2 = 0.35;
const float SCROLL_FACTOR3 = 0.3;

// -----------------------------
// misc
// -----------------------------

const float PI = 3.1415926535897932384626433832795;

void main()
{
    // Update transforms to map scale
    vec4 scaledCameraTransform = cameraTransform;
    scaledCameraTransform.xy *= map_scale;
    

    // Rendering parallax background first
    float horizon = window_size.y - (window_size.y * horizonOffset);
    vec2 uv = tex_coord_;
    vec2 myCoord = uv;
    float cos_theta = cos(scaledCameraTransform.w);
    float sin_theta = sin(scaledCameraTransform.w);
    float epsilon = 0.0001;

    if (gl_FragCoord.y > horizon) {
        // Parallax rendering
        float rotation = scaledCameraTransform.w;
        uv.y = 1.0 - uv.y;
        uv.y /= (1.0 - horizon / window_size.y);

        vec2 texture_size1 = textureSize(parallax1_tex, 0);
        vec2 texture_size2 = textureSize(parallax2_tex, 0);
        vec2 texture_size3 = textureSize(parallax3_tex, 0);

        float screenAspect = window_size.x / window_size.y;

        vec2 tex3Aspect = vec2(texture_size3.x / texture_size3.y, 1.0);
        vec2 tex2Aspect = vec2(texture_size2.x / texture_size2.y, 1.0);
        vec2 tex1Aspect = vec2(texture_size1.x / texture_size1.y, 1.0);

        float aspectRatioCorrection3 = max(tex3Aspect.x / screenAspect, 1.0);
        float aspectRatioCorrection2 = max(tex2Aspect.x / screenAspect, 1.0);
        float aspectRatioCorrection1 = max(tex1Aspect.x / screenAspect, 1.0);

        vec2 tex3Uv = uv;
        tex3Uv.x -= (rotation * SCROLL_FACTOR3);
        tex3Uv *= vec2(1.0 / aspectRatioCorrection3, 1.0);

        vec2 tex2Uv = uv;
        tex2Uv.x -= (rotation * SCROLL_FACTOR2);
        tex2Uv *= vec2(1.0 / aspectRatioCorrection2, 1.0);

        vec2 tex1Uv = uv;
        tex1Uv.x -= (rotation * SCROLL_FACTOR1);
        tex1Uv *= vec2(1.0 / aspectRatioCorrection1, 1.0);

        vec4 parallax1 = texture2D(parallax1_tex, tex1Uv);
        vec4 parallax2 = texture2D(parallax2_tex, tex2Uv);
        vec4 parallax3 = texture2D(parallax3_tex, tex3Uv);

        vec4 final = mix(parallax3, parallax2, parallax2.a);
        final = mix(final, parallax1, parallax1.a);

        gl_FragColor = final;

    } else {
        // Rendering map next
        myCoord.x *= 256.0;
        myCoord.y *= 224.0;
        myCoord.x -= 128.0;

        vec2 rotatedCoord;
        rotatedCoord.x = myCoord.x * cos_theta - myCoord.y * sin_theta;
        rotatedCoord.y = myCoord.x * sin_theta + myCoord.y * cos_theta;

        float perspectiveFactor = (horizon - gl_FragCoord.y) / (cameraTransform.z + epsilon);
        rotatedCoord /= perspectiveFactor;

        vec2 map_size = textureSize(map_tex, 0) * map_scale;

        rotatedCoord.x += scaledCameraTransform.x;
        rotatedCoord.y += scaledCameraTransform.y;

        if (rotatedCoord.x >= 0.0 && rotatedCoord.x < map_size.x &&
            rotatedCoord.y >= 0.0 && rotatedCoord.y < map_size.y) {
            vec2 mapUV = rotatedCoord / map_size.x;
            mapUV.y = 1.0 - mapUV.y;
            gl_FragColor = texture2D(map_tex, mapUV);
        } else {
            vec2 tiledCoord = mod(rotatedCoord, 4.0);
            tiledCoord = abs(tiledCoord);
            vec2 oobUV = tiledCoord / 4.0;
            gl_FragColor = texture2D(oob_tex, oobUV);
        }
    }

	vec4 color_fg = texture2D(tex_fg, tex_coord_);

	// overlay fg on color
	gl_FragColor = mix(gl_FragColor, color_fg, color_fg.a);

}