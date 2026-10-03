// 채우기 그라데이션. t = dot(VERTEX, g_a) + g_b (VERTEX는 글자 박스 중심 기준 로컬 px).
// 블록 좌표 기준이면 g_a/g_b에 글자의 블록 내 위치·회전이 들어 있어 셀마다 그라데이션이 이어진다.
shader_type canvas_item;
render_mode unshaded;

uniform sampler2D stops : filter_linear, repeat_disable;
uniform vec2 g_a = vec2(0.0, 0.01);
uniform float g_b = 0.5;

varying vec2 lp;

void vertex() {
	lp = VERTEX;
}

void fragment() {
	float t = clamp(dot(lp, g_a) + g_b, 0.0, 1.0);
	vec4 g = texture(stops, vec2(t, 0.5));
	COLOR = vec4(g.rgb, g.a * COLOR.a);
}
