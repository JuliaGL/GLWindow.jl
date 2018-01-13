#Came from GLWindow/types.jl
#I think this could be useful somewhere, although I'm not sure where at the moment it is used.
#It seems GLContext, the way it's used atm, is more like a context ID rather than the fully fledged GLContext

abstract type AbstractContext end
#this should remain here, maybe, it uses a glframebuffer
mutable struct GLContext <: AbstractContext
    window::GLFW.Window
    framebuffer::GLFramebuffer
    visible::Bool
    cache::Dict
end
GLContext(window, framebuffer, visible) = GLContext(window, framebuffer, visible, Dict())

function set_visibility!(glc::AbstractContext, visible::Bool)
    if glc.visible != visible
        set_visibility!(glc.window, visible)
        glc.visible = visible
    end
    return
end