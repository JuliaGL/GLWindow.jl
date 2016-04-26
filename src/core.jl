#=
Functions that are derived from Base or other packages
=#
function Base.show(io::IO, m::MonitorProperties)
    println(io, "name: ", m.name)
    println(io, "physicalsize: ",  m.physicalsize[1], "x", m.physicalsize[2])
    println(io, "resolution: ", m.videomode.width, "x", m.videomode.height)
    println(io, "dpi: ", m.dpi[1], "x", m.dpi[2])
end
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
    isinside(zeroposition(value(screen.area)), mpos...) || return false
    for s in screen.children
        # if inside any children, it's not inside screen
        isinside(value(s.area), mpos...) && return false
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

"""
Returns the monitor resolution of the primary monitor.
"""
function primarymonitorresolution()
    props = MonitorProperties(GLFW.GetPrimaryMonitor())
    w,h = props.videomode.width, props.videomode.height
    Vec(Int(w),Int(h))
end

"""
Create a new rectangle with x,y == 0,0 while taking the widths from the original
Rectangle
"""
zeroposition{T}(r::SimpleRectangle{T}) = SimpleRectangle(zero(T), zero(T), r.w, r.h)
