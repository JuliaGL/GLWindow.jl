using GLFW
import GLFW.Window
export UnicodeInput, KeyPressed, MouseClicked, MouseMoved, EnteredWindow, WindowResized, MouseDragged

immutable UnicodeInput{T} <: Event
	source::T
	char::Char
end
immutable KeyPressed{T} <: Event
	source::T
	key::Int
	scancode::Int
	action::Int
	mods::Int
end
immutable MouseClicked{T} <: Event
	source::T
	button::Int
	actions::Int
	mods::Int
end
immutable MouseMoved{T} <: Event
	source::T
	x::Float64
	y::Float64
end
immutable EnteredWindow{T} <: Event
	source::T
	entered::Bool
end
immutable WindowResized{T} <: Event
	source::T
	w::Int
	h::Int
end
immutable Scrolled{T} <: Event
	source::T
	xOffet::Float64
	yOffet::Float64
end


const EVENT_HISTORY = Dict{DataType, Any}()

function window_closed(window)
    println("kthxbye...!")
    for elem in RENDER_DICT
       delete!(elem[2])
    end
    return nothing
end

const WINDOW_SIZE = [0,0]
function window_resized(window, w, h)
	WINDOW_SIZE[1] = int(w)
    WINDOW_SIZE[2] = int(h)
    publishEvent(WindowResized(window, int(w), int(h)))
end


function key_pressed(window::Window, key::Cint, scancode::Cint, action::Cint, mods::Cint)
    publishEvent(KeyPressed(window, int(key), int(scancode), int(action), int(mods)))
end
function mouse_clicked(window::Window, button::Cint, actions::Cint, mods::Cint)
	publishEvent(MouseClicked(window, int(button), int(actions), int(mods)))
end

function unicode_input(window::Window, c::Cuint)
	publishEvent(UnicodeInput(window, char(c)))
end

function cursor_position(window::Window, x::Cdouble, y::Cdouble)
	publishEvent(MouseMoved(window, float64(x), float64(y)))
end
function scroll(window::Window, xoffset::Cdouble, yoffset::Cdouble)
	publishEvent(Scrolled(window, float64(xoffset), float64(yoffset)))
end
function entered_window(window::Window, entered::Cint)
	publishEvent(EnteredWindow(window, entered == 1))
end

for elem in [WindowResized, KeyPressed, MouseClicked, UnicodeInput, MouseMoved, Scrolled, EnteredWindow]
	registerEventAction(elem{Window}, x -> true, x -> EVENT_HISTORY[typeof(x)] = x)
end

registerEventAction(EnteredWindow{Window}, x -> true, x -> println(EVENT_HISTORY))



function renderloop(window)
		# Loop until the user closes the window
	while !GLFW.WindowShouldClose(window)
		glClearColor(1f0, 1f0, 1f0, 1f0)   
	    glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT)
		
	    renderLoop()

		GLFW.SwapBuffers(window)
		GLFW.PollEvents()
	end
	GLFW.Terminate()
end


function createWindow(size, name::ASCIIString)
	GLFW.Init()
	GLFW.WindowHint(GLFW.SAMPLES, 4)

	@osx_only begin
		GLFW.WindowHint(GLFW.CONTEXT_VERSION_MAJOR, 3)
		GLFW.WindowHint(GLFW.CONTEXT_VERSION_MINOR, 3)
		glfwWindowHint(GLFW_OPENGL_FORWARD_COMPAT, GL_TRUE)
		GLFW.WindowHint(GLFW.OPENGL_PROFILE, GLFW.OPENGL_CORE_PROFILE)
	end 
	window = GLFW.CreateWindow(size..., name)
	GLFW.MakeContextCurrent(window)

	GLFW.SetWindowCloseCallback(window, window_closed)
	GLFW.SetWindowSizeCallback(window, window_resized)
	GLFW.SetKeyCallback(window, key_pressed)
	GLFW.SetCharCallback(window, unicode_input)
	GLFW.SetMouseButtonCallback(window, mouse_clicked)
	GLFW.SetCursorPosCallback(window, cursor_position)
	GLFW.SetScrollCallback(window, scroll)
	GLFW.SetCursorEnterCallback(window, entered_window)

	initGLUtils()	

	@async renderloop(window)

	window
end