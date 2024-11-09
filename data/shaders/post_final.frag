#version 130


uniform sampler2D map_tex;
uniform sampler2D oob_tex;
const float map_scale = 0.25;

uniform sampler2D parallax1_tex;
uniform sampler2D parallax2_tex;
uniform sampler2D parallax3_tex;

/*
// -----------------------------
//       Players
// -----------------------------


uniform sampler2D player1_tex;      // player1 spritesheet
uniform vec4 player1TexCoords;      // player1 texture coordinates (x, y, width, height)
uniform vec4 player1Transform;            // player1 position in the world (x, y, z, rotation radians)
uniform vec4 player1Data;

uniform sampler2D player2_tex;      // player2 spritesheet
uniform vec4 player2TexCoords;      // player2 texture coordinates (x, y, width, height)
uniform vec4 player2Transform;            // player2 position in the world (x, y, z, rotation radians)
uniform vec4 player2Active; 

uniform sampler2D player3_tex;      // player3 spritesheet
uniform vec4 player3TexCoords;      // player3 texture coordinates (x, y, width, height)
uniform vec4 player3Transform;            // player3 position in the world (x, y, z, rotation radians)
uniform vec4 player3Active;

uniform sampler2D player4_tex;      // player4 spritesheet
uniform vec4 player4TexCoords;      // player4 texture coordinates (x, y, width, height)
uniform vec4 player4Transform;            // player4 position in the world (x, y, z, rotation radians)
uniform vec4 player4Active;
*/

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
//       Pixelation Control
// -----------------------------

vec2 applyPixelation(vec2 coord, vec2 res) {
    vec2 pixel_size = vec2(1.0) / res;
    return floor(coord / pixel_size) * pixel_size;
}

// -----------------------------
//       Debugging
// -----------------------------
float pow10(int exp) {
    exp = min(exp, 16);
    float result = 1;
    for (int i = 0; i < exp; ++i) {
            result *= 10;
    }
    return result;
}

float pow10neg(int exp) {
    exp = max(exp, -16);
    float result = 1;
    for (int i = 0; i < -exp; ++i) {
            result /= 10;
    }
    return result;
}

// Draws numbers on the screen for displaying the values of floats
void debugDrawFloatButBetter(ivec2 pos, float value, float size, vec4 color){
    const int[14] n = int[14](0x7b6f,0x7493,0x73E7,0x79e7,0x49ED,0x79CF,0x7bcf,0x24A7,0x7bef,0x49ef,0x2000,0x1c0,0x0,0x63EA);
    vec2 rpos = vec2(gl_FragCoord.x, window_size.y - gl_FragCoord.y) - pos;
    rpos = vec2(rpos / size);
    if(rpos.x < 0 || rpos.y < 0 || rpos.y >= 5 || int(rpos.x) % 4 == 3) return;
    float absvalue = abs(value);
    int floatingPointOffset = int(log(absvalue)/log(10.0));
    int integerDigits = max(0, floatingPointOffset);
    int xoffset = int(rpos.x / 4) - 1;
    if(11 - xoffset < 0) return;
    int digitOffset = xoffset - integerDigits - 1;
    int digit = 10;

    if(digitOffset > 0){
        digit = int(absvalue * pow10(digitOffset)) % 10;
    } else if(digitOffset < 0) {
        digit = int(absvalue * pow10neg(digitOffset+1)) % 10;
    }
    if(xoffset == -1){
        if(value < 0){
            digit = 11;
        } else {
            digit = 12;
        }
    }
    if(xoffset > 8){
        digit = 12;
    }
    int i = int(rpos.x) % 4 + int(rpos.y) * 3;
    if(((n[digit] >> i) & 1) == 1){
        gl_FragColor.rgb = mix(gl_FragColor.rgb, color.rgb, color.a);
    }
}
// -----------------------------
// misc
// -----------------------------

const float PI = 3.1415926535897932384626433832795;

// Function to convert a world position (X Y Z) to screen UV coordinated
// `worldPos` is the position in world space, and `cameraTransform` represents the camera's position and orientation.
vec3 worldToScreenUV(vec2 worldPos, vec4 cameraTransform) {

    // Compute sine and cosine of the camera's rotation angle (cameraTransform.w)
    float cos_theta = cos(cameraTransform.w);
    float sin_theta = sin(cameraTransform.w);

    // Small value to avoid division by zero
    float epsilon = 0.0001;

    // Calculate the horizon position and offset in screen space
    float horizon = window_size.y - (window_size.y * horizonOffset);
    
    // The camera height plus epsilon to avoid precision issues
    float C = cameraTransform.z + epsilon;
    float windowHeight = window_size.y;

    // Compute the difference between the world position and the camera position
    float dx = worldPos.x - cameraTransform.x;
    float dy = worldPos.y - cameraTransform.y;

    // A and B are factors used for perspective projection
    float A = horizon * 224.0;
    float B = C * 224 + (-sin_theta * dx + cos_theta * dy) * windowHeight;


    // Check if B is too small (to avoid division by zero); if so, return default UV coordinates (0, 0)
    if (abs(B) < 1e-6) {
        return vec3(0.0, 0.0, 0.0);
    }

    // Compute perspective factor P
    float P = A / B;

    // Compute texture coordinates based on the perspective factor and camera position
    float tex_coord_y = (horizon - P * C) / windowHeight;
    float tex_coord_x = (128.0 + P * (cos_theta * dx + sin_theta * dy)) / 256.0;

    // Return the calculated UV coordinates
    return vec3(tex_coord_x, tex_coord_y, P);
}


// Function to draw billboard sprites in the world
// `cameraTransform` is the position and orientation of the camera
// `spriteSheet` is the texture atlas of sprites
// `spriteSize` defines the dimensions of a single sprite
// `spriteCount` is the number of sprites for half a rotation (front and back)
// `sideSpriteIndex` is the index of the side-facing sprite
// `spriteGap` is the gap between sprites in the texture
// `worldTransform` represents the sprite's world position and orientation
// `transparentColor` is the color to be treated as transparent
// `spriteScale` controls the scale of the sprite
void drawDirectionalSprite(
    vec4 cameraTransform,
    sampler2D spriteSheet,
    vec2 spriteSize,
    int spriteCount,
    int sideSpriteIndex,
    int spriteGap,
    vec4 worldTransform,
    vec3 transparentColor,
    float spriteScale
) {

    // Transform UV coordinates to match texture space
    vec2 uv = tex_coord_;
    uv.y = 1.0 - uv.y;  // Flip Y coordinate for correct orientation

    // Get the texture's total dimensions
    vec2 spriteDimensions = textureSize(spriteSheet, 0).xy;
	
    // Compute fragment coordinate in texture space
    vec2 fragCoord = uv * spriteDimensions;

    // Convert the world position to screen space
    vec3 screenPos = worldToScreenUV(worldTransform.xy, cameraTransform);
    screenPos.y = 1.0 - screenPos.y;  // Flip Y for screen-space representation
    screenPos.xy = screenPos.xy * spriteDimensions.xy;  // Scale to screen dimensions

    // Calculate camera's forward vector
    vec2 cameraForward = vec2(cos(cameraTransform.w), sin(cameraTransform.w));
    cameraForward = vec2(-cameraForward.y, cameraForward.x);  // Rotate 90 degrees

    // Compute actual camera position offset by height, so it behaves like it is on the ground
    vec2 actualCameraPos = cameraTransform.xy - (cameraForward.xy * cameraTransform.z);

	// Compute the Euclidean distance between the sprite and the camera
	float distance = length(worldTransform.xy - actualCameraPos.xy);

	// Avoid division by zero by clamping the distance to a minimum value
	distance = max(distance, 0.0001);

	// Calculate the scaling factor based on the distance / perspective
	float P = screenPos.z;

	// Calculate the draw scale based on the distance and sprite scale
	vec2 drawScale = vec2(P, P) * spriteScale;

	drawScale.y /= 6.0;  // Adjust the Y scale to match the sprite's aspect ratio

	// update height based on worldPos.z and P
	screenPos.y -= worldTransform.z * P;

    // Calculate the direction vector from the camera to the sprite
    vec2 toSprite = normalize(worldTransform.xy - actualCameraPos.xy);
    
    // Compute the dot product to determine if the sprite is in front of the camera
    float dotProduct = dot(toSprite, cameraForward);
    if (dotProduct <= 0.0) {
        return;  // Skip rendering if behind the camera
    }


    // Calculate the relative angle from the camera to the sprite
    vec2 toCamera = actualCameraPos.xy - worldTransform.xy;
    vec2 relativeToCameraForward = toCamera.xy - cameraForward.xy;
    float toCameraAngle = atan(relativeToCameraForward.y, relativeToCameraForward.x);
    float spriteRotation = worldTransform.w;

    // Calculate the relative angle between the camera's forward vector and the sprite's orientation
    float relativeAngle = toCameraAngle - spriteRotation;
    relativeAngle = mod(relativeAngle, 2.0 * PI);  // Normalize the angle

    // Determine if the sprite should be mirrored
    bool mirror = false;
    if (relativeAngle > PI) {
        mirror = true;
        relativeAngle = 2.0 * PI - relativeAngle;
    }

    // Compute the index of the sprite to use based on the relative angle
    float anglePerSpriteBackwards = (PI / 2) / float(sideSpriteIndex);
    float anglePerSpriteForwards = (PI / 2) / float(spriteCount - sideSpriteIndex);
    int spriteIndex = int(floor(relativeAngle / anglePerSpriteBackwards)) % spriteCount;
    if (relativeAngle > PI / 2) {
        spriteIndex = int(floor((relativeAngle - PI / 2) / anglePerSpriteForwards)) % spriteCount;
        spriteIndex += sideSpriteIndex;
    }

    // Calculate texture coordinates for the sprite
    vec2 spriteTexCoord;
    spriteTexCoord.x = (spriteSize.x + float(spriteGap)) * float(spriteIndex);
    spriteTexCoord.y = 0.0;

    // Check if the fragment coordinate is within the bounds of the sprite
    vec2 spritePos = screenPos.xy;
	spritePos.x -= (spriteSize.x / 2) * drawScale.x;
    spritePos.y -= (spriteSize.y) * drawScale.y;

	vec2 sprite3DScale = vec2(2.0, 4.0);

	// calculate the Y offset based on relative angle and 3D scale
	float yOffset = (relativeAngle - PI / 2) / (PI / 2);
	// abs
	yOffset = abs(yOffset);

	float offset = mix(sprite3DScale.x, sprite3DScale.y, yOffset);

	// offset needs to get smaller with distance
	// use perspective factor
	

	spritePos.y += 1 * (drawScale.y);


	if (fragCoord.x < (spriteSize.x * drawScale.x) + spritePos.x &&
        fragCoord.y < (spriteSize.y * drawScale.y) + spritePos.y &&
        fragCoord.x > spritePos.x && fragCoord.y > spritePos.y) {

        // Calculate the texture coordinates for the sprite's fragment
        vec2 textureSize = textureSize(spriteSheet, 0).xy;
        vec2 spriteUV = (fragCoord - spritePos) / (spriteSize * drawScale);

        // Mirror the texture if necessary
        if (mirror) {
            spriteUV.x = 1.0 - spriteUV.x;
        }

        // Compute the final texture position
        vec2 spriteTexPos = (spriteTexCoord.xy + spriteUV * spriteSize) / textureSize;

        // Fetch the texture color and discard if it matches the transparent color
        vec4 color = texture2D(spriteSheet, spriteTexPos);
        if (color.rgb != transparentColor) {
            gl_FragColor = color;  // Set the final fragment color
        }
    }
}







void main()
{
    // Update transforms to map scale
    vec4 scaledCameraTransform = cameraTransform;
    scaledCameraTransform.xy *= map_scale;
    

    // Rendering parallax background first
    float horizon = window_size.y - (window_size.y * horizonOffset);
    vec2 uv = tex_coord_;
    vec2 myCoord = applyPixelation(uv, window_size / 2);
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

	/*
    // Array to store player transforms and distances
    vec4 playerTransforms[4];
    float playerDistances[4];
    bool playerActive[4];
    int playerIndices[4];  // Declare without initialization

    // Assign values to playerIndices manually
    playerIndices[0] = 0;
    playerIndices[1] = 1;
    playerIndices[2] = 2;
    playerIndices[3] = 3;

    // Calculate distances from the camera for each active player
    if (player1Active.x > 0) {
        playerTransforms[0] = player1Transform;
        playerTransforms[0].xy *= map_scale;
        playerDistances[0] = length(playerTransforms[0].xy - scaledCameraTransform.xy);
        playerActive[0] = true;
    } else {
        playerDistances[0] = -1.0;  // Inactive
        playerActive[0] = false;
    }

    if (player2Active.x > 0) {
        playerTransforms[1] = player2Transform;
        playerTransforms[1].xy *= map_scale;
        playerDistances[1] = length(playerTransforms[1].xy - scaledCameraTransform.xy);
        playerActive[1] = true;
    } else {
        playerDistances[1] = -1.0;
        playerActive[1] = false;
    }

    if (player3Active.x > 0) {
        playerTransforms[2] = player3Transform;
        playerTransforms[2].xy *= map_scale;
        playerDistances[2] = length(playerTransforms[2].xy - scaledCameraTransform.xy);
        playerActive[2] = true;
    } else {
        playerDistances[2] = -1.0;
        playerActive[2] = false;
    }

    if (player4Active.x > 0) {
        playerTransforms[3] = player4Transform;
        playerTransforms[3].xy *= map_scale;
        playerDistances[3] = length(playerTransforms[3].xy - scaledCameraTransform.xy);
        playerActive[3] = true;
    } else {
        playerDistances[3] = -1.0;
        playerActive[3] = false;
    }

    // Sort the players by distance using their indices
    for (int i = 0; i < 4; ++i) {
        for (int j = i + 1; j < 4; ++j) {
            if (playerDistances[i] < playerDistances[j]) {
                // Swap distances
                float tempDist = playerDistances[i];
                playerDistances[i] = playerDistances[j];
                playerDistances[j] = tempDist;

                // Swap indices
                int tempIndex = playerIndices[i];
                playerIndices[i] = playerIndices[j];
                playerIndices[j] = tempIndex;
            }
        }
    }

    // Now draw the players in the sorted order using the indices
    float playerScale = 0.1;

    for (int i = 0; i < 4; ++i) {
        int playerIndex = playerIndices[i];  // Get the sorted player index
        if (playerActive[playerIndex]) {
            if (playerIndex == 0) {
                drawDirectionalSprite(
                    scaledCameraTransform,
                    player1_tex,  // Texture remains assigned to player 1
                    player1TexCoords.zw,
                    12, 8, 1,
                    playerTransforms[0],  // Use correct transform based on sorted distance
                    vec3(26.0 / 255.0, 132.0 / 255.0, 57.0 / 255.0),
                    playerScale
                );
            } else if (playerIndex == 1) {
                drawDirectionalSprite(
                    scaledCameraTransform,
                    player2_tex,  // Texture remains assigned to player 2
                    player2TexCoords.zw,
                    12, 8, 1,
                    playerTransforms[1],
                    vec3(26.0 / 255.0, 132.0 / 255.0, 57.0 / 255.0),
                    playerScale
                );
            } else if (playerIndex == 2) {
                drawDirectionalSprite(
                    scaledCameraTransform,
                    player3_tex,  // Texture remains assigned to player 3
                    player3TexCoords.zw,
                    12, 8, 1,
                    playerTransforms[2],
                    vec3(26.0 / 255.0, 132.0 / 255.0, 57.0 / 255.0),
                    playerScale
                );
            } else if (playerIndex == 3) {
                drawDirectionalSprite(
                    scaledCameraTransform,
                    player4_tex,  // Texture remains assigned to player 4
                    player4TexCoords.zw,
                    12, 8, 1,
                    playerTransforms[3],
                    vec3(26.0 / 255.0, 132.0 / 255.0, 57.0 / 255.0),
                    playerScale
                );
            }
        }
    }*/

	vec4 color_fg = texture2D(tex_fg, tex_coord_);

	// overlay fg on color
	gl_FragColor = mix(gl_FragColor, color_fg, color_fg.a);

}