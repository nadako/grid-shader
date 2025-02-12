package main

import "base:runtime"
import "core:log"
import sdl "vendor:sdl3"
import im "shared:imgui"
import im_sdl3 "shared:imgui/imgui_impl_sdl3"
import im_sdlgpu3 "shared:imgui/imgui_impl_sdlgpu3"

default_context: runtime.Context
window: ^sdl.Window
gpu: ^sdl.GPUDevice

main :: proc() {
	context.logger = log.create_console_logger()
	default_context = context

	sdl.SetLogPriorities(.VERBOSE)
	sdl.SetLogOutputFunction(proc "c" (userdata: rawptr, category: sdl.LogCategory, priority: sdl.LogPriority, message: cstring) {
		context = default_context
		log.debugf("SDL {} [{}]: {}", category, priority, message)
	}, nil)

	ok: bool

	ok = sdl.Init({.VIDEO}); assert(ok)
	window = sdl.CreateWindow("Playground", 1600, 900, {}); assert(window != nil)
	gpu = sdl.CreateGPUDevice({.SPIRV}, true, nil); assert(gpu != nil)
	ok = sdl.ClaimWindowForGPUDevice(gpu, window); assert(ok)

	im.CreateContext()
	im_io := im.GetIO()
	im_sdl3.InitForSDLGPU(window)
	im_sdlgpu3.Init({
		Device = gpu,
		ColorTargetFormat = sdl.GetGPUSwapchainTextureFormat(gpu, window)
	})

	game_init()

	main_loop: for {
		free_all(context.temp_allocator)

		im_sdlgpu3.NewFrame()
		im_sdl3.NewFrame()
		im.NewFrame()

		game_new_frame()

		ev: sdl.Event
		for sdl.PollEvent(&ev) {
			im_sdl3.ProcessEvent(&ev)
			#partial switch ev.type {
				case .QUIT:
					break main_loop
				case .KEY_DOWN:
					if im_io.WantCaptureKeyboard do continue
					if ev.key.scancode == .ESCAPE do break main_loop
			}
			game_event(&ev)
		}

		game_update()

		im.Render()
		im_draw_data := im.GetDrawData()

		cmd_buf := sdl.AcquireGPUCommandBuffer(gpu)
		swapchain_tex: ^sdl.GPUTexture
		ok = sdl.WaitAndAcquireGPUSwapchainTexture(cmd_buf, window, &swapchain_tex, nil, nil); assert(ok)

		if swapchain_tex != nil {
			game_render(cmd_buf, swapchain_tex)
			render_imgui(im_draw_data, cmd_buf, swapchain_tex, .LOAD)
		}

		ok = sdl.SubmitGPUCommandBuffer(cmd_buf); assert(ok)
	}
}

render_imgui :: proc(draw_data: ^im.DrawData, cmd_buf: ^sdl.GPUCommandBuffer, target_tex: ^sdl.GPUTexture, load_op: sdl.GPULoadOp) {
	im_sdlgpu3.PrepareDrawData(draw_data, cmd_buf)
	im_render_pass := sdl.BeginGPURenderPass(cmd_buf, &(sdl.GPUColorTargetInfo {
		texture = target_tex,
		load_op = load_op,
		store_op = .STORE
	}), 1, nil)
	im_sdlgpu3.RenderDrawData(draw_data, cmd_buf, im_render_pass)
	sdl.EndGPURenderPass(im_render_pass)
}
