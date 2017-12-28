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

"""
Create a new rectangle with x,y == 0,0 while taking the widths from the original
Rectangle
"""
zeroposition(r::SimpleRectangle{T}) where {T} = SimpleRectangle(zero(T), zero(T), r.w, r.h)
