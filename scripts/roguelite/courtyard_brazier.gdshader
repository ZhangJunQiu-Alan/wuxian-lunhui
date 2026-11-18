shader_type spatial;
render_mode unshaded, cull_disabled, blend_mix;

float strand(vec2 p, float shift, float width, float height, float time) {
	float v = p.y / height;
	float sway = sin(v*7.0-time*4.4+shift*9.0)*.064 + sin(v*15.0-time*6.7)*.017;
	float x = abs(p.x - shift - smoothstep(.05,.81,v)*sway);
	float taper = width * pow(max(0.0,1.0-v),.74) * (.74+.26*sin(2.5*v));
	return (1.0-smoothstep(taper*.36,taper+.012,x)) * (1.0-smoothstep(.89,1.03,v)) * smoothstep(-.02,.13,v);
}

void fragment() {
	vec2 q = vec2(UV.x-.5,1.0-UV.y);
	float t = TIME;
	float center = strand(q,.018,.207,.92+.07*sin(t*5.3),t);
	float left = strand(q,-.16,.134,.68+.12*cos(t*6.4),t+.47);
	float right = strand(q,.164,.119,.58+.12*sin(t*7.7),t+1.13);
	float heat = max(center,max(left,right));
	vec3 fire = mix(vec3(1.0,.20,.026),vec3(1.0,.81,.41),heat*(1.0-q.y*.52));
	ALBEDO = fire;
	EMISSION = fire * heat * .67;
	ALPHA = clamp(heat*1.19,0.0,1.0);
}
