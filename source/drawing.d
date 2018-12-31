module drawing;

import std.stdio;
import derelict.opengl;
import derelict.sfml2.system;
import derelict.sfml2.graphics;

import particles;
import terrain;
import shaders;
import gl;

private immutable struct Quad_Data {
	struct Vertex {
		GLfloat[2] pos;
		GLfloat[2] texCoord;
	}

	static Vertex[4] elements = [
		// positions      // texCoords
		{ [-1.0f,  1.0f], [0.0f, 1.0f] },
		{ [-1.0f, -1.0f], [0.0f, 0.0f] },
		{ [ 1.0f, -1.0f], [1.0f, 0.0f] },
		{ [ 1.0f,  1.0f], [1.0f, 1.0f] }
	];

	static uint[6] indices = [
		0, 1, 2, 0, 2, 3
	];
}

struct Quad {
	uint vao;
	alias vao this;
}

const(Quad) new_quad() {
	uint vbo, vao, ebo;

	glGenVertexArrays(1, &vao);
	glGenBuffers(1, &vbo);
	glGenBuffers(1, &ebo);

	glBindVertexArray(vao);

	const vertices = Quad_Data.elements;
	const indices = Quad_Data.indices;

	glBindBuffer(GL_ARRAY_BUFFER, vbo);
	glBufferData(GL_ARRAY_BUFFER, vertices.sizeof, vertices.ptr, GL_STATIC_DRAW);

	glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, ebo);
	glBufferData(GL_ELEMENT_ARRAY_BUFFER, indices.sizeof, indices.ptr, GL_STATIC_DRAW);

	// Position
	alias Vertex = Quad_Data.Vertex;
	glVertexAttribPointer(0, 2, GL_FLOAT, GL_FALSE, Vertex.sizeof, cast(void*)Vertex.pos.offsetof);
	glEnableVertexAttribArray(0);

	// Tex coords
	glVertexAttribPointer(1, 2, GL_FLOAT, GL_FALSE, Vertex.sizeof, cast(void*)Vertex.texCoord.offsetof);
	glEnableVertexAttribArray(1);

	// Cleanup
	glBindBuffer(GL_ARRAY_BUFFER, 0);
	glBindVertexArray(0);
	glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, 0);

	check_GL_error();

	return Quad(vao);
}

struct Vertex_Array {
	uint vao;
	uint size;
	alias vao this;
}

const(Vertex_Array) new_vertex_array(uint n)
in {
	assert(n > 0);
}
out (result) {
	assert(result > 0);
}
do {
	uint vbo, vao;

	glGenVertexArrays(1, &vao);
	glGenBuffers(1, &vbo);

	glBindVertexArray(vao);
	check_GL_error();

	auto vertices = new int[n];
	for (int i = 0; i < n; ++i) {
		vertices[i] = i;
	}

	glBindBuffer(GL_ARRAY_BUFFER, vbo);
	glBufferData(GL_ARRAY_BUFFER, uint.sizeof * vertices.length, vertices.ptr, GL_STATIC_DRAW);
	check_GL_error();

	// Position
	glVertexAttribPointer(0, 1, GL_INT, GL_FALSE, int.sizeof, cast(void*)0);
	glEnableVertexAttribArray(0);

	// Cleanup
	glBindBuffer(GL_ARRAY_BUFFER, 0);
	glBindVertexArray(0);
	check_GL_error();

	Vertex_Array va;
	va.size = n;
	va.vao = vao;
	return va;
}

const(Shader) load_terrain_shader() {
	return load_shader("shaders/fullscreen.vert", "shaders/fullscreen.frag");
}

const(Shader) load_draw_particles_shader() {
	return load_shader("shaders/draw_particles.vert", "shaders/draw_particles.frag");
}

const(Shader) load_debug_draw_particles_shader() {
	return load_shader("shaders/debug_draw_particles.vert", "shaders/debug_draw_particles.frag");
}

void draw_terrain(in Terrain terrain, in Quad screen_quad, in Shader shader) {
	glUseProgram(shader);

	{
		glUniform1i(glGetUniformLocation(shader, "fgtex"), 0);
		glActiveTexture(GL_TEXTURE0);
		glBindTexture(GL_TEXTURE_2D, sfTexture_getNativeHandle(terrain.fgtex));
	}

	{
		glUniform1i(glGetUniformLocation(shader, "bgtex"), 1);
		glActiveTexture(GL_TEXTURE1);
		glBindTexture(GL_TEXTURE_2D, sfTexture_getNativeHandle(terrain.bgtex));
	}

	{
		glBindVertexArray(screen_quad);
		glDrawElements(GL_TRIANGLES, 6, GL_UNSIGNED_BYTE, cast(const(void)*)0);
		glBindVertexArray(0);
	}
}

void draw_particles(in Simulation sim, in Vertex_Array vertex_array, in Shader shader) {
	glUseProgram(shader);

	{
		glUniform1i(glGetUniformLocation(shader, "positions"), 0);
		glActiveTexture(GL_TEXTURE0);
		glBindTexture(GL_TEXTURE_2D, sim.particle_positions);
	}

	{
		glUniform1i(glGetUniformLocation(shader, "velocities"), 1);
		glActiveTexture(GL_TEXTURE1);
		glBindTexture(GL_TEXTURE_2D, sim.particle_velocities);
	}

	{
		immutable sim_size = sim.particle_positions.size;
		glUniform2ui(glGetUniformLocation(shader, "state_size"), sim_size.x, sim_size.y);
		glUniform2ui(glGetUniformLocation(shader, "display_size"), sim.display_size.x, sim.display_size.y);
		glUniform1f(glGetUniformLocation(shader, "point_size"), 2f);
		glUniform1f(glGetUniformLocation(shader, "pos_min"), sim.encoding.min_value_pos);
		glUniform1f(glGetUniformLocation(shader, "pos_max"), sim.encoding.max_value_pos);
		glUniform1f(glGetUniformLocation(shader, "vel_min"), sim.encoding.min_value_vel);
		glUniform1f(glGetUniformLocation(shader, "vel_max"), sim.encoding.max_value_vel);
	}

	{
		immutable float[4] col = [1f, 0f, 0f, 1f];
		glUniform4f(glGetUniformLocation(shader, "color"), col[0], col[1], col[2], col[3]);
	}

	{
		glBindVertexArray(vertex_array);
		immutable n_particles = vertex_array.size;
		debug (2) writefln("drawing %d particles", n_particles);
		glDrawArrays(GL_POINTS, 0, n_particles);
		glBindVertexArray(0);
	}
}

void debug_draw_particles(in Simulation sim, in Vertex_Array vertex_array, in Shader shader) {
	glUseProgram(shader);

	{
		glUniform1i(glGetUniformLocation(shader, "positions"), 0);
		glActiveTexture(GL_TEXTURE0);
		glBindTexture(GL_TEXTURE_2D, sim.particle_positions);
	}

	{
		//assert_uniform_active(shader, "display_size");
		//assert_uniform_active(shader, "state_size");
		assert_uniform_active(shader, "pos_min");
		assert_uniform_active(shader, "pos_max");

		immutable sim_size = sim.particle_positions.size;
		glUniform2ui(glGetUniformLocation(shader, "state_size"), sim_size.x, sim_size.y);
		glUniform2ui(glGetUniformLocation(shader, "display_size"), sim.display_size.x, sim.display_size.y);
		glUniform1f(glGetUniformLocation(shader, "pos_min"), sim.encoding.min_value_pos);
		glUniform1f(glGetUniformLocation(shader, "pos_max"), sim.encoding.max_value_pos);
		check_GL_error();
	}

	{
		glBindVertexArray(vertex_array);
		immutable n_particles = vertex_array.size;
		debug (2) writefln("drawing %d particles", n_particles);
		glDrawArrays(GL_POINTS, 0, n_particles);
		glBindVertexArray(0);
	}
}
