shader_type canvas_item;

uniform sampler2D screen_texture:hint_screen_texture;
uniform sampler2D dither_texture:hint_default_black, filter_nearest, repeat_enable; // https://seansleblanc.itch.io/ordered-dither-maker
uniform int color_depth : hint_range(1, 8) = 5;
uniform int resolution_scale = 4;
uniform float strength = 2.0;

void fragment() {
	ivec2 uv = ivec2(FRAGCOORD.xy / float(resolution_scale));
	vec2 dither_uv = vec2(uv) / vec2(textureSize(dither_texture, 0));
	
	vec3 color = texelFetch(screen_texture, uv * resolution_scale, 0).rgb;
	ivec3 c = ivec3(round(color * 255.0));
	c += ivec3( texture(dither_texture, dither_uv).rgb * strength);
	c >>= (8 - color_depth);
	color = vec3(c) / float(1 << color_depth);
	
	COLOR.rgb = color;
}