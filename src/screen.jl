abstract type Screen end
#each screen backend should be able to do following functions.

include(joinpath(@__DIR__,"GLFW/screen.jl"))

function Base.show(io::IO, m::Screen)
    println(io, "name: ", m.name)
    println(io, "children: ", length(m.children))
    println(io, "callbacks:")
    for (key, value) in m.callbacks
        println(io, "  ", key, " => ", typeof(value))
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

"""
Check if a Screen is opened.
"""
function Base.isopen(screen::Screen)
    isopen(nativewindow(screen))
end

"""
mouse position is in coorditnates relative to `screen`
"""
function isinside(screen::Screen, mpos)
    isinside(zeroposition(screen.area), mpos[1], mpos[2]) || return false
    for s in screen.children
        # if inside any children, it's not inside screen
        isinside(s.area, mpos[1], mpos[2]) && return false
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

function Base.resize!(x::Screen, w::Integer, h::Integer)
    nw = nativewindow(x)
    if isroot(x)
        resize!(nw, w, h)
    end
    area = x.area
    f = scaling_factor(nw)
    # There was some performance issue with round.(Int, SVector) - not sure if resolved.
    wf, hf = round.(f .* (w, h))
    x.area = (x=area[:x], y=area[:y], w=Int(wf), h=Int(hf))
end

widths(s::Screen) = widths(value(s.area))

function abs_area(s::Screen)
    area = s.area
    while !isroot(s)
        s = s.parent
        pa = s.area
        area = (x=area[:x] + pa[:x], y=area[:y] + pa[:y], w=area[:w], h=area[:h])
    end
    area
end

"""
Swap the framebuffers on the Screen.
"""
function swapbuffers(screen::Screen)
    swapbuffers(nativewindow(screen))
end

"""
Empties the content of the renderlist
"""
function Base.empty!(screen::Screen)
    foreach(destroy!, copy(screen.children)) # children delete themselves from screen.children
    return
end

function destroy!(screen::Screen)
    empty!(screen) # remove all children and renderobjects
    # close(screen.area, false)
    if isroot(screen) # close gl context (aka ultimate parent)
        destroywindow!(screen)
    else # delete from parent
        filter!(s-> !(s===screen), screen.parent.children) # remove from parent
    end
    empty!(screen.callbacks)
    return
end

"""
Takes a screen and registers a list of callback functions.
Returns a dict{Symbol, Signal}(name_of_callback => signal)
"""
function register_callbacks(screen::Screen, callbacks::Vector{Function})
    register_callbacks(nativewindow(screen), callbacks)
end

#make_fullscreen is implemented by each backend specifically
make_windowed!(screen::Screen) = make_windowed!(nativewindow(screen))

"""
If hidden, window will stop rendering.
"""
ishidden(s::Screen) = s.hidden

"""
Sets visibility of OpenGL window. Will still render if not visible.
Only applies to the root screen holding the opengl context.
"""
function set_visibility!(screen::Screen, visible::Bool)
    if screen.visiblie != visible
        set_visibility!(nativewindow(screen), visible)
        screen.visible = visible
    end
end

"""
Hides a window and stops it from being rendered.
"""
function hide!(s::Screen)
    if isroot(s)
        set_visibility!(s, false)
    end
    s.hidden = true
end

"""
Shows a window and turns rendering back on
"""
function show!(s::Screen)
    if isroot(s)
        set_visibility!(s, true)
    end
    s.hidden = false
end

