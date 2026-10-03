// 구운 프리멀티플라이드 색을 필터링한다. 블러 셀은 격리된 mipmap 텍스처라 이웃 글자가 섞이지 않는다.
shader_type canvas_item;
render_mode blend_premul_alpha, unshaded;

uniform sampler2D glow_texture : filter_linear_mipmap, repeat_disable;
uniform bool has_glow = false;
uniform float glow_multiplier = 1.0;
uniform float brightness = 0.0;
uniform float blur_radius = 0.0;
uniform vec2 blur_direction = vec2(0.0);
uniform vec4 source_rect = vec4(0.0, 0.0, 1.0, 1.0);
uniform vec3 canvas_x = vec3(1.0, 0.0, 0.0);
uniform vec3 canvas_y = vec3(0.0, 1.0, 0.0);
uniform vec2 canvas_x_to_uv = vec2(0.0);
uniform bool clip_enabled = false;
uniform bool clip_invert = false;
uniform vec4 clip_rect = vec4(0.0);
uniform float clip_feather = 0.0;
uniform int slice_count = 0;
uniform float slice_origin_y = 0.0;
uniform float slice_height = 1.0;
uniform float slice_offsets[32];

varying vec4 glyph_color;
varying vec2 canvas_pos;

void vertex() {
	glyph_color = COLOR;
	canvas_pos = vec2(dot(canvas_x, vec3(VERTEX, 1.0)), dot(canvas_y, vec3(VERTEX, 1.0)));
}

vec4 sample_glyph(sampler2D tex, vec2 uv, float lod) {
	if (any(lessThan(uv, source_rect.xy)) || any(greaterThan(uv, source_rect.zw))) {
		return vec4(0.0);
	}
	vec4 base = textureLod(tex, uv, lod);
	if (has_glow) {
		vec4 glow = textureLod(glow_texture, uv, lod) * glow_multiplier;
		// 강한 글로우도 프리멀티플라이드 관계를 지킨다.
		glow /= max(1.0, glow.a);
		base += glow * (1.0 - base.a);
	}
	return base;
}

vec4 blurred_glyph(sampler2D tex, vec2 pixel_size, vec2 uv) {
	if (blur_radius < 0.05) {
		return sample_glyph(tex, uv, 0.0);
	}
	vec4 total = vec4(0.0);
	float weights = 0.0;
	if (length(blur_direction) > 0.01) {
		// 방향성 블러는 mipmap을 쓰지 않아 직교 방향의 획이 퍼지지 않는다.
		vec2 step_uv = normalize(blur_direction) * pixel_size;
		float sigma = max(0.5, blur_radius * 0.5);
		int count = int(ceil(min(blur_radius, 96.0)));
		float stride = max(1.0, blur_radius / float(count));
		for (int i = -count; i <= count; i++) {
			float offset = float(i) * stride;
			float w = exp(-offset * offset / (2.0 * sigma * sigma));
			total += sample_glyph(tex, uv + step_uv * offset, 0.0) * w;
			weights += w;
		}
	} else {
		// 넓은 커널은 mipmap으로 먼저 저역 통과시켜 고정 7×7 표본 사이에 격자 잔상이 생기지 않게 한다.
		float lod = max(0.0, log2(max(1.0, blur_radius / 3.0)));
		vec2 stride = pixel_size * blur_radius / 3.0;
		for (int y = -3; y <= 3; y++) {
			for (int x = -3; x <= 3; x++) {
				float w = exp(-float(x * x + y * y) / 4.5);
				total += sample_glyph(tex, uv + vec2(float(x), float(y)) * stride, lod) * w;
				weights += w;
			}
		}
	}
	return total / max(weights, 0.00001);
}

float mask_alpha() {
	if (!clip_enabled) {
		return 1.0;
	}
	vec2 distance_inside = min(canvas_pos - clip_rect.xy, clip_rect.zw - canvas_pos);
	float d = min(distance_inside.x, distance_inside.y);
	float a = clip_feather > 0.001 ? smoothstep(-clip_feather * 0.5, clip_feather * 0.5, d) : step(0.0, d);
	return clip_invert ? 1.0 - a : a;
}

void fragment() {
	vec2 uv = UV;
	if (slice_count > 0) {
		int index = int(floor((canvas_pos.y - slice_origin_y) / max(0.001, slice_height)));
		if (index >= 0 && index < slice_count) {
			uv -= canvas_x_to_uv * slice_offsets[index];
		}
	}
	vec4 c = blurred_glyph(TEXTURE, TEXTURE_PIXEL_SIZE, uv);
	c *= glyph_color;
	c.rgb = mix(c.rgb, vec3(c.a), clamp(brightness, 0.0, 1.0));
	COLOR = c * mask_alpha();
}
