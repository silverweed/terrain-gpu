#version 330 core

precision highp float;

layout (location = 0) in uvec2 in_idx;

out vec2 out_pos;

uniform float pos_min;
uniform float pos_max;
uniform sampler2D positions;
uniform uvec2 state_size;
uniform uvec2 display_size;

const float POINT_SIZE = 5.f;

float decode(vec2 channels, float vmin, float vmax) {
	float v = channels.x * 256.0 + channels.y;
	float diff = vmax - vmin;
	return diff / 65535.0 * (v + 65535.0 * vmin / diff);
}

void main() {
	vec4 psample = texture2D(positions, in_idx / state_size);
	vec2 p = vec2(decode(psample.rg, pos_min, pos_max), decode(psample.ba, pos_min, pos_max));
	out_pos = p;
	vec2 sp = vec2(float(in_idx % state_size.x), float(in_idx / state_size.x));
	gl_Position = vec4(
		0.0001 * pos_min + 0.0001 * pos_max + (sp.x / display_size.x * 2.0 - 1.0),
		-0.2 + (1.0 - 2.0 * sp.y / display_size.y),
		0.0, 1.0);
	gl_PointSize = POINT_SIZE;
}
