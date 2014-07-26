# GLWindow
Simple package to create an OpenGL window.
It also wraps the window events into React signals.
Supposedly more than one window creation library will be suppported, but so far it just creates them with GLFW.
createwindow will return a screen object which basically just wraps all the signals and exposes the handle to the underlying glfw window.
These are the exposed Signals:
```Julia
Screen.inputs = [
		:mouseposition					=> Input{Vector2{Float64})},
		:mousedragged 					=> Input{Vector2{Float64})},
		:window_size					=> Input{Vector2{Int})},
		:framebuffer_size 				=> Input{Vector2{Int})},
		:windowposition					=> Input{Vector2{Int})},

		:unicodeinput					=> Input{Char},
		:keymodifiers					=> Input{Int},
		:keypressed 					=> Input{Int},
		:keypressedstate				=> Input{Int},
		:mousebutton 					=> Input{Int},
		:mousepressed					=> Input{Bool},
		:scroll_x						=> Input{Int},
		:scroll_y						=> Input{Int},
		:insidewindow 					=> Input{Bool},
		:open 							=> Input{Bool}
	]
=#
```
