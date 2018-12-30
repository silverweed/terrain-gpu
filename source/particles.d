module particles;

debug import std.stdio;
import std.math;
import std.algorithm;
import std.string : format;
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
	enum INVALID_POS = -10;

	sfVector2u display_size;
	ulong n_particles;

	struct Encoding {
		float min_value_pos;
		float max_value_pos;
		float min_value_vel;
		float max_value_vel;
	}
	Encoding encoding;

	/// RG -> x, BA -> y
	Texture particle_positions;
	/// RG -> vx, BA -> vy
	Texture particle_velocities;

	this(in sfVector2u display_size, in ulong n_particles) {
		immutable size = sfVector2u(
			cast(uint) ceil(sqrt(cast(double) n_particles)),
			cast(uint) floor(sqrt(cast(double) n_particles)));

		this.display_size = display_size;

		encoding.min_value_pos = INVALID_POS;
		encoding.max_value_pos = cast(float) max(display_size.x, display_size.y);
		encoding.min_value_vel = -1000;
		encoding.max_value_vel = -encoding.min_value_vel;
		debug writefln("encoding:\nmin pos = %f\nmax pos = %f\nmin vel = %f\nmax vel = %f",
			encoding.min_value_pos, encoding.max_value_pos,
			encoding.min_value_vel, encoding.max_value_vel);

		particle_positions = create_storage_texture(size);
		particle_velocities = create_storage_texture(size);

		set_initial_particles_positions_and_velocities(this);
	}

	invariant {
		assert(encoding.min_value_pos <= INVALID_POS, "min position value should always be <= INVALID_POS!");
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

/// Given a value `x` in range [xmin, xmax], maps it to integer range [OUTMIN, OUTMAX].
int ps_map_to_range(int OUTMIN, int OUTMAX)(in float x, in float xmin, in float xmax) pure
in {
	static assert(OUTMAX > OUTMIN, "OUTMAX is <= OUTMIN!");
	debug {
		assert(xmax > xmin, format!"xmax (%f) is less than xmin (%f)!"(xmax, xmin));
		assert(x >= xmin, format!"given x should be >= %f but is %f!"(xmin, x));
		assert(x <= xmax, format!"given x should be <= %f but is %f!"(xmax, x));
	}
}
out (res) {
	debug {
		assert(res >= OUTMIN, format!"returned value should be >= %d but is %d!"(OUTMIN, res));
		assert(res <= OUTMAX, format!"returned value should be <= %d but is %d!"(OUTMAX, res));
	}
}
do {
	return cast(int) (OUTMAX * (x - xmin) / (xmax - xmin) + OUTMIN);
}

/// Inverse function of ps_map_to_range
float ps_unmap_from_range(int OUTMIN, int OUTMAX)(in int x, in float xmin, in float xmax) pure
in {
	static assert(OUTMAX > OUTMIN);
	debug {
		assert(xmax > xmin, format!"xmax (%f) is less than xmin (%f)!"(xmax, xmin));
		assert(x >= OUTMIN, format!"given x should be >= %d but is %d!"(OUTMIN, x));
		assert(x <= OUTMAX, format!"given x should be <= %d but is %d!"(OUTMAX, x));
	}
}
out (res) {
	debug {
		assert(res >= xmin, format!"returned value should be >= %f but is %f!"(xmin, res));
		assert(res <= xmax, format!"returned value should be <= %f but is %f!"(xmax, res));
	}
}
do {
	immutable diff = xmax - xmin;
	return diff / OUTMAX * (x - OUTMIN + OUTMAX * xmin / diff);
}

// Particle storage encoding/decoding
/// Converts `value` into a (x, y) pair to be stored in RG or BA channels.
auto ps_encode(in float value, in float min_value, in float max_value) pure {
	immutable v = ps_map_to_range!(0, 2^^16-1)(value, min_value, max_value);
	return Encoded_Pair(
		cast(byte) (v >> 8),
		cast(byte)  v
	);
}

auto ps_decode(in Encoded_Pair pair, in float min_value, in float max_value) pure {
	immutable v = (pair.a << 8) | pair.b;
	return ps_unmap_from_range!(0, 2^^16-1)(v, min_value, max_value);
}

unittest {
	immutable values = [
		0, 0.1123, 1, 100, 222.22, 1000, -10, -3.5
	];

	immutable pairs = [
		Encoded_Pair(0, 0), Encoded_Pair(12, 34), Encoded_Pair(255, 255), Encoded_Pair(0, 221),
		Encoded_Pair(255, 0), Encoded_Pair(128, 128)
	];

	immutable min_values = [
		-100, -20.4, -0.44, 0, 1, 10, 20.5, 0.55, 100, 300.33
	];

	immutable max_values = [
		10, 23.1, 0.85, 120, 540.33, 1000
	];

	bool pair_similar(in Encoded_Pair a, in Encoded_Pair b, ubyte tolerance = 1) pure @nogc {
		return abs(a.a - b.a) + abs(a.b - b.b) <= tolerance;
	}

	bool val_similar(T)(in T a, in T b, float tolerance = 0.05) pure @nogc {
		return abs(a - b) <= tolerance;
	}

	void nonfatal_assert(Args...)(bool cond, Args args) {
		if (!cond)
			writeln("Assertion failed: ", args);
		else
			writeln("Assertion OK! ", args);
	}

	immutable min_pair = Encoded_Pair(0, 0);
	immutable max_pair = Encoded_Pair(255, 255);

	foreach (minv; min_values) {
		foreach (maxv; max_values) {
			if (maxv <= minv) continue;

			// Test limits
			immutable minp = ps_encode(minv, minv, maxv);
			nonfatal_assert(pair_similar(minp, min_pair),
				format!"pair %s is not similar to expected %s!"(minp, min_pair));

			immutable maxp = ps_encode(maxv, minv, maxv);
			nonfatal_assert(pair_similar(maxp, max_pair),
				format!"pair %s is not similar to expected %s!"(maxp, max_pair));

			immutable minval = ps_decode(min_pair, minv, maxv);
			nonfatal_assert(val_similar(minval, minv),
				format!"value %f is not similar to expected %f!"(minval, minv));

			immutable maxval = ps_decode(max_pair, minv, maxv);
			nonfatal_assert(val_similar(maxval, maxv),
				format!"value %f is not similar to expected %f!"(maxval, maxv));

			foreach (v; values) {
				if (v < minv || v > maxv) continue;

				enum tolerance = 0.05;
				immutable enc = ps_encode(v, minv, maxv);
				immutable dec = ps_decode(enc, minv, maxv);
				nonfatal_assert(val_similar(dec, v, tolerance),
					format!"with min %f / max %f: decoded: %f, expected: %f (diff %f > tolerance %f) [mid result = %s]"(
						minv, maxv, dec, v, dec - v, tolerance, enc));
			}
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

	immutable encode_pos = (in float x) => ps_encode(x, sim.encoding.min_value_pos, sim.encoding.max_value_pos);
	immutable encode_vel = (in float x) => ps_encode(x, sim.encoding.min_value_vel, sim.encoding.max_value_vel);

	immutable invalid_pos_x = encode_pos(Simulation.INVALID_POS);
	immutable invalid_pos_y = invalid_pos_x;

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
			//immutable px = encode_pos(uniform01() * sim.display_size.x);
			//immutable py = encode_pos(uniform01() * sim.display_size.y);
			immutable px = encode_pos(cast(float)x/size_x * sim.display_size.x);
			immutable py = encode_pos(cast(float)y/size_y * sim.display_size.y);
			positions[i + 0] = px.a;
			positions[i + 1] = px.b;
			positions[i + 2] = py.a;
			positions[i + 3] = py.b;
			//debug writeln(px, ", ", py, " -> (", positions[i+0]/255f, ",",
				//positions[i+1]/255f, ",", positions[i+2]/255f, ",",
				//positions[i+3]/255f,")");
			debug {
				immutable decx = ps_decode(px, sim.encoding.min_value_pos, sim.encoding.max_value_pos);
				assert(decx >= -0.05 && decx <= sim.display_size.x, format!"decoded value is %f!"(decx));
				immutable decy = ps_decode(py, sim.encoding.min_value_pos, sim.encoding.max_value_pos);
				assert(decy >= -0.05 && decy <= sim.display_size.y);
			}

			immutable vx = encode_vel(uniform01() - 0.5);
			immutable vy = encode_vel(uniform01() * 2.5);
			velocities[i + 0] = vx.a;
			velocities[i + 1] = vx.b;
			velocities[i + 2] = vy.a;
			velocities[i + 3] = vy.b;
		}
	}

	glBindTexture(GL_TEXTURE_2D, sim.particle_positions);
	glTexSubImage2D(GL_TEXTURE_2D, 0, 0, 0, size_x, size_y, GL_RGBA, GL_UNSIGNED_BYTE, positions.ptr);

	//glBindTexture(GL_TEXTURE_2D, sim.particle_velocities);
	//glTexSubImage2D(GL_TEXTURE_2D, 0, 0, 0, size_x, size_y, GL_RGBA, GL_UNSIGNED_BYTE, velocities.ptr);

	glBindTexture(GL_TEXTURE_2D, 0);
}
