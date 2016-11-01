
function clear_all!(window)
    wh = widths(window)
    glViewport(0,0, wh...)
    fb = framebuffer(window)
    glBindFramebuffer(GL_FRAMEBUFFER, fb.id[1])
    glDrawBuffers(2, [GL_COLOR_ATTACHMENT0, GL_COLOR_ATTACHMENT1])
    glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT)
    glBindFramebuffer(GL_FRAMEBUFFER, fb.id[2])
    glClear(GL_COLOR_BUFFER_BIT)
    glBindFramebuffer(GL_FRAMEBUFFER, 0)
    glClear(GL_COLOR_BUFFER_BIT)
    return
end


function renderloop(window::Screen)
    while isopen(window)
        render_frame(window)
        swapbuffers(window)
        pollevents()
        yield()
    end
    destroy!(window)
    return
end

function shape_prerender()
    glDisable(GL_DEPTH_TEST)
    glDepthMask(GL_FALSE)
    glDisable(GL_CULL_FACE)
    glDisable(GL_BLEND)
    return
end

function setup_window(window, strokepass, pa=value(window.area))
    if isopen(window) && !ishidden(window)
        sa = value(window.area)
        sa = SimpleRectangle(pa.x+sa.x, pa.y+sa.y, sa.w, sa.h)
        if !strokepass
            glScissor(sa.x, sa.y, sa.w, sa.h)
            if window.clear
                c = window.color
                glClearColor(red(c), green(c), blue(c), alpha(c))
            end
            glClearStencil(window.id)
            glClear(GL_COLOR_BUFFER_BIT | GL_STENCIL_BUFFER_BIT)
        end
        if window.stroke[1] > 0 && strokepass
            c = window.stroke[2]
            s = 2
            # not the best way to draw stroke, but quite simple and should be fast
            glClearColor(red(c), green(c), blue(c), alpha(c))
            glScissor(sa.x, sa.y, s, sa.h)
            glClear(GL_COLOR_BUFFER_BIT)
            glScissor(sa.x, sa.y, sa.w, s)
            glClear(GL_COLOR_BUFFER_BIT)
            glScissor(sa.x+sa.w-s, sa.y, s, sa.h)
            glClear(GL_COLOR_BUFFER_BIT)
            glScissor(sa.x, sa.y+sa.h-s, sa.w, s)
            glClear(GL_COLOR_BUFFER_BIT)
        end
        for elem in window.children
            setup_window(elem, strokepass, sa)
        end
    end
    return
end

"""
Renders a single frame of a `window`
"""
function render_frame(window)
    !isopen(window) && return
    fb = GLWindow.framebuffer(window)
    wh = widths(window)
    resize!(fb, wh)
    w, h = wh
    #prepare for geometry in need of anti aliasing
    glBindFramebuffer(GL_FRAMEBUFFER, fb.id[1]) # color framebuffer
    glDrawBuffers(2, [GL_COLOR_ATTACHMENT0, GL_COLOR_ATTACHMENT1])
    # setup stencil and backgrounds
    glEnable(GL_STENCIL_TEST)
    glStencilOp(GL_KEEP, GL_KEEP, GL_REPLACE)
    glStencilMask(0xff)
    glClearStencil(0)
    glClear(GL_DEPTH_BUFFER_BIT | GL_STENCIL_BUFFER_BIT)
    glEnable(GL_SCISSOR_TEST)
    setup_window(window, false)
    glDisable(GL_SCISSOR_TEST)
    glColorMask(GL_TRUE, GL_TRUE, GL_TRUE, GL_TRUE)
    # deactivate stencil write
    glEnable(GL_STENCIL_TEST)
    glStencilOp(GL_KEEP, GL_KEEP, GL_REPLACE)
    glStencilMask(0x00)
    GLAbstraction.render(window, true)
    glDisable(GL_STENCIL_TEST)

    # transfer color to luma buffer and apply fxaa
    glBindFramebuffer(GL_FRAMEBUFFER, fb.id[2]) # luma framebuffer
    glDrawBuffer(GL_COLOR_ATTACHMENT0)
    glViewport(0, 0, w, h)
    GLAbstraction.render(fb.postprocess[1]) # add luma and preprocess

    glBindFramebuffer(GL_FRAMEBUFFER, fb.id[1]) # transfer to non fxaa framebuffer
    glDrawBuffer(GL_COLOR_ATTACHMENT0)
    GLAbstraction.render(fb.postprocess[2]) # copy with fxaa postprocess

    #prepare for non anti aliased pass
    glDrawBuffers(2, [GL_COLOR_ATTACHMENT0, GL_COLOR_ATTACHMENT1])

    glEnable(GL_STENCIL_TEST)
    glStencilOp(GL_KEEP, GL_KEEP, GL_REPLACE)
    glStencilMask(0x00)
    GLAbstraction.render(window, false)
    glDisable(GL_STENCIL_TEST)
    # draw strokes
    glEnable(GL_SCISSOR_TEST)
    setup_window(window, true)
    glDisable(GL_SCISSOR_TEST)
    glViewport(0,0, wh...)
    #Read all the selection queries
    GLWindow.push_selectionqueries!(window)
    glBindFramebuffer(GL_FRAMEBUFFER, 0) # transfer back to window
    GLAbstraction.render(fb.postprocess[3]) # copy postprocess
    return
end



function GLAbstraction.render(x::Screen, fxaa::Bool, parent::Screen=x, context=x.area.value)
    if isopen(x) && !ishidden(x)
        sa    = value(x.area)
        sa    = SimpleRectangle(context.x+sa.x, context.y+sa.y, sa.w, sa.h) # bring back to absolute values
        pa    = context
        sa_pa = intersect(pa, sa) # intersection with parent
        if (
                sa_pa != SimpleRectangle(0,0,0,0) && # if it is in the parent area
                (sa_pa.w > 0 && sa_pa.h > 0)
            ) # if it is in the parent area
            glViewport(sa)
            glStencilFunc(GL_EQUAL, x.id, 0xff)
            if fxaa
                render(x.renderlist_fxaa)
            else
                render(x.renderlist)
            end
            for window in x.children
                render(window, fxaa, x, sa)
            end
        end
    end
    return
end
