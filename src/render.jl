function renderloop_inner(screen, framebuffer, selectionquery, selection, postprocess_robj)
    yield()
    prepare(framebuffer)
    render(screen)
    #Read all the selection queries
    push_selectionqueries!(framebuffer.objectid, screen, screen.area.value)

    swapbuffers(screen)
    pollevents(screen)
end

function renderloop(screen, selectionquery, selection, postprocess_robj, renderloop_callback)
    framebuffer = screen.inputs[:framebuffer]
    objectid_buffer = screen.inputs[:framebuffer]
    while isopen(screen)
        renderloop_inner(screen, framebuffer, selectionquery, selection, postprocess_robj)
    end
    GLAbstraction.empty_shader_cache!()
end

function prepare(fb::GLFramebuffer)
    glDisable(GL_SCISSOR_TEST)
    glBindFramebuffer(GL_FRAMEBUFFER, framebuffer.render_framebuffer)
    glDrawBuffers(2, [GL_COLOR_ATTACHMENT0, GL_COLOR_ATTACHMENT1])
end

function display(fb::GLFramebuffer, screen)
    glDisable(GL_SCISSOR_TEST)
    glBindFramebuffer(GL_FRAMEBUFFER, 0)
    glViewport(screen.area.value)
    glClear(GL_COLOR_BUFFER_BIT)
    render(postprocess_robj)
end
function GLAbstraction.render(x::Screen, parent::Screen=x, context=x.area.value)
    if x.inputs[:open].value
        sa    = x.area.value
        sa    = SimpleRectangle(context.x+sa.x, context.y+sa.y, sa.w, sa.h) # bring back to absolute values
        pa    = context
        sa_pa = intersect(pa, sa)
        if sa_pa != SimpleRectangle{Int}(0,0,0,0) # if it is in the parent area
            glEnable(GL_SCISSOR_TEST)
            glScissor(sa_pa)
            glViewport(sa)
            x.transparent.value || glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT)
            render(x.renderlist)
            for screen in x.children; render(screen, x, sa); end
        end
    end
end