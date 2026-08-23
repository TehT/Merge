// weather.gdshaderinc — Cloud overlay system (sphere-mapped, seamless)
//
// Required uniforms in host shader:
//   uniform sampler2D moisture_map : hint_default_black, filter_linear_mipmap_anisotropic, repeat_enable;
//   uniform float weather_time;
//   uniform vec2 wind_direction;
//   uniform float wind_speed;
//   uniform float cloud_coverage;
//   uniform float cloud_opacity;
//   uniform float season;
//
// Usage in fragment():
//   vec2 weather = weather_get(uv, moisture_map, weather_time,
//                              wind_direction, wind_speed,
//                              cloud_coverage, cloud_opacity, season);
//   color.rgb = weather_apply(color.rgb, weather.x, lit);

// ---- 3D noise (seamless on sphere) ----

float _wh(vec3 p) {
    p = fract(p * vec3(0.1031, 0.1030, 0.0973));
    p += dot(p, p.yxz + 33.33);
    return fract((p.x + p.y) * p.z);
}

float _wn(vec3 p) {
    vec3 i = floor(p);
    vec3 f = fract(p);
    f = f * f * (3.0 - 2.0 * f);

    float a = _wh(i);
    float b = _wh(i + vec3(1, 0, 0));
    float c = _wh(i + vec3(0, 1, 0));
    float d = _wh(i + vec3(1, 1, 0));
    float e = _wh(i + vec3(0, 0, 1));
    float f1 = _wh(i + vec3(1, 0, 1));
    float g = _wh(i + vec3(0, 1, 1));
    float h = _wh(i + vec3(1, 1, 1));

    float x1 = mix(a, b, f.x);
    float x2 = mix(c, d, f.x);
    float x3 = mix(e, f1, f.x);
    float x4 = mix(g, h, f.x);

    return mix(mix(x1, x2, f.y), mix(x3, x4, f.y), f.z);
}

float _wfbm(vec3 p, int octaves) {
    float value = 0.0;
    float amp = 0.5;
    float freq = 1.0;
    for (int i = 0; i < octaves; i++) {
        value += amp * _wn(p * freq);
        freq *= 2.0;
        amp *= 0.5;
    }
    return value;
}

// ---- Main API ----

// Returns vec2(cloud_alpha, precipitation_chance)
vec2 weather_get(vec2 uv, sampler2D moisture_map, float weather_time,
                 vec2 wind_direction, float wind_speed,
                 float cloud_coverage, float cloud_opacity, float season) {

    // Equirectangular UV to sphere position (seamless, no date line seam)
    float lon = uv.x * 6.28318;
    float lat = (0.5 - uv.y) * 3.14159;
    vec3 sphere = vec3(
        cos(lat) * cos(lon),
        sin(lat),
        cos(lat) * sin(lon)
    );

    // Wind offset in 3D
    float t = weather_time * wind_speed;
    vec3 wind_3d = vec3(wind_direction.x, 0.0, wind_direction.y) * t * 0.3;

    // Three noise layers at different scales and speeds
    float systems    = _wfbm(sphere * 3.0  + wind_3d * 0.3, 3);  // large slow systems
    float formations = _wfbm(sphere * 8.0  + wind_3d * 0.7, 4);  // medium cloud bodies
    float detail     = _wfbm(sphere * 16.0 + wind_3d * 1.5, 3);  // fine fast wisps

    float cloud_noise = systems * 0.4 + formations * 0.4 + detail * 0.2;

    // Moisture from climate data
    float moisture = texture(moisture_map, uv).r;

    // Seasonal ITCZ shift
    float lat_deg = (0.5 - uv.y) * 180.0;
    float itcz_shift = sin(season * 6.28318) * 8.0;
    float itcz_boost = exp(-0.5 * pow((lat_deg - itcz_shift) / 10.0, 2.0)) * 0.15;
    moisture = clamp(moisture + itcz_boost, 0.0, 1.0);

    // Cloud threshold: high moisture = low threshold = more clouds
    float threshold = 1.0 - (moisture * cloud_coverage);
    float clouds = smoothstep(threshold, threshold + 0.15, cloud_noise);
    clouds *= smoothstep(0.03, 0.15, moisture); // desert suppression

    float alpha = clouds * cloud_opacity;

    // Precipitation: thick clouds + high moisture
    float precip = clouds * moisture * smoothstep(0.4, 0.7, cloud_noise);

    return vec2(alpha, precip);
}

// Apply cloud overlay to a base color. lit = 0.0 night, 1.0 day.
vec3 weather_apply(vec3 base_color, float cloud_alpha, float lit) {
    vec3 cloud_day   = vec3(0.92, 0.93, 0.95);
    vec3 cloud_night = vec3(0.08, 0.09, 0.11);
    vec3 cloud_color = mix(cloud_night, cloud_day, lit);

    // Terminator glow on clouds
    float terminator = smoothstep(0.0, 0.15, lit) * (1.0 - smoothstep(0.15, 0.3, lit));
    cloud_color += vec3(0.3, 0.15, 0.05) * terminator;

    return mix(base_color, cloud_color, cloud_alpha);
}
