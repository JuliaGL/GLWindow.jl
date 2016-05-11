{{GLSL_VERSION}}

in vec2 frag_uv;

uniform sampler2D sum_color_tex;
uniform sampler2D sum_weight_tex;
uniform sampler2D opaque_color_tex;

layout(location=0) out vec4 fragment_color;

vec3 linear_tone_mapping(vec3 color, float gamma)
{
    color = clamp(color, 0., 1.);
    color = pow(color, vec3(1. / gamma));
    return color;
}

vec3 resolve_color(
        sampler2D sum_color_tex,
        sampler2D sum_weight_tex,
        sampler2D opaque_color,
        vec2 frag_uv
    ){
    float transmittance = texture(sum_weight_tex, frag_uv).r;
    vec4 color = texture(opaque_color, frag_uv).rgba;
    vec4 sum_color = texture(sum_color_tex, frag_uv);
    vec3 average_color = sum_color.rgb / max(sum_color.a, 0.00001);
    return average_color * (1 - transmittance) + (color.rgb*color.a) * transmittance;
}

void main(void)
{
    // resolve transparency
    vec3 opaque = resolve_color(sum_color_tex, sum_weight_tex, opaque_color_tex, frag_uv);

    // do tonemapping
    //opaque = linear_tone_mapping(opaque, 2.0);  // linear color output
    fragment_color.rgb = opaque; // gamma 2.0 color output
    // save luma in alpha for FXAA
    fragment_color.a = dot(opaque, vec3(0.299, 0.587, 0.114)); // compute luma
}
