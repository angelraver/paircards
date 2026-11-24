// Crisp Juice Particles - shared helpers.
// sine-free hashes (stable across GPUs, no precision blocks at large inputs)
float cj_hash(float n) { n = fract(n * 0.1031); n *= n + 33.33; n *= n + n; return fract(n); }
float cj_hash2(vec2 p) { vec3 p3 = fract(vec3(p.xyx) * 0.1031); p3 += dot(p3, p3.yzx + 33.33); return fract((p3.x + p3.y) * p3.z); }
float cj_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(cj_hash2(i), cj_hash2(i + vec2(1.0, 0.0)), u.x), mix(cj_hash2(i + vec2(0.0, 1.0)), cj_hash2(i + vec2(1.0, 1.0)), u.x), u.y);
}
float cj_fbm(vec2 p) {
	float s = 0.0;
	float a = 0.5;
	for (int i = 0; i < 4; i++) {
		s += a * cj_noise(p);
		p = p * 2.03 + vec2(1.7, 9.2);
		a *= 0.5;
	}
	return s;
}
float cj_ease_out(float t) { t = clamp(t, 0.0, 1.0); return 1.0 - (1.0 - t) * (1.0 - t) * (1.0 - t); }
float cj_back_out(float t) { t = clamp(t, 0.0, 1.0) - 1.0; return 1.0 + t * t * (2.7 * t + 1.7); }
// signed distance -> coverage, about one pixel of anti-aliasing
float cj_cov(float d) { float w = max(fwidth(d), 1e-4); return clamp(0.5 - d / w, 0.0, 1.0); }
vec2 cj_rot(vec2 p, float a) { float c = cos(a); float s = sin(a); return vec2(c * p.x - s * p.y, s * p.x + c * p.y); }
