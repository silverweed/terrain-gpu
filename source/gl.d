module gl;

import derelict.sfml2.system;
import derelict.sfml2.window;
import derelict.opengl;

import shaders;

void check_GL_error() {
	debug {
		const e = glGetError();
		switch (e) {
		case GL_NO_ERROR: return;
		case GL_INVALID_ENUM:
			assert(0, "GL error: INVALID_ENUM!");
		case GL_INVALID_VALUE:
			assert(0, "GL error: INVALID_VALUE!");
		case GL_INVALID_OPERATION:
			assert(0, "GL error: INVALID_OPERATION!");
		case GL_INVALID_FRAMEBUFFER_OPERATION:
			assert(0, "GL error: INVALID_FRAMEBUFFER_OPERATION!");
		case GL_OUT_OF_MEMORY:
			assert(0, "GL error: OUT_OF_MEMORY!");
		default:
			assert(0, "GL error: UNKNOWN!");
		}
	}
}

sfWindow* create_GL_context_and_window(in sfVector2u size) {
	sfContextSettings ctx_settings;
	ctx_settings.majorVersion = 3;
	ctx_settings.minorVersion = 3;
	ctx_settings.attributeFlags = sfContextCore;

	auto w = sfWindow_create(sfVideoMode(size.x, size.y), "Terrain GPU", sfResize|sfClose, &ctx_settings);
	sfWindow_setActive(w, true);
	DerelictGL3.reload();

	return w;
}

void assert_uniform_active(in Shader program, in string name) {
	import std.string: toStringz;
	assert(glGetUniformLocation(program.id, name.toStringz()) > -1, "Uniform " ~ name ~ " is not active!");
}
