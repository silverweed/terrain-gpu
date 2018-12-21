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

	auto window = create_GL_context_and_window(terrain.pixel_size);
	auto winsize = sfWindow_getSize(window);
	glViewport(0, 0, winsize.x, winsize.y);

	const terrain_shader = load_terrain_shader();
	assert(terrain_shader.id != Shader.INVALID_ID);

	const screen_quad = new_quad();

	glDisable(GL_CULL_FACE);
	glDisable(GL_DEPTH_TEST);

	auto frame_time = new Frame_Time();

	while (running) {
		frame_time.begin_frame();

		process_input(window);

		glClearColor(0.2, 0.3, 0.3, 1.0);
		glClear(GL_COLOR_BUFFER_BIT);

		draw_terrain(terrain, screen_quad, terrain_shader);

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

void draw_terrain(in Terrain terrain, in Quad screen_quad, in Shader terrain_shader) {
	glUseProgram(terrain_shader);

	glUniform1i(glGetUniformLocation(terrain_shader, "fgtex"), 0);
	glActiveTexture(GL_TEXTURE0);
	glBindTexture(GL_TEXTURE_2D, sfTexture_getNativeHandle(terrain.fgtex));

	glUniform1i(glGetUniformLocation(terrain_shader, "bgtex"), 1);
	glActiveTexture(GL_TEXTURE1);
	glBindTexture(GL_TEXTURE_2D, sfTexture_getNativeHandle(terrain.bgtex));

	glBindVertexArray(screen_quad);
	glDrawElements(GL_TRIANGLES, 6, GL_UNSIGNED_INT, cast(const(void)*)0);
	glBindVertexArray(0);
}
