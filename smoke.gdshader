// Rising smoke column: upright quad turned to the camera, looping through the frames of the
// game's translucent smoke animation (RESTNOBJ 1186); each column starts at its own frame.
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never;

uniform sampler2DArray frames : source_color, filter_linear_mipmap, repeat_disable;
uniform int frame_count = 13;
uniform float fps = 7.0;

void vertex() {
	vec3 origin = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	vec3 to_cam = CAMERA_POSITION_WORLD - origin;
	to_cam.y = 0.0;
	vec3 side = length(to_cam) < 1e-4 ? vec3(1.0, 0.0, 0.0) : normalize(cross(vec3(0.0, 1.0, 0.0), to_cam));
	vec3 w = origin + side * VERTEX.x + vec3(0.0, VERTEX.y, 0.0);
	POSITION = PROJECTION_MATRIX * VIEW_MATRIX * vec4(w, 1.0);
}

void fragment() {
	float phase = fract(sin(dot(NODE_POSITION_WORLD.xz, vec2(12.9898, 78.233))) * 43758.5453);
	float f = mod(floor(TIME * fps + phase * float(frame_count)), float(frame_count));
	vec4 c = texture(frames, vec3(UV, f));
	ALBEDO = c.rgb;
	ALPHA = c.a;
}
