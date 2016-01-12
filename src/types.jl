type GLFramebuffer
    render_framebuffer ::GLuint
    color              ::Texture{RGBA{UFixed8}, 2}
    objectid           ::Texture{Vec{2, GLushort}, 2}
    depth              ::Texture{Float32, 2}
    postprocess        ::RenderObject
end


function GLFramebuffer(framebuffsize::Signal{Vec{2, Int}})
    render_framebuffer = glGenFramebuffers()
    glBindFramebuffer(GL_FRAMEBUFFER, render_framebuffer)

    buffersize      = tuple(framebuffsize.value...)
    color_buffer    = Texture(RGBA{UFixed8},    buffersize, minfilter=:nearest, x_repeat=:clamp_to_edge)
    objectid_buffer = Texture(Vec{2, GLushort}, buffersize, minfilter=:nearest, x_repeat=:clamp_to_edge)
    depth_buffer    = Texture(Float32, buffersize,
        internalformat = GL_DEPTH_COMPONENT32F,
        format         = GL_DEPTH_COMPONENT,
        minfilter=:nearest, x_repeat=:clamp_to_edge
    )

    glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_TEXTURE_2D, color_buffer.id, 0)
    glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT1, GL_TEXTURE_2D, objectid_buffer.id, 0)
    glFramebufferTexture2D(GL_FRAMEBUFFER, GL_DEPTH_ATTACHMENT,  GL_TEXTURE_2D, depth_buffer.id, 0)
    p  = postprocess(color_buffer, framebuffsize)
    fb = GLFramebuffer(render_framebuffer, color_buffer, objectid_buffer, depth_buffer, p)
    preserve(const_lift(resizebuffers, framebuffsize, fb))
    glBindFramebuffer(GL_FRAMEBUFFER, 0)
    fb
end

function resizebuffers(window_size, framebuffer::GLFramebuffer)
    if all(x->x>0, window_size)
        render_framebuffer = glGenFramebuffers()
        glBindFramebuffer(GL_FRAMEBUFFER, render_framebuffer)
        ws = tuple(window_size...)
        resize_nocopy!(framebuffer.color,    ws)
        resize_nocopy!(framebuffer.objectid, ws)
        resize_nocopy!(framebuffer.depth,    ws)

        glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_TEXTURE_2D, framebuffer.color.id, 0)
        glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT1, GL_TEXTURE_2D, framebuffer.objectid.id, 0)
        glFramebufferTexture2D(GL_FRAMEBUFFER, GL_DEPTH_ATTACHMENT,  GL_TEXTURE_2D, framebuffer.depth.id, 0)

        glBindFramebuffer(GL_FRAMEBUFFER, 0)
        framebuffer.render_framebuffer = render_framebuffer
    end
    nothing
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

type Screen
    id 		 	::Symbol
    area 		::Signal{SimpleRectangle{Int}}
    parent 		::Screen
    children 	::Vector{Screen}
    inputs 		::Dict{Symbol, Any}
    renderlist 	::Vector{RenderObject}


    hidden 		::Signal{Bool}
    hasfocus 	::Signal{Bool}

    cameras 	::Dict{Symbol, Any}
    nativewindow::Window
    transparent ::Signal{Bool}
    keydict     ::Dict{Int, Bool}

    function Screen(
            name::Symbol,
            area,
            parent 		::Screen,
            children 	::Vector{Screen},
            inputs 		::Dict{Symbol, Any},
            renderlist 	::Vector{RenderObject},

            hidden 		::Signal{Bool},
            hasfocus 	::Signal{Bool},
            cameras 	::Dict{Symbol, Any},
            nativewindow::Window,
            transparent = Signal(false)
        )
        global SCREEN_ID_COUNTER
        new(
            name,
            area, parent, children, inputs, renderlist,
            hidden, hasfocus, cameras, nativewindow, transparent, Dict{Int, Bool}()
        )
    end

    function Screen(
            name,
            area,
            children 	 ::Vector{Screen},
            inputs 		 ::Dict{Symbol, Any},
            renderlist 	 ::Vector{RenderObject},

            hidden  	 ::Signal{Bool},
            hasfocus 	 ::Signal{Bool},
            cameras 	 ::Dict{Symbol, Any},
            nativewindow ::Window,
            transparent = Signal(false)
        )
        parent = new()
        global SCREEN_ID_COUNTER
        new(
            name,
            area, parent, children, inputs,
            renderlist, hidden, hasfocus,
            cameras, nativewindow, transparent, Dict{Int, Bool}()
        )
    end
end
