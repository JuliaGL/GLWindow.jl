#version 130

in vec2 frag_uv;

uniform sampler2D color_texture;

out vec4 fragment_color;

void main(){
    fragment_color = texture(color_texture, frag_uv);
}
