shader_type canvas_item;

// Controls the blur strength
uniform float blur_amount : hint_range(0.0, 10.0) = 2.5;

// Adds a color picker in the inspector (defaults to red)
uniform vec4 tint_color : source_color = vec4(1.0, 0.0, 0.0, 0.5);

uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, filter_linear_mipmap;

void fragment() {
    // Get the blurred screen texture
    vec4 blurred_color = textureLod(SCREEN_TEXTURE, SCREEN_UV, blur_amount);
    
    // Mix the blurred screen with the tint color based on the tint's transparency (alpha)
    COLOR = mix(blurred_color, tint_color, tint_color.a);
}
