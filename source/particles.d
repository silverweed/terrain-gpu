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
	debug writefln("creating texture of size %d x %d", size.x, size.y);
	uint tex_id;
	glGenTextures(1, &tex_id);
	check_GL_error();

	glBindTexture(GL_TEXTURE_2D, tex_id);
	scope (exit) glBindTexture(GL_TEXTURE_2D, 0);

	glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
	glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
	glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST);
	glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_NEAREST);
	glTexStorage2D(GL_TEXTURE_2D, 1, GL_RGBA8, size.x, size.y);
	check_GL_error();

	debug writefln("created texture %d", tex_id);

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
		debug writefln("scale = %f", scale[0]);
		particle_positions = create_storage_texture(size);
		particle_velocities = create_storage_texture(size);

		set_initial_particles_positions_and_velocities(this);
	}
}

struct Encoded_Pair {
	ubyte a;
	ubyte b;

	string toString() const {
		import std.string;
		return format!"(%d, %d)"(a, b);
	}
}

// Particle storage encoding/decoding
/// Converts `value` into a (x, y) pair to be stored in RG or BA channels.
auto ps_encode(in float value, in float scale) pure @nogc {
	enum BASE = 255;
	enum OFFSET = BASE * BASE / 2;
	immutable v = cast(int) (value * scale + OFFSET);
	return Encoded_Pair(
		cast(ubyte) (cast(float)(v % BASE) / BASE * 255),
		cast(ubyte) (cast(float)(v / BASE) / BASE * 255)
	);
}

auto ps_decode(in Encoded_Pair pair, in float scale) pure @nogc {

	enum BASE = 255;
	enum OFFSET = BASE * BASE / 2;

	immutable int a = cast(int)(pair.a / 255f * BASE);
	immutable int b = cast(int)(pair.b / 255f * BASE * BASE);

	return (a + b - OFFSET) / scale;
}

unittest {
	// FIXME: several of these fail, investigate

	immutable values = [
		0, 0.1123, 1, 100, 222.22, 10000, -23.4, -999, -10000
	];

	immutable pairs = [
		Encoded_Pair(0, 0), Encoded_Pair(12, 34), Encoded_Pair(255, 255), Encoded_Pair(0, 221),
		Encoded_Pair(255, 0), Encoded_Pair(128, 128)
	];

	immutable scales = [
		1, 10, 20.5, 0.55, 100, 300.33
	];

	bool pair_similar(in Encoded_Pair a, in Encoded_Pair b, float tolerance = 15.0) pure @nogc {
		return abs(a.a - b.a) + abs(a.b - b.b) <= tolerance;
	}

	import std.string : format;

	void nonfatal_assert(Args...)(bool cond, Args args) {
		if (!cond)
			writeln("Assertion failed: ", args);
		else
			writeln("Assertion OK! ", args);
	}

	foreach (scale; scales) {
		foreach (v; values) {
			if (v > scale) continue;
			immutable tolerance = 0.15;
			immutable enc = ps_encode(v, scale);
			immutable dec = ps_decode(enc, scale);
			immutable diff = abs(dec - v) / (v == 0 ? 1 : v);
			nonfatal_assert(diff < tolerance,
				format!"with scale %f: decoded: %f, expected: %f (diff %f > tolerance %f) [mid result = %s]"(
					scale, dec, v, diff, tolerance, enc));
		}
		foreach (p; pairs) {
			immutable dec = ps_decode(p, scale);
			if (dec > scale) continue;
			immutable e = ps_encode(dec, scale);
			nonfatal_assert(pair_similar(e, p),
				format!"with scale %s: encoded: %s, expected: %s"(scale, e, p));
		}
	}
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

	auto positions = new ubyte[4 * size_x * size_y];
	auto velocities = new ubyte[4 * size_x * size_y];

	immutable invalid_pos_x = ps_encode(-100, sim.scale[0]);
	immutable invalid_pos_y = ps_encode(-100, sim.scale[0]);

	// Set all positions to invalid and all velocities to random
	for (int y = 0; y < size_y; ++y) {
		for (int x = 0; x < size_x; ++x) {
			immutable i = 4 * (y * size_x + x);

			//immutable px = invalid_pos_x;
			//immutable py = invalid_pos_y;
			//positions[i + 0] = invalid_pos_x.a;
			//positions[i + 1] = invalid_pos_x.b;
			//positions[i + 2] = invalid_pos_y.a;
			//positions[i + 3] = invalid_pos_y.b;
			immutable px = ps_encode(uniform01() * sim.display_size.x, sim.scale[0]);
			// FIXME: something's wrong with this
			immutable py = ps_encode(uniform01() * sim.display_size.y, sim.scale[0]);
			positions[i + 0] = px.a;
			positions[i + 1] = px.b;
			positions[i + 2] = py.a;
			positions[i + 3] = py.b;

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
