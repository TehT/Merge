shader_type spatial;
render_mode unshaded, cull_disabled;

#include "weather.gdshaderinc"

// ---- Mode toggle ----
uniform bool detail_mode = false;

// ---- Textures ----
uniform sampler2D land_mask : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D land_mask_detailed : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D lights_mask : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D heightmap : hint_default_black, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D satellite_map : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D moisture_map : hint_default_black, filter_linear_mipmap_anisotropic, repeat_enable;

// ---- Terrain ----
uniform float height_scale : hint_range(0.0, 0.2) = 0.03;
uniform float hillshade_strength : hint_range(0.0, 1.0) = 0.5;

uniform vec3 sea_color_day : source_color = vec3(0.05, 0.18, 0.35);
uniform vec3 sea_color_night : source_color = vec3(0.01, 0.03, 0.08);
uniform vec3 land_color_day : source_color = vec3(0.16, 0.42, 0.18);
uniform vec3 land_color_night : source_color = vec3(0.03, 0.08, 0.04);

// ---- Lighting ----
uniform vec3 city_light_color : source_color = vec3(1.0, 0.82, 0.45);
uniform float city_light_intensity : hint_range(0.0, 2.0) = 0.9;
uniform vec3 terminator_glow_color : source_color = vec3(0.9, 0.55, 0.15);
uniform float terminator_width : hint_range(0.0, 0.1) = 0.015;
uniform vec3 sun_direction = vec3(1.0, 0.0, 0.0);
uniform bool enable_night = true;

// ---- Globe mode: unfold ----
uniform float flatten : hint_range(0.0, 1.0) = 0.0;
const float PLANE_HALF_WIDTH = 3.14159265;
const float PLANE_HALF_HEIGHT = 1.5707963;

// ---- Globe mode: graticule & hover ----
uniform bool show_graticule = true;
uniform float graticule_step_deg = 15.0;
uniform float graticule_width = 0.006;
uniform vec3 graticule_color : source_color = vec3(0.2, 0.5, 0.3);
uniform float graticule_alpha = 0.25;
uniform vec2 hovered_cell = vec2(-999.0, -999.0);
uniform vec3 highlight_color : source_color = vec3(0.3, 0.8, 1.0);
uniform float highlight_alpha : hint_range(0.0, 1.0) = 0.2;

// ---- Detail mode: cell region & border ----
uniform vec2 cell_uv_min = vec2(0.0);
uniform vec2 cell_uv_max = vec2(1.0);
uniform vec3 border_color : source_color = vec3(0.3, 0.8, 1.0);
uniform float border_width : hint_range(0.0, 0.05) = 0.015;

// ---- Weather (driven by WeatherController) ----
uniform float weather_time = 0.0;
uniform vec2 wind_direction = vec2(1.0, 0.2);
uniform float wind_speed = 0.3;
uniform float cloud_coverage = 0.5;
uniform float cloud_opacity = 0.55;
uniform float season = 0.0;

varying vec2 v_uv;


void vertex() {
    v_uv = UV;

    if (!detail_mode) {
        // Globe unfold: sphere -> cylinder -> plane
        float stage1 = clamp(flatten * 2.0, 0.0, 1.0);
        float stage2 = clamp(flatten * 2.0 - 1.0, 0.0, 1.0);

        float phi = 3.14159265 * UV.y;
        float theta = UV.x * 6.2831853;

        float sphere_radius = sin(phi);
        float sphere_y = cos(phi);

        float cyl_radius = 1.0;
        float cyl_y = (0.5 - UV.y) * 2.0 * PLANE_HALF_HEIGHT;

        float r = mix(sphere_radius, cyl_radius, stage1);
        float y = mix(sphere_y, cyl_y, stage1);

        float x_pos = sin(theta) * r;
        float z_pos = cos(theta) * r;

        if (stage2 > 0.0) {
            float unroll = max(1.0 - stage2, 0.0001);
            float R = 1.0 / unroll;
            float s = (UV.x - 0.5) * 6.2831853;
            float theta_roll = s * unroll;
            x_pos = -R * sin(theta_roll);
            z_pos = -(1.0 - R + R * cos(theta_roll));
        }

        VERTEX = vec3(x_pos, y, z_pos);
    }
}

float grid_line(float coord, float step_deg, float width) {
    float m = mod(coord, step_deg);
    float d = min(m, step_deg - m);
    return 1.0 - smoothstep(0.0, width * step_deg * 10.0, d);
}

void fragment() {
    // ---- UV source ----
    vec2 uv = v_uv;
    if (detail_mode) {
        uv = mix(cell_uv_min, cell_uv_max, UV);
    }
    float mask;
    if (detail_mode) {
        mask = texture(land_mask_detailed, uv).r;
    } else {
        mask = texture(land_mask, uv).r;
    }

    // ---- Reconstruct surface normal for lighting ----
    float lon_deg = (v_uv.x - 0.5) * 360.0;
    float lat_deg = (0.5 - uv.y) * 180.0;
    float phi = 3.14159265 * uv.y;
    float w = sin(phi);
    vec3 n = normalize(vec3(sin(uv.x * 6.2831853) * w, cos(phi), cos(uv.x * 6.2831853) * w));

    float ndotl = dot(n, normalize(sun_direction));
    float lit = smoothstep(-terminator_width, terminator_width, ndotl);
    if (!enable_night) {
        lit = 1.0;
        ndotl = 1.0;
    }

    // ---- Land/sea base color ----
    vec3 sea = mix(sea_color_night, sea_color_day, lit);
    vec3 land;

    if (detail_mode) {
        vec3 sat = texture(satellite_map, uv).rgb;
        land = mix(sat * 0.12, sat, lit);
    } else {
        land = mix(land_color_night, land_color_day, lit);
    }

    vec3 color = mix(sea, land, mask);

    // ---- Heightmap hillshade ----
    float h_center = texture(heightmap, uv).r;
    vec2 texel = vec2(1.0 / 2048.0, 1.0 / 1024.0);
    float h_l = texture(heightmap, v_uv + vec2(-texel.x, 0.0)).r;
    float h_r = texture(heightmap, v_uv + vec2( texel.x, 0.0)).r;
    float h_d = texture(heightmap, v_uv + vec2(0.0, -texel.y)).r;
    float h_u = texture(heightmap, v_uv + vec2(0.0,  texel.y)).r;
    float slope = length(vec2(h_r - h_l, h_u - h_d)) * height_scale * 30.0;
    float elev_mod = (h_center - 0.05) * height_scale * 8.0;
    float tint = clamp(1.0 + elev_mod - slope * 0.5, 0.7, 1.3);
    color *= mix(1.0, tint, mask * hillshade_strength);

    // ---- City lights ----
    float lights = texture(lights_mask, uv).r;
    color += city_light_color * lights * mask * (1.0 - lit) * city_light_intensity;

    // ---- Terminator glow ----
    float edge = 1.0 - smoothstep(0.0, terminator_width * 3.0, abs(ndotl));
    color += terminator_glow_color * edge * 0.35;

    // ---- Mode-specific overlays ----
    if (detail_mode) {
        // Border
        float bx = min(UV.x, 1.0 - UV.x);
        float by = min(UV.y, 1.0 - UV.y);
        float b = 1.0 - smoothstep(0.0, border_width, min(bx, by));
        color = mix(color, border_color, b * 0.8);
    } else {
        // Graticule
        if (show_graticule) {
            float g = max(grid_line(lon_deg, graticule_step_deg, graticule_width),
                          grid_line(lat_deg, graticule_step_deg, graticule_width));
            color = mix(color, graticule_color,
                        g * graticule_alpha * lit * 0.6 + g * graticule_alpha * (1.0 - lit) * 0.15);
        }
        // Hover highlight
        if (hovered_cell.x > -999.0) {
            vec2 cell = floor(vec2(lon_deg, lat_deg) / graticule_step_deg);
            if (cell == hovered_cell) {
                color = mix(color, highlight_color, highlight_alpha);
            }
        }
    }


    // ---- Weather ----
    vec2 weather = weather_get(uv, moisture_map, weather_time,
                               wind_direction, wind_speed,
                               cloud_coverage, cloud_opacity, season);
    color.rgb = weather_apply(color.rgb, weather.x, lit);

    if (detail_mode) {
        uv = mix(cell_uv_min, cell_uv_max, UV);
    } else {
        uv = v_uv;
    }
    ALBEDO = color;
	}