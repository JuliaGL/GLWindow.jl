
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
        |  $(String(message, length))
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
        area = map(zeroposition, parent.area),
        children::Vector{Screen} = Screen[],
        inputs::Dict{Symbol, Any} = copy(parent.inputs),
        renderlist::Tuple = (),
        hidden = parent.hidden,
        clear::Bool = parent.clear,
        color = RGBA{Float32}(1,1,1,1),
        stroke = (0f0, color),
        glcontext::AbstractContext = parent.glcontext,
        cameras = Dict{Symbol, Any}(),
        position = Vec3f0(2),
        lookat = Vec3f0(0)
    )
    screen = Screen(name,
        area, parent, children, inputs,
        renderlist, hidden, clear, color, stroke,
        cameras, glcontext
    )
    pintersect = const_lift(x->intersect(zeroposition(value(parent.area)), x), area)
    relative_mousepos = map(inputs[:mouseposition]) do mpos
        Point{2, Float64}(mpos[1]-value(pintersect).x, mpos[2]-value(pintersect).y)
    end
    #checks if mouse is inside screen and not inside any children
    insidescreen = droprepeats(const_lift(isinside, screen, relative_mousepos))
    merge!(screen.inputs, Dict(
        :mouseinside => insidescreen,
        :mouseposition => relative_mousepos,
        :window_area => area
    ))
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
    Vec{2,Float64}(mouse_position[1], window_size.value[2] - mouse_position[2]) .* s
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


full_screen_usage_message() = """
Keyword arg fullscreen accepts:
    Integer: The number of the Monitor to Select
    Bool: if true, primary monitor gets fullscreen, false no fullscren (default)
    GLFW.Monitor: Fullscreens on the passed monitor
"""

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
        contexthints = standard_context_hints(major, minor),
        visible = true,
        focus = false,
        fullscreen = false
    )
    # we create a new context, so we need to clear the shader cache.
    # TODO, cache shaders in GLAbstraction per GL context
    GLFW.WindowHint(GLFW.VISIBLE, visible)
    GLFW.WindowHint(GLFW.FOCUSED, focus)
    GLAbstraction.empty_shader_cache!()
    for ch in contexthints
        GLFW.WindowHint(ch[1], ch[2])
    end
    for wh in windowhints
        GLFW.WindowHint(wh[1], wh[2])
    end

    @static if is_apple()
        if debugging
            warn("OpenGL debug message callback not available on osx")
            debugging = false
        end
    end
    GLFW.WindowHint(GLFW.OPENGL_DEBUG_CONTEXT, Cint(debugging))
    monitor = if fullscreen != nothing
        if isa(fullscreen, GLFW.Monitor)
            monitor
        elseif isa(fullscreen, Bool)
            fullscreen ? GLFW.GetPrimaryMonitor() : GLFW.Monitor(C_NULL)
        elseif isa(fullscreen, Integer)
            GLFW.GetMonitors()[fullscreen]

        else
            error(string(
                "Usage Error. Keyword argument fullscreen has value: $fullscreen.\n",
                full_screen_usage_message()
            ))
        end
    else
        GLFW.Monitor(C_NULL)
    end
    window = GLFW.CreateWindow(resolution..., String(name))
    if monitor != GLFW.Monitor(C_NULL)
        GLFW.SetKeyCallback(window, (_1, button, _2, _3, _4) -> begin
            button == GLFW.KEY_ESCAPE && GLWindow.make_windowed!(window)
        end)
        GLWindow.make_fullscreen!(window)
    end
    GLFW.MakeContextCurrent(window)
    # tell GLAbstraction that we created a new context.
    # This is important for resource tracking
    GLAbstraction.new_context()

    debugging && glDebugMessageCallbackARB(_openglerrorcallback, C_NULL)
    window
end

make_fullscreen!(screen::Screen, monitor::GLFW.Monitor = GLFW.GetPrimaryMonitor()) = make_fullscreen!(nativewindow(screen), monitor)
function make_fullscreen!(window::GLFW.Window, monitor::GLFW.Monitor = GLFW.GetPrimaryMonitor())
    vidmodes = GLFW.GetVideoModes(monitor)[end]
    GLFW.SetWindowMonitor(window, monitor, 0, 0, vidmodes.width, vidmodes.height, GLFW.DONT_CARE)
    return
end

make_windowed!(screen::Screen) = make_windowed!(nativewindow(screen))
function make_windowed!(window::GLFW.Window)
    width, height = standard_screen_resolution()
    GLFW.SetWindowMonitor(window, GLFW.Monitor(C_NULL), 0, 0, width, height, GLFW.DONT_CARE)
    return
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
        clear = true,
        color = RGBA{Float32}(1,1,1,1),
        stroke = (0f0, color),
        hidden = false,
        visible = true,
        focus = false,
        fullscreen = false
    )
    # create glcontext

    window = create_glcontext(
        name,
        resolution = resolution, debugging = debugging,
        major = major, minor = minor,
        windowhints = windowhints, contexthints=contexthints,
        visible = visible, focus = focus,
        fullscreen = fullscreen
    )
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

    GLFW.SwapInterval(0) # deactivating vsync seems to make everything quite a bit smoother
    screen = Screen(
        Symbol(name), window_area, nothing,
        Screen[], signal_dict,
        (), hidden, clear, color, stroke,
        Dict{Symbol, Any}(),
        GLContext(window, GLFramebuffer(framebuffer_size), visible)
    )
    signal_dict[:mouseinside] = droprepeats(
        const_lift(isinside, screen, signal_dict[:mouseposition])
    )
    screen
end

"""
Function that creates a screenshot from `window` and saves it to `path`.
You can choose the channel of the framebuffer, which is usually:
`color`, `depth` and `objectid`
"""
function screenshot(window; path="screenshot.png", channel=:color)
    save(path, screenbuffer(window, channel), true)
end

"""
Returns the contents of the framebuffer of `window` as a Julia Array.
You can choose the channel of the framebuffer, which is usually:
`color`, `depth` and `objectid`
"""
function screenbuffer(window, channel = :color)
    fb = framebuffer(window)
    channels = fieldnames(fb)[2:end]
    area = abs_area(window)
    w = widths(area)
    x1, x2 = max(area.x, 1), min(area.x + w[1], size(fb.color, 1))
    y1, y2 = max(area.y, 1), min(area.y + w[2], size(fb.color, 2))
    if channel == :depth
        w, h = x2 - x1 + 1, y2 - y1 + 1
        data = Matrix{Float32}(w, h)
        glBindFramebuffer(GL_FRAMEBUFFER, fb.id[1])
        glDisable(GL_SCISSOR_TEST)
        glDisable(GL_STENCIL_TEST)
        glReadPixels(x1 - 1, y1 - 1, w, h, GL_DEPTH_COMPONENT, GL_FLOAT, data)
        return rotl90(data)
    elseif channel in channels
        buff = gpu_data(getfield(fb, channel))
        img = view(buff, x1:x2, y1:y2)
        if channel == :color
            img = RGB{N0f8}.(img)
        end
        return rotl90(img)
    end
    error("Channel $channel does not exist. Only these channels are available: $channels")
end

"""
If hidden, window will stop rendering.
"""
ishidden(s::Screen) = value(s.hidden)

"""
Hides a window and stops it from being rendered.
"""
function hide!(s::Screen)
    if isroot(s)
        set_visibility!(s, false)
    end
    push!(s.hidden, true)
end
"""
Shows a window and turns rendering back on
"""
function show!(s::Screen)
    if isroot(s)
        set_visibility!(s, true)
    end
    push!(s.hidden, false)
end


"""
Sets visibility of OpenGL window. Will still render if not visible.
Only applies to the root screen holding the opengl context.
"""
function set_visibility!(screen::Screen, visible::Bool)
    set_visibility!(screen.glcontext, visible)
    return
end
function set_visibility!(glc::AbstractContext, visible::Bool)
    if glc.visible != visible
        set_visibility!(glc.window, visible)
        glc.visible = visible
    end
    return
end
function set_visibility!(screen::GLFW.Window, visible::Bool)
    if visible
        GLFW.ShowWindow(screen)
    else !visible
        GLFW.HideWindow(screen)
    end
    return
end


widths(s::Screen) = widths(value(s.area))
framebuffer(s::Screen) = s.glcontext.framebuffer
nativewindow(s::Screen) = s.glcontext.window

"""
Check if a Screen is opened.
"""
function Base.isopen(window::Screen)
    isopen(nativewindow(window))
end
function Base.isopen(window::GLFW.Window)
    window.handle == C_NULL && return false
    !GLFW.WindowShouldClose(window)
end
"""
Swap the framebuffers on the Screen.
"""
function swapbuffers(window::Screen)
    swapbuffers(nativewindow(window))
end
function swapbuffers(window::GLFW.Window)
    window.handle == C_NULL && return
    GLFW.SwapBuffers(window)
    return
end
function Base.resize!(x::Screen, w::Int, h::Int)
    if isroot(x)
        resize!(GLWindow.nativewindow(x), w, h)
    end
    area = value(x.area)
    push!(x.area, SimpleRectangle(area.x, area.y, w, h))
end
function Base.resize!(x::GLFW.Window, w::Int, h::Int)
    GLFW.SetWindowSize(x, w, h)
end

"""
Poll events on the screen which will propogate signals through react.
"""
function poll_glfw()
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
function Base.empty!(screen::Screen)
    screen.renderlist = () # remove references and empty lists
    screen.renderlist_fxaa = () # remove references and empty lists
    foreach(destroy!, copy(screen.children)) # children delete themselves from screen.children
    return
end

"""
returns a copy of the renderlist
"""
function GLAbstraction.renderlist(s::Screen)
    vcat(s.renderlist..., s.renderlist_fxaa...)
end
function destroy!(screen::Screen)
    empty!(screen) # remove all children and renderobjects
    close(screen.area, false)
    empty!(screen.cameras)
    if isroot(screen) # close gl context (aka ultimate parent)
        nw = nativewindow(screen)
        for (k, s) in screen.inputs
            close(s, false)
        end
        if nw.handle != C_NULL
            GLFW.DestroyWindow(nw)
            nw.handle = C_NULL
        end
    else # delete from parent
        filter!(s-> !(s===screen), screen.parent.children) # remove from parent
    end
    empty!(screen.inputs)

    return
end

get_id(x::Integer) = x
get_id(x::RenderObject) = x.id
function delete_robj!(list, robj)
    for (i, id) in enumerate(list)
        if get_id(id) == robj.id
            splice!(list, i)
            return true, i
        end
    end
    false, 0
end

function Base.delete!(screen::Screen, robj::RenderObject)
    for renderlist in screen.renderlist
        deleted, i = delete_robj!(renderlist, robj)
        deleted && return true
    end
    for renderlist in screen.renderlist_fxaa
        deleted, i = delete_robj!(renderlist, robj)
        deleted && return true
    end
    false
end

function GLAbstraction.robj_from_camera(window, camera)
    cam = window.cameras[camera]
    return filter(renderlist(window)) do robj
        robj[:projection] == cam.projection
    end
end

function isroot(s::Screen)
    !isdefined(s, :parent)
end
function rootscreen(s::Screen)
    while !isroot(s)
        s = s.parent
    end
    s
end

function abs_area(s::Screen)
    area = value(s.area)
    while !isroot(s)
        s = s.parent
        pa = value(s.area)
        area = SimpleRectangle(area.x + pa.x, area.y + pa.y, area.w, area.h)
    end
    area
end

function Base.push!(screen::Screen, robj::RenderObject{Pre}) where Pre
    # since fxaa is the default, if :fxaa not in uniforms --> needs fxaa
    sym = Bool(get(robj.uniforms, :fxaa, true)) ? :renderlist_fxaa : :renderlist
    # find renderlist specialized to current prerender function
    index = findfirst(getfield(screen, sym)) do renderlist
        prerendertype(eltype(renderlist)) == Pre
    end
    if index == 0
        # add new specialised renderlist, if none found
        setfield!(screen, sym, (getfield(screen, sym)..., RenderObject{Pre}[]))
        index = length(getfield(screen, sym))
    end
    # only add to renderlist if not already in there
    in(robj, getfield(screen, sym)[index]) || push!(getfield(screen, sym)[index], robj)
    nothing
end
