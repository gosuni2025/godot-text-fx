shader_type canvas_item;
render_mode unshaded;

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear;

uniform vec2 rect_size = vec2(880.0, 104.0);
uniform vec4 deep_metal_color : source_color = vec4(0.07, 0.10, 0.15, 1.0);
uniform vec4 mid_metal_color : source_color = vec4(0.38, 0.45, 0.54, 1.0);
uniform vec4 light_metal_color : source_color = vec4(0.73, 0.79, 0.84, 1.0);
uniform vec4 rift_color : source_color = vec4(0.08, 0.46, 0.86, 1.0);
uniform vec4 flare_color : source_color = vec4(0.52, 0.86, 1.0, 1.0);
uniform vec4 glow_color : source_color = vec4(0.01, 0.22, 0.46, 1.0);
uniform float motion_enabled : hint_range(0.0, 1.0) = 1.0;
uniform float reduced_transparency_amount : hint_range(0.0, 1.0) = 0.0;
uniform float high_contrast_amount : hint_range(0.0, 1.0) = 0.0;
uniform float sweep_progress : hint_range(-0.2, 1.2) = -0.2;
uniform float sweep_width_px : hint_range(24.0, 160.0) = 58.0;
uniform float sweep_core_width_px : hint_range(1.0, 8.0) = 2.2;
uniform float fragment_length_px : hint_range(4.0, 48.0) = 32.0;
uniform float fragment_strength : hint_range(0.0, 1.0) = 0.58;
uniform float fragment_row_height_px : hint_range(3.0, 8.0) = 4.0;
uniform float tear_length_px : hint_range(8.0, 48.0) = 44.0;
uniform float tear_trail_width_px : hint_range(16.0, 128.0) = 68.0;
uniform float tear_strength : hint_range(0.0, 1.0) = 0.72;

varying vec2 local_position;


void vertex() {
	local_position = VERTEX;
}


float hash_value(float value) {
	return fract(sin(value * 91.739 + 17.133) * 43758.5453);
}


float hash_position(vec2 value) {
	return fract(sin(dot(value, vec2(127.1, 311.7))) * 43758.5453);
}


float value_noise(vec2 value) {
	vec2 cell = floor(value);
	vec2 phase = fract(value);
	phase = phase * phase * (3.0 - 2.0 * phase);
	float top = mix(
		hash_position(cell),
		hash_position(cell + vec2(1.0, 0.0)),
		phase.x
	);
	float bottom = mix(
		hash_position(cell + vec2(0.0, 1.0)),
		hash_position(cell + vec2(1.0, 1.0)),
		phase.x
	);
	return mix(top, bottom, phase.y);
}


vec4 sample_group(vec2 screen_uv, vec2 screen_pixel_size, vec2 offset_px) {
	vec4 sample_color = textureLod(
		screen_texture,
		screen_uv + offset_px * screen_pixel_size,
		0.0
	);
	if (sample_color.a > 0.0001) {
		sample_color.rgb /= sample_color.a;
	}
	return sample_color;
}


float face_weight_from_sample(vec4 sample_color) {
	float luminance = dot(sample_color.rgb, vec3(0.299, 0.587, 0.114));
	return smoothstep(0.38, 0.62, luminance);
}


float sample_face_alpha(vec2 screen_uv, vec2 screen_pixel_size, vec2 offset_px) {
	vec4 sample_color = sample_group(screen_uv, screen_pixel_size, offset_px);
	return sample_color.a * face_weight_from_sample(sample_color);
}


void fragment() {
	vec4 canvas_modulate = COLOR;
	vec2 resolved_size = max(rect_size, vec2(1.0));
	vec2 point = clamp(local_position, vec2(0.0), resolved_size);
	float vertical = point.y / resolved_size.y;
	vec4 glyph = sample_group(SCREEN_UV, SCREEN_PIXEL_SIZE, vec2(0.0));
	float glyph_alpha = glyph.a;
	float face_weight = face_weight_from_sample(glyph);
	float face_alpha = glyph_alpha * face_weight;

	// Preserve the original wordmark silhouette. Coarse, deterministic noise
	// affects only the metal tone, giving the face a worn stone-steel finish.
	float coarse_noise = value_noise(point * vec2(0.062, 0.085) + vec2(4.7, 1.9));
	float fine_noise = hash_position(
		floor(point * vec2(0.19, 0.24) + vec2(13.1, 7.3))
	);
	float top_light = 1.0 - smoothstep(0.04, 0.96, vertical);
	float metal_light = clamp(
		0.24 + top_light * 0.48 + (coarse_noise - 0.5) * 0.44
			+ (fine_noise - 0.5) * 0.12,
		0.0,
		1.0
	);
	vec3 metal = mix(
		deep_metal_color.rgb,
		mid_metal_color.rgb,
		smoothstep(0.08, 0.74, metal_light)
	);
	metal = mix(
		metal,
		light_metal_color.rgb,
		smoothstep(0.62, 1.0, metal_light) * 0.78
	);

	vec4 glyph_above = sample_group(
		SCREEN_UV,
		SCREEN_PIXEL_SIZE,
		vec2(0.0, -1.5)
	);
	vec4 glyph_left = sample_group(
		SCREEN_UV,
		SCREEN_PIXEL_SIZE,
		vec2(-1.5, 0.0)
	);
	vec4 glyph_right = sample_group(
		SCREEN_UV,
		SCREEN_PIXEL_SIZE,
		vec2(1.5, 0.0)
	);
	vec4 glyph_below = sample_group(
		SCREEN_UV,
		SCREEN_PIXEL_SIZE,
		vec2(0.0, 1.5)
	);
	float face_alpha_above = glyph_above.a * face_weight_from_sample(glyph_above);
	float face_alpha_left = glyph_left.a * face_weight_from_sample(glyph_left);
	float face_alpha_right = glyph_right.a * face_weight_from_sample(glyph_right);
	float face_alpha_below = glyph_below.a * face_weight_from_sample(glyph_below);
	float upper_rim = max(face_alpha - min(face_alpha_above, face_alpha_left), 0.0);
	float lower_shadow = max(face_alpha - face_alpha_below, 0.0);
	float left_face_edge = clamp(
		(face_alpha - face_alpha_left) * 2.4,
		0.0,
		1.0
	);
	float right_face_edge = clamp(
		(face_alpha - face_alpha_right) * 2.4,
		0.0,
		1.0
	);
	metal = mix(metal, light_metal_color.rgb, upper_rim * 0.44);
	metal = mix(metal, deep_metal_color.rgb, lower_shadow * 0.34);

	// Sparse hairline rows pull broken cross-sections of the source strokes
	// beyond their contour. The source glyph stays intact; only the exposed
	// roots at its left and right edges take on the blue rift color.
	float resolved_row_height = max(fragment_row_height_px, 1.0);
	float row_coordinate = (point.y + 0.5) / resolved_row_height;
	float row_id = floor(row_coordinate);
	float row_phase = fract(row_coordinate);
	float row_random = hash_value(row_id);
	float thin_row = 1.0 - smoothstep(0.08, 0.25, abs(row_phase - 0.5));
	float sparse_row = step(0.60, row_random);
	float segment_id = floor(point.x / 24.0);
	float segment_random = hash_position(vec2(segment_id, row_id + 23.0));
	float broken_segment = step(0.42, segment_random);
	float fracture_mask = thin_row * sparse_row * broken_segment;

	float direction_random = hash_value(row_id + 41.7);
	float direction = mix(-1.0, 1.0, step(0.5, direction_random));
	float resolved_fragment_length = fragment_length_px * mix(0.38, 1.0, row_random);
	float pulled_alpha = 0.0;
	if (fracture_mask > 0.001) {
		for (int sample_index = 1; sample_index <= 3; sample_index++) {
			float sample_ratio = float(sample_index) / 3.0;
			float sampled_alpha = sample_face_alpha(
				SCREEN_UV,
				SCREEN_PIXEL_SIZE,
				vec2(direction * resolved_fragment_length * sample_ratio, 0.0)
			);
			pulled_alpha = max(
				pulled_alpha,
				sampled_alpha * mix(0.94, 0.24, sample_ratio)
			);
		}
	}
	float transparency_scale = mix(1.0, 0.18, reduced_transparency_amount);
	float fragment_alpha = pulled_alpha * fracture_mask;
	fragment_alpha *= 1.0 - smoothstep(0.02, 0.45, glyph_alpha);
	fragment_alpha *= fragment_strength * transparency_scale;

	float travel = clamp(sweep_progress, 0.0, 1.0);
	float inside_travel = step(0.0, sweep_progress) * (1.0 - step(1.0, sweep_progress));
	float active = inside_travel * motion_enabled;
	float sweep_x = mix(-sweep_width_px, resolved_size.x + sweep_width_px, travel);
	sweep_x += (vertical - 0.5) * 30.0;
	float sweep_distance = abs(point.x - sweep_x);
	float sweep_aura = (
		1.0 - smoothstep(sweep_core_width_px, sweep_width_px, sweep_distance)
	) * active;
	float sweep_core = (
		1.0 - smoothstep(0.0, sweep_core_width_px, sweep_distance)
	) * active;
	float static_face_edge = mix(
		right_face_edge,
		left_face_edge,
		step(0.0, direction)
	);
	float static_rift_root = smoothstep(0.06, 0.72, static_face_edge);
	float moving_rift_root = smoothstep(0.06, 0.72, left_face_edge);
	float static_rift = fracture_mask * face_weight * static_rift_root;
	static_rift *= mix(0.30, 0.68, row_random);
	float moving_rift = sweep_aura * face_weight;
	moving_rift *= 0.04 + fracture_mask * moving_rift_root * 0.64;
	metal = mix(metal, rift_color.rgb, clamp(static_rift + moving_rift, 0.0, 0.82));
	metal = mix(
		metal,
		flare_color.rgb,
		sweep_core * face_weight * (0.16 + moving_rift_root * 0.66)
	);
	fragment_alpha *= 1.0 + sweep_aura * 0.42;

	float distance_behind = sweep_x - point.x;
	float tear_trail = (
		1.0 - smoothstep(0.0, tear_trail_width_px, distance_behind)
	) * step(0.0, distance_behind) * active;
	float tear_row_random = hash_value(row_id + 73.9);
	float tear_row_mask = thin_row * step(0.46, tear_row_random);
	tear_row_mask *= step(0.35, segment_random);
	float torn_streak_source = 0.0;
	if (tear_trail > 0.001 && tear_row_mask > 0.001) {
		for (int sample_index = 1; sample_index <= 3; sample_index++) {
			float sample_ratio = float(sample_index) / 3.0;
			float tear_sample_alpha = sample_face_alpha(
				SCREEN_UV,
				SCREEN_PIXEL_SIZE,
				vec2(tear_length_px * sample_ratio, 0.0)
			);
			torn_streak_source = max(
				torn_streak_source,
				tear_sample_alpha * mix(0.90, 0.18, sample_ratio)
			);
		}
	}
	float torn_streak_alpha = torn_streak_source * tear_row_mask;
	torn_streak_alpha *= 1.0 - smoothstep(0.02, 0.42, glyph_alpha);
	torn_streak_alpha *= tear_trail * tear_strength * transparency_scale;

	vec4 nearby_right_sample = sample_group(
		SCREEN_UV,
		SCREEN_PIXEL_SIZE,
		vec2(3.0, 0.0)
	);
	float nearby_right = nearby_right_sample.a;
	vec4 nearby_left_sample = sample_group(
		SCREEN_UV,
		SCREEN_PIXEL_SIZE,
		vec2(-3.0, 0.0)
	);
	float nearby_left = nearby_left_sample.a;
	float nearby_alpha = max(nearby_right, nearby_left);
	nearby_alpha = max(nearby_alpha, sample_group(SCREEN_UV, SCREEN_PIXEL_SIZE, vec2(0.0, 3.0)).a);
	nearby_alpha = max(nearby_alpha, sample_group(SCREEN_UV, SCREEN_PIXEL_SIZE, vec2(0.0, -3.0)).a);
	float glow_alpha = max(nearby_alpha - glyph_alpha, 0.0);
	glow_alpha *= (0.08 + sweep_aura * 0.12) * transparency_scale;

	vec3 high_contrast_metal = mix(mid_metal_color.rgb, vec3(0.94), 0.68);
	metal = mix(metal, high_contrast_metal, high_contrast_amount * 0.46);
	vec3 glyph_color = metal;
	vec3 fragment_base = mix(light_metal_color.rgb, rift_color.rgb, 0.32);
	float outside_root = max(
		nearby_left_sample.a * face_weight_from_sample(nearby_left_sample),
		nearby_right_sample.a * face_weight_from_sample(nearby_right_sample)
	);
	outside_root *= 1.0 - smoothstep(0.02, 0.45, glyph_alpha);
	fragment_base = mix(fragment_base, rift_color.rgb, outside_root * 0.72);
	vec3 fragment_color = mix(
		fragment_base,
		flare_color.rgb,
		max(sweep_aura, tear_trail) * 0.68
	);
	float resolved_fragment_alpha = max(fragment_alpha, torn_streak_alpha);
	float outside_alpha = resolved_fragment_alpha;
	outside_alpha += glow_alpha * (1.0 - resolved_fragment_alpha);
	vec3 outside_premultiplied = fragment_color * resolved_fragment_alpha;
	outside_premultiplied += glow_color.rgb * glow_alpha * (1.0 - resolved_fragment_alpha);
	float composed_alpha = glyph_alpha + outside_alpha * (1.0 - glyph_alpha);
	vec3 composed_premultiplied = glyph_color * glyph_alpha;
	composed_premultiplied += outside_premultiplied * (1.0 - glyph_alpha);
	vec3 composed_color = composed_premultiplied / max(composed_alpha, 0.0001);
	COLOR = canvas_modulate * vec4(composed_color, composed_alpha);
}
