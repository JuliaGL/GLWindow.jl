using GLFW, React, ImmutableArrays, ModernGL, GLUtil
import GLFW.Window, GLUtil.update, GLFW.Monitor
export UnicodeInput, KeyPressed, MouseClicked, MouseMoved, EnteredWindow, WindowResized
export MouseDragged, Scrolled, Window, renderloop, leftbuttondragged, middlebuttondragged, rightbuttondragged, leftclickup, leftclickdown


include("enum.jl")

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

	dpi					= Vector2(videomode.width / 25.4, videomode.height / 25.4) ./ physicalsize
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
	inputs::Dict{Symbol, Input}
	renderList::Vector{Any}
	function Screen(id::Symbol,
					children::Vector{Screen},
					inputs::Dict{Symbol, Input},
					renderList::Vector{Any})
		parent = new()
		new(id::Symbol, parent, children, inputs, renderList)
	end
	function Screen(id::Symbol,
					parent::Screen,
					children::Vector{Screen},
					inputs::Dict{Symbol, Input},
					renderList::Vector{Any})
		new(id::Symbol, parent, children, inputs, renderList)
	end
end
const ROOT_SCREEN = Screen(:root, Screen[], Dict{Symbol, Input}(), {})

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
	update(window, :window_width, int(w))
	update(window, :window_height, int(h))
    return nothing
end

function window_position(window, x::Cint, y::Cint)
	update(window, :windowposition_x, int(x))
	update(window, :windowposition_y, int(y))
    return nothing
end


function key_pressed(window::Window, key::Cint, scancode::Cint, action::Cint, mods::Cint)
	update(window, :keyboardpressed, int(key))
	update(window, :keyboardpressedstate, int(action))
	update(window, :keyboardmodifiers, int(mods))

	return nothing
end
function mouse_clicked(window::Window, button::Cint, action::Cint, mods::Cint)
	update(window, :mousepressed, int(button))
	update(window, :keyboardmodifiers, int(mods))
	update(window, :mousepressedstate, int(action))

	return nothing
end

function unicode_input(window::Window, c::Cuint)
	update(window, :unicodeinput, char(c))
	return nothing
end

function cursor_position(window::Window, x::Cdouble, y::Cdouble)
		screen = WINDOW_TO_SCREEN_DICT[window]
		wh = screen.inputs[:window_height].value
		update(window, :mouseposition_x, float64(x))
		update(window, :mouseposition_y, wh - float64(y))
	return nothing
end
function scroll(window::Window, xoffset::Cdouble, yoffset::Cdouble)
	update(window, :scrolldiff_x, int(xoffset))
	update(window, :scrolldiff_y, int(yoffset))
	return nothing
end
function entered_window(window::Window, entered::Cint)
	update(window, :insidewindow, entered == 1)
	return nothing
end

function renderloop(window)
		# Loop until the user closes the window
	while !GLFW.WindowShouldClose(window)
		#test(shape)
		test()
		GLFW.SwapBuffers(window)
		GLFW.PollEvents()
	end
	GLFW.Terminate()
end
function createWindow(name::Symbol, w, h)
	GLFW.WindowHint(GLFW.SAMPLES, 4)
	#GLFW.WindowHint(GLFW.CONTEXT_VERSION_MAJOR, 3)
	#GLFW.WindowHint(GLFW.CONTEXT_VERSION_MINOR, 3)
	#GLFW.WindowHint(GLFW.OPENGL_FORWARD_COMPAT, GL_TRUE)
	#GLFW.WindowHint(GLFW.OPENGL_PROFILE, GLFW.OPENGL_CORE_PROFILE)

	window = GLFW.CreateWindow(w, h, string(name))
	GLFW.MakeContextCurrent(window)

	GLFW.SetWindowCloseCallback(window, window_closed)
	GLFW.SetWindowSizeCallback(window, window_resized)
	GLFW.SetWindowPosCallback(window, window_position)
	GLFW.SetKeyCallback(window, key_pressed)
	GLFW.SetCharCallback(window, unicode_input)
	GLFW.SetMouseButtonCallback(window, mouse_clicked)
	GLFW.SetCursorPosCallback(window, cursor_position)
	GLFW.SetScrollCallback(window, scroll)
	GLFW.SetCursorEnterCallback(window, entered_window)
	inputs = Dict{Symbol,Input}([
		:mouseposition_x		=> Input(0.0),
		:mouseposition_y		=> Input(0.0),

		:unicodeinput			=> Input('0'),

		:window_width			=> Input(0),
		:window_height 			=> Input(0),
		:windowposition_x		=> Input(0),
		:windowposition_y		=> Input(0),

		:keyboardmodifiers		=> Input(0),
		:keyboardpressed 		=> Input(0),
		:keyboardpressedstate	=> Input(0),
		:mousepressed 			=> Input(0),
		:mousepressedstate		=> Input(0),
		:scrolldiff_x			=> Input(0),
		:scrolldiff_y			=> Input(0),
		:insidewindow 			=> Input(false),
		:open 					=> Input(true)
	])

	screen = Screen(name, ROOT_SCREEN, Screen[], inputs, {})
	WINDOW_TO_SCREEN_DICT[window] = screen
	w,h = GLFW.GetWindowSize(window)
	update(window, :window_width, int(w))
	update(window, :window_height, int(h))

	#initGLUtils()
	screen, window
end




function test()
	glClearColor(1f0, 1f0, 1f0, 0f0)   
    glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT)
	
	programID = shape.vertexArray.program.id
	glUseProgram(programID)
	render(shape.uniforms)

	render(:model, Float32[rect.w 0 0 rect.x ; 0 rect.h 0 rect.y ; 0 0 1 0 ; 0 0 0 1], programID)
	
	glBindVertexArray(shape.vertexArray.id)
	glDrawElements(GL_TRIANGLES, shape.vertexArray.indexLength, GL_UNSIGNED_INT, GL_NONE)
	nothing
end


GLFW.Init()


const monitors = map(MonitorProperties, GLFW.GetMonitors())
println(monitors)
const screen, w = createWindow(:loley, 512, 512)

rect = Rectangle(0.0,0.0,20.0,20.0)

lift(Float64, x -> rect.x = x, screen.inputs[:mouseposition_x])
lift(Float64, y -> rect.y = y, screen.inputs[:mouseposition_y])



cam = OrthogonalCamera()

flatshader = GLProgram("flatShader")
const shape = RenderObject(
[
	:indexes 		=> GLBuffer(GLuint[0, 1, 2,  2, 3, 0], 1, bufferType = GL_ELEMENT_ARRAY_BUFFER),
	:position		=> GLBuffer(GLfloat[0,0,  1,0,  1,1,  0,1], 2),
	:uv				=> GLBuffer(GLfloat[0,1,  1,1,  1,0, 0,0], 2),
	:vcolor 		=> GLBuffer([0f0 for i=1:16], 4),

	:textureon		=> 0f0,
	:border			=> 0f0,
	:borderColor	=> Float32[0,0,0,1],
	:mvp  			=> cam,
	:model  		=> eye(Float32, 4, 4)
], flatshader)



renderloop(w)