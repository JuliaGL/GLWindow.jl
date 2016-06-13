immutable GLContext
    context
end

type FrameBuffer
    id::GLuint
    attachments::Vector
    color_attachments::Vector{Int} # indices to color attachments
    context::GLContext
end
Base.length(fb::FrameBuffer) = length(fb.attachments)
Base.start(fb::FrameBuffer) = 1
Base.next(fb::FrameBuffer, state::Integer) = fb[state], state+1
Base.done(fb::FrameBuffer, state::Integer) = length(fb) <  state

# used to bind GL_FRAMEBUFFER to 0
function Base.bind(fb::FrameBuffer, id)
    glBindFramebuffer(GL_FRAMEBUFFER, id)
end
function Base.bind(fb::FrameBuffer)
    bind(fb, fb.id)
end
function drawbuffers(fb::FrameBuffer, bufferset=fb.color_attachments)
    if !isempty(bufferset)
        n = length(fb.attachments)
        buffers = GLenum[i in bufferset ? fb.attachments[i][2] : GL_NONE for i=1:n]
        glDrawBuffers(n, buffers)
    end
    nothing
end
function Base.getindex(fb::FrameBuffer, i::Integer)
    fb.attachments[i]
end
function Base.setindex!(fb::FrameBuffer, attachment::Tuple{Texture, GLenum}, i::Integer)
    bind(fb)
    fb.attachments[i] = attachment
    attach_framebuffer(attachment...)
    bind(fb, 0)
end
function Base.size(fb::FrameBuffer)
    if isempty(fb.attachments)
        # no attachments implies, that the context holds the attachments and size
        return size(fb.context)
    else
        size(first(fb)[1]) # it's guaranteed, that they all have the same size
    end
end
function attach_framebuffer{T}(t::Texture{T, 2}, attachmentpoint)
    glFramebufferTexture2D(GL_FRAMEBUFFER,
        attachmentpoint,
        t.texturetype, t.id, 0
    )
end
"""
Creates a framebuffer from `targets`, which is a `Vector` of tuples containing
a texture with it's attachment point, e.g. `(Texture, GL_COLOR_ATTACHMENT0)`
`Context` is the context the texture is created from.
"""
function FrameBuffer(targets::Vector, context)
    color_attachments = Int[]
    fb = FrameBuffer(
        glGenFramebuffers(),
        targets, color_attachments, context
    )
    bind(fb)
    i = 1
    for (target, attachmentpoint) in targets
        attach_framebuffer(target, attachmentpoint)
        if attachmentpoint != GL_DEPTH_ATTACHMENT
            push!(color_attachments, i)
        end
        i+=1
    end
    bind(fb, 0)
    fb
end
function Base.resize!(fb::FrameBuffer, window_size)
    ws = tuple(window_size...)
    if ws!=size(fb) && all(x->x>0, window_size)
        @static if false# hacky workaround for linux driver bug (more specificall Intel!?)
            fb.id = glGenFramebuffers()
            bind(fb)
            for (i, (attachment, attachmentpoint)) in enumerate(fb)
                new_attachment = similar(attachment)
                attach_framebuffer(new_attachment, attachmentpoint)
                fb.attachments[i] = (attachment, attachmentpoint)
            end
            bind(fb, 0)
        else
            for (attachment, _) in fb
                resize_nocopy!(attachment, ws)
            end
        end
    end
    nothing
end




immutable RenderPass
    pass # any X that has render(::X) defined
    target::FrameBuffer
end


immutable FullscreenPreRender end
function Base.call(::FullscreenPreRender)
    glDisable(GL_DEPTH_TEST)
    glDisable(GL_STENCIL_TEST)
    glDisable(GL_CULL_FACE)
    glDisable(GL_BLEND)
end
immutable FullScreenPostRender
    vao_id::GLuint
end
function call(fs::FullScreenPostRender)
    glBindVertexArray(fs.vao_id)
    glDrawArrays(GL_TRIANGLES, 0, 3)
    glBindVertexArray(0)
end
immutable OITPreRender end

# TODO implement this correctly according to the paper
function call(::OITPreRender)
    glDisable(GL_DEPTH_TEST)
    glDisable(GL_STENCIL_TEST)
    glDisable(GL_CULL_FACE)
    glDisable(GL_BLEND)
end

immutable OpaquePreRender end
function call(::OpaquePreRender)
    glEnable(GL_DEPTH_TEST)
    glDepthMask(GL_TRUE)
    glDisable(GL_BLEND)
    glEnable(GL_ALPHA_TEST)
    glAlphaFunc(GL_EQUAL, 1.0f0)
end


loadshader(name) = load(joinpath(dirname(@__FILE__), name))

rcpframe(x) = 1f0/Vec2f0(x[1], x[2])
"""
Creates a postprocessing render object.
This will transfer the pixels from the color texture of the FrameBuffer
to the screen and while at it, it can do some postprocessing (not doing it right now):
E.g fxaa anti aliasing, color correction etc.
"""
function FXAAProcess(color_texture, framebuffer_size)
    shader = LazyShader(
        loadshader("fullscreen.vert"),
        loadshader("fxaa.frag")
    )
    data = Dict(
        :RCPFrame => map(rcpframe, framebuffer_size),
        :color_texture => color_texture
    )
    robj = RenderObject(data, shader, FullscreenPreRender(), nothing)
    robj.postrenderfunction = FullScreenPostRender(robj.vertexarray.id)
    robj
end

"""
Order independant Transparancy resolve pass
as described in this blog post/paper:
(OIT)[http://casual-effects.blogspot.de/2014/03/weighted-blended-order-independent.html]
"""
function OITResolve(sum_color, sum_weight, opaque_color)
    shader = LazyShader(
        loadshader("fullscreen.vert"),
        loadshader("oit_combine.frag")
    )
    data = Dict{Symbol, Any}(
        :sum_color_tex => sum_color,
        :sum_weight_tex => sum_weight,
        :opaque_color_tex => opaque_color,
    )
    robj = RenderObject(data, shader, OITPreRender(), nothing)
    robj.postrenderfunction = FullScreenPostRender(robj.vertexarray.id)
    robj
end


"""
Sets up renderpasses for `window`
"""
function add_oit_fxaa_postprocessing!(window)
    buffersize_s = window.inputs[:framebuffer_size]
    buffersize = tuple(value(buffersize_s)...)
    context = window.glcontext
    # render target for hit detection
    objectid_buffer = Texture(Vec{2, GLushort}, buffersize, minfilter=:nearest, x_repeat=:clamp_to_edge)

    # order independant transparency (OIT) render targets
    sum_color = Texture(RGBA{Float16}, buffersize, minfilter=:nearest, x_repeat=:clamp_to_edge)
    sum_weight = Texture(U8, buffersize, minfilter=:nearest, x_repeat=:clamp_to_edge)

    # opaque render targets for color combination and postprocessing
    opaque_color = Texture(RGBA{U8}, buffersize, minfilter=:nearest, x_repeat=:clamp_to_edge)
    depth_buffer = Texture(Float32, buffersize,
        internalformat=GL_DEPTH_COMPONENT32F,
        format=GL_DEPTH_COMPONENT,
        minfilter=:nearest, x_repeat=:clamp_to_edge
    )
    # final tonemapped color stage
    # must use linear interpolation for FXAA sampling and supply luma in alpha
    tonemapped_luma = Texture(RGBA{U8}, buffersize, minfilter=:linear, x_repeat=:clamp_to_edge)


    opaque_transparent_fb = FrameBuffer([
        (opaque_color, GL_COLOR_ATTACHMENT0),
        (sum_color, GL_COLOR_ATTACHMENT1),
        (sum_weight, GL_COLOR_ATTACHMENT2),
        (objectid_buffer, GL_COLOR_ATTACHMENT3),
        (depth_buffer, GL_DEPTH_ATTACHMENT),
    ], context)


    color_resolve_fb = FrameBuffer([
        (tonemapped_luma, GL_COLOR_ATTACHMENT0),
    ], context)

    # window target... Could also be offscreen
    final_target = FrameBuffer(0, Tuple{Texture, GLenum}[], GLenum[], context)

    opaque_pass = RenderPass(window, opaque_transparent_fb)
    transparent_pass = RenderPass(window, opaque_transparent_fb)
    colore_resolve_pass = RenderPass(OITResolve(
        sum_color, sum_weight, opaque_color
    ), color_resolve_fb)
    fxaa_pass = RenderPass(FXAAProcess(tonemapped_luma, buffersize_s), final_target)
    # update renderpasses
    resize!(window.renderpasses, 4)
    window.renderpasses[:] = [opaque_pass, transparent_pass, colore_resolve_pass, fxaa_pass]
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
    name 		 = GLFW.GetMonitorName(monitor)
    isprimary 	 = GLFW.GetPrimaryMonitor() == monitor
    position	 = Vec{2, Int}(GLFW.GetMonitorPos(monitor)...)
    physicalsize = Vec{2, Int}(GLFW.GetMonitorPhysicalSize(monitor)...)
    videomode 	 = GLFW.GetVideoMode(monitor)

    dpi			 = Vec(videomode.width * 25.4, videomode.height * 25.4) ./ Vec{2, Float64}(physicalsize)
    videomode_supported = GLFW.GetVideoModes(monitor)

    MonitorProperties(name, isprimary, position, physicalsize, videomode, videomode_supported, dpi, monitor)
end



function process_events(w)
    while isopen(w)

    end
end

type Screen
    name 		::Symbol
    area 		::Signal{SimpleRectangle{Int}}
    parent 		::Screen
    children 	::Vector{Screen}
    inputs 		::Dict{Symbol, Any}
    renderlist 	::Vector

    hidden 		::Bool
    color       ::RGBA{Float32}

    cameras 	::Dict{Symbol, Any}

    glcontext   ::GLContext
    renderpasses::Vector{RenderPass}
    opaque      ::Vector{Int}
    transparent ::Vector{Int}
    camera2robj ::Dict{Symbol, Vector{Int}}


    function Screen(
            name        ::Symbol,
            area        ::Signal{SimpleRectangle{Int}},
            parent 		::Screen,
            children 	::Vector{Screen},
            inputs 		::Dict{Symbol, Any},
            renderlist 	::Vector,
            hidden 		::Bool,
            color       ::Colorant,
            cameras 	::Dict{Symbol, Any},
            context     ::GLContext
        )
        w = new(
            name, area, parent,
            children, inputs, renderlist,
            hidden, RGBA{Float32}(color), cameras,
            context, RenderPass[], Int[], Int[],
            Dict{Symbol, Vector{Int}}()
        )
    end

    function Screen(
            name        ::Symbol,
            area        ::Signal{SimpleRectangle{Int}},
            children    ::Vector{Screen},
            inputs      ::Dict{Symbol, Any},
            renderlist  ::Vector,
            hidden      ::Bool,
            color       ::Colorant,
            cameras     ::Dict{Symbol, Any},
            context     ::GLContext
        )

        parent = new()
        w = new(
            name, area, parent,
            children, inputs, renderlist,
            hidden, RGBA{Float32}(color), cameras,
            context, RenderPass[], Int[], Int[],
            Dict{Symbol, Vector{Int}}()
        )
    end
end
