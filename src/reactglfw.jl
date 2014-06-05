using GLFW, React
import GLFW.Window
export UnicodeInput, KeyPressed, MouseClicked, MouseMoved, EnteredWindow, WindowResized
export MouseDragged, Scrolled, Window, renderloop, leftbuttondragged, middlebuttondragged, rightbuttondragged, leftclickup, leftclickdown

immutable Screen
	id::Symbol
	inputs::Dict{Symbol, Input}
	parent::Screen
	children::Vector{Screen}
	renderList::Vector{Any}
	function Screen()
	end
end

immutable UnicodeInput <: Event
	char::Char
end
immutable KeyPressed <: Event
	key::Int
	scancode::Int
	action::Int
	mods::Int
end
immutable MouseClicked <: Event
	button::Int
	action::Int
	mods::Int
end
immutable MouseMoved <: Event
	x::Float64
	y::Float64
end
immutable MouseDragged <: Event
	start::MouseClicked
	x::Float64
	y::Float64
end
immutable EnteredWindow <: Event
	entered::Bool
end
immutable WindowResized <: Event
	w::Int
	h::Int
end
immutable WindowClosed <: Event
	closed::True
end
immutable Scrolled <: Event
	xOffset::Float64
	yOffset::Float64
end

const ROOT_SCREEN = 


function window_closed(window)
    println("kthxbye...!")
    push!(WINDOW_EVENT_STREAM[(window, WindowClosed)], WindowClosed(True))
    return nothing
end

const WINDOW_SIZE = [0,0]
function window_resized(window, w, h)
	WINDOW_SIZE[1] = int(w)
    WINDOW_SIZE[2] = int(h)
    push!(WINDOW_EVENT_STREAM[(window, WindowResized)], WindowResized(int(w),int(h)))
end

MousePosition 	= Input(Vec2(0,0))
UnicodeInput	= Input('0')
WindowWidth 	= Input(0)
WindowHeight 	= Input(0)
WindowPosX	 	= Input(0)
WindowPosY	 	= Input(0)

function key_pressed(window::Window, key::Cint, scancode::Cint, action::Cint, mods::Cint)
    push!(WINDOW_EVENT_STREAM[(window, KeyPressed)], KeyPressed(int(key), int(scancode), int(action), int(mods)))
end
function mouse_clicked(window::Window, button::Cint, action::Cint, mods::Cint)
	push!(WINDOW_EVENT_STREAM[(window, MouseClicked)], MouseClicked(int(button), int(action), int(mods)))
end

function unicode_input(window::Window, c::Cuint)
	push!(WINDOW_EVENT_STREAM[(window, UnicodeInput)],UnicodeInput(char(c)))

end

function cursor_position(window::Window, x::Cdouble, y::Cdouble)
	event = MouseMoved(window, float64(x), float64(y))
	push!(WINDOW_EVENT_STREAM[(window, WindowResized)],event)
	EVENT_HISTORY[typeof(event)] = event
end
function scroll(window::Window, xoffset::Cdouble, yoffset::Cdouble)
	push!(WINDOW_EVENT_STREAM[(window, WindowResized)],Scrolled(window, float64(xoffset), float64(yoffset)))
end
function entered_window(window::Window, entered::Cint)
	push!(WINDOW_EVENT_STREAM[(window, WindowResized)],EnteredWindow(window, entered == 1))
end


leftbuttondragged(event::MouseDragged) 		= event.start.button == 0
middlebuttondragged(event::MouseDragged) 	= event.start.button == 2
rightbuttondragged(event::MouseDragged) 	= event.start.button == 1

leftclickdown(event::MouseClicked) = event.button == 0 && event.action == 1
leftclickup(event::MouseClicked) = event.button == 0 && event.action == 0

function isdragged(event::MouseMoved)
	if haskey(EVENT_HISTORY, MouseClicked{Window})
		pastClick = EVENT_HISTORY[MouseClicked{Window}]
		if pastClick.action == 1
			push!(WINDOW_EVENT_STREAM[(window, WindowResized)],MouseDragged(event.source, pastClick, event.x, event.y))
		end
	end
end
registerEventAction(MouseMoved{Window}, x -> true, isdragged)

function renderloop(window)
		# Loop until the user closes the window
	while !GLFW.WindowShouldClose(window)
		glClearColor(1f0, 1f0, 1f0, 0f0)   
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

	window
end