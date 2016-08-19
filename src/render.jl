
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
Renders a single frame of a `window`
"""
function render_frame(window)
    fb = framebuffer(window)
    wh = widths(window)
    resize!(fb, wh)
    prepare(fb)
    glViewport(0,0, wh...)
    glClearColor(1,1,1,1)
    glClear(GL_DEPTH_BUFFER_BIT | GL_COLOR_BUFFER_BIT)
    render(window)
    #Read all the selection queries
    push_selectionqueries!(window)
    display(fb, window)
end

function renderloop(window::Screen)
    while isopen(window)
        render_frame(window)
        swapbuffers(window)
        GLFW.PollEvents()
        yield()
    end
    destroy!(window)
end

function prepare(fb::GLFramebuffer)
    glDisable(GL_SCISSOR_TEST)
    glBindFramebuffer(GL_FRAMEBUFFER, fb.id)
    glDrawBuffers(2, [GL_COLOR_ATTACHMENT0, GL_COLOR_ATTACHMENT1])
end

function display(fb::GLFramebuffer, window)
    glDisable(GL_SCISSOR_TEST)
    glBindFramebuffer(GL_FRAMEBUFFER, 0)
    glViewport(0,0, widths(window)...)
    render(fb.postprocess)
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
