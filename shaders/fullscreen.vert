#version 330 core

layout (location = 0) in vec2 in_pos;
layout (location = 1) in vec2 in_tex_coords;

out VS_OUT {
	vec2 tex_coords;
} vs_out;

void main() {
	vs_out.tex_coords = in_tex_coords;
	gl_Position = vec4(in_pos, 0.0, 1.0);
}
