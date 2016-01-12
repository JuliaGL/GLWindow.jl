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
    println(io, "name: ", m.id)
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

function isoutside(screens_mpos)
    screens, mpos = screens_mpos
    for screen in screens
        isinside(screen, mpos) && return false
    end
    true
end

immutable MonitorProperties
    name::ASCIIString
    isprimary::Bool
    position::Vec{2, Int}
    physicalsize::Vec{2, Int}
    videomode::GLFW.VidMode
    videomode_supported::Vector{GLFW.VidMode}
    dpi::Vec{2, Float64}
    monitor::Monitor
end

function MonitorProperties(monitor::Monitor)
    name 		 = GLFW.GetMonitorName(monitor)
    isprimary 	 = GLFW.GetPrimaryMonitor() == monitor
    position	 = Vec{2, Int}(GLFW.GetMonitorPos(monitor)...)
    physicalsize = Vec{2, Int}(GLFW.GetMonitorPhysicalSize(monitor)...)
    videomode 	 = GLFW.GetVideoMode(monitor)

    dpi			 = Vec(videomode.width * 25.4, videomode.height * 25.4) ./ Vec{2, Float64}(physicalsize)
    videomode_supported = GLFW.GetVideoModes(monitor)

    MonitorProperties(name, isprimary, position, physicalsize, videomode, videomode_supported, dpi, monitor)
end

function primarymonitorresolution()
    props = MonitorProperties(GLFW.GetPrimaryMonitor())
    w,h = props.videomode.width, props.videomode.height
    Vec(Int(w),Int(h))
end
function default_screen_resolution()
    w, h = primarymonitorresolution()
    (div(w,2), div(h,2)) # half of total resolution seems like a good fit!
end

zeroposition{T}(r::SimpleRectangle{T}) = SimpleRectangle(zero(T), zero(T), r.w, r.h)
export zeroposition
