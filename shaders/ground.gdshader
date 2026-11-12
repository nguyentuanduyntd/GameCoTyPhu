// Nền cỏ quanh bàn cờ: loang màu cỏ nhiều tầng, tối nhẹ sát chân bàn (AO giả),
// tan dần vào màu chân trời ở xa để không thấy mép mặt phẳng.
shader_type spatial;
render_mode diffuse_burley;

uniform vec4 grass_a : source_color = vec4(0.25, 0.47, 0.22, 1.0);
uniform vec4 grass_b : source_color = vec4(0.38, 0.60, 0.29, 1.0);
uniform vec4 far_color : source_color = vec4(0.62, 0.74, 0.58, 1.0);
uniform float board_half = 9.5;
uniform float fade_start = 26.0;
uniform float fade_end = 70.0;
uniform float detail = 1.0;

varying vec3 wpos;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

void fragment() {
	vec2 p = wpos.xz;
	float n = vnoise(p * 0.22) * 0.55 + vnoise(p * 1.1) * 0.3 + vnoise(p * 6.0) * 0.15 * detail;
	vec3 c = mix(grass_a.rgb, grass_b.rgb, mix(0.5, n, detail));
	float r = max(abs(p.x), abs(p.y)) - board_half;
	c *= mix(0.62, 1.0, smoothstep(0.0, 2.2, r));
	c = mix(c, far_color.rgb, smoothstep(fade_start, fade_end, length(p)));
	ALBEDO = c;
	ROUGHNESS = 0.95;
	SPECULAR = 0.15;
}
