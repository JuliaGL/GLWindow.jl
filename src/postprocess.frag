{{GLSL_VERSION}}

in vec2 frag_uv;

uniform sampler2D color_texture;

layout(location=0) out vec4 fragment_color;

vec3 linear_tone_mapping(vec3 color, float gamma)
{
    color = clamp(color, 0., 1.);
    color = pow(color, vec3(1. / gamma));
    return color;
}

void main(void)
{
    vec3 opaque = texture(color_texture, frag_uv).rgb;
    // do tonemapping
    //opaque = linear_tone_mapping(opaque, 1.8);  // linear color output
    fragment_color.rgb = opaque;
    // save luma in alpha for FXAA
    fragment_color.a = dot(opaque.rgb, vec3(0.299, 0.587, 0.114)); // compute luma
}
