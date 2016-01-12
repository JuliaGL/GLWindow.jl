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
