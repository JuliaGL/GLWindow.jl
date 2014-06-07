using GLFW, React, ImmutableArrays, ModernGL
import GLFW.Window
export UnicodeInput, KeyPressed, MouseClicked, MouseMoved, EnteredWindow, WindowResized
export MouseDragged, Scrolled, Window, renderloop, leftbuttondragged, middlebuttondragged, rightbuttondragged, leftclickup, leftclickdown


include("enum.jl")

immutable Monitor
	name::ASCIIString
	isprimary::Bool
	position::Bool
	physicalsize_w::Int
	physicalsize_h::Int
	gamma::Float64
	gammaramp::GammaRamp
	videomode::VidMode
	videomode_supported::Vector{VidMode}
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
	update(window, :mouseposition_x, float64(x))
	update(window, :mouseposition_y, float64(y))

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
		glClearColor(1f0, 1f0, 1f0, 0f0)   
	    glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT)
		

		GLFW.SwapBuffers(window)
		GLFW.PollEvents()
	end
	GLFW.Terminate()
end
function createWindow(name::Symbol, w, h)
	GLFW.WindowHint(GLFW.SAMPLES, 4)
	GLFW.WindowHint(GLFW.CONTEXT_VERSION_MAJOR, 3)
	GLFW.WindowHint(GLFW.CONTEXT_VERSION_MINOR, 3)
	GLFW.WindowHint(GLFW.OPENGL_FORWARD_COMPAT, GL_TRUE)
	GLFW.WindowHint(GLFW.OPENGL_PROFILE, GLFW.OPENGL_CORE_PROFILE)

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
	println(typeof(inputs))
	for elem in inputs
		lift(Nothing, (x) -> println(elem[1], ": ", x), elem[2])
	end
	screen = Screen(name, ROOT_SCREEN, Screen[], inputs, {})
	WINDOW_TO_SCREEN_DICT[window] = screen
	#initGLUtils()
	screen, window
end

GLFW.Init()




const a,w = createWindow(:loley, 512, 512)


renderloop(w)