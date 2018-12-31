#version 330 core

precision highp float;

in vec2 in_pos;

out vec4 out_color;

uniform uvec2 display_size;

void main() {
	//out_color = vec4(in_pos.x / float(display_size.x), 0.0, in_pos.y / float(display_size.y), 1.0);
	out_color = vec4(0.7, 0.7, 0.0, 1.0);
}
