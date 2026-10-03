shader_type canvas_item;
// 미리보기 배경 체커보드(투명 영역 표시용). 칸 크기는 화면 px.

uniform float cell = 16.0;
uniform vec4 color_a : source_color = vec4(0.22, 0.23, 0.27, 1.0);
uniform vec4 color_b : source_color = vec4(0.30, 0.31, 0.36, 1.0);

varying vec2 local_pos;

void vertex() {
	local_pos = VERTEX;
}

void fragment() {
	vec2 c = floor(local_pos / cell);
	COLOR = mod(c.x + c.y, 2.0) < 1.0 ? color_a : color_b;
}
