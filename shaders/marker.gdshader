shader_type spatial;
// Unshaded so markers stay readable against both the day and night sides.
// cull_disabled because the billboard can end up facing either way as the globe spins.
// depth_test_disabled so markers never clip into height-displaced terrain
// (mountains etc. can rise above the marker's small SURFACE_OFFSET) —
// safe because far-side markers are already hidden on the CPU side via
// MarkerLayer's hide_far_side/is_facing_camera check, not depth testing.
render_mode unshaded, cull_disabled, blend_mix, depth_test_disabled;

uniform vec3 base_color : source_color = vec3(0.95, 0.78, 0.22);
uniform vec3 hover_color : source_color = vec3(1.0, 0.95, 0.55);
uniform vec3 selected_color : source_color = vec3(1.0, 0.35, 0.2);
uniform vec3 spawn_color : source_color = vec3(1.0, 1.0, 1.0);
uniform float hovered = 0.0;    // 0 = idle, 1 = mouse is over this marker
uniform float selected = 0.0;   // 0 = idle, 1 = selected
uniform float pulse = 0.0;      // 0..1, drives the selection ring animation
uniform float spawn_glow = 0.0; // 1.0 right after spawn, decays to 0 - one-shot "new event" ring
uniform float is_base = 0.0;    // 1.0 = render as a diamond HQ icon instead of a dot

void vertex() {
	// Standard billboard: replace the rotation part of the modelview with the
	// camera's, keeping only this node's world translation. Because the quad's
	// size is baked into its vertex positions, marker scale survives this.
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(
		INV_VIEW_MATRIX[0],
		INV_VIEW_MATRIX[1],
		INV_VIEW_MATRIX[2],
		MODEL_MATRIX[3]
	);
}

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float d = length(p);
	// diamond metric (Manhattan distance) - the HQ icon's shape
	float dm = abs(p.x) + abs(p.y);

	// solid core dot, or a diamond for the HQ base marker
	float core = mix(
		1.0 - smoothstep(0.34, 0.42, d),
		1.0 - smoothstep(0.5, 0.58, dm),
		is_base);

	// thin outline so the dot reads against bright land as well as dark ocean
	float outline = mix(
		smoothstep(0.42, 0.46, d) - smoothstep(0.52, 0.56, d),
		smoothstep(0.58, 0.64, dm) - smoothstep(0.78, 0.84, dm),
		is_base);

	// soft halo behind the dot on hover - independent of selection, so hovering
	// the already-selected marker still gives feedback
	float halo = 1.0 - smoothstep(0.0, 0.62, d);
	halo *= hovered * 0.35;

	// expanding ring, only when selected
	float ring_r = mix(0.62, 0.94, pulse);
	float ring = smoothstep(ring_r - 0.06, ring_r - 0.02, d) - smoothstep(ring_r + 0.02, ring_r + 0.06, d);
	ring *= selected * (1.0 - pulse * 0.7);

	// one-shot expanding ring that plays once when the marker first appears,
	// independent of selection - draws attention to newly spawned events
	float spawn_ring_r = mix(0.5, 1.3, 1.0 - spawn_glow);
	float spawn_ring = smoothstep(spawn_ring_r - 0.07, spawn_ring_r - 0.02, d) - smoothstep(spawn_ring_r + 0.02, spawn_ring_r + 0.07, d);
	spawn_ring *= spawn_glow;

	float a = clamp(core + outline * 0.85 + ring + halo + spawn_ring, 0.0, 1.0);
	if (a < 0.01) {
		discard;
	}

	vec3 color = mix(base_color, hover_color, hovered * 0.8);
	color = mix(color, selected_color, selected);
	color = mix(color, spawn_color, spawn_ring);

	ALBEDO = color;
	ALPHA = a;
}