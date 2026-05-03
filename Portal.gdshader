shader_type spatial;
// unshaded means no post processing, only renders what the camera is seeing.
render_mode unshaded, cull_disabled;
// albedo texture lets us use the cameras view as a texture (not exactly how it works but close enough)
uniform sampler2D texture_albedo : source_color;


void fragment() {
	// Called for every pixel the material is visible on.
	// grab the xy position of the window rather than the polygon to get the appropriate pixel from the camera viewport
	vec2 base_uv = SCREEN_UV;
	// set the albedo to the color of the pixel taken from the viewport
	vec4 albedo_tex = texture(texture_albedo, base_uv);
	ALBEDO = albedo_tex.rgb;
}

//void light() {
//	// Called for every pixel for every light affecting the material.
//	// Uncomment to replace the default light processing function with this one.
//}
