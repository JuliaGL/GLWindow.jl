# GLWindow
Simple package to create an OpenGL window.
It also wraps the window events into React signals.
Supposedly more than one window creation library will be suppported, but so far it just creates them with GLFW.
createwindow will return a screen object which basically just wraps all the signals and exposes the handle to the underlying glfw window.
These are the exposed Signals:
```Julia
Screen.inputs = [
		:insidewindow 					=> Input(false),
		:open 							=> Input(true),

		:window_size					=> window_size(Vector{Float64}(width, height),
		:framebuffer_size 				=> Input(Vector2(0)),
		:windowposition					=> Input(Vector2(0)),

		:unicodeinput					=> Input('0'),

		:buttonspressed					=> Input(IntSet()),# Set of pressed keyboard keys
		:buttondown						=> Input(0),
		:buttonreleased					=> Input(0),

		:mousebuttonspressed			=> Input(IntSet()), # Set of pressed mousekeys
		:mousedown						=> Input(0),
		:mousereleased					=> Input(0),

		:mouseposition					=> mouseposition,
		:mouseposition_glfw_coordinates	=> mouseposition_glfw,

		:scroll_x						=> Input(0),
		:scroll_y						=> Input(0)
		
	]
=#
```
