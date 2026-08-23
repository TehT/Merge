shader_type canvas_item;

uniform sampler2D satellite_map : filter_linear;
uniform vec2 uv_min = vec2(0.0);
uniform vec2 uv_max = vec2(1.0);
uniform vec2 marker_uv = vec2(0.5);
uniform float aspect = 1.75;

void fragment() {
	vec2 map_uv = mix(uv_min, uv_max, UV);
	vec3 base = texture(satellite_map, map_uv).rgb;

	// Marker dot + ring
	vec2 marker_local = (marker_uv - uv_min) / (uv_max - uv_min);
	vec2 diff = UV - marker_local;
	diff.x *= aspect;
	float dist = length(diff);

	vec3 pin = vec3(1.0, 0.25, 0.2);
	float dot = smoothstep(0.024, 0.018, dist);
	float ring = smoothstep(0.045, 0.038, dist) - smoothstep(0.032, 0.025, dist);

	base = mix(base, pin, dot);
	base += pin * ring * 0.6;

	COLOR = vec4(base, 1.0);
}
