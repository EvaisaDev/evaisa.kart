#version 110
#define PIXEL_ART_FILTER

uniform sampler2D tex;
uniform vec2 tex_size;


// generates a pixel art friendly texture coordinate ala https://csantosbh.wordpress.com/2014/01/25/manual-texture-filtering-for-pixelated-games-in-webgl/
// NOTE: texture filtering mode must be set to bilinear for this trick to work
vec4 pixel_art_filter_uv( vec2 uv, vec2 tex_size_pixels )
{
        uv *= tex_size_pixels;
        uv = floor(uv) + smoothstep(0.0, 1.0, fract(uv) / fwidth(uv)) - 0.5;
        uv /= tex_size_pixels;
        return uv;
}

void main()
{
#ifdef PIXEL_ART_FILTER
	vec2 o = vec2(1.0,1.0) / tex_size;
	vec4 uvs = pixel_art_filter_uv( gl_TexCoord[0].xy, tex_size );
	vec4 color_smoothed = texture2D( tex, uvs.xy );
	vec4 color_center = texture2D( tex, uvs.zw );

	vec4 color = color_smoothed;
	{
		// use pixel center color near edges, not the neighbour color
		vec4 color1 = texture2D( tex, uvs.zw - vec2(o.x,0.0) );
		vec4 color2 = texture2D( tex, uvs.zw + vec2(o.x,0.0) );
		vec4 color3 = texture2D( tex, uvs.zw - vec2(0.0,o.y) );
		vec4 color4 = texture2D( tex, uvs.zw + vec2(0.0,o.y) );

		vec4 c = color_center * step(0.1,color_center.a);
		float a = color1.a + color2.a + color3.a + color4.a;
		if ( color_center.a == 0.0  )
		{
			c +=
			(color1 * color1.a +
			color2 * color2.a +
			color3 * color3.a +
			color4 * color4.a) / a;
		}

		if ( color_smoothed.a < (1.0) )
		{
			color.rgb = c.rgb;
		}
	}
#else
	vec4 color = texture2D( tex, gl_TexCoord[0].xy );
#endif

	gl_FragColor = color * gl_Color;
}
