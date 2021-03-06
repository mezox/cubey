
__VS__

layout(location = 0) in vec4 in_vertex_position;

void main() {
	gl_Position = in_vertex_position;
}

__FS__

layout (binding = 0) uniform sampler3D t_density;
layout (binding = 1) uniform sampler3D t_lighting;
layout (binding = 2) uniform sampler3D t_obstacle;
layout (binding = 3) uniform sampler3D t_temperature;

uniform float u_step_size = 1.0/128;
uniform int u_max_steps = 1000;
uniform float u_density_factor = 10.0;

uniform vec3 u_smoke_color[4] = vec3[](vec3(1, 0, 0), vec3(0, 1, 0), vec3(0, 0, 1), vec3(0, 0, 0));

uniform vec3 u_light_color = vec3(1.0);
uniform float u_light_intensity = 100.0;
uniform float u_absorption = 100.0;

uniform vec3 u_obstacle_color = vec3(1.0, 1.0, 1.0);

uniform float u_jittering = 0.5;

uniform float u_ambient = 1.0f;

uniform vec2 u_viewport_size;
uniform mat4 u_inverse_mvp;

uniform float u_temperature_color_falloff = 1.0f;

uniform int u_enable_shadowing = 1;
uniform int u_temperature_color = 0;

out vec4 out_color;

const float pi = 3.1415926535897932384626433832795;

struct Ray {
	vec3 origin;
	vec3 dir;
};

struct AABB {
	vec3 min_pos;
	vec3 max_pos;
};

vec2 IntersectBox(Ray r, AABB aabb) {
	vec3 t_min = (aabb.min_pos - r.origin) / r.dir;
	vec3 t_max = (aabb.max_pos - r.origin) / r.dir;
	vec3 t0 = min(t_min, t_max);
	vec3 t1 = max(t_min, t_max);
	float t_near = max(t0.x, max(t0.y, t0.z));
	float t_far = min(t1.x, min(t1.y, t1.z));
	return vec2(t_near, t_far);
}

float rand_float(vec3 v_in) {
    return fract(sin(dot(v_in ,vec3(12.9898, 78.233, 56.8346))) * 43758.5453);
}

void main() {
	vec4 screen_pos;
	screen_pos.xy = 2.0 * gl_FragCoord.xy / u_viewport_size - 1.0;
	screen_pos.z = - 1 / tan(pi * 30.0 / 180.0);
	screen_pos.x *= u_viewport_size.x / u_viewport_size.y;
	screen_pos.w = 0.0;
	
	vec3 local_dir = normalize((u_inverse_mvp * screen_pos).xyz);
	vec3 local_origin = (u_inverse_mvp * vec4(0,0,0,1)).xyz + vec3(0.5);
	
	Ray eye_ray = Ray(local_origin, local_dir);
	AABB aabb = AABB(vec3(0), vec3(1,1,1));
	
	vec2 t = IntersectBox(eye_ray, aabb);
	if(t.x >= t.y) discard;
	//else {out_color = vec4(0.5,0.5,0.5, 1.0);}
	
	if(t.x < 0) t.x = 0;
	vec3 entry_coord = local_origin + local_dir * t.x;
	vec3 exit_coord = local_origin + local_dir * t.y;

	vec3 tracing_coord = entry_coord + mix(-u_jittering/2.0, u_jittering/2.0, rand_float(entry_coord)) * u_step_size * local_dir;

	//tracing_coord.y /= 2.0;
	//local_dir.y /= 2.0;

	float acc_alpha = 1.0;
	vec3 acc_color = vec3(0);

	for(int i=0; i< u_max_steps; i++) {

		tracing_coord += local_dir * u_step_size;

		if (tracing_coord.x < 0 || tracing_coord.y < 0 || tracing_coord.z < 0 ) break;
		if (tracing_coord.x > 1 || tracing_coord.y > 1 || tracing_coord.z > 1 ) break;

		vec4 density = texture(t_density, tracing_coord) * u_density_factor;
		float sum_density = density.x + density.y + density.z + density.w;
		
		float acc_light = 1.0;
		if (u_enable_shadowing == 1) acc_light = texture(t_lighting, tracing_coord).x;

		float temperature = texture(t_temperature, tracing_coord).x;
		
		float ob = texture(t_obstacle, tracing_coord).x;
		if (ob > 0.2) {
			acc_color += u_obstacle_color * u_light_color * u_light_intensity * acc_light * acc_alpha * u_step_size;
			acc_alpha = 0;
			break;
		}

		if (sum_density <= 0.1 * u_ambient) {
			acc_color += u_light_color * acc_light * acc_alpha * u_ambient * u_step_size;
			acc_alpha *= 1.0 - u_step_size*u_ambient;
		}
		else {
			
			vec3 color = u_smoke_color[0] * density.x + u_smoke_color[1] * density.y + u_smoke_color[2] * density.z + u_smoke_color[3] * density.w;

			if(u_temperature_color == 1) color = mix(color, vec3(0) , exp(-temperature*temperature/u_temperature_color_falloff));

			acc_color += u_light_color * u_light_intensity * acc_light * acc_alpha * u_step_size * color;
			acc_alpha *= exp( - sum_density * u_step_size * u_absorption);
		}
		
		if (acc_alpha <= 0.01) break;

	}
	out_color = vec4(acc_color, 1 - acc_alpha);
}
