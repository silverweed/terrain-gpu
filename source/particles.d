module particles;

debug import std.stdio;
import std.math;
import std.algorithm;
import derelict.opengl;
import derelict.sfml2.system;

import gl;

struct Texture {
	enum INVALID_ID = -1;

	sfVector2u size;
	int id;

	alias id this;
}

/// Creates an empty texture with the given size, storing 4 bytes per pixel
Texture create_storage_texture(in sfVector2u size) {
	uint tex_id;
	glGenTextures(1, &tex_id);
	check_GL_error();

	glBindTexture(GL_TEXTURE_2D, tex_id);
	scope (exit) glBindTexture(GL_TEXTURE_2D, 0);

	glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
	glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
	glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST);
	glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_NEAREST);
	glTexStorage2D(GL_TEXTURE_2D, 0, GL_RGBA, size.x, size.y);

	return Texture(size, tex_id);
}

class Simulation {
	sfVector2u display_size;
	ulong n_particles;
	float[2] scale;
	/// RG -> x, BA -> y
	Texture particle_positions;
	/// RG -> vx, BA -> vy
	Texture particle_velocities;

	this(in sfVector2u display_size, in ulong n_particles) {
		immutable size = sfVector2u(
			cast(uint) ceil(sqrt(cast(double) n_particles)),
			cast(uint) floor(sqrt(cast(double) n_particles)));

		this.display_size = display_size;

		// asspulled from https://github.com/skeeto/webgl-particles/blob/master/js/particles.js#L15
		immutable s = floor(cast(float) 255 * 255 / max(display_size.x, display_size.y) / 3);
		scale = [s, s * 100];
		debug writefln("creating textures of size %d x %d", size.x, size.y);
		particle_positions = create_storage_texture(size);
		particle_velocities = create_storage_texture(size);

		set_initial_particles_positions_and_velocities(this);
	}
}

struct Encoded_Pair {
	byte a;
	byte b;
}

// Particle storage encoding/decoding
/// Converts `value` into a (x, y) pair to be stored in RG or BA channels.
auto ps_encode(in float value, in float scale) pure @nogc {
	enum BASE = 255;
	enum OFFSET = BASE * BASE / 2;
	immutable v = cast(int) (value * scale + OFFSET);
	return Encoded_Pair(
		cast(byte) ((v % BASE) / BASE * 255),
		cast(byte) ((v / BASE) / BASE * 255)
	);
}

auto ps_decode(in Encoded_Pair pair, in float scale) pure @nogc {
	enum BASE = 255;
	enum OFFSET = BASE * BASE / 2;
	return (((pair.a / 255) * BASE + (pair.b / 255) * BASE * BASE) - OFFSET) / scale;
}

void set_initial_particles_positions_and_velocities(Simulation sim)
in {
	assert(sim.particle_positions.id != Texture.INVALID_ID);
	assert(sim.particle_velocities.id != Texture.INVALID_ID);
	assert(sim.particle_positions.size == sim.particle_velocities.size);
	assert(sim.display_size.x > 0);
	assert(sim.display_size.y > 0);
}
do {
	import std.random : uniform01;

	immutable size_x = sim.particle_positions.size.x;
	immutable size_y = sim.particle_positions.size.y;

	byte[] positions = new byte[4 * size_x * size_y];
	byte[] velocities = new byte[4 * size_x * size_y];

	immutable invalid_pos_x = ps_encode(100, sim.scale[0]);
	immutable invalid_pos_y = ps_encode(100, sim.scale[0]);

	// Set all positions to invalid and all velocities to random
	for (int y = 0; y < size_y; ++y) {
		for (int x = 0; x < size_x; ++x) {
			immutable i = 4 * (y * size_x + x);

			immutable px = invalid_pos_x;
			immutable py = invalid_pos_y;
			positions[i + 0] = invalid_pos_x.a;
			positions[i + 1] = invalid_pos_x.b;
			positions[i + 2] = invalid_pos_y.a;
			positions[i + 3] = invalid_pos_y.b;

			immutable vx = ps_encode(uniform01() - 0.5, sim.scale[1]);
			immutable vy = ps_encode(uniform01() * 2.5, sim.scale[1]);
			velocities[i + 0] = vx.a;
			velocities[i + 1] = vx.b;
			velocities[i + 2] = vy.a;
			velocities[i + 3] = vy.b;
		}
	}

	glBindTexture(GL_TEXTURE_2D, sim.particle_positions);
	glTexSubImage2D(GL_TEXTURE_2D, 0, 0, 0, size_x, size_y, GL_RGBA, GL_UNSIGNED_BYTE, positions.ptr);

	glBindTexture(GL_TEXTURE_2D, sim.particle_velocities);
	glTexSubImage2D(GL_TEXTURE_2D, 0, 0, 0, size_x, size_y, GL_RGBA, GL_UNSIGNED_BYTE, velocities.ptr);

	glBindTexture(GL_TEXTURE_2D, 0);
}
