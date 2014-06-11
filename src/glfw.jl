using GLFW, Events, GLUtil, ModernGL
import GLFW.Window
export UnicodeInput, KeyPressed, MouseClicked, MouseMoved, EnteredWindow, WindowResized
export MouseDragged, Scrolled, Window, renderloop, leftbuttondragged, middlebuttondragged, rightbuttondragged, leftclickup, leftclickdown


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
	action::Int
	mods::Int
	x::Float64
	y::Float64
end
immutable MouseMoved{T} <: Event
	source::T
	x::Float64
	y::Float64
end
immutable MouseDragged{T} <: Event
	source::T
	start::MouseClicked
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
immutable WindowClosed{T} <: Event
	source::T
end
immutable Scrolled{T} <: Event
	source::T
	xOffset::Float64
	yOffset::Float64
end


const EVENT_HISTORY = Dict{DataType, Any}()

function window_closed(window)
    println("kthxbye...!")
    publishEvent(WindowClosed(window))
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
function mouse_clicked(window::Window, button::Cint, action::Cint, mods::Cint)
	position = get(EVENT_HISTORY, MouseMoved{Window}, MouseMoved(window, 0.0, 0.0))
	event = MouseClicked(window, int(button), int(action), int(mods), position.x, position.y)
	publishEvent(event)
	EVENT_HISTORY[typeof(event)] = event
end

function unicode_input(window::Window, c::Cuint)
	publishEvent(UnicodeInput(window, char(c)))

end

function cursor_position(window::Window, x::Cdouble, y::Cdouble)
	event = MouseMoved(window, float64(x), WINDOW_SIZE[2] - float64(y))
	publishEvent(event)
	EVENT_HISTORY[typeof(event)] = event
end
function scroll(window::Window, xoffset::Cdouble, yoffset::Cdouble)
	publishEvent(Scrolled(window, float64(xoffset), float64(yoffset)))
end
function entered_window(window::Window, entered::Cint)
	publishEvent(EnteredWindow(window, entered == 1))
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
			publishEvent(MouseDragged(event.source, pastClick, event.x, event.y))
		end
	end
end
registerEventAction(MouseMoved{Window}, x -> true, isdragged)

function renderloop(window)
		# Loop until the user closes the window
	while !GLFW.WindowShouldClose(window)
		
		
	   	renderLoop()

		GLFW.SwapBuffers(window)
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

	println(errormessage)
	nothing
end

global const _openglerrorcallback = cfunction(openglerrorcallback, Void,
										(GLenum, GLenum,
										GLuint, GLenum,
										GLsizei, Ptr{GLchar},
										Ptr{Void}))

function createWindow(name::Symbol, w::Int, h::Int)
	GLFW.Init()
	GLFW.WindowHint(GLFW.SAMPLES, 8)

	@osx_only begin
		GLFW.WindowHint(GLFW.CONTEXT_VERSION_MAJOR, 3)
		GLFW.WindowHint(GLFW.CONTEXT_VERSION_MINOR, 2)
		GLFW.WindowHint(GLFW_OPENGL_FORWARD_COMPAT, GL_TRUE)
		GLFW.WindowHint(GLFW.OPENGL_PROFILE, GLFW.OPENGL_CORE_PROFILE)
	end 
	GLFW.WindowHint(GLFW.OPENGL_DEBUG_CONTEXT, 1)

	window = GLFW.CreateWindow(w,h, string(name))
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
	glDebugMessageCallbackARB(_openglerrorcallback, C_NULL)

	window
end
