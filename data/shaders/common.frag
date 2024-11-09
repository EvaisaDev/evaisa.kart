// generates a pixel art friendly texture coordinate ala https://csantosbh.wordpress.com/2014/01/25/manual-texture-filtering-for-pixelated-games-in-webgl/
// NOTE: texture filtering mode must be set to bilinear for this trick to work
vec2 pixel_art_filter_uv( vec2 uv, vec2 tex_size_pixels )
{
        uv *= tex_size_pixels;
        uv = floor(uv) + smoothstep(0.0, 1.0, fract(uv) / fwidth(uv)) - 0.5;
        uv /= tex_size_pixels;
        return uv;
}
