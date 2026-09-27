// Planet sky: the game's cloud texture seen as a ceiling, fading into the haze color at the
// horizon; airless worlds (no cloud texture) get a black sky with stars.
shader_type sky;

uniform sampler2D clouds : source_color, filter_linear_mipmap, repeat_enable;
uniform bool has_clouds = true;
uniform vec3 haze : source_color = vec3(0.7, 0.76, 0.84);
uniform float cloud_scale = 0.22;

float hash(vec3 p) {
	return fract(sin(dot(p, vec3(127.1, 311.7, 74.7))) * 43758.5453);
}

void sky() {
	vec3 d = EYEDIR;
	vec3 col = haze;
	if (d.y > 0.0) {
		vec3 top;
		if (has_clouds) {
			vec2 uv = d.xz / max(d.y, 0.05) * cloud_scale;
			top = texture(clouds, uv).rgb;
			col = mix(haze, top, smoothstep(0.0, 0.28, d.y));
		} else {
			vec3 q = floor(d * 420.0);
			float s = hash(q);
			top = s > 0.9975 ? vec3(0.55 + 0.45 * fract(s * 97.0)) : vec3(0.0);
			col = mix(haze, top, smoothstep(0.0, 0.08, d.y));
		}
	}
	COLOR = col;
}
