#version 330 core

in VS_OUT {
	vec2 tex_coords;
} fs_in;

out vec4 out_color;

uniform sampler2D fgtex;
uniform sampler2D bgtex;

void main() {
	vec2 c = fs_in.tex_coords;
	c = vec2(c.x, 1.0 - c.y);
	vec4 fg = texture(fgtex, c);
	if (fg.a == 0.0)
		out_color = vec4(texture(bgtex, c).rgb, 1.0);
	else
		out_color = vec4(fg.rgb, 1.0);
}
