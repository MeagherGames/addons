shader_type canvas_item;

const vec4 yellow = vec4(1.0,1.0,0.0,1.0);
const vec4 magenta = vec4(1.0,0.0,1.0,1.0);
const vec4 cyan = vec4(0.0,1.0,1.0,1.0);
const vec4 black = vec4(0.0,0.0,0.0,1.0);

uniform sampler2D screen_texture: hint_screen_texture, repeat_disable, filter_linear;
uniform int dot_size = 1;
uniform float interlace_width = 1;
uniform float curviture = 3.0;
uniform float dot_blend = 0.1;
uniform float interlace_blend = 0.1;

ivec2 fetch(vec2 uv) {
	ivec2 screen_size = textureSize(screen_texture,0);
	return ivec2(int(uv.x * float(screen_size.x)), int(uv.y * float(screen_size.y)));
}

vec2 warp(vec2 uv,float curv){
	vec2 nuv = uv * 2.0 - vec2(1.0,1.0);
	vec2 offset = 1.0 / curv * nuv;
	nuv = nuv + (nuv * (offset * offset)) - offset;
	nuv = nuv * 0.5 + 0.5;
	return nuv;
}

vec2 vingette(vec2 uv,float width,vec2 size){
	vec2 nuv = uv * 2.0 - vec2(1.0);
	vec2 interp = vec2(width) / size;
	vec2 inv_nuv = vec2(1.0) - abs(nuv);
	return smoothstep(vec2(0.0),interp,inv_nuv);
}

void fragment() {
	
	ivec2 coord = fetch(UV);
	vec2 WUV = warp(UV,curviture);
	vec4 pixel;
	vec4 color;
	
	vec2 vin = vingette(UV,curviture + 32.0,vec2(textureSize(screen_texture,0)));
	vec4 tex = texture(screen_texture,WUV);
	pixel.rgb = tex.rgb * (vin.x * vin.y) * length(vin);
	pixel.a = 1.0;
	
	int point = (int(coord.x) / (dot_size + 1)) % 3;
	switch (point){
		case 0:
			color = mix(pixel,yellow * pixel,dot_blend);
			break;
	 	case 1:
			color = mix(pixel,magenta * pixel,dot_blend);
			break;
		case 2:
			color = mix(pixel,cyan * pixel,dot_blend);
			break;
	}
	float value = sin(float(coord.y) / interlace_width);
	color.rgb =  mix(color.rgb,color.rgb * vec3(1.0 - min(0.5,max(0,value))),interlace_blend);
	COLOR = color;
}
