SCREEN_ID_COUNTER = 1
type Screen
    id 		 	::Symbol
    area 		::Signal{SimpleRectangle{Int}}
    parent 		::Screen
    children 	::Vector{Screen}
    inputs 		::Dict{Symbol, Any}
    renderlist 	::Vector{RenderObject}


    hidden 		::Signal{Bool}
    hasfocus 	::Signal{Bool}

    cameras 	::Dict{Symbol, Any}
    nativewindow::Window
    transparent ::Signal{Bool}
    keydict     ::Dict{Int, Bool}

    function Screen(
            name::Symbol,
            area,
            parent 		::Screen,
            children 	::Vector{Screen},
            inputs 		::Dict{Symbol, Any},
            renderlist 	::Vector{RenderObject},

            hidden 		::Signal{Bool},
            hasfocus 	::Signal{Bool},
            cameras 	::Dict{Symbol, Any},
            nativewindow::Window,
            transparent = Signal(false)
        )
        global SCREEN_ID_COUNTER
        new(
            name,
            area, parent, children, inputs, renderlist,
            hidden, hasfocus, cameras, nativewindow, transparent, Dict{Int, Bool}()
        )
    end

    function Screen(
            name = gensym("Screen"),
            area,
            children 	 ::Vector{Screen},
            inputs 		 ::Dict{Symbol, Any},
            renderlist 	 ::Vector{RenderObject},

            hidden  	 ::Signal{Bool},
            hasfocus 	 ::Signal{Bool},
            cameras 	 ::Dict{Symbol, Any},
            nativewindow ::Window,
            transparent = Signal(false)
        )
        parent = new()
        global SCREEN_ID_COUNTER
        new(
            name,
            area, parent, children, inputs,
            renderlist, hidden, hasfocus,
            cameras, nativewindow, transparent, Dict{Int, Bool}()
        )
    end
end


#Screen constructor
function Screen(
        parent::Screen;
        name = gensym("Screen"),
        area 				      		 = parent.area,
        children::Vector{Screen}  		 = Screen[],
        inputs::Dict{Symbol, Any} 		 = parent.inputs,
        renderlist::Vector{RenderObject} = RenderObject[],

        hidden::Signal{Bool}   			 = parent.hidden,
        hasfocus::Signal{Bool} 			 = parent.hasfocus,

        nativewindow::Window 			 = parent.nativewindow,
        position 					     = Vec3f0(2),
        lookat 					     	 = Vec3f0(0),
        transparent                      = Signal(false)
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
    screen  = Screen(name,
        area, parent, children, new_input,
        renderlist, hidden, hasfocus,
        Dict(:perspective=>pcamera, :orthographic_pixel=>ocamera),
        nativewindow,transparent
    )
    push!(parent.children, screen)
    screen
end

function GLAbstraction.render(x::Screen, parent::Screen=x, context=x.area.value)
    if x.inputs[:open].value
        sa    = x.area.value
        sa    = SimpleRectangle(context.x+sa.x, context.y+sa.y, sa.w, sa.h) # bring back to absolute values
        pa    = context
        sa_pa = intersect(pa, sa)
        if sa_pa != SimpleRectangle{Int}(0,0,0,0) # if it is in the parent area
            glEnable(GL_SCISSOR_TEST)
            glScissor(sa_pa)
            glViewport(sa)
            x.transparent.value || glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT)
            render(x.renderlist)
            for screen in x.children; render(screen, x, sa); end
        end
    end
end




function openglerrorcallback(
        source::GLenum, typ::GLenum,
        id::GLuint, severity::GLenum,
        length::GLsizei, message::Ptr{GLchar},
        userParam::Ptr{Void}
    )
    errormessage = """
         ________________________________________________________________
        |
        | OpenGL Error!
        | source: $(GLENUM(source).name) :: type: $(GLENUM(typ).name)
        |  $(ascii(bytestring(message, length)))
        |________________________________________________________________
    """
    output = typ == GL_DEBUG_TYPE_ERROR ? error : info
    output(errormessage)
    nothing
end
global const _openglerrorcallback = cfunction(
    openglerrorcallback, Void,
    (GLenum, GLenum,GLuint, GLenum, GLsizei, Ptr{GLchar}, Ptr{Void})
)

function scaling_factor(window::Vec{Int}, fb::Vec{2, Int})
    (window[1] == 0 || window[2] == 0) && return Vec{2, Float64}(1.0)
    Vec{2, Float64}(fb) ./ Vec{2, Float64}(window.w)
end

function corrected_coordinates(
        window_size::Signal{Vec{2,Int}},
        framebuffer_width::Signal{Vec{2,Int}},
        mouse_position::Vec{2,Float64}
    )
    scaling_factor = scaling_factor(window_size.value, framebuffer_width.value)
    Vec(mouse_position[1], window_size.value[2] - mouse_position[2])
end

funcion standard_callbacks()
    Function[
        window_close,
        window_size,
        window_position,
        key_pressed,
        dropped_files,
        framebuffer_size,
        mouse_clicked,
        unicode_input,
        cursor_position,
        scroll,
        hasfocus,
        entered_window,
    ]
end

function createwindow(name::AbstractString, w, h; debugging = false, windowhints=[(GLFW.SAMPLES, 4)])
    for elem in windowhints
        GLFW.WindowHint(elem...)
    end
    @osx_only begin
        if debugging
            warn("OpenGL debug message callback not available on osx")
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


    glViewport(0, 0, fwidth, fheight)

    mouseposition = const_lift(corrected_coordinates,
        Signal(window_size), Signal(framebuffer_width), cursor_position
    )

    buttonspressed = Int[]
    sizehint!(buttonspressed, 10) # make it less suspicable to growing/shrinking

    screen = Screen(
        inputs[:window_size], children, inputs,
        RenderObject[], Signal(false), inputs[:hasfocus],
        Dict(:perspective=>pcamera, :orthographic_pixel=>pocamera),
        window
    )
    screen
end

"""
Check if a Screen is opened.
"""
function Base.isopen(s::Screen)
    !GLFW.WindowShouldClose(s.nativewindow)
end

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
