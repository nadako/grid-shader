package main

import "core:log"
import "core:math/linalg"
import sdl "vendor:sdl3"
import im "shared:imgui"

shader_grid_vert_code := #load("../grid.spv.vert")
shader_grid_frag_code := #load("../grid.spv.frag")

Vec3 :: [3]f32
Mat4 :: matrix[4,4]f32

Globals :: struct {
	grid_pipeline: ^sdl.GPUGraphicsPipeline,
	grid: struct {
		size: i32,
		step: f32,
		color: sdl.FColor,
	},
	camera: struct {
		fov: f32,
		position: Vec3,
		target: Vec3,
	},
	clear_color: sdl.FColor,
}
g: ^Globals

game_init :: proc() {
	g = new(Globals)
	g^ = {
		grid = {
			size = 10,
			step = 1,
			color = {0,0,0,1}
		},
		camera = {
			fov = 70,
			position = {0,10,15},
			target = {0,0,0}
		},
		clear_color = {0, 0.2, 0.4, 1},
	}

	shader_grid_vert := create_shader(shader_grid_vert_code, .VERTEX, num_uniform_buffers = 1)
	shader_grid_frag := create_shader(shader_grid_frag_code, .FRAGMENT, num_uniform_buffers = 1)
	g.grid_pipeline = sdl.CreateGPUGraphicsPipeline(gpu, {
		vertex_shader = shader_grid_vert,
		fragment_shader = shader_grid_frag,
		primitive_type = .LINELIST,
		target_info = {
			num_color_targets = 1,
			color_target_descriptions = &(sdl.GPUColorTargetDescription {
				format = sdl.GetGPUSwapchainTextureFormat(gpu, window)
			})
		},
	})
	sdl.ReleaseGPUShader(gpu, shader_grid_vert)
	sdl.ReleaseGPUShader(gpu, shader_grid_frag)
}

game_new_frame :: proc() {
}

game_event :: proc(ev: ^sdl.Event) {
}

game_update :: proc() {
	if im.Begin("Inspector", flags={.AlwaysAutoResize}) {
		im.ColorEdit4("Clear", transmute(^[4]f32)&g.clear_color)

		im.SeparatorText("Grid")
		im.SliderInt("Size", &g.grid.size, 1, 100)
		im.SliderFloat("Step", &g.grid.step, 0.1, 10)
		im.ColorEdit4("Color", transmute(^[4]f32)&g.grid.color)

		im.SeparatorText("Camera")
		im.DragFloat3("Position", &g.camera.position, 0.1)
		im.DragFloat3("Target", &g.camera.target, 0.1)
	}
	im.End()
}

game_render :: proc(cmd_buf: ^sdl.GPUCommandBuffer, target_tex: ^sdl.GPUTexture) {
	color_target := sdl.GPUColorTargetInfo {
		texture = target_tex,
		load_op = .CLEAR,
		clear_color = g.clear_color
	}
	pass := sdl.BeginGPURenderPass(cmd_buf, &color_target, 1, nil)

	win_size: [2]i32
	sdl.GetWindowSize(window, &win_size.x, &win_size.y)

	p := linalg.matrix4_perspective_f32(g.camera.fov, f32(win_size.x) / f32(win_size.y), 0.0001, 1000)
	v := linalg.matrix4_look_at_f32(g.camera.position, g.camera.target, {0,1,0})
	mvp := p * v

	draw_grid(cmd_buf, pass, g.grid.size, g.grid.step, g.grid.color, mvp)

	sdl.EndGPURenderPass(pass)
}

draw_grid :: proc(cmd_buf: ^sdl.GPUCommandBuffer, render_pass: ^sdl.GPURenderPass, size: i32, step: f32, color: sdl.FColor, mvp: Mat4) {
	color := color

	Grid_Data :: struct {
		mvp: Mat4,
		size: i32,
		step: f32,
	}
	grid_data := Grid_Data {
		mvp = mvp,
		size = size,
		step = step,
	}
	num_lines := u32(grid_data.size + grid_data.size + 2)

	sdl.BindGPUGraphicsPipeline(render_pass, g.grid_pipeline)
	sdl.PushGPUVertexUniformData(cmd_buf, 0, &grid_data, size_of(grid_data))
	sdl.PushGPUFragmentUniformData(cmd_buf, 0, &color, size_of(color))
	sdl.DrawGPUPrimitives(render_pass, 2, num_lines, 0, 0)
}


create_shader :: proc(code: []u8, stage: sdl.GPUShaderStage, num_uniform_buffers: u32 = 0) -> ^sdl.GPUShader {
	return sdl.CreateGPUShader(gpu, {
		code_size = len(code),
		code = raw_data(code),
		stage = stage,
		format = {.SPIRV},
		entrypoint = "main",
		num_uniform_buffers = num_uniform_buffers,
	})
}
