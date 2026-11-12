// Mặt ô bàn cờ / khối gỗ: vát cạnh giả (pháp tuyến nghiêng + viền sáng ở mép mặt trên),
// nhiễu màu nhẹ theo toạ độ thế giới (không lặp giữa các ô), chuyển màu nhẹ theo chiều sâu ô,
// thành ô tối hơn mặt ô, vân gỗ tuỳ chọn. Một material dùng chung, màu/kích thước là tham số từng ô.
shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

instance uniform vec4 tint : source_color = vec4(1.0);
// nửa kích thước mặt trên (x, z) của khối, đơn vị mét
instance uniform vec2 half_size = vec2(0.58, 0.98);
// độ rộng vùng vát cạnh
instance uniform float bevel = 0.07;
// 0 = không vân gỗ, 1 = vân gỗ rõ
instance uniform float grain = 0.0;
// 0 = tắt nhiễu/chuyển màu (chất lượng Thấp), 1 = bật
uniform float detail = 1.0;

varying vec3 lp;
varying vec3 ln;
varying vec3 wpos;

void vertex() {
	lp = VERTEX;
	ln = NORMAL;
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
	vec3 c = tint.rgb;
	float top = step(0.5, ln.y);
	vec2 wp = wpos.xz;
	// nhiễu 2 tầng + chuyển màu: mép ngoài (z+) hơi trầm, mép trong sáng hơn
	float n = (vnoise(wp * 2.6) - 0.5) * 0.07 + (vnoise(wp * 15.0) - 0.5) * 0.035;
	float grad = -0.04 * (lp.z / max(half_size.y, 0.01));
	c *= 1.0 + (n + grad) * detail;
	if (grain > 0.0) {
		float g = sin((wp.y * 3.0 + wp.x + vnoise(wp * vec2(0.6, 3.5)) * 1.6) * 14.0) * 0.5 + 0.5;
		c *= 1.0 - grain * 0.13 * g * detail;
	}
	// vát cạnh giả ở mặt trên
	vec2 d = half_size - abs(lp.xz);
	float e = min(d.x, d.y);
	float rim = (1.0 - smoothstep(0.0, bevel, e)) * top;
	vec2 outward = d.x < d.y ? vec2(sign(lp.x), 0.0) : vec2(0.0, sign(lp.z));
	if (top > 0.5) {
		vec3 n_obj = normalize(vec3(outward.x * rim * 0.85, 1.0, outward.y * rim * 0.85));
		NORMAL = normalize((VIEW_MATRIX * MODEL_MATRIX * vec4(n_obj, 0.0)).xyz);
	}
	c = mix(c, c * 1.07 + 0.025, rim);
	c *= mix(0.8, 1.0, top);
	ALBEDO = c;
	ROUGHNESS = 0.78;
	SPECULAR = 0.3;
}
