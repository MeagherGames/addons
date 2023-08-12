group_uniforms Metallic;
uniform float specular: hint_range(0.0, 1.0) = 0.5;

group_uniforms Light;
uniform sampler2D light_ramp: hint_default_black, repeat_disable;

group_uniforms Rim;
uniform vec3 rim_color: source_color = vec3(1.0);
uniform float rim_width: hint_range(0.0, 1.0) = 0.0;
uniform float rim_shadow: hint_range(0.0, 1.0) = 1.0;
uniform float rim_tint: hint_range(0.0, 1.0) = 1.0;

float SchlickFresnel(float u) {
	float m = 1.0 - u;
	float m2 = m * m;
	return m2 * m2 * m; // pow(m,5)
}
float fresnel(float amount, vec3 normal, vec3 view) {
	return pow((1.0 - clamp(dot(normalize(normal), normalize(view)), 0.0, 1.0 )), amount);
}
float D_GGX(float cos_theta_m, float alpha) {
	float a = cos_theta_m * alpha;
	float k = alpha / (1.0 - cos_theta_m * cos_theta_m + a * a);
	return k * k * (1.0 / PI);
}
float V_GGX(float NdotL, float NdotV, float alpha) {
	return 0.5 / mix(2.0 * NdotL * NdotV, NdotL + NdotV, alpha);
}

void light() {
	float cNdotL = clamp(dot(NORMAL, LIGHT), 0.0, 1.0);
	
	/* Basic lighting */
	{
		vec4 ramp_color = texture(light_ramp, vec2(cNdotL, 0.5));
		ramp_color.rgb *= 1.0 / PI;
		DIFFUSE_LIGHT += LIGHT_COLOR * ramp_color.rgb * ATTENUATION;
	}
	
	vec3 f0 = mix(vec3(0.16 * specular * specular), ALBEDO, METALLIC);
	vec3 HALF = normalize(VIEW + LIGHT);
	float cNdotH = clamp(dot(NORMAL, HALF), 0.0, 1.0);
	float cLdotH = clamp(dot(LIGHT, HALF), 0.0, 1.0);
	float cNdotV = max(dot(NORMAL, VIEW), 1e-4);
	
	/* Specular highlights */
	{
		float D = D_GGX(cNdotH, ROUGHNESS * ROUGHNESS);
		float G = V_GGX(cNdotL, cNdotV, ROUGHNESS * ROUGHNESS);
		float cLdotH5 = SchlickFresnel(cLdotH);
		float f90 = clamp(50.0 * f0.g, 0.0, 1.0);
		vec3 F = f0 + (f90 - f0) * cLdotH5;
		
		// Make sure the shadow still shows up on metallic objects correctly
		vec4 ramp_color = texture(light_ramp, vec2(cNdotL, 0.5));
		vec3 metallic_shadow = mix(vec3(1.0), ramp_color.rgb * ATTENUATION, METALLIC);
		
		SPECULAR_LIGHT += cNdotL * max(D * F * G, vec3(0.0)) * metallic_shadow;
	}
	
	/* Rim lighting */
	{
		float fresnel = fresnel(1.0 / rim_width, NORMAL, VIEW);
		float light = dot(NORMAL, LIGHT);
		light = mix(fresnel, light * fresnel, rim_shadow);
		vec4 ramp_color = texture(light_ramp, vec2(light, 0.5));
		
		vec3 a = mix(rim_color, vec3(1.0), rim_tint);
		vec3 b = mix(rim_color, ALBEDO, rim_tint);
		
		SPECULAR_LIGHT += ramp_color.rgb * mix(a, b, METALLIC);
	}
}