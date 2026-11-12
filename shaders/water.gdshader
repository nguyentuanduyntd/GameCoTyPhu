// Biển giữa bàn cờ: hai lớp nhiễu trôi chậm ngược chiều tạo gợn sóng, vệt sáng mảnh trên đỉnh sóng,
// pháp tuyến lấy từ độ dốc nhiễu để ánh nắng lấp lánh. `detail` = 0 thì thành mặt nước phẳng (máy yếu).
shader_type spatial;
render_mode specular_schlick_ggx;

uniform vec4 deep : source_color = vec4(0.20, 0.52, 0.79, 1.0);
uniform vec4 shallow : source_color = vec4(0.42, 0.75, 0.92, 1.0);
uniform float detail = 1.0;
uniform float speed = 0.3;

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

// bốn sóng sin khác hướng/bước sóng chồng lên nhau: mượt tuyệt đối (không lộ lưới như nhiễu giá trị)
float waves(vec2 p, float t) {
	return 0.5
		+ 0.17 * sin(dot(p, vec2(0.91, 0.41)) * 2.1 + t * 2.0)
		+ 0.13 * sin(dot(p, vec2(-0.52, 0.85)) * 3.3 + t * 1.6)
		+ 0.10 * sin(dot(p, vec2(0.2, -0.98)) * 4.9 + t * 2.7)
		+ 0.07 * sin(dot(p, vec2(-0.8, -0.6)) * 7.1 - t * 2.3);
}

void fragment() {
	float t = TIME * speed;
	vec2 p = wpos.xz;
	float h = waves(p, t);
	float big = vnoise(p * 0.18 + vec2(t * 0.15, 0.0));   // loang màu lớn, rất mượt ở tỉ lệ này
	vec3 c = mix(deep.rgb, shallow.rgb, 0.3 + (0.22 * smoothstep(0.2, 0.85, h) + 0.18 * big) * detail);
	float crest = smoothstep(0.62, 0.66, h) - smoothstep(0.66, 0.72, h);
	c += crest * 0.05 * detail;
	if (detail > 0.0) {
		float e = 0.06;
		float hx = waves(p + vec2(e, 0.0), t) - h;
		float hz = waves(p + vec2(0.0, e), t) - h;
		vec3 n_world = normalize(vec3(-hx / e * 0.1 * detail, 1.0, -hz / e * 0.1 * detail));
		NORMAL = normalize((VIEW_MATRIX * vec4(n_world, 0.0)).xyz);
	}
	ALBEDO = c;
	ROUGHNESS = 0.22;
	SPECULAR = 0.45;
}
