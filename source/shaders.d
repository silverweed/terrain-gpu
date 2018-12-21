module shaders;

import std.stdio;
import derelict.opengl;

import gl;

struct Shader {
	enum INVALID_ID = -1;

	int id;
	alias id this;
}

Shader load_shader(in string vs_file, in string fs_file) {
	import std.file : readText;
	import std.string : toStringz;

	scope (failure) {
		stderr.writefln("Failed to load shader(s): %s, %s", vs_file, fs_file);
		return Shader(Shader.INVALID_ID);
	}

	const vs_id = glCreateShader(GL_VERTEX_SHADER);
	scope (exit) glDeleteShader(vs_id);
	{
		auto vs_code = readText(vs_file);
		const(char)* vs_code_ptr = vs_code.toStringz();
		glShaderSource(vs_id, 1, &vs_code_ptr, null);
		glCompileShader(vs_id);
		check_shader_err!"Vertex"(vs_file, vs_id);
	}

	const fs_id = glCreateShader(GL_FRAGMENT_SHADER);
	scope (exit) glDeleteShader(fs_id);
	{
		auto fs_code = readText(fs_file);
		const(char)* fs_code_ptr = fs_code.toStringz();
		glShaderSource(fs_id, 1, &fs_code_ptr, null);
		glCompileShader(fs_id);
		check_shader_err!"Fragment"(fs_file, fs_id);
	}

	const shader_id = glCreateProgram();
	glAttachShader(shader_id, vs_id);
	glAttachShader(shader_id, fs_id);
	glLinkProgram(shader_id);
	check_shader_err!"Program"(vs_file ~ "+" ~ fs_file, shader_id);

	check_GL_error();

	return Shader(shader_id);
}

private void check_shader_err(string type)(in string file, uint id) {
	enum NULL = cast(int*)0;

	int success = 0;
	char[1024] info_log;
	for (int i = 0; i < info_log.length; ++i)
		info_log[i] = 0;

	static if (type != "Program") {
		glGetShaderiv(id, GL_COMPILE_STATUS, &success);
		if (!success) {
			glGetShaderInfoLog(id, info_log.length, NULL, info_log.ptr);
			stderr.writeln("[ ERR ] ", type, " Shader ", file, " failed to compile: ", info_log);
		}
	} else {
		glGetProgramiv(id, GL_LINK_STATUS, &success);
		if (!success) {
			glGetProgramInfoLog(id, info_log.length, NULL, info_log.ptr);
			stderr.writeln("[ ERR ] Shader ", file, " failed to link: ", info_log);
		}
	}
}
