#Came from GLWindow/types.jl
using Base.RefValue
#This should be put in some kind of globals.jl file, like where the contexts are being counted.
const screen_id_counter = RefValue(0)
# start from new and hope we don't display all displays at once.
# TODO make it clearer if we reached max num, or if we just created
# a lot of small screens and display them simultanously
new_id() = (screen_id_counter[] = mod1(screen_id_counter[] + 1, 255); screen_id_counter[])[]

mutable struct Screen
    name        ::Symbol
    area        ::Signal{SimpleRectangle{Int}}
    parent      ::Screen
    children    ::Vector{Screen}
    inputs      ::Dict{Symbol, Any}
    isleaf_signal ::Dict{Symbol, Bool}
    renderlist_fxaa::Tuple # a tuple of specialized renderlists
    renderlist     ::Tuple # a tuple of specialized renderlists
    visible     ::Bool # if window is visible. Will still render
    hidden      ::Signal{Bool} # if window is hidden. Will not render
    clear       ::Bool
    color       ::RGBA{Float32}
    stroke      ::Tuple{Float32, RGBA{Float32}}

    cameras     ::Dict{Symbol, Any}

    glcontext   ::AbstractContext
    id          ::Int

    function Screen(
            name        ::Symbol,
            area        ::Signal{SimpleRectangle{Int}},
            parent      ::Union{Screen, Void},
            children    ::Vector{Screen},
            inputs      ::Dict{Symbol, Any},
            renderlist  ::Tuple,
            hidden,
            clear       ::Bool,
            color       ::Colorant,
            stroke      ::Tuple,
            cameras     ::Dict{Symbol, Any},
            context     ::AbstractContext
        )
        screen = new()
        if parent != nothing
            screen.parent = parent
        end
        leaves = Dict{Symbol, Bool}()
        for (k, v) in inputs
            leaves[k] = isempty(v.actions)
        end
        screen.name = name
        screen.area = area
        screen.children = children
        screen.inputs = inputs
        screen.isleaf_signal = leaves
        screen.renderlist = renderlist
        screen.renderlist_fxaa = ()
        screen.hidden = isa(hidden, Signal) ? hidden : Signal(hidden)
        screen.clear = clear
        screen.color = RGBA{Float32}(color)
        screen.stroke = (Float32(stroke[1]), RGBA{Float32}(stroke[2]))
        screen.cameras = cameras
        screen.glcontext = context
        screen.id = new_id()
        screen
    end
end

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
        fullscreen = false,
        monitor = nothing

    )
    # create glcontext

    window = create_glcontext(
        name,
        resolution = resolution, debugging = debugging,
        major = major, minor = minor,
        windowhints = windowhints, contexthints=contexthints,
        visible = visible, focus = focus,
        fullscreen = fullscreen,
        monitor = monitor
    )
    #create standard signals
    signal_dict = register_callbacks(window, callbacks)
    @materialize window_position, window_size, hasfocus = signal_dict
    @materialize framebuffer_size, cursor_position = signal_dict

    # make sure we get newest updates from glfw and reactive!
    push!(framebuffer_size, Vec(GLFW.GetFramebufferSize(window)))

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
Takes a screen and registers a list of callback functions.
Returns a dict{Symbol, Signal}(name_of_callback => signal)
"""
function register_callbacks(window::Screen, callbacks::Vector{Function})
    register_callbacks(window.nativewindow, callbacks)
end



make_fullscreen!(screen::Screen, monitor::GLFW.Monitor = GLFW.GetPrimaryMonitor()) = make_fullscreen!(nativewindow(screen), monitor)


make_windowed!(screen::Screen) = make_windowed!(nativewindow(screen))


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

widths(s::Screen) = widths(value(s.area))
framebuffer(s::Screen) = s.glcontext.framebuffer
nativewindow(s::Screen) = s.glcontext.window


"""
Check if a Screen is opened.
"""
function Base.isopen(screen::Screen)
    isopen(nativewindow(screen))
end

"""
Swap the framebuffers on the Screen.
"""
function swapbuffers(screen::Screen)
    swapbuffers(nativewindow(screen))
end

function Base.resize!(x::Screen, w::Integer, h::Integer)
    nw = GLWindow.nativewindow(x)
    if isroot(x)
        resize!(nw, w, h)
    end
    area = value(x.area)
    f = scaling_factor(nw)
    # There was some performance issue with round.(Int, SVector) - not sure if resolved.
    wf, hf = round.(f .* Vec(w, h))
    push!(x.area, SimpleRectangle(area.x, area.y, Int(wf), Int(hf)))
end
"""
Poll events on the screen which will propogate signals through react.
"""
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

function Base.delete!(screen::Screen, c::Composable)
    deleted = false
    for elem in GLAbstraction.extract_renderable(c)
        deleted &= delete!(screen, elem)
    end
    deleted # TODO This is not really correct...
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

#=
Functions that are derived from Base or other packages
=#

function Base.show(io::IO, m::Screen)
    println(io, "name: ", m.name)
    println(io, "children: ", length(m.children))
    println(io, "Inputs:")
    for (key, value) in m.inputs
        println(io, "  ", key, " => ", typeof(value))
    end
end

"""
mouse position is in coorditnates relative to `screen`
"""
function GeometryTypes.isinside(screen::Screen, mpos)
    isinside(zeroposition(value(screen.area)), mpos[1], mpos[2]) || return false
    for s in screen.children
        # if inside any children, it's not inside screen
        isinside(value(s.area), mpos[1], mpos[2]) && return false
    end
    true
end

"""
Args: `screens_mpos` -> Tuple{Vector{Screen}, Vec{2,T}}
"""
function isoutside(screens_mouseposition)
    screens, mpos = screens_mouseposition
    for screen in screens
        isinside(screen, mpos) && return false
    end
    true
end

