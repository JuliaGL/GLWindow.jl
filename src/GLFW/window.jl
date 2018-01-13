

function GLFWWindow(
        name = "GLWindow";
        resolution = standard_screen_resolution(),
        debugging = false,
        major = 3,
        minor = 3,# this is what GLVisualize needs to offer all features
        windowhints = standard_window_hints(),
        contexthints = standard_context_hints(major, minor),
        visible = true,
        focus = false,
        fullscreen = false,
        monitor = nothing
    )
    WindowHint(VISIBLE, visible)
    WindowHint(FOCUSED, focus)
    for ch in contexthints
        WindowHint(ch[1], ch[2])
    end
    for wh in windowhints
        WindowHint(wh[1], wh[2])
    end

    @static if is_apple()
        if debugging
            warn("OpenGL debug message callback not available on osx")
            debugging = false
        end
    end

    WindowHint(OPENGL_DEBUG_CONTEXT, Cint(debugging))

    monitor = if monitor == nothing
        GetPrimaryMonitor()
    elseif isa(monitor, Integer)
        GetMonitors()[monitor]
    elseif isa(monitor, Monitor)
        monitor
    else
        error("Monitor needs to be nothing, int, or GLFW.Monitor. Found: $monitor")
    end

    window = CreateWindow(resolution..., String(name))

    if fullscreen
        SetKeyCallback(window, (_1, button, _2, _3, _4) -> begin
            button == KEY_ESCAPE && make_windowed!(window)
        end)
        make_fullscreen!(window, monitor)
    end

    MakeContextCurrent(window)

    #this line didnt make it... Is it necessary? I think we can keep this for in the higher level screen
    debugging && glDebugMessageCallbackARB(_openglerrorcallback, C_NULL)
    window
end

function Base.isopen(window::Window)
    window.handle == C_NULL && return false
    !WindowShouldClose(window)
end

function Base.resize!(x::Window, w::Integer, h::Integer)
    SetWindowSize(x, w, h)
end


function swapbuffers(window::Window)
    window.handle == C_NULL && return
    SwapBuffers(window)
    return
end
#Came from GLWindow.jl/screen.jl
#question: Is this correct?
"""
Takes a Window and registers a list of callback functions.
Returns a Dict{Symbol, Any}(name_of_callback => signal)
"""
function register_callbacks(window::Window, callbacks::Vector{Function})
    tmp = map(callbacks) do f
        (Symbol(last(split(string(f),"."))), f(window))
    end
    Dict{Symbol, Any}(tmp)
end

#question: what is this exactly?
full_screen_usage_message() = """
Keyword arg fullscreen accepts:
    Integer: The number of the Monitor to Select
    Bool: if true, primary monitor gets fullscreen, false no fullscren (default)
    GLFW.Monitor: Fullscreens on the passed monitor
"""

function poll_glfw()
    PollEvents()
end

#Came from: GLWindow/events.jl
function to_arrow_symbol(button_set)
    for b in button_set
        KEY_RIGHT == b && return :right
        KEY_LEFT  == b && return :left
        KEY_DOWN  == b && return :down
        KEY_UP    == b && return :up
    end
    return :nothing
end