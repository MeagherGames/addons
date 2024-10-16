const mat3 RGB_TO_YUV_MATRIX = mat3(
    vec3(0.299, 0.587, 0.114),
    vec3(-0.14713, -0.28886, 0.436),
    vec3(0.615, -0.51499, -0.10001)
);

const mat3 LINEAR_RGB_TO_XYZ_MATRIX = mat3(
    vec3(0.4124564, 0.3575761, 0.1804375),
    vec3(0.2126729, 0.7151522, 0.0721750),
    vec3(0.0193339, 0.1191920, 0.9503041)
);

vec3 gamma_correct(vec3 rgb) {
    return mix(rgb * 12.92, pow(rgb, vec3(1.0 / 2.4)) * 1.055 - 0.055, step(0.0031308, rgb));
}

vec3 inverse_gamma_correct(vec3 rgb) {
    return mix(rgb / 12.92, pow((rgb + 0.055) / 1.055, vec3(2.4)), step(0.04045, rgb));
}

vec3 colorize(vec3 original_rgb, vec3 target_rgb) {
    vec3 original_yuv = RGB_TO_YUV_MATRIX * original_rgb;
    vec3 target_yuv = RGB_TO_YUV_MATRIX * target_rgb;
    vec3 result_yuv = vec3(target_yuv.x, target_yuv.y, original_yuv.z);
    return inverse(RGB_TO_YUV_MATRIX) * result_yuv;
}

vec3 rgb_to_xyz(vec3 rgb) {
    return LINEAR_RGB_TO_XYZ_MATRIX * gamma_correct(rgb);
}

vec3 xyz_to_rgb(vec3 xyz) {
    return inverse_gamma_correct(inverse(LINEAR_RGB_TO_XYZ_MATRIX) * xyz);
}

vec3 xyz_to_lab(vec3 xyz) {
    // Reference white point (D65 illuminant)
    vec3 ref = vec3(0.95047, 1.00000, 1.08883);
    
    // Normalize the XYZ values by the reference white point
    xyz /= ref;
    
    // Apply the CIELAB transformation
    vec3 f = mix(
        pow(xyz, vec3(1.0 / 3.0)), // If xyz > 0.008856, use the cube root
        (7.787 * xyz) + (16.0 / 116.0), // Otherwise, use the linear transformation
        step(0.008856, xyz) // Step function to choose between the two transformations
    );
    
    // Calculate the L*, a*, and b* values
    return vec3(
        (116.0 * f.y) - 16.0, // L* component
        500.0 * (f.x - f.y), // a* component
        200.0 * (f.y - f.z) // b* component
    );
}

vec3 lab_to_xyz(vec3 lab) {
    // Reference white point (D65 illuminant)
    vec3 ref = vec3(0.95047, 1.00000, 1.08883);
    
    // Calculate the f values
    float fy = (lab.x + 16.0) / 116.0;
    float fx = (lab.y / 500.0) + fy;
    float fz = fy - (lab.z / 200.0);
    
    // Calculate the XYZ values
    vec3 xyz = vec3(
        pow(fx, 3.0), // X component
        pow(fy, 3.0), // Y component
        pow(fz, 3.0) // Z component
    );
    
    // Denormalize the XYZ values by the reference white point
    return xyz * ref;
}

vec3 rgb_to_hsv(vec3 rgb) {
    float maxc = max(rgb.r, max(rgb.g, rgb.b));
    float minc = min(rgb.r, min(rgb.g, rgb.b));
    float delta = maxc - minc;

    float hue = 0.0;
    if (delta > 0.00001) {
        if (maxc == rgb.r) {
            hue = mod((rgb.g - rgb.b) / delta, 6.0);
        } else if (maxc == rgb.g) {
            hue = (rgb.b - rgb.r) / delta + 2.0;
        } else {
            hue = (rgb.r - rgb.g) / delta + 4.0;
        }
    }
    hue = hue / 6.0; // Normalize hue to [0, 1]
    
    float saturation = maxc == 0.0 ? 0.0 : delta / maxc;
    float value = maxc;
    
    return vec3(hue, saturation, value);
}

vec3 hsv_to_rgb(vec3 hsv) {
    float c = hsv.z * hsv.y;
    float x = c * (1.0 - abs(mod(hsv.x * 6.0, 2.0) - 1.0));
    float m = hsv.z - c;
    
    vec3 rgb;
    if (hsv.x < 1.0 / 6.0) {
        rgb = vec3(c, x, 0.0);
    } else if (hsv.x < 2.0 / 6.0) {
        rgb = vec3(x, c, 0.0);
    } else if (hsv.x < 3.0 / 6.0) {
        rgb = vec3(0.0, c, x);
    } else if (hsv.x < 4.0 / 6.0) {
        rgb = vec3(0.0, x, c);
    } else if (hsv.x < 5.0 / 6.0) {
        rgb = vec3(x, 0.0, c);
    } else {
        rgb = vec3(c, 0.0, x);
    }
    
    return rgb + m;
}
