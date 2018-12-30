import std.stdio;
import derelict.sfml2.system;
import derelict.sfml2.window;
import derelict.sfml2.graphics;
import derelict.opengl;

import gl;
import terrain;
import drawing;
import shaders : Shader;
import fpscounter;
import chronometer;
import particles;

bool running = true;

class Frame_Time {
	this() {
		fps = new FPSCounter(2f);
		clock = new Chronometer();
	}

	void begin_frame() {
		auto t = sfTime_asSeconds(clock.getElapsedTime());
		dt = t - last_frame;
		last_frame = t;
	}

	void end_frame() {
		fps.update(dt);
	}

	float delta_time() const {
		return dt;
	}

private:
	FPSCounter fps;
	Chronometer clock;
	float dt = 0;
	float last_frame = 0;
}

void main() {
	// Load shared C libraries
	DerelictGL3.load();
	DerelictSFML2System.load();
	DerelictSFML2Window.load();
	DerelictSFML2Graphics.load();

	Terrain terrain;
	if (!load_terrain_image(&terrain, "fg.png", "bg.png")) {
		stderr.writeln("Error loading terrain image.");
		return;
	}

	auto window = create_GL_context_and_window(terrain.size);
	auto winsize = sfWindow_getSize(window);
	glViewport(0, 0, winsize.x, winsize.y);
	debug writefln("winsize: %d, %d", winsize.x, winsize.y);

	const terrain_shader = load_terrain_shader();
	assert(terrain_shader.id != Shader.INVALID_ID);

	const draw_particles_shader = load_draw_particles_shader();
	assert(draw_particles_shader.id != Shader.INVALID_ID);

	const debug_draw_particles_shader = load_debug_draw_particles_shader();
	assert(debug_draw_particles_shader.id != Shader.INVALID_ID);

	auto sim = new Simulation(winsize, 2048);

	const screen_quad = new_quad();
	const particles_vertices = new_vertex_array(sim.particle_positions.size.x * sim.particle_positions.size.y);

	glDisable(GL_CULL_FACE);
	glDisable(GL_DEPTH_TEST);
	glEnable(GL_PROGRAM_POINT_SIZE);
	check_GL_error();

	auto frame_time = new Frame_Time();

	while (running) {
		frame_time.begin_frame();

		process_input(window);

		glClearColor(0.2, 0.3, 0.3, 1.0);
		glClear(GL_COLOR_BUFFER_BIT);

		//draw_terrain(terrain, screen_quad, terrain_shader);
		//draw_particles(sim, particles_vertices, draw_particles_shader);
		debug_draw_particles(sim, particles_vertices, debug_draw_particles_shader);

		sfWindow_display(window);

		frame_time.end_frame();
	}
}

void process_input(sfWindow* window) {
	sfEvent event;
	while (sfWindow_pollEvent(window, &event)) {
		switch (event.type) {
		case sfEvtResized:
			glViewport(0, 0, event.size.width, event.size.height);
			break;
		case sfEvtClosed:
			running = false;
			break;
		case sfEvtKeyPressed:
			switch (event.key.code) {
			case sfKeyQ:
				running = false;
				break;
			default:
				break;
			}
			break;
		default:
			break;
		}
	}
}
