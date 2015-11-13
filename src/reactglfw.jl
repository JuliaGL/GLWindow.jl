immutable MonitorProperties
    name::ASCIIString
    isprimary::Bool
    position::Vec{2, Int}
    physicalsize::Vec{2, Int}
    videomode::GLFW.VidMode
    videomode_supported::Vector{GLFW.VidMode}
    dpi::Vec{2, Float64}
    monitor::Monitor
end

function MonitorProperties(monitor::Monitor)
    name 				= GLFW.GetMonitorName(monitor)
    isprimary 			= GLFW.GetPrimaryMonitor() == monitor
    position			= Vec{2, Int}(GLFW.GetMonitorPos(monitor)...)
    physicalsize		= Vec{2, Int}(GLFW.GetMonitorPhysicalSize(monitor)...)
    videomode 			= GLFW.GetVideoMode(monitor)

    dpi					= Vec(videomode.width * 25.4, videomode.height * 25.4) ./ Vec{2, Float64}(physicalsize)
    videomode_supported = GLFW.GetVideoModes(monitor)

    MonitorProperties(name, isprimary, position, physicalsize, videomode, videomode_supported, dpi, monitor)
end

function primarymonitorresolution()
    props = MonitorProperties(GLFW.GetPrimaryMonitor())
    w,h = props.videomode.width, props.videomode.height
    Vec(Int(w),Int(h))
end

function Base.show(io::IO, m::MonitorProperties)
    println(io, "name: ", m.name)
    println(io, "physicalsize: ",  m.physicalsize[1], "x", m.physicalsize[2])
    println(io, "resolution: ", m.videomode.width, "x", m.videomode.height)
    println(io, "dpi: ", m.dpi[1], "x", m.dpi[2])
end
zeroposition{T}(r::Rectangle{T}) = Rectangle(zero(T), zero(T), r.w, r.h)
export zeroposition

SCREEN_ID_COUNTER = 1

type Screen
    id 		 	::Symbol
    area 		::Signal{Rectangle{Int}}
    parent 		::Screen
    children 	::Vector{Screen}
    inputs 		::Dict{Symbol, Any}
    renderlist 	::Vector{RenderObject}


    hidden 		::Signal{Bool}
    hasfocus 	::Signal{Bool}

    cameras 	::Dict{Symbol, Any}
    nativewindow::Window
    transparent ::Signal{Bool}

    function Screen(
        area,
        parent 		::Screen,
        children 	::Vector{Screen},
        inputs 		::Dict{Symbol, Any},
        renderlist 	::Vector{RenderObject},

        hidden 		::Signal{Bool},
        hasfocus 	::Signal{Bool},
        cameras 	::Dict{Symbol, Any},
        nativewindow::Window,
        transparent = Input(false))

        global SCREEN_ID_COUNTER

        new(
            symbol("display"*string(SCREEN_ID_COUNTER+=1)),
            area, parent, children, inputs, renderlist,
            hidden, hasfocus, cameras, nativewindow, transparent
        )
    end

    function Screen(
        area,
        children 	 ::Vector{Screen},
        inputs 		 ::Dict{Symbol, Any},
        renderlist 	 ::Vector{RenderObject},

        hidden  	 ::Signal{Bool},
        hasfocus 	 ::Signal{Bool},
        cameras 	 ::Dict{Symbol, Any},
        nativewindow ::Window,
        transparent = Input(false))
        parent = new()

        global SCREEN_ID_COUNTER

        new(
            symbol("display"*string(SCREEN_ID_COUNTER+=1)),
            area, parent, children, inputs,
            renderlist, hidden, hasfocus,
            cameras, nativewindow, transparent
        )
    end
end

"""
Check if a Screen is opened.
"""
Base.isopen(s::Screen) = s.inputs[:open].value

"""
Swap the framebuffers on the Screen.
"""
function swapbuffers(s::Screen)
    GLFW.SwapBuffers(s.nativewindow)
end

"""
Poll events on the screen which will propogate signals through react.
"""
function pollevents(::Screen)
    GLFW.PollEvents()
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
        position 					     = Vec3f0(2),
        lookat 					     	 = Vec3f0(0),
        transparent                      = Input(false)
    )

    pintersect = const_lift(intersect, const_lift(zeroposition, parent.area), area)

    #checks if mouse is inside screen and not inside any children
    relative_mousepos = const_lift(inputs[:mouseposition]) do mpos
        Point{2, Float64}(mpos[1]-pintersect.value.x, mpos[2]-pintersect.value.y)
    end
    insidescreen = const_lift(relative_mousepos) do mpos
        mpos[1]>=0 && mpos[2]>=0 && mpos[1] <= pintersect.value.w && mpos[2] <= pintersect.value.h && !any(screen->isinside(screen.area.value, mpos...), children)
    end
    # creates signals for the camera, which are only active if mouse is inside screen
    camera_input = merge(inputs, Dict(
        :mouseposition 	=> filterwhen(insidescreen, Vec(0.0, 0.0), relative_mousepos),
        :scroll_x 		=> filterwhen(insidescreen, 0.0, 			inputs[:scroll_x]),
        :scroll_y 		=> filterwhen(insidescreen, 0.0, 			inputs[:scroll_y]),
        :window_size 	=> area
    ))
    new_input = merge(inputs, Dict(
        :mouseinside 	=> insidescreen,
        :mouseposition 	=> relative_mousepos,
        :scroll_x 		=> inputs[:scroll_x],
        :scroll_y 		=> inputs[:scroll_y],
        :window_size 	=> area
    ))
    # creates cameras for the sceen with the new inputs
    ocamera = OrthographicPixelCamera(camera_input)
    pcamera = PerspectiveCamera(camera_input, position, lookat)
    screen  = Screen(
        area, parent, children, new_input,
        renderlist, hidden, hasfocus,
        Dict(:perspective=>pcamera, :orthographic_pixel=>ocamera),
        nativewindow,transparent
    )
    push!(parent.children, screen)
    screen
end
GeometryTypes.isinside{T}(x::Screen, position::Vec{2, T}) =
    !any(screen->isinside(screen.area.value, position...), x.children) && isinside(x.area.value, position...)

GeometryTypes.isinside(screen::Screen, point) = isinside(screen.area.value, point...)

function isoutside(screens_mpos)
    screens, mpos = screens_mpos
    for screen in screens
        isinside(screen, mpos) && return false
    end
    true
end


function Base.intersect{T}(a::Rectangle{T}, b::Rectangle{T})
    axrange = a.x:xwidth(a)
    ayrange = a.y:yheight(a)

    bxrange = b.x:xwidth(b)
    byrange = b.y:yheight(b)

    xintersect = intersect(axrange, bxrange)
    yintersect = intersect(ayrange, byrange)
    (isempty(xintersect) || isempty(yintersect) ) && return Rectangle(zero(T), zero(T), zero(T), zero(T))
    x,y   = first(xintersect), first(yintersect)
    xw,yh = last(xintersect), last(yintersect)
    Rectangle(x,y, xw-x, yh-y)
end

function GLAbstraction.render(x::Screen, parent::Screen=x, context=x.area.value)
    if x.inputs[:open].value
        sa    = x.area.value
        sa    = Rectangle(context.x+sa.x, context.y+sa.y, sa.w, sa.h) # bring back to absolute values
        pa    = context
        sa_pa = intersect(pa, sa)
        if sa_pa != Rectangle{Int}(0,0,0,0)
            glEnable(GL_SCISSOR_TEST)
            glScissor(sa_pa)
            glViewport(sa)
            x.transparent.value || glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT)
            render(x.renderlist)
            for screen in x.children; render(screen, x, sa); end
        end
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


import Base.(==)
Base.hash(x::Window, h::UInt64)    = hash(x.ref, h)
Base.isequal(a::Window, b::Window) = isequal(a.ref, b.ref)
==(a::Window, b::Window) 	       = a.ref == b.ref

function update(window::Window, key::Symbol, value; keepsimilar::Bool = false)
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
    update(window, :_window_size, Rectangle(0, 0, Int(w), Int(h)))
    return nothing
end
function framebuffer_size(window, w::Cint, h::Cint)
    update(window, :framebuffer_size, Vec{2, Int}(w, h))
    return nothing
end
function window_position(window, x::Cint, y::Cint)
    update(window, :windowposition, Vec(Int(x),Int(y)))
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
        elseif action == GLFW.RELEASE
            buttonreleased 	= screen.inputs[:buttonreleased]
            push!(buttonreleased, buttonI)
            keyset = setdiff(keyset,buttonI)
        elseif action == GLFW.REPEAT
            push!(keyset, buttonI)
        end
        keyset = unique(keyset)
        push!(buttonspressed, keyset)
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
        push!(buttondown, 		buttonI)
        push!(keyset, 			buttonI)
        push!(buttonspressed, 	keyset)
    elseif action == GLFW.RELEASE
        buttonreleased 	= screen.inputs[:mousereleased]
        push!(buttonreleased, 	buttonI)
        keyset = setdiff(keyset,	buttonI)
        push!(buttonspressed, 	keyset)
    end
    return nothing
end

function unicode_input(window::Window, c::Cuint)
    update(window, :unicodeinput, [Char(c)], keepsimilar = true)
    update(window, :unicodeinput, Char[], 	 keepsimilar = true)
    return nothing
end

function cursor_position(window::Window, x::Cdouble, y::Cdouble)
    update(window, :mouseposition_glfw_coordinates, Vec{2, Float64}(x, y))
    return nothing
end
function hasfocus(window::Window, focus::Cint)
    update(window, :hasfocus, focus==GL_TRUE)
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

function dropped_files{T <: AbstractString}(window::Window, files::Vector{T})
    update(window, :droppedfiles, map(utf8, files), keepsimilar=true)
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


glfw2gl(mouse, window) = Vec(mouse[1], window.h - mouse[2])



function scaling_factor(window::Rectangle{Int}, fb::Vec{2, Int})
    (window.w == 0 || window.h == 0) && return Vec{2, Float64}(1.0)
    Vec{2, Float64}(fb[1] / window.w, fb[2] / window.h)
end


function createwindow(name::AbstractString, w, h; debugging = false, windowhints=[(GLFW.SAMPLES, 4)])

    for elem in windowhints
        GLFW.WindowHint(elem...)
    end
    @osx_only begin
        if debugging
            println("warning: OpenGL debug message callback not available on osx")
            debugging = false
        end
    end

    GLFW.WindowHint(GLFW.CONTEXT_VERSION_MAJOR, 3)
    GLFW.WindowHint(GLFW.CONTEXT_VERSION_MINOR, 3)
    GLFW.WindowHint(GLFW.OPENGL_FORWARD_COMPAT, GL_TRUE)
    GLFW.WindowHint(GLFW.OPENGL_PROFILE, GLFW.OPENGL_CORE_PROFILE)

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
    framebuffers 		= Input(Vec{2, Int}(fwidth, fheight))
    window_size 		= Input(Rectangle{Int}(0, 0, width, height))
    glViewport(0, 0, fwidth, fheight)


    mouseposition_glfw 	= Input(Vec(0.0, 0.0))
    mouseposition 		= const_lift(glfw2gl, mouseposition_glfw, window_size)

    window_scale_factor = const_lift(scaling_factor, window_size, framebuffers)

    mouseposition 		= const_lift(.*, mouseposition, window_scale_factor)

    inputs = Dict{Symbol, Any}()
    inputs[:insidewindow] 			= Input(false)
    inputs[:open] 					= Input(true)
    inputs[:hasfocus] 				= Input(false)

    inputs[:_window_size] 			= window_size # to get
    inputs[:window_size] 			= const_lift(Rectangle, framebuffers) # to get
    inputs[:framebuffer_size] 		= framebuffers
    inputs[:windowposition] 		= Input(Vec(0,0))

    inputs[:unicodeinput] 			= Input(Char[])

    inputs[:buttonspressed] 		= Input(Int[])
    inputs[:buttondown] 			= Input(0)
    inputs[:buttonreleased] 		= Input(0)

    inputs[:mousebuttonspressed] 	= Input(Int[])
    inputs[:mousedown] 				= Input(0)
    inputs[:mousereleased] 			= Input(0)

    inputs[:mouseposition] 					= mouseposition
    inputs[:mouseposition_glfw_coordinates] = mouseposition_glfw

    inputs[:scroll_x] 		= Input(0.0)
    inputs[:scroll_y] 		= Input(0.0)

    inputs[:droppedfiles] 	= Input(UTF8String[])

    children 	 	= Screen[]
    children_mouse 	= const_lift(tuple, children, mouseposition)
    children_mouse 	= filter(isoutside, (Screen[], Vec(0.0, 0.0)), children_mouse)
    mouse 	     	= const_lift(last, children_mouse)
    camera_input 	= merge(inputs, Dict(:mouseposition=>mouse))
    pcamera  	 	= PerspectiveCamera(camera_input, Vec3f0(2), Vec3f0(0))
    pocamera     	= OrthographicPixelCamera(camera_input)

    screen = Screen(
        inputs[:window_size], children, inputs,
        RenderObject[], Input(false), inputs[:hasfocus],
        Dict(:perspective=>pcamera, :orthographic_pixel=>pocamera),
        window
    )
    WINDOW_TO_SCREEN_DICT[window] = screen
    push!(GLFW_SCREEN_STACK, screen)
    screen

end
