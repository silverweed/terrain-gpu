module gl;

import derelict.sfml2.system;
import derelict.sfml2.window;
import derelict.opengl;

void check_GL_error() {
	const e = glGetError();
	if (e == GL_NO_ERROR)
		return;

	assert(0, "GL error!");
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

