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
zeroposition{T}(r::Rectangle{T}) = Rectangle(zero(T), zero(T), r.w, r.h)
export zeroposition
type Screen
    id 		 	::Symbol
    area
    parent 		::Screen
    children 	::Vector{Screen}
    inputs 		::Dict{Symbol, Any}
    renderlist 	::Vector{RenderObject}

    hidden 		::Signal{Bool}
    hasfocus 	::Signal{Bool}

    cameras 	::Dict{Symbol, Any}
    nativewindow::Window

    counter = 1
    function Screen(
    	area,
	    parent 		::Screen,
	    children 	::Vector{Screen},
	    inputs 		::Dict{Symbol, Any},
	    renderlist 	::Vector{RenderObject},

	    hidden 		::Signal{Bool},
	    hasfocus 	::Signal{Bool},
	    cameras 	::Dict{Symbol, Any},
	    nativewindow::Window)
        new(
        	symbol("display"*string(counter+=1)), 
        	area, parent, children, inputs, renderlist, 
        	hidden, hasfocus, cameras, nativewindow)
    end

    function Screen(
        area,
        children 	 ::Vector{Screen},
        inputs 		 ::Dict{Symbol, Any},
        renderlist 	 ::Vector{RenderObject},

        hidden  	 ::Signal{Bool},
        hasfocus 	 ::Signal{Bool},
        cameras 	 ::Dict{Symbol, Any},
        nativewindow ::Window)
        parent = new()
        new(
        	symbol("display"*string(counter+=1)), 
        	area, parent, children, inputs, 
        	renderlist, hidden, hasfocus, 
        	cameras, nativewindow)
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
        
        nativewindow::Window 			 = parent.nativewindow,
        position 					     = Vec3(2),
        lookat 					     	 = Vec3(0),)

	#checks if mouse is inside screen and not inside any children
	relative_mousepos = lift(inputs[:mouseposition]) do mpos
		Point2(mpos.x-area.value.x, mpos.y-area.value.y)
	end
	pintersect = lift(intersect, lift(zeroposition, parent.area), area)
	insidescreen = lift(relative_mousepos) do mpos
		mpos.x>=0 && mpos.y>=0 && mpos.x <= pintersect.value.w && mpos.y <= pintersect.value.h && !any(children) do screen 
			isinside(screen.area.value, mpos...)
		end
	end
	# creates signals for the camera, which are only active if mouse is inside screen
	camera_input = merge(inputs, Dict(
		:mouseposition 	=> keepwhen(insidescreen, Vector2(0.0), relative_mousepos), 
		:scroll_x 		=> keepwhen(insidescreen, 0.0, 			inputs[:scroll_x]), 
		:scroll_y 		=> keepwhen(insidescreen, 0.0, 			inputs[:scroll_y]), 
		:window_size 	=> lift(x->Vector4(x.x, x.y, x.w, x.h), area)
	))
	new_input = merge(inputs, Dict(
		:mouseinside 	=> insidescreen,
		:mouseposition 	=> relative_mousepos, 
		:scroll_x 		=> inputs[:scroll_x], 
		:scroll_y 		=> inputs[:scroll_y], 
		:window_size 	=> lift(x->Vector4(x.x, x.y, x.w, x.h), area)
	))
	# creates cameras for the sceen with the new inputs
	ocamera = OrthographicPixelCamera(camera_input)
	pcamera = PerspectiveCamera(camera_input, position, lookat)
    screen = Screen(
    	area, parent, children, new_input, 
    	renderlist, hidden, hasfocus, 
    	Dict(:perspective=>pcamera, :orthographic_pixel=>ocamera),
    	nativewindow)
	push!(parent.children, screen)
	screen
end
function GLAbstraction.isinside(x::Screen, position::Vector2)
	!any(screen->isinside(screen.area.value, position...), x.children) && isinside(x.area.value, position...)
end



function Base.intersect{T}(a::Rectangle{T}, b::Rectangle{T})
	axrange = a.x:xwidth(a)
	ayrange = a.y:yheight(a)

	bxrange = b.x:xwidth(b)
	byrange = b.y:yheight(b)

	xintersect = intersect(axrange, bxrange)
	yintersect = intersect(ayrange, byrange)
	(isempty(xintersect) || isempty(yintersect) ) && return Rectangle(zero(T), zero(T), zero(T), zero(T))
	x,y 	= first(xintersect), first(yintersect)
	xw,yh 	= last(xintersect), last(yintersect)
	Rectangle(x,y, xw-x,yh-y)
end

function GLAbstraction.render(x::Screen, parent::Screen=x, context=x.area.value)
	sa 	 	= x.area.value
	sa 		= Rectangle(context.x+sa.x, context.y+sa.y, sa.w, sa.h) # bring back to absolute values
	pa 	 	= context
	sa_pa 	= intersect(pa, sa)
	if sa_pa != Rectangle{Int}(0,0,0,0)
 		glEnable(GL_SCISSOR_TEST)
    	glScissor(sa_pa)
    	glViewport(sa)
    	render(x.renderlist)
    	for screen in x.children; render(screen, x, sa); end
    end
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
	update(window, :window_size, Vector4(0, 0, Int(w), Int(h)))
    return nothing
end
function framebuffer_size(window, w::Cint, h::Cint)
	update(window, :framebuffer_size, Vector2(Int(w), Int(h)))
    return nothing
end
function window_position(window, x::Cint, y::Cint)
	update(window, :windowposition, Vector2(Int(x),Int(y)))
    return nothing
end



function key_pressed(window::Window, button::Cint, scancode::Cint, action::Cint, mods::Cint)
	screen = WINDOW_TO_SCREEN_DICT[window]
	if button != GLFW.KEY_UNKNOWN
		buttonspressed 	= screen.inputs[:buttonspressed]
		keyset 			= buttonspressed.value
		buttonI 		= Int(button)
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
		elseif action == GLFW.REPEAT
			push!(keyset, buttonI)
			push!(buttonspressed, keyset)
		end
	end
	return nothing
end
function mouse_clicked(window::Window, button::Cint, action::Cint, mods::Cint)
	screen = WINDOW_TO_SCREEN_DICT[window]
	
	buttonspressed 	= screen.inputs[:mousebuttonspressed]
	keyset 			= buttonspressed.value
	buttonI 		= Int(button)
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
	update(window, :unicodeinput, [Char(c)], keepsimilar = true)
	update(window, :unicodeinput, Char[], keepsimilar = true)
	return nothing
end

function cursor_position(window::Window, x::Cdouble, y::Cdouble)
	update(window, :mouseposition_glfw_coordinates, Vector2(Float64(x), Float64(y)))
	return nothing
end
function hasfocus(window::Window, focus::Cint)
	update(window, :hasfocus, Bool(focus==GL_TRUE))
	return nothing
end
function scroll(window::Window, xoffset::Cdouble, yoffset::Cdouble)
	screen = WINDOW_TO_SCREEN_DICT[window]
	push!(screen.inputs[:scroll_x], Float64(xoffset)) 
	push!(screen.inputs[:scroll_y], Float64(yoffset))
	push!(screen.inputs[:scroll_x], Float64(0)) # reset to zero
	push!(screen.inputs[:scroll_y], Float64(0))
	return nothing
end
function entered_window(window::Window, entered::Cint)
	update(window, :insidewindow, entered == 1)
	return nothing
end

function dropped_files(window::Window, count::Cint, files::Ptr{Ptr{UInt8}})
	files = pointer_to_array(files, count)
	files = map(utf8, files)
	update(window, :droppedfiles, files, keepsimilar = true)
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


glfw2gl(mouse, window) = Vector2(mouse[1], window[4] - mouse[2])

GLAbstraction.isinside(screen::Screen, point) = isinside(screen.area.value, point...)
function isoutside(screens_mpos) 
	screens, mpos = screens_mpos
	for screen in screens
		isinside(screen, mpos) && return false
	end
	true
end

GLAbstraction.Rectangle{T}(val::Vector2{T}) = Rectangle{T}(0, 0, val...)
	
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
	
	GLFW.WindowHint(GLFW.OPENGL_DEBUG_CONTEXT, Cint(debugging))
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
	GLFW.SetDropCallback(window, dropped_files)
	
	width, height 		= GLFW.GetWindowSize(window)
	fwidth, fheight 	= GLFW.GetFramebufferSize(window)
	framebuffers 		= Input(Vector2{Int}(fwidth, fheight))
	window_size 		= Input(Vector4{Int}(0, 0, width, height))
	glViewport(0, 0, fwidth, fheight)


	mouseposition_glfw 	= Input(Vector2(0.0))
	mouseposition 		= lift(glfw2gl, mouseposition_glfw, window_size)

	
	inputs = Dict{Symbol, Any}()
	inputs[:insidewindow] 	= Input(false)
	inputs[:open] 			= Input(true)
	inputs[:hasfocus] 		= Input(false)

	inputs[:window_size] 		= window_size
	inputs[:framebuffer_size] 	= framebuffers
	inputs[:windowposition] 	= Input(Vector2(0))

	inputs[:unicodeinput] 		= Input(Char[])

	inputs[:buttonspressed] = Input(IntSet())
	inputs[:buttondown] 	= Input(0)
	inputs[:buttonreleased] = Input(0)

	inputs[:mousebuttonspressed] 	= Input(IntSet())
	inputs[:mousedown] 				= Input(0)
	inputs[:mousereleased] 			= Input(0)

	inputs[:mouseposition] 					= mouseposition
	inputs[:mouseposition_glfw_coordinates] = mouseposition_glfw

	inputs[:scroll_x] = Input(0.0)
	inputs[:scroll_y] = Input(0.0)

	inputs[:droppedfiles] = Input(UTF8String[])

	children 	 	= Screen[]
	children_mouse 	= lift(tuple, Input(children), mouseposition)
	children_mouse 	= filter(isoutside, Vector2(0.0), children_mouse)
	mouse 	     	= lift(last, children_mouse)
	camera_input 	= merge(inputs, Dict(:mouseposition=>mouse))
	pcamera  	 	= PerspectiveCamera(camera_input, Vec3(2), Vec3(0))
	pocamera     	= OrthographicPixelCamera(camera_input)

	screen = Screen(
		lift(Rectangle, framebuffers), children, inputs, 
		RenderObject[], Input(false), inputs[:hasfocus], 
		Dict(:perspective=>pcamera, :orthographic_pixel=>pocamera), 
		window
	)
	WINDOW_TO_SCREEN_DICT[window] = screen
	push!(GLFW_SCREEN_STACK, screen)

	init_glutils()
	screen
end
