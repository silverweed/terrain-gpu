module terrain;

import std.stdio;
import derelict.sfml2.graphics;
import derelict.sfml2.system;

struct Terrain {
	/// Pixels per side
	sfVector2u size;

	sfImage* fg;
	sfImage* bg;
	sfTexture* fgtex;
	sfTexture* bgtex;
}

bool load_terrain_image(Terrain* terrain, const(char)* fgfile, const(char)* bgfile) {
	terrain.fg = sfImage_createFromFile(fgfile);
	if (!terrain.fg)
		return false;

	terrain.bg = sfImage_createFromFile(bgfile);
	if (!terrain.bg)
		return false;

	terrain.fgtex = sfTexture_createFromImage(terrain.fg, null);
	if (!terrain.fgtex)
		return false;

	terrain.bgtex = sfTexture_createFromImage(terrain.bg, null);
	if (!terrain.bgtex)
		return false;

	terrain.size = sfImage_getSize(terrain.fg);
	writefln("Loaded a %dx%d terrain.", terrain.size.x, terrain.size.y);

	assert(sfImage_getSize(terrain.fg) == sfImage_getSize(terrain.bg),
		"Bg and Fg image have different sizes!");

	return true;
}
