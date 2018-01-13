function shape_prerender()
    glDisable(GL_DEPTH_TEST)
    glDepthMask(GL_FALSE)
    glDisable(GL_CULL_FACE)
    glDisable(GL_BLEND)
    return
end

