// Power suit limb, drawn like the game: a sprite stretched between two joints, turned to face
// the camera around the segment, the view picked from the camera's angle around the limb.
// Node basis: Y = joint a -> joint b (length = world units per sprite pixel), X = soldier forward.
// Mesh: quad in sprite pixels, x across, y along the segment (joint a at y = 0).
shader_type spatial;
render_mode unshaded, cull_disabled;

uniform sampler2DArray views : source_color, filter_linear_mipmap, repeat_disable;
uniform int view_count = 16;      // 16 views all around, or 9 from back to front (torso)

varying flat int layer;
varying flat float flip;

void vertex() {
	vec3 origin = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	vec3 axis = (MODEL_MATRIX * vec4(0.0, 1.0, 0.0, 0.0)).xyz;
	float s = length(axis);
	vec3 ax = axis / s;
	vec3 fwd = normalize((MODEL_MATRIX * vec4(1.0, 0.0, 0.0, 0.0)).xyz);
	vec3 rgt = normalize(cross(fwd, ax));
	vec3 to_cam = CAMERA_POSITION_WORLD - origin;
	vec3 across = cross(ax, to_cam);
	across = length(across) < 1e-6 ? rgt : normalize(across);
	vec3 w = origin + across * (VERTEX.x * s) + ax * (VERTEX.y * s);
	POSITION = PROJECTION_MATRIX * VIEW_MATRIX * vec4(w, 1.0);
	vec3 c = to_cam - ax * dot(to_cam, ax);
	float ang = atan(dot(c, rgt), dot(c, fwd));          // 0 = seen from the front
	flip = 1.0;
	if (view_count >= 16) {
		layer = int(mod(round(8.0 + ang / (TAU / 16.0)), 16.0));
	} else {
		layer = clamp(int(round(8.0 - abs(ang) / (PI / 8.0))), 0, view_count - 1);
		flip = ang < 0.0 ? -1.0 : 1.0;
	}
}

void fragment() {
	vec2 uv = UV;
	if (flip < 0.0) {
		uv.x = 1.0 - uv.x;
	}
	vec4 col = texture(views, vec3(uv, float(layer)));
	if (col.a < 0.5) {
		discard;
	}
	ALBEDO = col.rgb;
}
