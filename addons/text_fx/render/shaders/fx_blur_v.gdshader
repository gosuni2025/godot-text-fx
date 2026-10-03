// 가로 블러 결과의 세로 가우시안 블러 → 색을 입혀 합성. channel 0 = 그림자(R), 1 = 글로우(G).
shader_type canvas_item;
render_mode unshaded;

uniform int channel = 0;
uniform float radius = 0.0;
uniform vec4 tint = vec4(0.0, 0.0, 0.0, 0.6);
uniform float strength = 1.0;
uniform vec2 offset_px = vec2(0.0);

float pick(vec4 c) {
	return channel == 0 ? c.r : c.g;
}

void fragment() {
	vec2 uv = UV - offset_px * TEXTURE_PIXEL_SIZE;
	float v = 0.0;
	if (radius < 0.5) {
		v = pick(texture(TEXTURE, uv));
	} else {
		float sigma = max(radius * 0.5, 0.5);
		int n = int(ceil(radius));
		float ws = 0.0;
		for (int i = -n; i <= n; i++) {
			float w = exp(-float(i * i) / (2.0 * sigma * sigma));
			v += pick(texture(TEXTURE, uv + vec2(0.0, float(i) * TEXTURE_PIXEL_SIZE.y))) * w;
			ws += w;
		}
		v /= ws;
	}
	v = clamp(v * strength, 0.0, 1.0);
	COLOR = vec4(tint.rgb, tint.a * v);
}
