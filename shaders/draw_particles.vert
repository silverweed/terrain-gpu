#version 330 core

precision highp float;

layout (location = 0) in vec2 in_idx;

out vec2 out_vel;

uniform sampler2D positions;
uniform sampler2D velocities;
uniform uvec2 state_size;
uniform uvec2 display_size;
uniform float point_size;
uniform vec2 scale;

const float BASE = 255.0;
const float OFFSET = BASE * BASE * 0.5;

float decode(vec2 channels, float scale) {
	return (dot(channels, vec2(BASE, BASE * BASE)) - OFFSET) / scale;
}

void main() {
	vec4 psample = texture2D(positions, in_idx / state_size);
	vec4 vsample = texture2D(velocities, in_idx / state_size);
	vec2 p = vec2(decode(psample.rg, scale.x), decode(psample.ba, scale.y));
	out_vel = vec2(decode(vsample.rb, scale.x), decode(vsample.ba, scale.y));
	gl_Position = vec4(p / display_size * 2.0 - 1.0, 0.0, 1.0);
	gl_PointSize = point_size;
}
