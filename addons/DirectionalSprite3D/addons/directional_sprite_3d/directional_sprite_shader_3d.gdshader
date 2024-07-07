shader_type spatial;
render_mode skip_vertex_transform, cull_disabled;

uniform vec4 front_region = vec4(0.0,0.0,1.0,1.0);
uniform vec4 left_region = vec4(0.0,0.0,1.0,1.0);
uniform vec4 right_region = vec4(0.0,0.0,1.0,1.0);
uniform vec4 back_region = vec4(0.0,0.0,1.0,1.0);

uniform sampler2D texture_albedo : source_color, repeat_enable, filter_linear_mipmap;

uniform vec4 albedo:source_color = vec4(1.0);
uniform float specular = 0.5;
uniform float metallic = 0.0;
uniform float roughness = 1.0;

uniform float alpha_scissor_threshold = 0.5;

uniform bool billboard_y = false;
uniform bool cardinal_sides = true;

varying flat int closest_side;

vec3 srgb(vec3 rgb){
	return mix(pow((rgb + vec3(0.055)) * (1.0 / (1.0 + 0.055)),vec3(2.4)),rgb.rgb * (1.0 / 12.92),lessThan(rgb.rgb,vec3(0.04045)));
}

vec2 pixel_filter_uv(vec2 uv, vec2 texture_size){
	vec2 pixel_size = (1.0 / texture_size);
	vec2 box_size = clamp(fwidth(uv) * texture_size, 1e-5, 1.0);
	vec2 texel = uv * texture_size - 0.5 * box_size;
	vec2 texel_offset = smoothstep(1.0 - box_size, vec2(1.0), fract(texel));
	
	return (floor(texel) + 0.5 + texel_offset) * pixel_size;
}

vec4 texture_pixel(sampler2D tex, vec2 uv){
	vec2 pixel_uv = pixel_filter_uv(uv, vec2(textureSize(tex, 0)));
	return textureGrad(tex, pixel_uv, dFdx(uv), dFdy(uv));
}

vec3[4] get_sides(mat4 matrix){

	mat3 rotY45;
	if (cardinal_sides) {
		rotY45 = mat3(vec3(1.0, 0.0, 0.0), vec3(0.0, 1.0, 0.0), vec3(0.0, 0.0, 1.0));
	} else {
		// front -> front_left
		// right -> front_right
		// left -> back_left
		// back -> back_right
		rotY45 = mat3(vec3(0.7071, 0.0, -0.7071), vec3(0.0, 1.0, 0.0), vec3(0.7071, 0.0, 0.7071));
	}
	
	vec3 front = (matrix * vec4(0,0,1,0)).xyz;
	vec3 up = (matrix * vec4(0,1,0,0)).xyz;
	vec3 right = normalize(cross(up, front));
	up = normalize(cross(front, right));
	front = normalize(cross(right, up));
	return {
		normalize(rotY45 * front),
		normalize(rotY45 * right),
		normalize(rotY45 * -front),
		normalize(rotY45 * -right)
	}; 
}

int get_closest_side(vec3[4] sides, vec3 direction) {
	float maxDot = -2.0;
	float nextMaxDot = -2.0;
	int sideIndex = 0;

	for (int i = 0; i < 4; i++) {
		vec3 sideNormal = sides[i];
		
		float dotProduct = dot(direction, sideNormal);
		
		if (dotProduct > maxDot) {
			maxDot = dotProduct;
			sideIndex = i;
		}
	}
	return sideIndex;
}

void vertex(){
	if (!OUTPUT_IS_SRGB) {
		COLOR.rgb = srgb(COLOR.rgb);
	}
	
	vec3 cameraDirectionView = normalize(INV_VIEW_MATRIX[2].xyz);
	vec3[4] sides = get_sides(MODEL_MATRIX);
	closest_side = get_closest_side(sides, cameraDirectionView);
	
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
	MODELVIEW_NORMAL_MATRIX = mat3(MODELVIEW_MATRIX);
	
	if (billboard_y) {
		MODELVIEW_MATRIX = VIEW_MATRIX * mat4(vec4(normalize(cross(vec3(0.0, 1.0, 0.0), INV_VIEW_MATRIX[2].xyz)), 0.0), vec4(0.0, 1.0, 0.0, 0.0), vec4(normalize(cross(INV_VIEW_MATRIX[0].xyz, vec3(0.0, 1.0, 0.0))), 0.0), MODEL_MATRIX[3]);
	} else {
		MODELVIEW_MATRIX = MODELVIEW_MATRIX * mat4(vec4(length(MODEL_MATRIX[0].xyz), 0.0, 0.0, 0.0),vec4(0.0, 1.0, 0.0, 0.0),vec4(0.0, 0.0, length(MODEL_MATRIX[2].xyz), 0.0), vec4(0.0, 0.0, 0.0, 1.0));	
	}
	
	VERTEX = (MODELVIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
    NORMAL = (MODELVIEW_MATRIX * vec4(NORMAL, 0.0)).xyz;
}

void fragment() {
	vec4 region = {front_region, right_region, back_region, left_region}[closest_side];
	vec2 half_pixel = 1.0 / vec2(textureSize(texture_albedo, 0)) * 0.5;
	vec2 uv = mix(region.xy + half_pixel, region.zw, UV);
	
	vec4 albedo_tex = texture_pixel(texture_albedo,uv);
	albedo_tex *= COLOR;
	ALBEDO *= albedo_tex.rgb * albedo.rgb;
	SPECULAR = specular;
	METALLIC = metallic;
	ROUGHNESS = roughness;
	
	ALPHA *= albedo_tex.a * albedo.a;
	ALPHA_SCISSOR_THRESHOLD = alpha_scissor_threshold;
}