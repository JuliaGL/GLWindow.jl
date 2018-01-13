
mutable struct GLFWScreen <: Screen
    name        ::Symbol
    id          ::Int
    window      ::GLFW.Window
    area        ::Tuple{Int,Int}
    parent      ::GLFWScreen
    children    ::Vector{GLFWScreen}
    callbacks   ::Dict{Symbol, Any}
    visible     ::Bool # if window is visible. Will still render
    hidden      ::Bool # if window is hidden. Will not render
    clear       ::Bool
    function GLFWScreen(
            name        ::Symbol,
            window      ::GLFW.Window,
            area        ::NamedTuple,
            parent      ::Union{Screen, Void},
            children    ::Vector{Screen},
            callbacks   ::Dict{Symbol, Any},
            hidden,
            clear       ::Bool,
        )
        screen = new()
        if parent != nothing
            screen.parent = parent
        end
        screen.name = name
        screen.window = window
        screen.area = area
        screen.children = children
        screen.callbacks = callbacks
        screen.hidden = hidden
        screen.clear = clear
        screen.id = new_id()
        screen
    end
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
function GLFWScreen(name = "GLWindow";
        resolution = standard_screen_resolution(),
        debugging = false,
        major = 3,
        minor = 3,# this is what GLVisualize needs to offer all features
        windowhints = standard_window_hints(),
        contexthints = standard_context_hints(major, minor),
        callbacks = standard_callbacks(),
        clear = true,
        hidden = false,
        visible = true,
        focus = false,
        fullscreen = false,
        monitor = nothing

    )
    # create glcontext

    window = GLFW.Window(
        name,
        resolution = resolution, debugging = debugging,
        major = major, minor = minor,
        windowhints = windowhints, contexthints=contexthints,
        visible = visible, focus = focus,
        fullscreen = fullscreen,
        monitor = monitor
    )
    #create standard signals
    callback_dict = register_callbacks(window, callbacks)

    area = (x=0, y=0, w=resolution[1], h=resolution[2])
    GLFW.SwapInterval(0) # deactivating vsync seems to make everything quite a bit smoother
    screen = Screen(
        Symbol(name), window, area, nothing,
        Screen[], callback_dict,
        (), hidden, clear
    )
    screen
end

"Create a screen from a parent screen"
function GLFWScreen(
        parent::GLFWScreen;
        name = gensym(parent.name),
        area = zeroposition(parent.area),
        children::Vector{GLFWScreen} = GLFWScreen[],
        callbacks::Dict{Symbol, Any} = copy(parent.callbacks),
        hidden = parent.hidden,
        clear::Bool = parent.clear,
    )
    #i'm not sure about the parent.window here!
    screen = GLFWScreen(name, parent.window, area, parent, children, callbacks, hidden, clear)
    push!(parent.children, screen)
    screen
end

nativewindow(s::Screen) = s.glcontext.window

function destroywindow!(screen::GLFWScreen)
    nw = nativewindow(screen)
    if nw.handle != C_NULL
        GLFW.DestroyWindow(nw)
        nw.handle = C_NULL
    end
end

make_fullscreen!(screen::GLFWScreen, monitor::GLFW.Monitor = GLFW.GetPrimaryMonitor()) = make_fullscreen!(nativewindow(screen), monitor)

function scaling_factor(nw)
    w, fb = GLFW.GetWindowSize(nw), GLFW.GetFramebufferSize(nw)
    scaling_factor((w,w), (fb,fb))
end