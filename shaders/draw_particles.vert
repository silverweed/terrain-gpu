#version 330 core

precision highp float;

layout (location = 0) in uvec2 in_idx;

out vec2 out_vel;

uniform sampler2D positions;
uniform sampler2D velocities;
uniform uvec2 state_size;
uniform uvec2 display_size;
uniform float point_size;
uniform float pos_min;
uniform float pos_max;
uniform float vel_min;
uniform float vel_max;

float decode(vec2 channels, float vmin, float vmax) {
	float v = channels.x * 256.0 + channels.y;
	float diff = vmax - vmin;
	return diff / 65535.0 * (v + 65535.0 * vmin / diff);
}

void main() {
	vec4 psample = texture2D(positions, in_idx / state_size);
	vec2 p = vec2(decode(psample.rg, pos_min, pos_max), decode(psample.ba, pos_min, pos_max));

	vec4 vsample = texture2D(velocities, in_idx / state_size);
	out_vel = vec2(decode(vsample.rb, vel_min, vel_max), decode(vsample.ba, vel_min, vel_max));

	gl_Position = vec4(p / display_size * 2.0 - 1.0, 0.0, 1.0);
	gl_PointSize = point_size;
}
