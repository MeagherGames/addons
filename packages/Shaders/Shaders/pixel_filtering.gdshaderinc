vec2 pixel_filter_uv(vec2 uv, vec2 texture_size){
	vec2 pixel_size = 1.0 / texture_size;
	vec2 box_size = clamp(fwidth(uv) * texture_size, 1e-5, 1.0);
	vec2 texel = uv * texture_size - 0.5 * box_size;
	vec2 texel_offset = smoothstep(1.0 - box_size, vec2(1.0), fract(texel));
	
	vec2 new_uv = (floor(texel) + 0.5 + texel_offset) * pixel_size;
	
	return new_uv;
}

vec4 texture_pixel(sampler2D tex, vec2 uv){
	vec2 pixel_uv = pixel_filter_uv(uv, vec2(textureSize(tex, 0)));
	return textureGrad(tex, pixel_uv, dFdx(uv), dFdy(uv));
}