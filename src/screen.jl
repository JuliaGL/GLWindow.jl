
"""
Callback which can be used to catch OpenGL errors.
"""
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


"""
Screen constructor cnstructing a new screen from a parant screen.
"""
function Screen(
        parent::Screen;
        name = gensym(parent.name),
        area = parent.area,
        children::Vector{Screen} = Screen[],
        inputs::Dict{Symbol, Any} = parent.inputs,
        renderlist::Tuple = (),
        hidden::Bool = parent.hidden,
        glcontext::GLContext = parent.glcontext,
        position = Vec3f0(2),
        lookat = Vec3f0(0),
        color = RGBA{Float32}(1,1,1,1)
    )
    pintersect = const_lift(x->intersect(zeroposition(value(parent.area)), x), area)
    relative_mousepos = const_lift(inputs[:mouseposition]) do mpos
        Point{2, Float64}(mpos[1]-value(pintersect).x, mpos[2]-value(pintersect).y)
    end
    #checks if mouse is inside screen and not inside any children

    insidescreen = droprepeats(const_lift(relative_mousepos) do mpos
        for screen in children
            # if inside any children, it's not inside screen
            isinside(value(screen.area), mpos...) && return false
        end
        (mpos[1] < 0 || mpos[2] < 0) && return false
        mpos[1] > value(pintersect).w && return false
        mpos[2] > value(pintersect).h && return false
        true
    end)
    # creates signals for the camera, which are only active if mouse is inside screen
    camera_input = merge(inputs, Dict(
        :mouseposition 	=> filterwhen(insidescreen, Vec(0.0, 0.0), relative_mousepos),
        :scroll 		=> filterwhen(insidescreen, 0.0, inputs[:scroll]),
        :window_area 	=> area
    ))
    new_input = merge(inputs, Dict(
        :mouseinside 	=> insidescreen,
        :mouseposition 	=> relative_mousepos,
        :scroll 		=> inputs[:scroll],
        :window_area 	=> area
    ))
    # creates cameras for the sceen with the new inputs
    ocamera = OrthographicPixelCamera(camera_input)
    pcamera = PerspectiveCamera(camera_input, position, lookat)
    screen  = Screen(name,
        area, parent, children, new_input,
        renderlist, hidden, color,
        Dict{Symbol, Any}(:perspective=>pcamera, :orthographic_pixel=>ocamera),
        glcontext
    )
    push!(parent.children, screen)
    screen
end

"""
On OSX retina screens, the window size is different from the
pixel size of the actual framebuffer. With this function we
can find out the scaling factor.
"""
function scaling_factor(window::Vec{2, Int}, fb::Vec{2, Int})
    (window[1] == 0 || window[2] == 0) && return Vec{2, Float64}(1.0)
    Vec{2, Float64}(fb) ./ Vec{2, Float64}(window)
end

"""
Correct OSX scaling issue and move the 0,0 coordinate to left bottom.
"""
function corrected_coordinates(
        window_size::Signal{Vec{2,Int}},
        framebuffer_width::Signal{Vec{2,Int}},
        mouse_position::Vec{2,Float64}
    )
    s = scaling_factor(window_size.value, framebuffer_width.value)
    Vec(mouse_position[1], window_size.value[2] - mouse_position[2]) .* s
end


"""
Standard set of callback functions
"""
function standard_callbacks()
    Function[
        window_open,
        window_size,
        window_position,
        keyboard_buttons,
        mouse_buttons,
        dropped_files,
        framebuffer_size,
        unicode_input,
        cursor_position,
        scroll,
        hasfocus,
        entered_window,
    ]
end

"""
Tries to create sensible context hints!
Taken from lessons learned at:
[GLFW](http://www.glfw.org/docs/latest/window.html)
"""
function standard_context_hints(major, minor)
    # this is spaar...Modern OpenGL !!!!
    major < 3 && error("OpenGL major needs to be at least 3.0. Given: $major")
    # core profile is only supported for OpenGL 3.2+ (and a must for OSX, so
    # for the sake of homogenity, we try to default to it for everyone!)
    if (major > 3 || (major == 3 && minor >= 2 ))
        profile = GLFW.OPENGL_CORE_PROFILE
    else
        profile = GLFW.OPENGL_ANY_PROFILE
    end
    [
        (GLFW.CONTEXT_VERSION_MAJOR, major),
        (GLFW.CONTEXT_VERSION_MINOR, minor),
        (GLFW.OPENGL_FORWARD_COMPAT, GL_TRUE),
        (GLFW.OPENGL_PROFILE, profile)
    ]
end

"""
Takes half the resolution of the primary monitor.
This should make for sensible defaults!
"""
function standard_screen_resolution()
    w, h = primarymonitorresolution()
    (div(w,2), div(h,2)) # half of total resolution seems like a good fit!
end



"""
Standard window hints for creating a plain context without any multisampling
or extra buffers beside the color buffer
"""
function standard_window_hints()
    [
        (GLFW.SAMPLES,      0),
        (GLFW.DEPTH_BITS,   0),

        (GLFW.ALPHA_BITS,   8),
        (GLFW.RED_BITS,     8),
        (GLFW.GREEN_BITS,   8),
        (GLFW.BLUE_BITS,    8),

        (GLFW.STENCIL_BITS, 0),
        (GLFW.AUX_BUFFERS,  0)
    ]
end
"""
Function to create a pure GLFW OpenGL window
"""
function create_glcontext(
        name = "GLWindow";
        resolution = standard_screen_resolution(),
        debugging = false,
        major = 3,
        minor = 3,# this is what GLVisualize needs to offer all features
        windowhints = standard_window_hints(),
        contexthints = standard_context_hints(major, minor)
    )

    for ch in contexthints
        GLFW.WindowHint(ch...)
    end
    for wh in windowhints
        GLFW.WindowHint(wh...)
    end

    @osx_only begin
        if debugging
            warn("OpenGL debug message callback not available on osx")
            debugging = false
        end
    end
    GLFW.WindowHint(GLFW.OPENGL_DEBUG_CONTEXT, Cint(debugging))

    window = GLFW.CreateWindow(resolution..., utf8(name))
    GLFW.MakeContextCurrent(window)

    debugging && glDebugMessageCallbackARB(_openglerrorcallback, C_NULL)
    window
end


"""
Most basic Screen constructor, which is usually used to create a parent screen.
It creates an OpenGL context and registeres all the callbacks
from the kw_arg `callbacks`.
You can change the OpenGL version with `major` and `minor`.
Also `windowhints` and `contexthints` can be given.
You can query the standard context and window hints
with `GLWindow.standard_context_hints` and `GLWindow.standard_window_hints`.
Finally you have the kw_args color and resolution. The first sets the background
color of the window and the other the resolution of the window.
"""
function Screen(name = "GLWindow";
        resolution = standard_screen_resolution(),
        debugging = false,
        major = 3,
        minor = 3,# this is what GLVisualize needs to offer all features
        windowhints = standard_window_hints(),
        contexthints = standard_context_hints(major, minor),
        callbacks = standard_callbacks(),
        color = RGBA{Float32}(1,1,1,1)
    )
    # create glcontext
    window = create_glcontext(
        name,
        resolution=resolution, debugging=debugging,
        major=major, minor=minor,
        windowhints=windowhints, contexthints=contexthints
    )
    GLFW.ShowWindow(window)

    #create standard signals
    signal_dict = register_callbacks(window, callbacks)
    @materialize window_position, window_size, hasfocus = signal_dict
    @materialize framebuffer_size, cursor_position = signal_dict
    window_area = map(SimpleRectangle,
        Signal(Vec(0,0)),
        framebuffer_size
    )
    signal_dict[:window_area] = window_area
    # seems to be necessary to set this as early as possible
    fb_size = value(framebuffer_size)
    glViewport(0, 0, fb_size...)

    # GLFW uses different coordinates from OpenGL, and on osx, the coordinates
    # are not in pixel coordinates
    # we coorect them to always be in pixel coordinates with 0,0 in left down corner
    signal_dict[:mouseposition] = const_lift(corrected_coordinates,
        Signal(window_size), Signal(framebuffer_size), cursor_position
    )
    signal_dict[:mouse2id] = Signal(SelectionID{Int}(-1, -1))
    # TODO: free when context is freed. We don't have a good abstraction of a gl context yet, though
    # (It could be shared, so it does not map directly to one screen)
    preserve(map(signal_dict[:window_open]) do open
        if !open
            GLAbstraction.empty_shader_cache!()
            GLFW.DestroyWindow(window)
        end
    end)

    screen = Screen(symbol(name),
        window_area, Screen[], signal_dict,
        (), false, color,
        Dict{Symbol, Any}(),
        GLContext(window, GLFramebuffer(framebuffer_size))
    )
    screen
end

"""
Function that creates a screenshot from `window` and saves it to `path`.
You can choose the channel of the framebuffer, which is usually:
`color`, `depth` and `objectid`
"""
screenshot(window; path="screenshot.png", channel=:color) =
   save(path, screenbuffer(window, channel), true)

"""
Returns the contents of the framebuffer of `window` as a Julia Array.
You can choose the channel of the framebuffer, which is usually:
`color`, `depth` and `objectid`
"""
function screenbuffer(window, channel=:color)
    fb = framebuffer(window)
    channels = fieldnames(fb)[2:end]
    if channel in channels
        img = gpu_data(fb.(channel))[window.area.value]
        return rotl90(img)
    end
    error("Channel $channel does not exist. Only these channels are available: $channels")
end



widths(s::Screen) = widths(value(s.area))
ishidden(s::Screen) = s.hidden
framebuffer(s::Screen) = s.glcontext.framebuffer
nativewindow(s::Screen) = s.glcontext.window

"""
Check if a Screen is opened.
"""
function Base.isopen(window::Screen)
    isopen(nativewindow(window))
end
function Base.isopen(window::GLFW.Window)
    !GLFW.WindowShouldClose(window)
end
"""
Swap the framebuffers on the Screen.
"""
function swapbuffers(window::Screen)
    swapbuffers(nativewindow(window))
end
function swapbuffers(window::GLFW.Window)
    GLFW.SwapBuffers(window)
end
"""
Poll events on the screen which will propogate signals through react.
"""
function pollevents()
    GLFW.PollEvents()
end

function mouse2id(s::Screen)
    s.inputs[:mouse2id]
end
export mouse2id
function mouseposition(s::Screen)
    s.inputs[:mouseposition]
end
"""
Empties the content of the renderlist
"""
function Base.empty!(s::Screen)
    s.renderlist = ()
end

"""
returns a copy of the renderlist
"""
function GLAbstraction.renderlist(s::Screen)
    vcat(s.renderlist...)
end
