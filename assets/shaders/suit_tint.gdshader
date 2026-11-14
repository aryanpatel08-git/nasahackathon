shader_type canvas_item;
// Recolours the grey parts of the astronaut suit with the player's chosen colour.
// Grey pixels (low saturation) are tinted; the blue visor and dark outline are left alone.

uniform vec4 suit_color : source_color = vec4(0.95, 0.55, 0.2, 1.0);
uniform float strength : hint_range(0.0, 1.0) = 0.85;

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	float mx = max(c.r, max(c.g, c.b));
	float mn = min(c.r, min(c.g, c.b));
	float sat = mx > 0.0 ? (mx - mn) / mx : 0.0;
	if (sat < 0.25) {
		float lum = dot(c.rgb, vec3(0.299, 0.587, 0.114));
		c.rgb = mix(c.rgb, min(suit_color.rgb * lum * 1.3, vec3(1.0)), strength);
	}
	COLOR = c;
}
