shader_type canvas_item;

// Creates a slider in the inspector to adjust the blur strength
uniform float blur_amount : hint_range(0.0, 10.0) = 2.5;

// Grabs the current screen texture with mipmaps enabled
uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, filter_linear_mipmap;

void fragment() {
    // Samples a lower-resolution (blurred) version of the screen
    vec4 blurred_color = textureLod(SCREEN_TEXTURE, SCREEN_UV, blur_amount);
    COLOR = blurred_color;
}