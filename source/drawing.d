module drawing;

import std.stdio;
import derelict.opengl;
import derelict.sfml2.system;

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
	glBufferData(GL_ARRAY_BUFFER, vertices.sizeof, &vertices, GL_STATIC_DRAW);

	glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, ebo);
	glBufferData(GL_ELEMENT_ARRAY_BUFFER, indices.sizeof, &indices, GL_STATIC_DRAW);

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

struct Vertex_Array_2D {
	sfVector2u size;
	uint vao;

	alias vao this;
}

const(Vertex_Array_2D) new_vertex_array_2D(uint nx, uint ny) {
	uint vbo, vao;

	glGenVertexArrays(1, &vao);
	glGenBuffers(1, &vbo);

	glBindVertexArray(vao);

	struct Vertex {
		float x;
		float y;
	}

	auto vertices = new Vertex[nx * ny];
	for (int x = 0; x < nx; ++x) {
		for (int y = 0; y < ny; ++y) {
			immutable i = 2 * (nx * y + x);
			vertices[i] = Vertex(x, y);
		}
	}

	glBindBuffer(GL_ARRAY_BUFFER, vbo);
	glBufferData(GL_ARRAY_BUFFER, Vertex.sizeof * vertices.length, &vertices, GL_STATIC_DRAW);

	// Position
	glVertexAttribPointer(0, 2, GL_FLOAT, GL_FALSE, Vertex.sizeof, cast(void*)0);
	glEnableVertexAttribArray(0);

	// Cleanup
	glBindBuffer(GL_ARRAY_BUFFER, 0);
	glBindVertexArray(0);

	check_GL_error();

	return Vertex_Array_2D(sfVector2u(nx, ny), vao);
}

const(Shader) load_terrain_shader() {
	return load_shader("shaders/fullscreen.vert", "shaders/fullscreen.frag");
}

const(Shader) load_draw_particles_shader() {
	return load_shader("shaders/draw_particles.vert", "shaders/draw_particles.frag");
}
