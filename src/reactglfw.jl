using GLFW, React, ImmutableArrays, ModernGL, GLUtil
import GLFW.Window, GLUtil.update, GLFW.Monitor, GLUtil.render
export UnicodeInput, KeyPressed, MouseClicked, MouseMoved, EnteredWindow, WindowResized
export MouseDragged, Scrolled, Window, renderloop, leftbuttondragged, middlebuttondragged, rightbuttondragged, leftclickup, leftclickdown



immutable MonitorProperties
	name::ASCIIString
	isprimary::Bool
	position::Vector2
	physicalsize::Vector2
	#gamma::Float64
	gammaramp::GLFW.GammaRamp
	videomode::GLFW.VidMode
	videomode_supported::Vector{GLFW.VidMode}
	dpi::Vector2
	monitor::Monitor
end

function MonitorProperties(monitor::Monitor)
	name 				= GLFW.GetMonitorName(monitor)
	isprimary 			= GLFW.GetPrimaryMonitor() == monitor
	position			= Vector2(GLFW.GetMonitorPos(monitor)...)
	physicalsize		= Vector2(GLFW.GetMonitorPhysicalSize(monitor)...)
	gammaramp 			= GLFW.GetGammaRamp(monitor)
	videomode 			= GLFW.GetVideoMode(monitor)

	dpi					= Vector2(videomode.width * 25.4, videomode.height * 25.4) ./ physicalsize
	videomode_supported = GLFW.GetVideoModes(monitor)

	MonitorProperties(name, isprimary, position, physicalsize, gammaramp, videomode, videomode_supported, dpi, monitor)
end

function Base.show(io::IO, m::MonitorProperties)
	println(io, "name: ", m.name)
	println(io, "physicalsize: ",  m.physicalsize[1], "x", m.physicalsize[2])
	println(io, "resolution: ", m.videomode.width, "x", m.videomode.height)
	println(io, "dpi: ", m.dpi[1], "x", m.dpi[2])
end

immutable Screen
	id::Symbol
	parent::Screen
	children::Vector{Screen}
	inputs::Dict{Symbol, Any}
	renderList::Vector{Any}
	glfwWindow::Window
	function Screen(id::Symbol,
					children::Vector{Screen},
					inputs::Dict{Symbol, Any},
					renderList::Vector{Any})
		parent = new()
		new(id::Symbol, parent, children, inputs, renderList, GLFW.NullWindow)
	end
	function Screen(id::Symbol,
					parent::Screen,
					children::Vector{Screen},
					inputs::Dict{Symbol, Any},
					renderList::Vector{Any},
					glfwWindow::Window)
		new(id::Symbol, parent, children, inputs, renderList, glfwWindow)
	end
end
const ROOT_SCREEN = Screen(:root, Screen[], Dict{Symbol, Any}(), {})

const WINDOW_TO_SCREEN_DICT = Dict{Window, Screen}()

function update(window::Window, key::Symbol, value)
	screen = WINDOW_TO_SCREEN_DICT[window]
	input = screen.inputs[key]
	if input.value != value
		push!(input, value)
	end
end

function window_closed(window)
	update(window, :open, false)
    return nothing
end

function window_resized(window, w::Cint, h::Cint)
	update(window, :window_size, Vector2(int(w), int(h)))
    return nothing
end
function framebuffer_size(window, w::Cint, h::Cint)
	update(window, :framebuffer_size, Vector2(int(w), int(h)))
    return nothing
end
function window_position(window, x::Cint, y::Cint)
	update(window, :windowposition, Vector2(int(x),int(y)))
    return nothing
end


function key_pressed(window::Window, key::Cint, scancode::Cint, action::Cint, mods::Cint)
	update(window, :keyboardpressed, int(key))
	update(window, :keyboardpressedstate, int(action))
	update(window, :keyboardmodifiers, int(mods))
	return nothing
end
function mouse_clicked(window::Window, button::Cint, action::Cint, mods::Cint)
	update(window, :mousebutton, int(button))
	update(window, :keyboardmodifiers, int(mods))
	update(window, :mousepressed, action == 1)
	return nothing
end

function unicode_input(window::Window, c::Cuint)
	update(window, :unicodeinput, char(c))
	return nothing
end

function cursor_position(window::Window, x::Cdouble, y::Cdouble)
	update(window, :mouseposition_glfw_coordinates, Vector2(float64(x), float64(y)))
	return nothing
end
function scroll(window::Window, xoffset::Cdouble, yoffset::Cdouble)
	screen = WINDOW_TO_SCREEN_DICT[window]
	push!(screen.inputs[:scroll_x], int(xoffset))
	push!(screen.inputs[:scroll_y], int(yoffset))

	return nothing
end
function entered_window(window::Window, entered::Cint)
	update(window, :insidewindow, entered == 1)
	return nothing
end

function renderloop(window)
		# Loop until the user closes the window
	while !GLFW.WindowShouldClose(window.glfwWindow)
		glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT)

		renderLoop()

		GLFW.SwapBuffers(window.glfwWindow)
		GLFW.PollEvents()
	end
	GLFW.Terminate()
end
function openglerrorcallback(
				source::GLenum, typ::GLenum,
				id::GLuint, severity::GLenum,
				length::GLsizei, message::Ptr{GLchar},
				userParam::Ptr{Void}
			)
	errormessage = 	"\n"*
					" ________________________________________________________________\n"* 
					"|\n"*
					"| OpenGL Error!\n"*
					"| source: $(GLENUM(source).name) :: type: $(GLENUM(typ).name)\n"*
					"| "*ascii(bytestring(message, length))*"\n"*
					"|________________________________________________________________\n"

	if typ == GL_DEBUG_TYPE_PERFORMANCE
		println(errormessage)
	else
		error(errormessage)
	end
	nothing
end

global const _openglerrorcallback = cfunction(openglerrorcallback, Void,
										(GLenum, GLenum,
										GLuint, GLenum,
										GLsizei, Ptr{GLchar},
										Ptr{Void}))

function createWindow(name::String, w, h; debugging = true)
	GLFW.Init()

	GLFW.WindowHint(GLFW.SAMPLES, 4)
	@osx_only begin
		if debugging
			println("warning: OpenGL debug message callback not available on osx")
			debugging = false
		end
		GLFW.WindowHint(GLFW.CONTEXT_VERSION_MAJOR, 3)
		GLFW.WindowHint(GLFW.CONTEXT_VERSION_MINOR, 3)
		GLFW.WindowHint(GLFW.OPENGL_FORWARD_COMPAT, GL_TRUE)
		GLFW.WindowHint(GLFW.OPENGL_PROFILE, GLFW.OPENGL_CORE_PROFILE)
	end
	
	GLFW.WindowHint(GLFW.OPENGL_DEBUG_CONTEXT, debugging)

	window = GLFW.CreateWindow(w, h, name)
	GLFW.MakeContextCurrent(window)
	if debugging
		glDebugMessageCallbackARB(_openglerrorcallback, C_NULL)
	end

	GLFW.SetWindowCloseCallback(window, window_closed)
	GLFW.SetWindowSizeCallback(window, window_resized)
	GLFW.SetWindowPosCallback(window, window_position)
	GLFW.SetKeyCallback(window, key_pressed)
	GLFW.SetCharCallback(window, unicode_input)
	GLFW.SetMouseButtonCallback(window, mouse_clicked)
	GLFW.SetCursorPosCallback(window, cursor_position)
	GLFW.SetScrollCallback(window, scroll)
	GLFW.SetCursorEnterCallback(window, entered_window)
	GLFW.SetFramebufferSizeCallback(window, framebuffer_size)

	window_size 		= Input(Vector2(0))
	mouseposition_glfw 	= Input(Vector2(0.0))
	mouseposition 		= lift((mouse, window) -> Vector2(mouse[1], window[2] - mouse[2]), Vector2{Float64}, mouseposition_glfw, window_size)
	mousebutton 		= Input(0)
	mousepressed		= Input(false)

	mousedragged 		= filter(_ -> mousepressed.value, Vector2(0.0), mouseposition)
	
	inputs = [
		:mouseposition					=> mouseposition,
		:mouseposition_glfw_coordinates	=> mouseposition_glfw,
		:mousedragged 					=> mousedragged,
		:window_size					=> window_size,
		:framebuffer_size 				=> Input(Vector2(0,0)),
		:windowposition					=> Input(Vector2(0,0)),

		:unicodeinput					=> Input('0'),
		:keyboardmodifiers				=> Input(0),
		:keyboardpressed 				=> Input(0),
		:keyboardpressedstate			=> Input(0),
		:mousebutton 					=> mousebutton,
		:mousepressed					=> mousepressed,
		:scroll_x						=> Input(0),
		:scroll_y						=> Input(0),
		:insidewindow 					=> Input(false),
		:open 							=> Input(true)
	]

	screen = Screen(symbol(name), ROOT_SCREEN, Screen[], inputs, {}, window)
	WINDOW_TO_SCREEN_DICT[window] = screen
	w,h = GLFW.GetWindowSize(window)
	update(window, :window_size, Vector2(int(w), int(h)))

	initGLUtils()
	screen
end



#const monitors = map(MonitorProperties, GLFW.GetMonitors())
#=

const screen = createWindow(:loley, 512, 512)

rect = Rectangle(0.0,0.0,20.0,20.0)

vsh = "
#version 130
in vec2 position;
out vec2 position_o;
uniform mat4 viewproj;
uniform mat4 model;
void main() {
	gl_Position = viewproj * model * vec4(position, 0.0, 1.0);
	position_o = position;
}
"
 
fsh = "
#version 130
out vec4 outColor;
in vec2 position_o;


void main() {
	float circle_radius = 0.5;
	vec4 circle_color = vec4(1.0, 0.0, 0.0, 1.0);
	vec2 circle_center = vec2(0.5, 0.5);
	float dist = length(circle_center - position_o);

    outColor = mix(vec4(.90, .90, .90, 1.0), vec4(.20, .20, .40, 1.0),smoothstep(0.492, 0.5, dist));
}
"

GLFW.GetWindowAttrib
function update(shader::GLProgram, source::ASCIIString, typ)

end
#shader = lift( (vert) -> GLProgram(vert, frag, "test"), Vector2{Float64}, vsh)
circle = Circle(0.0,0.0, 50.0)

cam = OrthogonalCamera()
resize(512, 512, cam)

const global circle_model = eye(Float32, 4,4)

const global circle_data = RenderObject([
	:indexes 		=> GLBuffer(GLuint[0, 1, 2,  2, 3, 0], 1, bufferType = GL_ELEMENT_ARRAY_BUFFER),
	:position		=> GLBuffer(GLfloat[0,0,  1,0,  1,1,  0,1], 2),
	:viewproj		=> cam,
	:model			=> circle_model
	], GLProgram(vsh, fsh, "circle"))

function render(x::Circle)
	circle_model = Float32[x.r 0 0 x.x ; 0 x.r 0 x.y ; 0 0 1 0 ; 0 0 0 1]
	render(circle_data)
end


renderloop(screen.glfwWindow)
=#
