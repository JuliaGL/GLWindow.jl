
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

type Screen
    id::Symbol
    area
    parent::Screen
    children::Vector{Screen}
    inputs::Dict{Symbol, Any}
    renderlist::Vector{RenderObject}

    hidden::Signal{Bool}
    hasfocus::Signal{Bool}

    perspectivecam::PerspectiveCamera
    orthographiccam::OrthographicCamera
    nativewindow::Window
    counter = 1
    function Screen(
    	area,
	    parent::Screen,
	    children::Vector{Screen},
	    inputs::Dict{Symbol, Any},
	    renderlist::Vector{RenderObject},

	    hidden::Signal{Bool},
	    hasfocus::Signal{Bool},

	    perspectivecam::PerspectiveCamera,
	    orthographiccam::OrthographicCamera,
	    nativewindow::Window)
        new(symbol("display"*string(counter+=1)), area, parent, children, inputs, renderlist, hidden, hasfocus, perspectivecam, orthographiccam, nativewindow)
    end

    function Screen(
        area,
        children::Vector{Screen},
        inputs::Dict{Symbol, Any},
        renderlist::Vector{RenderObject},

        hidden::Signal{Bool},
        hasfocus::Signal{Bool},

        perspectivecam::PerspectiveCamera,
        orthographiccam::OrthographicCamera,
        nativewindow::Window)
        parent = new()
        new(symbol("display"*string(counter+=1)), area, parent, children, inputs, renderlist, hidden, hasfocus, perspectivecam, orthographiccam, nativewindow)
    end
end

#Screen constructor
function Screen(
        parent::Screen;
        area 				      		 = parent.area,
        children::Vector{Screen}  		 = Screen[],
        inputs::Dict{Symbol, Any} 		 = parent.inputs,
        renderlist::Vector{RenderObject} = RenderObject[],

        hidden::Signal{Bool}   			 = parent.hidden,
        hasfocus::Signal{Bool} 			 = parent.hasfocus,
        
        nativewindow::Window 			 = parent.nativewindow)
	#checks if mouse is inside screen
	insidescreen = lift(inputs[:mouseposition]) do mpos
		isinside(area.value, mpos...) && !any(children) do screen 
			isinside(screen.area.value, mpos...)
		end
	end
	# creates signals for the camera, which are only active if mouse is inside screen
	camera_input = merge(inputs, @compat(Dict(
		:mouseposition 	=> keepwhen(insidescreen, Vector2(0.0), inputs[:mouseposition]), 
		:scroll_x 		=> keepwhen(insidescreen, 0, inputs[:scroll_x]), 
		:scroll_y 		=> keepwhen(insidescreen, 0, inputs[:scroll_y]), 
		:window_size 	=> lift(x->Vector4(x.x, x.y, x.w, x.h), area)
	)))
	# creates cameras for the sceen with the new inputs
	ocamera      = OrthographicPixelCamera(camera_input)
	pcamera  	 = PerspectiveCamera(camera_input, Vec3(2), Vec3(0))
    screen = Screen(area, parent, children, inputs, renderlist, hidden, hasfocus, pcamera, ocamera, nativewindow)
	push!(parent.children, screen)
	screen
end
function GLAbstraction.isinside(x::Screen, position::Vector2)
	!any(screen->inside(screen.area.value, position...), x.children) && inside(x.area, position...)
end

function Screen(obj::RenderObject, parent::Screen)

	area 	 = boundingbox2D(obj)
	hidden   = Input(false)
	screen 	 = Screen(parent)
	mouse 	 = filter(inside, Input(Screen), parent.inputs[:mouseposition])

	hasfocus = lift(parent.inputs[:mouseposition], parent.inputs[:mousebuttonpressed], screen.area) do pos, buttons, area
		isinside(area, pos...) && !isempty(bottons)
	end
	buttons  = menubar(screen)
	push!(parent.children, screen)
	push!(screen.renderlist, buttons)
	push!(screen.renderlist, obj)
end

function Screen(style::Style{:Default}, parent=first(SCREEN_STACK))

	hidden   	= Input(true)
	screen 	 	= Screen(parent)
	mouse 	 	= filter(Input(Screen), parent.inputs[:mouseposition]) do screen, mpos
	end
	inputs 		= merge(parent.inputs, @compat(Dict(:mouseposition=>mouse)))
	opxcamera   = OrthographicPixelCamera(inputs)
	pcamera  	= PerspectiveCamera(inputs)
	hasfocus 	= lift(parent.inputs[:mouseposition], parent.inputs[:mousebuttonpressed], screen.area) do pos, buttons, area
		isinside(area, pos...) && !isempty(bottons)
	end
	screen 		= Screen(area, parent, children=Screen[], inputs, renderList, hidden, hasfocus, perspectivecam, orthographiccam)
	buttons     = menubar(screen, style)

	push!(parent.children, screen)
	push!(screen.renderlist, buttons)

end

dict = Dict{Symbol, Vec4}()
function GLAbstraction.render(x::Screen)
 	glEnable(GL_SCISSOR_TEST)
    glScissor(x.area.value.x, x.area.value.y, x.area.value.w, x.area.value.h)
    glViewport(x.area.value)

    render(x.renderlist)
    render(x.children)
end
function Base.show(io::IO, m::Screen)
	println(io, "name: ", m.id)
	println(io, "children: ", length(m.children))
	println(io, "Inputs:")
	map(m.inputs) do x
		key, value = x
		println(io, "  ", key, " => ", typeof(value))
	end
end

const WINDOW_TO_SCREEN_DICT 	   = Dict{Window, Screen}()
const GLFW_SCREEN_STACK 	   	   = Screen[]


import Base.(==)
Base.hash(x::Window, h::Int64) 	   = hash(convert(Uint, x.ref), h)
Base.isequal(a::Window, b::Window) = isequal(convert(Uint, a.ref), convert(Uint, b.ref))
==(a::Window, b::Window) 	       = convert(Uint, a.ref) == convert(Uint, b.ref)

function update(window::Window, key::Symbol, value; keepsimilar = false)
	if haskey(WINDOW_TO_SCREEN_DICT, window)
		screen  = WINDOW_TO_SCREEN_DICT[window]
		input 	= screen.inputs[key]
		if keepsimilar || input.value != value
			push!(input, value)
		end
	end
end

function window_closed(window)
	update(window, :open, false)
    return nothing
end

function window_resized(window, w::Cint, h::Cint)
	update(window, :window_size, Vector4{Int}(0, 0, w, h))
    return nothing
end
function framebuffer_size(window, w::Cint, h::Cint)
	update(window, :framebuffer_size, Vector2{Int}(w, h))
    return nothing
end
function window_position(window, x::Cint, y::Cint)
	update(window, :windowposition, Vector2{Int}(x,y))
    return nothing
end



function key_pressed(window::Window, button::Cint, scancode::Cint, action::Cint, mods::Cint)
	screen = WINDOW_TO_SCREEN_DICT[window]
	if sign(button) == 1
		buttonspressed 	= screen.inputs[:buttonspressed]
		keyset 			= buttonspressed.value
		buttonI 		= @compat(Int(button))
		if action == GLFW.PRESS  
			buttondown 	= screen.inputs[:buttondown]
			push!(buttondown, buttonI)
			push!(keyset, buttonI)
			push!(buttonspressed, keyset)
		elseif action == GLFW.RELEASE 
			buttonreleased 	= screen.inputs[:buttonreleased]
			push!(buttonreleased, buttonI)
			setdiff!(keyset, Set(buttonI))
			push!(buttonspressed, keyset)
		end
	end
	return nothing
end
function mouse_clicked(window::Window, button::Cint, action::Cint, mods::Cint)
	screen = WINDOW_TO_SCREEN_DICT[window]
	
	buttonspressed 	= screen.inputs[:mousebuttonspressed]
	keyset 			= buttonspressed.value
	buttonI 		= @compat(Int(button))
	if action == GLFW.PRESS  
		buttondown 	= screen.inputs[:mousedown]
		push!(buttondown, buttonI)
		push!(keyset, buttonI)
		push!(buttonspressed, keyset)
	elseif action == GLFW.RELEASE 
		buttonreleased 	= screen.inputs[:mousereleased]
		push!(buttonreleased, buttonI)
		setdiff!(keyset, Set(buttonI))
		push!(buttonspressed, keyset)
	end
	return nothing
end

function unicode_input(window::Window, c::Cuint)
	update(window, :unicodeinput, Char[c], keepsimilar = true)
	update(window, :unicodeinput, Char[], keepsimilar = true)
	return nothing
end

function cursor_position(window::Window, x::Cdouble, y::Cdouble)
	update(window, :mouseposition_glfw_coordinates, Vector2{Float64}(x, y))
	return nothing
end
function hasfocus(window::Window, focus::Cint)
	update(window, :hasfocus, focus==GL_TRUE)
	return nothing
end
function scroll(window::Window, xoffset::Cdouble, yoffset::Cdouble)
	screen = WINDOW_TO_SCREEN_DICT[window]
	push!(screen.inputs[:scroll_x], @compat(Float64(xoffset)))
	push!(screen.inputs[:scroll_y], @compat(Float64(yoffset)))
	push!(screen.inputs[:scroll_x], zero(Float64))
	push!(screen.inputs[:scroll_y], zero(Float64))
	return nothing
end
function entered_window(window::Window, entered::Cint)
	update(window, :insidewindow, entered == 1)
	return nothing
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
	if typ == GL_DEBUG_TYPE_ERROR
		error(errormessage)
	end
	nothing
end



global const _openglerrorcallback = cfunction(openglerrorcallback, Void,
										(GLenum, GLenum,
										GLuint, GLenum,
										GLsizei, Ptr{GLchar},
										Ptr{Void}))

function createwindow(name::String, w, h; debugging = false, windowhints=[(GLFW.SAMPLES, 4)])
	GLFW.Init()
	for elem in windowhints
		GLFW.WindowHint(elem...)
	end
	@osx_only begin
		if debugging
			println("warning: OpenGL debug message callback not available on osx")
			debugging = false
		end
		GLFW.WindowHint(GLFW.CONTEXT_VERSION_MAJOR, 3)
		GLFW.WindowHint(GLFW.CONTEXT_VERSION_MINOR, 2)
		GLFW.WindowHint(GLFW.OPENGL_FORWARD_COMPAT, GL_TRUE)
		GLFW.WindowHint(GLFW.OPENGL_PROFILE, GLFW.OPENGL_CORE_PROFILE)
	end
	
	GLFW.WindowHint(GLFW.OPENGL_DEBUG_CONTEXT, @compat(Cint(debugging)))
	window = GLFW.CreateWindow(w, h, name)
	GLFW.MakeContextCurrent(window)
	GLFW.ShowWindow(window)
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
	GLFW.SetWindowFocusCallback(window, hasfocus)

	GLFW.SetWindowSize(window, w, h) # Seems to be necessary to guarantee that window > 0

	width, height 		= GLFW.GetWindowSize(window)
	fwidth, fheight 	= GLFW.GetFramebufferSize(window)
	framebuffers 		= Input(Vector2{Int}(fwidth, fheight))
	window_size 		= Input(Vector4{Int}(0, 0, width, height))
	glViewport(0, 0, fwidth, fheight)


	mouseposition_glfw 	= Input(Vector2(0.0))
	mouseposition 		= lift((mouse, window) -> Vector2(mouse[1], window[4] - mouse[2]), Vector2{Float64}, mouseposition_glfw, window_size)

	
	inputs = Dict{Symbol, Any}()
	inputs[:insidewindow] = Input(false)
	inputs[:open] = Input(true)
	inputs[:hasfocus] = Input(false)

	inputs[:window_size] = window_size
	inputs[:framebuffer_size] = framebuffers
	inputs[:windowposition] = Input(Vector2(0))

	inputs[:unicodeinput] = Input(Char[])

	inputs[:buttonspressed] = Input(IntSet())
	inputs[:buttondown] = Input(0)
	inputs[:buttonreleased] = Input(0)

	inputs[:mousebuttonspressed] = Input(IntSet())
	inputs[:mousedown] = Input(0)
	inputs[:mousereleased] = Input(0)

	inputs[:mouseposition] = mouseposition
	inputs[:mouseposition_glfw_coordinates] = mouseposition_glfw

	inputs[:scroll_x] = Input(0.0)
	inputs[:scroll_y] = Input(0.0)

	children = Screen[]
	mouse 	 = filter(Vector2(0.0), mouseposition) do mpos
		!any(children) do screen 
			isinside(screen.area.value, mpos...)
		end
	end
	camera_input = merge(inputs, @compat(Dict(:mouseposition=>mouse)))
	pcamera  	 = PerspectiveCamera(camera_input, Vec3(2), Vec3(0))
	pocamera     = OrthographicPixelCamera(camera_input)

	screen = Screen(lift(x->Rectangle(0, 0, x...), framebuffers), children, inputs, RenderObject[], Input(false), inputs[:hasfocus], pcamera, pocamera, window)
	WINDOW_TO_SCREEN_DICT[window] = screen
	push!(GLFW_SCREEN_STACK, screen)

	init_glutils()
	screen
end
