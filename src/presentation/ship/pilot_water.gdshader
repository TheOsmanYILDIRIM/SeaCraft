shader_type canvas_item;
render_mode unshaded;

// Pilot adaptation of GDQuest's Animated Water and UV Coordinates lesson:
// https://www.gdquest.com/library/godot_3_shaders_introduction/
// Two displaced sine/cosine layers; no demo textures or screen sampling.
varying vec2 world_position;

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

void fragment() {
	vec2 p = world_position * 0.039;
	float a = sin(dot(p, vec2(0.7, 0.6)) + TIME * 0.8 + cos(p.y * 0.38 - TIME * 0.2));
	float b = cos(dot(p, vec2(-0.36, 0.94)) - TIME * 0.55 + sin(p.x * 0.47));
	float value = 0.5 + 0.26 * a + 0.19 * b;
	COLOR = vec4(mix(vec3(0.025, 0.075, 0.095), vec3(0.055, 0.145, 0.165), value), 1.0);
}
