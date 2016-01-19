# GLWindow
Simple package to create an OpenGL window.
It also wraps the window events into React signals.
Supposedly more than one window creation library will be suppported, but so far it just creates them with GLFW.
createwindow will return a screen object which basically just wraps all the signals and exposes the handle to the underlying glfw window.
These are the exposed Signals:
```Julia
Screen.inputs = [
		:insidewindow 					=> Signal(false),
		:open 							=> Signal(true),

		:window_size					=> window_size(Vector{Float64}(width, height),
		:framebuffer_size 				=> Signal(Vector2(0)),
		:windowposition					=> Signal(Vector2(0)),

		:unicodeinput					=> Input('0'),

		:buttonspressed					=> Signal(Set{Int}()),# Set of pressed keyboard keys
		:buttondown						=> Signal(0),
		:buttonreleased					=> Signal(0),

		:mousebuttonspressed			=> Signal(Set{Int}()), # Set of pressed mousekeys
		:mousedown						=> Signal(0),
		:mousereleased					=> Signal(0),

		:mouseposition					=> mouseposition,
		:mouseposition_glfw_coordinates	=> mouseposition_glfw,

		:scroll_x						=> Signal(0),
		:scroll_y						=> Signal(0)
		
	]
=#
```
