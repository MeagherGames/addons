shader_type spatial;

#include "pixel_filtering.gdshaderinc"

group_uniforms Albedo;
uniform sampler2D albedo_texture: source_color;
uniform ivec2 columns = ivec2(1,1);
instance uniform int frame = 0;

uniform vec3 albedo: source_color = vec3(1.0);

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

void fragment() {
	vec2 uv = UV;
	
	vec2 frameSize = vec2(1.0 / float(columns.x), 1.0 / float(columns.y));
	vec2 currentFrame = vec2(float(frame % columns.x), float(frame / columns.x));
	
	vec4 albedo_tex = texture_pixel(albedo_texture, uv * frameSize + currentFrame * frameSize);
	ALBEDO = albedo * albedo_tex.rgb * COLOR.rgb;
	
	vec4 roughness_tex = texture_pixel(roughness_texture, uv);
	ROUGHNESS = roughness_tex.r * roughness;
	
	vec4 metallic_tex = texture_pixel(metallic_texture, uv);
	METALLIC = metallic_tex.r * metallic;
	
	vec4 emission_tex = texture_pixel(emission_texture, uv);
	EMISSION = (emission_tex.rgb + emission) * emission_multiplier;
	
	SPECULAR = specular;
}
