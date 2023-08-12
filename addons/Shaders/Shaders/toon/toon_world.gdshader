shader_type spatial;

#include "pixel_filtering.gdshaderinc"

group_uniforms Albedo;
uniform sampler2D albedo_texture: source_color;
uniform ivec2 columns = ivec2(1,1);
instance uniform int frame = 0;

uniform vec3 albedo: source_color = vec3(1.0);
uniform sampler2D detail_texture: source_color, hint_default_transparent;

uniform bool vertex_color_on_detail = false;

group_uniforms Roughness;
uniform float roughness: hint_range(0.0, 1.0) = 1.0;
uniform sampler2D roughness_texture: hint_default_white;

group_uniforms Metallic;
uniform float metallic: hint_range(0.0, 1.0) = 0.0;
uniform sampler2D metallic_texture: hint_default_white;

group_uniforms Light;
uniform vec3 emission: source_color = vec3(0.0);
uniform float emission_multiplier: hint_range(0.0, 16.0) = 1.0;
uniform sampler2D emission_texture: source_color, hint_default_black;

#include "toon_lighting.gdshaderinc"

group_uniforms UV;
uniform vec3 uv_scale = vec3(1.0);
uniform vec3 uv_offset = vec3(0.0);
uniform float uv_blend_sharpness = 1.0;
varying vec3 uv_triplanar_pos;
varying vec3 uv_power_normal;

vec4 triplanar_texture(sampler2D p_sampler,vec3 p_weights,vec3 p_triplanar_pos, vec2 uv_mult) {
	vec4 samp=vec4(0.0);
	samp+= texture_pixel(p_sampler,p_triplanar_pos.xy * uv_mult) * p_weights.z;
	samp+= texture_pixel(p_sampler,p_triplanar_pos.xz * uv_mult) * p_weights.y;
	samp+= texture_pixel(p_sampler,p_triplanar_pos.zy * uv_mult * vec2(-1.0,1.0)) * p_weights.x;
	return samp;
}

void vertex(){
	uv_power_normal=pow(abs(mat3(MODEL_MATRIX) * NORMAL),vec3(uv_blend_sharpness));
	uv_triplanar_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0f)).xyz * uv_scale + uv_offset;
	uv_power_normal /= dot(uv_power_normal,vec3(1.0));
	uv_triplanar_pos *= vec3(1.0,-1.0, 1.0);
}

void fragment() {
	
	vec2 frameSize = vec2(1.0 / float(columns.x), 1.0 / float(columns.y));
	vec2 currentFrame = vec2(float(frame % columns.x), float(frame / columns.x));
	
	vec4 albedo_tex = triplanar_texture(albedo_texture, uv_power_normal, uv_triplanar_pos, frameSize + currentFrame * frameSize);
	vec4 detail_tex = triplanar_texture(detail_texture, uv_power_normal, uv_triplanar_pos, vec2(1.0));
	ALBEDO = albedo * albedo_tex.rgb * COLOR.rgb;
	if (vertex_color_on_detail){
		detail_tex.rgb *= COLOR.rgb;
	}
	ALBEDO = mix(ALBEDO, detail_tex.rgb, detail_tex.a);
	
	vec4 roughness_tex = triplanar_texture(roughness_texture,  uv_power_normal, uv_triplanar_pos, vec2(1.0));
	ROUGHNESS = roughness_tex.r * roughness;
	
	vec4 metallic_tex = triplanar_texture(metallic_texture,  uv_power_normal, uv_triplanar_pos, vec2(1.0));
	METALLIC = metallic_tex.r * metallic;
	
	vec4 emission_tex = triplanar_texture(emission_texture,  uv_power_normal, uv_triplanar_pos, vec2(1.0));
	EMISSION = (emission_tex.rgb + emission) * emission_multiplier;
	
	SPECULAR = specular;
}