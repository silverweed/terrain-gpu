#version 330 core

precision highp float;

in vec2 in_velocity;

out vec4 out_color;

uniform vec4 color;

const float DELTA = 0.2;

void main() {
	vec2 p = 2.0 * (gl_PointCoord - 0.5);
	float a = smoothstep(1.0 - DELTA, 1.0, length(p));
	float e = 0.0 + length(in_velocity) / 3.0;
	out_color = pow(mix(color, vec4(0, 0, 0, 0), a), vec4(e));
	//out_color = vec4(1.0, 0.0, 0.0, 1.0);
}
