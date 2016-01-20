
type GLFramebuffer
    id         ::GLuint
    color      ::Texture{RGBA{UFixed8}, 2}
    objectid   ::Texture{Vec{2, GLushort}, 2}
    depth      ::Texture{Float32, 2}
    postprocess::RenderObject
end
Base.size(fb::GLFramebuffer) = size(fb.color) # it's guaranteed, that they all have the same size

loadshader(name) = load(joinpath(dirname(@__FILE__), name))
"""
Creates a postprocessing render object.
This will transfer the pixels from the color texture of the Framebuffer
to the screen and while at it, it can do some postprocessing (not doing it right now):
E.g fxaa anti aliasing, color correction etc.
"""
function postprocess(color::Texture, framebuffer_size)
    data = Dict{Symbol, Any}()
    @gen_defaults! data begin
        main       = nothing
        model      = eye(Mat4f0)
        resolution = const_lift(Vec2f0, framebuffer_size)
        u_texture0 = color
        primitive::GLUVMesh2D = SimpleRectangle(-1f0,-1f0, 2f0, 2f0)
        shader     = LazyShader(
            loadshader("fxaa.vert"),
            loadshader("fxaa.frag"),
            loadshader("fxaa_combine.frag")
        )
    end
    std_renderobject(data, shader, Signal(AABB{Float32}(primitive)))
end

function attach_framebuffer{T}(t::Texture{T, 2}, attachment)
    glFramebufferTexture2D(GL_FRAMEBUFFER, attachment, GL_TEXTURE_2D, t.id, 0)
end

function GLFramebuffer(fb_size)
    render_framebuffer = glGenFramebuffers()
    glBindFramebuffer(GL_FRAMEBUFFER, render_framebuffer)

    buffersize      = tuple(value(fb_size)...)
    color_buffer    = Texture(RGBA{UFixed8},    buffersize, minfilter=:nearest, x_repeat=:clamp_to_edge)
    objectid_buffer = Texture(Vec{2, GLushort}, buffersize, minfilter=:nearest, x_repeat=:clamp_to_edge)
    depth_buffer    = Texture(Float32, buffersize,
        internalformat = GL_DEPTH_COMPONENT32F,
        format         = GL_DEPTH_COMPONENT,
        minfilter=:nearest, x_repeat=:clamp_to_edge
    )
    attach_framebuffer(color_buffer, GL_COLOR_ATTACHMENT0)
    attach_framebuffer(objectid_buffer, GL_COLOR_ATTACHMENT1)
    attach_framebuffer(depth_buffer, GL_DEPTH_ATTACHMENT)

    p  = postprocess(color_buffer, fb_size)
    fb = GLFramebuffer(render_framebuffer, color_buffer, objectid_buffer, depth_buffer, p)
    glBindFramebuffer(GL_FRAMEBUFFER, 0)
    fb
end

function Base.resize!(fb::GLFramebuffer, window_size)
    ws = tuple(window_size...)
    if ws!=size(fb) && all(x->x>0, window_size)
        render_framebuffer = glGenFramebuffers()
        glBindFramebuffer(GL_FRAMEBUFFER, render_framebuffer)

        buffersize      = tuple(window_size...)
        color_buffer    = Texture(RGBA{UFixed8},    buffersize, minfilter=:nearest, x_repeat=:clamp_to_edge)
        objectid_buffer = Texture(Vec{2, GLushort}, buffersize, minfilter=:nearest, x_repeat=:clamp_to_edge)
        depth_buffer    = Texture(Float32, buffersize,
            internalformat = GL_DEPTH_COMPONENT32F,
            format         = GL_DEPTH_COMPONENT,
            minfilter=:nearest, x_repeat=:clamp_to_edge
        )
        attach_framebuffer(color_buffer, GL_COLOR_ATTACHMENT0)
        attach_framebuffer(objectid_buffer, GL_COLOR_ATTACHMENT1)
        attach_framebuffer(depth_buffer, GL_DEPTH_ATTACHMENT)

        p  = postprocess(color_buffer, Signal(window_size))
        fb.id = render_framebuffer
        fb.color = color_buffer
        fb.objectid = objectid_buffer
        fb.depth = depth_buffer
        fb.postprocess = p
        glBindFramebuffer(GL_FRAMEBUFFER, 0)
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

immutable GLContext
    window::GLFW.Window
    framebuffer::GLFramebuffer
end



type Screen
    name 		::Symbol
    area 		::Signal{SimpleRectangle{Int}}
    parent 		::Screen
    children 	::Vector{Screen}
    inputs 		::Dict{Symbol, Any}
    renderlist 	::Vector{RenderObject}

    hidden 		::Bool
    color       ::RGBA{Float32}

    cameras 	::Dict{Symbol, Any}

    glcontext   ::GLContext

    function Screen(
            name        ::Symbol,
            area        ::Signal{SimpleRectangle{Int}},
            parent 		::Screen,
            children 	::Vector{Screen},
            inputs 		::Dict{Symbol, Any},
            renderlist 	::Vector{RenderObject},
            hidden 		::Bool,
            color       ::Colorant,
            cameras 	::Dict{Symbol, Any},
            context     ::GLContext
        )
        new(
            name, area, parent,
            children, inputs, renderlist,
            hidden, RGBA{Float32}(color), cameras,
            context
        )
    end

    function Screen(
            name        ::Symbol,
            area        ::Signal{SimpleRectangle{Int}},
            children    ::Vector{Screen},
            inputs      ::Dict{Symbol, Any},
            renderlist  ::Vector{RenderObject},
            hidden      ::Bool,
            color       ::Colorant,
            cameras     ::Dict{Symbol, Any},
            context     ::GLContext
        )
        parent = new()
        new(
            name, area, parent,
            children, inputs, renderlist,
            hidden, color, cameras,
            context
        )
    end
end


width(s::Screen) = widths(value(s.area))
ishidden(s::Screen) = s.hidden
framebuffer(s::Screen) = s.glcontext.framebuffer
nativewindow(s::Screen) = s.glcontext.window

"""
Check if a Screen is opened.
"""
function Base.isopen(s::Screen)
    !GLFW.WindowShouldClose(nativewindow(s))
end

"""
Swap the framebuffers on the Screen.
"""
function swapbuffers(s::Screen)
    GLFW.SwapBuffers(nativewindow(s))
end

"""
Poll events on the screen which will propogate signals through react.
"""
function pollevents(::Screen)
    GLFW.PollEvents()
end

function mouse2id(s::Screen)
    s.inputs[:mouse2id]
end
function mouseposition(s::Screen)
    s.inputs[:mouseposition]
end
