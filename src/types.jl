
type GLFramebuffer{T}
    id1        ::GLuint
    id2        ::GLuint
    color      ::Texture{RGBA{UFixed8}, 2}
    objectid   ::Texture{Vec{2, GLushort}, 2}
    depth      ::Texture{Float32, 2}
    color_luma ::Texture{RGBA{UFixed8}, 2}
    postprocess::T
end
Base.size(fb::GLFramebuffer) = size(fb.color) # it's guaranteed, that they all have the same size

loadshader(name) = load(joinpath(dirname(@__FILE__), name))

function draw_fullscreen(vao_id)
    glBindVertexArray(vao_id)
    glDrawArrays(GL_TRIANGLES, 0, 3)
    glBindVertexArray(0)
end
immutable PostprocessPrerender
end
@compat function (sp::PostprocessPrerender)()
    glDepthMask(GL_TRUE)
    glDisable(GL_DEPTH_TEST)
    glDisable(GL_BLEND)
    glDisable(GL_STENCIL_TEST)
    glStencilMask(0xff)
    glDisable(GL_CULL_FACE)
end



rcpframe(x) = 1f0./Vec2f0(x[1], x[2])

"""
Creates a postprocessing render object.
This will transfer the pixels from the color texture of the Framebuffer
to the screen and while at it, it can do some postprocessing (not doing it right now):
E.g fxaa anti aliasing, color correction etc.
"""
function postprocess(color::Texture, color_luma::Texture, framebuffer_size)
    shader1 = LazyShader(
        loadshader("fullscreen.vert"),
        loadshader("postprocess.frag")
    )
    data1 = Dict{Symbol, Any}(
        :color_texture => color
    )
    pass1 = RenderObject(data1, shader1, PostprocessPrerender(), nothing)
    pass1.postrenderfunction = () -> draw_fullscreen(pass1.vertexarray.id)

    shader2 = LazyShader(
        loadshader("fullscreen.vert"),
        loadshader("fxaa.frag")
    )
    data2 = Dict{Symbol, Any}(
        :color_texture => color_luma,
        :RCPFrame => map(rcpframe, framebuffer_size)
    )
    pass2 = RenderObject(data2, shader2, PostprocessPrerender(), nothing)
    pass2.postrenderfunction = () -> draw_fullscreen(pass2.vertexarray.id)

    shader3 = LazyShader(
        GLWindow.loadshader("fullscreen.vert"),
        GLWindow.loadshader("copy.frag")
    )
    data3 = Dict{Symbol, Any}(
        :color_texture => color
    )
    pass3 = RenderObject(data3, shader3, GLWindow.PostprocessPrerender(), nothing)
    pass3.postrenderfunction = () -> GLWindow.draw_fullscreen(pass3.vertexarray.id)


    (pass1, pass2, pass3)
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
    stencil         = Texture(U8, buffersize, minfilter=:nearest, x_repeat=:clamp_to_edge)
    depth_buffer    = Texture(Float32, buffersize,
        internalformat = GL_DEPTH24_STENCIL8,
        format         = GL_DEPTH_STENCIL,
        minfilter=:nearest, x_repeat=:clamp_to_edge
    )
    attach_framebuffer(color_buffer, GL_COLOR_ATTACHMENT0)
    attach_framebuffer(objectid_buffer, GL_COLOR_ATTACHMENT1)
    attach_framebuffer(depth_buffer, GL_DEPTH_STENCIL_ATTACHMENT)

    color_luma = Texture(RGBA{UFixed8}, buffersize, minfilter=:linear, x_repeat=:clamp_to_edge)
    color_luma_framebuffer = glGenFramebuffers()
    glBindFramebuffer(GL_FRAMEBUFFER, color_luma_framebuffer)
    attach_framebuffer(color_luma, GL_COLOR_ATTACHMENT0)

    p  = postprocess(color_buffer, color_luma, fb_size)
    fb = GLFramebuffer(
        render_framebuffer, color_luma_framebuffer,
        color_buffer, objectid_buffer, depth_buffer,
        color_luma,
        p
    )
    glBindFramebuffer(GL_FRAMEBUFFER, 0)
    fb
end

function Base.resize!(fb::GLFramebuffer, window_size)
    ws = tuple(window_size...)
    if ws!=size(fb) && all(x->x>0, window_size)
        buffersize = tuple(window_size...)
        resize_nocopy!(fb.color, buffersize)
        resize_nocopy!(fb.color_luma, buffersize)
        resize_nocopy!(fb.objectid, buffersize)
        resize_nocopy!(fb.depth, buffersize)
    end
    nothing
end


immutable MonitorProperties
    name::Compat.UTF8String
    isprimary::Bool
    position::Vec{2, Int}
    physicalsize::Vec{2, Int}
    videomode::GLFW.VidMode
    videomode_supported::Vector{GLFW.VidMode}
    dpi::Vec{2, Float64}
    monitor::Monitor
end

function MonitorProperties(monitor::Monitor)
    name = GLFW.GetMonitorName(monitor)
    isprimary = GLFW.GetPrimaryMonitor() == monitor
    position = Vec{2, Int}(GLFW.GetMonitorPos(monitor)...)
    physicalsize = Vec{2, Int}(GLFW.GetMonitorPhysicalSize(monitor)...)
    videomode = GLFW.GetVideoMode(monitor)

    dpi = Vec(videomode.width * 25.4, videomode.height * 25.4) ./ Vec{2, Float64}(physicalsize)
    videomode_supported = GLFW.GetVideoModes(monitor)

    MonitorProperties(name, isprimary, position, physicalsize, videomode, videomode_supported, dpi, monitor)
end

immutable GLContext
    window::GLFW.Window
    framebuffer::GLFramebuffer
end

global new_id
let counter::Int = 0
    function new_id()
        counter += 1
        counter
    end
end
type Screen
    name        ::Symbol
    area        ::Signal{SimpleRectangle{Int}}
    parent      ::Screen
    children    ::Vector{Screen}
    inputs      ::Dict{Symbol, Any}
    renderlist_fxaa::Tuple # a tuple of specialized renderlists
    renderlist     ::Tuple # a tuple of specialized renderlists

    hidden      ::Bool
    color       ::RGBA{Float32}

    cameras     ::Dict{Symbol, Any}

    glcontext   ::GLContext
    id          ::Int

    function Screen(
            name        ::Symbol,
            area        ::Signal{SimpleRectangle{Int}},
            parent      ::Screen,
            children    ::Vector{Screen},
            inputs      ::Dict{Symbol, Any},
            renderlist  ::Tuple,
            hidden      ::Bool,
            color       ::Colorant,
            cameras     ::Dict{Symbol, Any},
            context     ::GLContext
        )
        new(
            name, area, parent,
            children, inputs, (), renderlist,
            hidden, RGBA{Float32}(color), cameras,
            context, new_id()
        )
    end

    function Screen(
            name        ::Symbol,
            area        ::Signal{SimpleRectangle{Int}},
            children    ::Vector{Screen},
            inputs      ::Dict{Symbol, Any},
            renderlist  ::Tuple,
            hidden      ::Bool,
            color       ::Colorant,
            cameras     ::Dict{Symbol, Any},
            context     ::GLContext
        )
        screen = new()
        screen.name = name
        screen.area = area
        screen.children = children
        screen.inputs = inputs
        screen.renderlist = renderlist
        screen.renderlist_fxaa = ()
        screen.hidden = hidden
        screen.color = RGBA{Float32}(color)
        screen.cameras = cameras
        screen.glcontext = context
        screen.id = new_id()
        screen
    end
end
