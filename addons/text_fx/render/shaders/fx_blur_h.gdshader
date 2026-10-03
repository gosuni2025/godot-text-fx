// 실루엣 아틀라스의 가로 가우시안 블러. R = 그림자 반경, G = 글로우 반경.
shader_type canvas_item;
render_mode blend_disabled, unshaded;

uniform float r_r = 0.0;
uniform float r_g = 0.0;

float hblur(sampler2D tex, vec2 uv, vec2 px, float r) {
	if (r < 0.5) {
		return texture(tex, uv).a;
	}
	float sigma = max(r * 0.5, 0.5);
	int n = int(ceil(r));
	float acc = 0.0;
	float ws = 0.0;
	for (int i = -n; i <= n; i++) {
		float w = exp(-float(i * i) / (2.0 * sigma * sigma));
		acc += texture(tex, uv + vec2(float(i) * px.x, 0.0)).a * w;
		ws += w;
	}
	return acc / ws;
}

void fragment() {
	COLOR = vec4(hblur(TEXTURE, UV, TEXTURE_PIXEL_SIZE, r_r), hblur(TEXTURE, UV, TEXTURE_PIXEL_SIZE, r_g), 0.0, 1.0);
}
