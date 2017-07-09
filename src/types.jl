
function draw_fullscreen(vao_id)
    glBindVertexArray(vao_id)
    glDrawArrays(GL_TRIANGLES, 0, 3)
    glBindVertexArray(0)
end
immutable PostprocessPrerender
end
function (sp::PostprocessPrerender)()
    glDepthMask(GL_TRUE)
    glDisable(GL_DEPTH_TEST)
    glDisable(GL_BLEND)
    glDisable(GL_STENCIL_TEST)
    glStencilMask(0xff)
    glDisable(GL_CULL_FACE)
    nothing
end

const PostProcessROBJ = RenderObject{PostprocessPrerender}
type GLFramebuffer
    id         ::NTuple{2, GLuint}
    color      ::Texture{RGBA{N0f8}, 2}
    objectid   ::Texture{Vec{2, GLushort}, 2}
    depth      ::GLuint
    color_luma ::Texture{RGBA{N0f8}, 2}
    postprocess::NTuple{3, PostProcessROBJ}
end
Base.size(fb::GLFramebuffer) = size(fb.color) # it's guaranteed, that they all have the same size

loadshader(name) = joinpath(dirname(@__FILE__), name)


rcpframe(x) = 1f0./Vec2f0(x[1], x[2])

"""
Creates a postprocessing render object.
This will transfer the pixels from the color texture of the Framebuffer
to the screen and while at it, it can do some postprocessing (not doing it right now):
E.g fxaa anti aliasing, color correction etc.
"""
function postprocess(color, color_luma, framebuffer_size)
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
    color_buffer    = Texture(RGBA{N0f8},    buffersize, minfilter=:nearest, x_repeat=:clamp_to_edge)
    objectid_buffer = Texture(Vec{2, GLushort}, buffersize, minfilter=:nearest, x_repeat=:clamp_to_edge)
    depth_stencil_rb = Ref{GLuint}()
    glGenRenderbuffers(1, depth_stencil_rb)
    glBindRenderbuffer(GL_RENDERBUFFER, depth_stencil_rb[])
    glRenderbufferStorage(GL_RENDERBUFFER, GL_DEPTH24_STENCIL8, buffersize...)

    glFramebufferRenderbuffer(GL_FRAMEBUFFER, GL_DEPTH_ATTACHMENT, GL_RENDERBUFFER, depth_stencil_rb[])
    glFramebufferRenderbuffer(GL_FRAMEBUFFER, GL_STENCIL_ATTACHMENT, GL_RENDERBUFFER, depth_stencil_rb[])
    attach_framebuffer(color_buffer, GL_COLOR_ATTACHMENT0)
    attach_framebuffer(objectid_buffer, GL_COLOR_ATTACHMENT1)

    status = glCheckFramebufferStatus(GL_FRAMEBUFFER)
    @assert status == GL_FRAMEBUFFER_COMPLETE

    color_luma = Texture(RGBA{N0f8}, buffersize, minfilter=:linear, x_repeat=:clamp_to_edge)
    color_luma_framebuffer = glGenFramebuffers()
    glBindFramebuffer(GL_FRAMEBUFFER, color_luma_framebuffer)
    attach_framebuffer(color_luma, GL_COLOR_ATTACHMENT0)
    @assert status == GL_FRAMEBUFFER_COMPLETE

    glBindFramebuffer(GL_FRAMEBUFFER, 0)

    p = postprocess(color_buffer, color_luma, fb_size)

    fb = GLFramebuffer(
        (render_framebuffer, color_luma_framebuffer),
        color_buffer, objectid_buffer, depth_stencil_rb[],
        color_luma,
        p
    )
    fb
end

function Base.resize!(fb::GLFramebuffer, window_size)
    ws = window_size[1], window_size[2]
    if ws!=size(fb) && all(x->x>0, window_size)
        buffersize = tuple(window_size...)
        resize_nocopy!(fb.color, buffersize)
        resize_nocopy!(fb.color_luma, buffersize)
        resize_nocopy!(fb.objectid, buffersize)
        glBindRenderbuffer(GL_RENDERBUFFER, fb.depth)
        glRenderbufferStorage(GL_RENDERBUFFER, GL_DEPTH24_STENCIL8, buffersize...)
        glBindRenderbuffer(GL_RENDERBUFFER, 0)
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
    sfactor = is_apple() ? 2.0 : 1.0
    dpi = Vec(videomode.width * 25.4, videomode.height * 25.4) * sfactor ./ Vec{2, Float64}(physicalsize)
    videomode_supported = GLFW.GetVideoModes(monitor)

    MonitorProperties(name, isprimary, position, physicalsize, videomode, videomode_supported, dpi, monitor)
end

abstract AbstractContext

type GLContext <: AbstractContext
    window::GLFW.Window
    framebuffer::GLFramebuffer
    visible::Bool
    cache::Dict
end
GLContext(window, framebuffer, visible) = GLContext(window, framebuffer, visible, Dict())

global new_id
let counter::Int = 0
    # start from new and hope we don't display all displays at once.
    # TODO make it clearer if we reached max num, or if we just created
    # a lot of small screens and display them simultanously
    new_id() = (counter = mod1(counter + 1, 255); counter)
end

type Screen
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
