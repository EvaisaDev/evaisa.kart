#version 110
#define PIXEL_ART_FILTER

uniform sampler2D tex;  // sprite
uniform sampler2D tex2; // sprite reference pose uvs
uniform sampler2D tex3; // reference pose stains

uniform vec4 data;
uniform vec2 tex_size;


#ifdef PIXEL_ART_FILTER
	// generates a pixel art friendly texture coordinate ala https://csantosbh.wordpress.com/2014/01/25/manual-texture-filtering-for-pixelated-games-in-webgl/
	// NOTE: texture filtering mode must be set to bilinear for this trick to work
	vec2 pixel_art_filter_uv( vec2 uv, vec2 tex_size_pixels )
	{
        uv *= tex_size_pixels;
        uv = floor(uv) + smoothstep(0.0, 1.0, fract(uv) / fwidth(uv)) - 0.5;
        uv /= tex_size_pixels;
        return uv;
	}
#else
	vec2 pixel_art_filter_uv( vec2 uv, vec2 tex_size_pixels )
	{
		return uv;
	}
#endif
	

void main()
{
	vec2 sprite_uv = pixel_art_filter_uv( gl_TexCoord[0].xy, tex_size );
	vec4 stain_uv  = texture2D( tex2, sprite_uv );

	vec2 stain_uv_orig = stain_uv.xy;

	stain_uv.xy *= data.xy; // atlas scale;
	stain_uv.xy += data.zw; // atlas offset;

	vec4 color = texture2D( tex,  sprite_uv );
	vec4 stain = texture2D( tex3, stain_uv.xy );

	vec4 out_color = vec4( mix( color.rgb, stain.rgb, min( stain.a * 1.5, 1.0 ) ), color.a );

	out_color *= gl_Color;

	// ---
	gl_FragColor = out_color;
}