shader_type spatial;
render_mode skip_vertex_transform;

const int DIR_RIGHT = 1;
const int DIR_LEFT = 2;
const int DIR_TOP = 3;
const int DIR_BOTTOM = 4;
const int DIR_FRONT = 5;
const int DIR_BACK = 6;

// #define SHADED
// #define DOUBLE_SIDED
// #define NO_DEPTH_TEST
// #defined FIXED_SIZE

// #define TRANSPARENCY
// #define TRANSPARENCY_DISCARD
// #define TRANSPARENCY_OPAQUE_PREPASS

// #define FILTER_NEAREST_MIPMAP_ANISOTROPIC
// #define FILTER_LINEAR_MIPMAP_ANISOTROPIC
// #define FILTER_NEAREST_MIPMAP
// #define FILTER_LINEAR_MIPMAP
// #define FILTER_NEAREST
// #define FILTER_LINEAR

// This will be replaced by the shader generator
#define __DEFINITIONS__

#ifdef __DEFINITIONS__
// We haven't replaced the definitions yet, so act as if all sides are present
#define HAS_RIGHT 1
#define HAS_LEFT 1
#define HAS_TOP 1
#define HAS_BOTTOM 1
#define HAS_FRONT 1
#define HAS_BACK 1
#define SIDE_COUNT 6
#endif

#ifndef SIDE_COUNT
#define SIDE_COUNT 0
#endif

#ifndef HAS_RIGHT
#define HAS_RIGHT 0
#endif
#ifndef HAS_LEFT
#define HAS_LEFT 0
#endif
#ifndef HAS_TOP
#define HAS_TOP 0
#endif
#ifndef HAS_BOTTOM
#define HAS_BOTTOM 0
#endif
#ifndef HAS_FRONT
#define HAS_FRONT 0
#endif
#ifndef HAS_BACK
#define HAS_BACK 0
#endif

#ifndef SHADED
render_mode unshaded;
#endif
#ifdef TRANSPARENCY_OPAQUE_PREPASS
render_mode depth_draw_opaque;
#endif
#ifdef DOUBLE_SIDED
render_mode cull_disabled;
#endif
#ifdef NO_DEPTH_TEST
render_mode depth_test_disabled;
#endif

uniform sampler2D texture_albedo : source_color, repeat_enable
#if defined(FILTER_NEAREST_MIPMAP_ANISOTROPIC)
,filter_nearest_mipmap_anisotropic
#elif defined(FILTER_LINEAR_MIPMAP_ANISOTROPIC)
,filter_linear_mipmap_anisotropic
#elif defined(FILTER_NEAREST_MIPMAP)
,filter_nearest_mipmap
#elif defined(FILTER_LINEAR_MIPMAP)
,filter_linear_mipmap
#elif defined(FILTER_NEAREST)
,filter_nearest
#else
,filter_linear
#endif
;

uniform vec2 uv_offset = vec2(0.0);
uniform vec2 uv_scale = vec2(1.0);
uniform vec2 size = vec2(1.0);

#if HAS_RIGHT
uniform vec2 right_offset;
uniform vec2 right_scale = vec2(1.0);
#endif
#if HAS_LEFT
uniform vec2 left_offset;
uniform vec2 left_scale = vec2(1.0);
#endif
#if HAS_TOP
uniform vec2 top_offset;
uniform vec2 top_scale = vec2(1.0);
#endif
#if HAS_BOTTOM
uniform vec2 bottom_offset;
uniform vec2 bottom_scale = vec2(1.0);
#endif
#if HAS_FRONT
uniform vec2 front_offset;
uniform vec2 front_scale = vec2(1.0);
#endif
#if HAS_BACK
uniform vec2 back_offset;
uniform vec2 back_scale = vec2(1.0);
#endif

varying flat vec2 offset;
varying flat int cube_side;

vec3 srgb(vec3 rgb){
	return mix(pow((rgb + vec3(0.055)) * (1.0 / (1.0 + 0.055)),vec3(2.4)),rgb.rgb * (1.0 / 12.92),lessThan(rgb.rgb,vec3(0.04045)));
}

vec2 offset_uv(vec2 uv){
	vec2 scale = {
		#if HAS_RIGHT
		right_scale
		#endif
		
		#if HAS_LEFT 
		#if HAS_RIGHT
		,
		#endif
		left_scale
		#endif
		
		#if HAS_TOP
		#if HAS_LEFT || HAS_RIGHT
		,
		#endif
		top_scale
		#endif
		
		#if HAS_BOTTOM 
		#if HAS_TOP || HAS_LEFT || HAS_RIGHT
		,
		#endif 
		bottom_scale
		#endif
		
		#if HAS_FRONT
		#if HAS_BOTTOM || HAS_TOP || HAS_LEFT || HAS_RIGHT
		,
		#endif
		front_scale
		#endif
		
		#if HAS_BACK
		#if HAS_FRONT || HAS_BOTTOM || HAS_TOP || HAS_LEFT || HAS_RIGHT
		,
		#endif
		back_scale
		#endif
	}[cube_side];
	return mod(uv * scale, size) + offset;
}


struct Cube {
	mat4 transform;
	vec3 sides[SIDE_COUNT];
	int directions[SIDE_COUNT];
};

struct CubeSideInfo {
	int side;
	int next;
	float delta;
	vec2 offset;
	int direction;
};

Cube create_cube(mat4 matrix){
	Cube c;
	vec3 front = (matrix * vec4(0,0,1,0)).xyz;
	vec3 up = (matrix * vec4(0,1,0,0)).xyz;
	vec3 right = normalize(cross(up, front));
	up = normalize(cross(front, right));
	front = normalize(cross(right, up));

	c.sides = {
		#if HAS_RIGHT
		right
		#endif
		
		#if HAS_LEFT
		#if HAS_RIGHT
		,
		#endif
		-right
		#endif
		
		#if HAS_TOP
		#if HAS_LEFT || HAS_RIGHT
		,
		#endif
		up
		#endif
		
		#if HAS_BOTTOM
		#if HAS_TOP || HAS_LEFT || HAS_RIGHT
		,
		#endif
		-up
		#endif
		
		#if HAS_FRONT
		#if HAS_BOTTOM || HAS_TOP || HAS_LEFT || HAS_RIGHT
		,
		#endif
		front
		#endif
		
		#if HAS_BACK
		#if HAS_FRONT || HAS_BOTTOM || HAS_TOP || HAS_LEFT || HAS_RIGHT
		,
		#endif
		-front
		#endif
	};

	c.directions = {
		#if HAS_RIGHT
		DIR_RIGHT
		#endif

		#if HAS_LEFT
		#if HAS_RIGHT
		,
		#endif
		DIR_LEFT
		#endif

		#if HAS_TOP
		#if HAS_LEFT || HAS_RIGHT
		,
		#endif
		DIR_TOP
		#endif

		#if HAS_BOTTOM
		#if HAS_TOP || HAS_LEFT || HAS_RIGHT
		,
		#endif
		DIR_BOTTOM
		#endif
		
		#if HAS_FRONT
		#if HAS_BOTTOM || HAS_TOP || HAS_LEFT || HAS_RIGHT
		,
		#endif
		DIR_FRONT
		#endif
		
		#if HAS_BACK
		#if HAS_FRONT || HAS_BOTTOM || HAS_TOP || HAS_LEFT || HAS_RIGHT
		,
		#endif
		DIR_BACK
		#endif
	};

	c.transform = matrix;
	
	return c;
}

CubeSideInfo get_cube_info(Cube c, vec3 direction) {
	CubeSideInfo info;
	info.side = -1;
	info.next = -1;
	info.delta = 1.0;
	info.offset = vec2(0,0);
	info.direction = -1;

	float maxDot = -2.0;
	float nextMaxDot = -2.0;
	int sideIndex = 0;

	// Check the dot product of the direction vector and each side normal
	// of the cube. The side with the largest dot product is the one
	// facing the direction vector
	for (int i = 0; i < SIDE_COUNT; i++) {
		vec3 sideNormal = c.sides[i];
		
		float dotProduct = dot(direction, sideNormal);
		
		if (dotProduct > maxDot) {
			info.side = i;
			maxDot = dotProduct;
			sideIndex = i;
		}
		else if(dotProduct > nextMaxDot){
			nextMaxDot = dotProduct;
			info.next = i;
			info.delta = 1.0 - nextMaxDot;
		}
	}
	info.delta = info.delta / maxDot;
	info.direction = c.directions[info.side];
	info.offset =  {
		#if HAS_RIGHT
		right_offset
		#endif
		
		#if HAS_LEFT 
		#if HAS_RIGHT
		,
		#endif
		left_offset
		#endif
		
		#if HAS_TOP
		#if HAS_LEFT || HAS_RIGHT
		,
		#endif
		top_offset
		#endif
		
		#if HAS_BOTTOM 
		#if HAS_TOP || HAS_LEFT || HAS_RIGHT
		,
		#endif 
		bottom_offset
		#endif
		
		#if HAS_FRONT
		#if HAS_BOTTOM ||  HAS_TOP || HAS_LEFT || HAS_RIGHT
		,
		#endif
		front_offset
		#endif
		
		#if HAS_BACK
		#if HAS_FRONT || HAS_BOTTOM ||  HAS_TOP || HAS_LEFT || HAS_RIGHT
		,
		#endif
		back_offset
		#endif
	}[info.side];
	return info;
}

void vertex(){
	if (!OUTPUT_IS_SRGB) {
		COLOR.rgb = srgb(COLOR.rgb);
	}
	UV=UV*uv_scale.xy+uv_offset.xy;
	
	vec3 cameraDirectionView = normalize(INV_VIEW_MATRIX[2].xyz);
	Cube object = create_cube(MODEL_MATRIX);
	CubeSideInfo info = get_cube_info(object, cameraDirectionView);
	
	cube_side = info.side;
	offset = info.offset;
	
	mat4 rotation;
	{
		int dir = object.directions[cube_side];
		mat3 m = mat3(INV_VIEW_MATRIX);
		mat3 rot = mat3(MODEL_MATRIX);
		// Since sides are dynamic I can't use the index to know if it's the top or bottom
		// so I have to check the normal

		#if HAS_TOP || HAS_BOTTOM
		bool isVertical = dir == DIR_TOP || dir == DIR_BOTTOM;
		if(isVertical){
			// vec3(-1,0,0)
			vec3 right = normalize(-rot[0].xyz);
			m[1] = normalize(cross(right, m[2]));
			m[2] = normalize(cross(m[1], right));
			m[0] = normalize(cross(m[1], m[2]));
		} else 
		#endif
		{
			// vec3(0,1,0);
			vec3 up = normalize(rot[1].xyz);
			m[2] = normalize(cross(m[0], up));
			m[0] = normalize(cross(up, m[2]));
			m[1] = normalize(cross(m[2], m[0]));
			
		}
		
		rotation = mat4(m);
		rotation[3] = MODEL_MATRIX[3];
	}
	
	MODELVIEW_MATRIX = VIEW_MATRIX * rotation;
	
	MODELVIEW_MATRIX = MODELVIEW_MATRIX * mat4(vec4(length(MODEL_MATRIX[0].xyz), 0.0, 0.0, 0.0),vec4(0.0, 1.0, 0.0, 0.0),vec4(0.0, 0.0, length(MODEL_MATRIX[2].xyz), 0.0), vec4(0.0, 0.0, 0.0, 1.0));
	
	#ifdef FIXED_SIZE
	if (PROJECTION_MATRIX[3][3] != 0.0) {
		float h = abs(1.0 / (2.0 * PROJECTION_MATRIX[1][1]));
		float sc = (h * 2.0); //consistent with Y-fov
		MODELVIEW_MATRIX[0]*=sc;
		MODELVIEW_MATRIX[1]*=sc;
		MODELVIEW_MATRIX[2]*=sc;
	} else {
		float sc = -(MODELVIEW_MATRIX)[3].z;
		MODELVIEW_MATRIX[0]*=sc;
		MODELVIEW_MATRIX[1]*=sc;
		MODELVIEW_MATRIX[2]*=sc;
	}
	#endif
	
	VERTEX = (MODELVIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
    NORMAL = (MODELVIEW_MATRIX * vec4(NORMAL, 0.0)).xyz;
}

void fragment() {
	vec2 base_uv = UV;
	vec2 uv = offset_uv(base_uv);
	
	vec4 albedo_tex = texture(texture_albedo,uv);
	albedo_tex *= COLOR;
	ALBEDO *= albedo_tex.rgb;
	SPECULAR = 0.5;
	METALLIC = 0.0;
	ROUGHNESS = 1.0;
	
	#if defined(TRANSPARENCY_DISCARD) || defined(TRANSPARENCY_OPAQUE_PREPASS) || defined(TRANSPARENCY)
	ALPHA *= albedo_tex.a;
	#endif
	
	#ifdef TRANSPARENCY_DISCARD
	ALPHA_SCISSOR_THRESHOLD = 0.5;
	#endif
}