

"""
Clears everything in a window
"""
function clear_all!(window)
    wh = widths(window)
    glViewport(0,0, wh...)
    fb = framebuffer(window)
    glBindFramebuffer(GL_FRAMEBUFFER, fb.id)
    glDrawBuffers(2, [GL_COLOR_ATTACHMENT0, GL_COLOR_ATTACHMENT1])
    glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT)
    glBindFramebuffer(GL_FRAMEBUFFER, 0)
    glClear(GL_COLOR_BUFFER_BIT)
end

"""
Renders a `RenderPass`
"""
function GLAbstraction.render(rp::RenderPass)
    bind(rp.target)
    # bind the framebuffer that is targeted and set it as draw buffer
    drawbuffers(rp.target)
    # render the pass
    render(rp.pass)
end

function opaque_setup()
    glDisable(GL_CULL_FACE)
    glEnable(GL_DEPTH_TEST)
    glDepthMask(GL_TRUE)
    glDisable(GL_BLEND)
end

function oit_setup()
    glEnable(GL_DEPTH_TEST)
    glDepthMask(GL_FALSE)
    zero_clear = Float32[0,0,0,0]
    one_clear = Float32[1,1,1,1]
    glClearBufferfv(GL_COLOR, 1, zero_clear)
    glClearBufferfv(GL_COLOR, 2, one_clear)
    glEnable(GL_BLEND)
    glBlendEquation(GL_FUNC_ADD)
    glBlendFunci(1, GL_ONE, GL_ONE)
    glBlendFunci(2, GL_ZERO, GL_ONE_MINUS_SRC_COLOR)
end




"""
Renders a single frame of a `window`
"""
function render_frame(window)
    isopen(window) || return
    wh = widths(window)
    opaque_pass, tansp_pass, color_pass, fxaa_pass = window.renderpasses


    ot_fb = opaque_pass.target # opaque and transparent share the same framebuffer
    bind(ot_fb)
    resize!(ot_fb, wh)
    glDisable(GL_SCISSOR_TEST)
    glViewport(0,0, wh...)
    drawbuffers(ot_fb, [1,4])
    glClearBufferfv(GL_COLOR, 3, Float32[0,0,0,0]) # clear the hit detection buffer

    # render the pass
    opaque_setup()
    glClearBufferfv(GL_DEPTH, 0, Float32[1]) # we always clear depth
    render_opaque(window)

    glDisable(GL_SCISSOR_TEST)
    glViewport(0,0, wh...)

    drawbuffers(ot_fb, [2,3])
    oit_setup()
    render_transparent(window)

    # while rendering windows, scissor test is on and viewport will be changed
    # to the children windows... So we need to revert this
    glDisable(GL_SCISSOR_TEST)
    glViewport(0,0, wh...)
    #Read all the selection queries
    push_selectionqueries!(window)

    # resolve colors
    resize!(color_pass.target, wh)
    render(color_pass)

    # do anti aliasing and write to final color framebuffer
    render(fxaa_pass)

    # swap buffers and poll GLFW events
    swapbuffers(window)
    GLFW.PollEvents()
    Reactive.run_timer()
    Reactive.run_till_now()
    Reactive.run_till_now() # execute secondary cycled events!
    yield()
    nothing
end

"""
Blocking renderloop
"""
function renderloop(window::Screen)
    while isopen(window)
        render_frame(window)
    end
    destroy!(window)
end


function render_transparent(x::Screen, parent::Screen=x, context=x.area.value)
    if isopen(x) && !ishidden(x)
        sa = value(x.area)
        sa = SimpleRectangle(context.x+sa.x, context.y+sa.y, sa.w, sa.h) # bring back to absolute values
        pa = context
        sa_pa = intersect(pa, sa) # intersection with parent
        if sa_pa != SimpleRectangle{Int}(0,0,0,0) # if it is in the parent area
            glEnable(GL_SCISSOR_TEST)
            glScissor(sa_pa)
            glViewport(sa)
            for elem in x.renderlist[x.transparent]
                elem[:is_transparent_pass] = Cint(true)
                render(elem)
            end
            for window in x.children
                render_transparent(window, x, sa)
            end
        end
    end
end


function render_opaque(x::Screen, parent::Screen=x, context=x.area.value)
    if isopen(x) && !ishidden(x)
        sa    = value(x.area)
        sa    = SimpleRectangle(context.x+sa.x, context.y+sa.y, sa.w, sa.h) # bring back to absolute values
        pa    = context
        sa_pa = intersect(pa, sa) # intersection with parent
        if sa_pa != SimpleRectangle{Int}(0,0,0,0) # if it is in the parent area
            glEnable(GL_SCISSOR_TEST)
            glScissor(sa_pa)
            glViewport(sa)
            c = Float32[red(x.color), green(x.color), blue(x.color), alpha(x.color)]
            glClearBufferfv(GL_COLOR, 0, c)
            for elem in x.renderlist
                elem[:is_transparent_pass] = Cint(false)
                render(elem)
            end
            for window in x.children
                render_opaque(window, x, sa)
            end
        end
    end
end
