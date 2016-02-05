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
    map(m.inputs) do x
        key, value = x
        println(io, "  ", key, " => ", typeof(value))
    end
end

GeometryTypes.isinside{T}(x::Screen, position::Vec{2, T}) =
    !any(screen->isinside(screen.area.value, position...), x.children) && isinside(x.area.value, position...)

GeometryTypes.isinside(screen::Screen, point) = isinside(screen.area.value, point...)

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
