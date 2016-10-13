
function clear_all!(window)
    wh = widths(window)
    glViewport(0,0, wh...)
    fb = framebuffer(window)
    glBindFramebuffer(GL_FRAMEBUFFER, fb.id1)
    glDrawBuffers(2, [GL_COLOR_ATTACHMENT0, GL_COLOR_ATTACHMENT1])
    glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT)
    glBindFramebuffer(GL_FRAMEBUFFER, fb.id2)
    glClear(GL_COLOR_BUFFER_BIT)
    glBindFramebuffer(GL_FRAMEBUFFER, 0)
    glClear(GL_COLOR_BUFFER_BIT)
end


function renderloop(window::Screen)
    while isopen(window)
        render_frame(window)
        swapbuffers(window)
        pollevents()
        yield()
    end
    destroy!(window)
end

"""
Renders a single frame of a `window`
"""
function render_frame(window)
    fb = framebuffer(window)
    wh = widths(window)
    resize!(fb, wh)
    #prepare for geometry in need of anti aliasing
    glDisable(GL_SCISSOR_TEST)
    glBindFramebuffer(GL_FRAMEBUFFER, fb.id1)
    glDrawBuffers(2, [GL_COLOR_ATTACHMENT0, GL_COLOR_ATTACHMENT1])
    glViewport(0,0, wh...)

    render(window)

    # transfer color to final buffer and to fxaa
    glDisable(GL_SCISSOR_TEST)
    glBindFramebuffer(GL_FRAMEBUFFER, fb.id2) # luma
    glDrawBuffer(GL_COLOR_ATTACHMENT0)
    glViewport(0,0, widths(window)...)
    render(fb.postprocess[1]) # add luma and preprocess
    glBindFramebuffer(GL_FRAMEBUFFER, fb.id1) # transfer back to initial color target with fxaa
    glDrawBuffer(GL_COLOR_ATTACHMENT0)
    render(fb.postprocess[2])

    # prepare for non anti aliasing pass
    glDisable(GL_SCISSOR_TEST)
    glBindFramebuffer(GL_FRAMEBUFFER, fb.id1)
    glDrawBuffers(2, [GL_COLOR_ATTACHMENT0, GL_COLOR_ATTACHMENT1])
    glViewport(0,0, wh...)

    #Read all the selection queries
    push_selectionqueries!(window)
    display(fb, window)
end



function prepare(fb::GLFramebuffer)

end

function display(fb::GLFramebuffer, window)

end

function GLAbstraction.render(x::Screen, parent::Screen=x, context=x.area.value)
    if isopen(x) && !ishidden(x)
        sa    = value(x.area)
        sa    = SimpleRectangle(context.x+sa.x, context.y+sa.y, sa.w, sa.h) # bring back to absolute values
        pa    = context
        sa_pa = intersect(pa, sa) # intersection with parent
        if (
                sa_pa != SimpleRectangle(0,0,0,0) && # if it is in the parent area
                (sa_pa.w > 0 && sa_pa.h > 0)
            ) # if it is in the parent area
            glEnable(GL_SCISSOR_TEST)
            glScissor(sa_pa)
            glViewport(sa)
            colorbits = GL_DEPTH_BUFFER_BIT
            if alpha(x.color) > 0
                glClearColor(red(x.color), green(x.color), blue(x.color), alpha(x.color))
                colorbits = colorbits | GL_COLOR_BUFFER_BIT
            end
            glClear(colorbits)
            render(x.renderlist)
            for window in x.children
                render(window, x, sa)
            end
        end
    end
end
