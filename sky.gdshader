// Planet sky: the game's cloud texture seen as a ceiling, fading into the haze color at the
// horizon; airless worlds get the game's star field (SKY3 / SKY4 resource 154, a 512 x 320
// wrapping map), one map pixel per screen pixel of the game's 320-pixel-wide view: the map
// repeats 4 times around the horizon.
shader_type sky;

uniform sampler2D clouds : source_color, filter_linear_mipmap, repeat_enable;
uniform bool has_clouds = true;
uniform sampler2D stars : source_color, filter_nearest, repeat_enable;
uniform bool has_stars = false;
uniform vec3 haze : source_color = vec3(0.7, 0.76, 0.84);
uniform float cloud_scale = 0.22;
uniform float star_pixel = 0.00307;        // radians per star map pixel (TAU / 4 / 512)

float hash(vec3 p) {
	return fract(sin(dot(p, vec3(127.1, 311.7, 74.7))) * 43758.5453);
}

void sky() {
	vec3 d = EYEDIR;
	vec3 col = haze;
	if (d.y > 0.0) {
		if (has_clouds) {
			vec2 uv = d.xz / max(d.y, 0.05) * cloud_scale;
			col = mix(haze, texture(clouds, uv).rgb, smoothstep(0.0, 0.28, d.y));
		} else {
			vec3 top = vec3(0.0);
			if (has_stars) {
				float az = atan(d.z, d.x) + PI;
				float el = asin(clamp(d.y, 0.0, 1.0));
				vec2 px = vec2(az / star_pixel, 320.0 - el / star_pixel);
				vec4 s = texelFetch(stars, ivec2(mod(floor(px), vec2(512.0, 320.0))), 0);
				top = s.a > 0.5 ? s.rgb : vec3(0.0);
			} else {
				float s2 = hash(floor(d * 420.0));
				top = s2 > 0.9975 ? vec3(0.55 + 0.45 * fract(s2 * 97.0)) : vec3(0.0);
			}
			col = mix(haze, top, smoothstep(0.0, 0.08, d.y));
		}
	}
	COLOR = col;
}
