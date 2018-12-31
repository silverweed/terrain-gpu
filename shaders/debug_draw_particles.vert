#version 330 core

precision highp float;

layout (location = 0) in int in_idx;

out vec2 out_pos;

uniform float pos_min;
uniform float pos_max;
uniform sampler2D positions;
uniform uvec2 state_size;
uniform uvec2 display_size;

const float POINT_SIZE = 5.f;

float decode(vec2 channels, float vmin, float vmax) {
	uvec2 pair = uvec2(round(channels.x * 255.0), round(channels.y * 255.0));
	float v = (pair.x << 8) | pair.y;
	float diff = vmax - vmin;
	return diff / 65535.0 * (v + 65535.0 * vmin / diff);
}

void main() {
	vec2 idx2d = vec2(
		float(in_idx % int(state_size.x)),
		float(in_idx / int(state_size.x))
	);
	vec4 psample = texture2D(positions, idx2d / state_size);
	vec2 p = vec2(decode(psample.rg, pos_min, pos_max), decode(psample.ba, pos_min, pos_max));
	out_pos = p;
	gl_Position = vec4(0.000001 * pos_min + 0.000001 * pos_max +
		float(in_idx) * 0.1,
		0.0,
		/*1.0 - 2.0 **/ //idx2d.y / float(state_size.y),
		0.0, 1.0);
	gl_PointSize = POINT_SIZE;
}
