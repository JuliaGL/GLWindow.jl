#version 110

attribute vec2 position;
attribute vec4 vcolor;
attribute vec2 uv;

varying vec2 o_uv;
varying vec4 o_vcolor;

uniform mat4 mvp;
uniform mat4 model;


void main(){
	gl_Position = mvp * model * vec4(position, 0.0, 1.0);	
	o_uv = uv;
	o_vcolor = vcolor;
}

