
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
    nothing
end

immutable BreadthFirstIter
    x::Any
end
children(s::Screen) = s.children
function Base.start(iter::BreadthFirstIter)
    (iter.x, 1)
end
function Base.next(iter::BreadthFirstIter, state)
    parent, next_parent, (childs, cstate, _done) = state
    if !done(childs, cstate)
        elem, cstate = next(childs, cstate)
        if isnull(next_parent) && !isempty(children(elem))
            next_parent = Nullable(elem)
        end
        return parent, next_parent, (elem, cstate, false)
    elseif !isnull(next_parent)
        np = get(next_parent)
        childs = children(np)
        return np, Nullable{typeof(np)}(), (childs, start(childs), false)
    else
        np, Nullable{typeof(np)}(), (childs, start(childs), true)
    end
end



function shape_prerender()
    glDisable(GL_DEPTH_TEST)
    glDepthMask(GL_FALSE)
    glDisable(GL_CULL_FACE)
    glDisable(GL_BLEND)
end

global get_shape
let _shape_cache = Dict{WeakRef, Any}()
    function get_shape(window)
        root = WeakRef(rootscreen(window)) # cache for root only
        get!(_shape_cache, root) do
            # jeez... But relying on GLVisualize creates a circular dependency -.-
            robj = Main.GLVisualize.visualize(
                SimpleRectangle(-1, -1, 2, 2),
                projection=eye(Mat4f0),
                view=eye(Mat4f0)
            ).children[]
            RenderObject{typeof(shape_prerender)}(
                robj.main, robj.uniforms, robj.vertexarray,
                shape_prerender, robj.postrenderfunction,
                robj.boundingbox
            )
        end
    end
end
function absolute_pos(w::Screen)
end
function setup_window(window, pa=value(window.area))
    if isopen(window) && !ishidden(window)
        glStencilFunc(GL_ALWAYS, window.id, 0xff)
        shape = get_shape(window)
        sa = value(window.area)
        sa = SimpleRectangle(pa.x+sa.x, pa.y+sa.y, sa.w, sa.h)
        #@show sa
        glViewport(sa) # children are in relative coordinates
        shape[:color] = window.color
        shape[:stroke_width] = -window.stroke[1] # negate to stroke inside window
        shape[:stroke_color] = window.stroke[2]
        render(shape)
        for elem in window.children
            setup_window(elem, sa)
        end
    end
end

"""
Renders a single frame of a `window`
"""
function render_frame(window)
    fb = GLWindow.framebuffer(window)

    wh = widths(window)
    resize!(fb, wh)
    w, h = wh
    #prepare for geometry in need of anti aliasing
    glBindFramebuffer(GL_FRAMEBUFFER, fb.id1)
    glDrawBuffers(2, [GL_COLOR_ATTACHMENT0, GL_COLOR_ATTACHMENT1])
    # setup stencil and backgrounds
    glEnable(GL_STENCIL_TEST)
    glStencilOp(GL_KEEP, GL_KEEP, GL_REPLACE)
    glStencilMask(0xff)
    glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT)
    glClear(GL_STENCIL_BUFFER_BIT)
    glViewport(0, 0, w, h)
    setup_window(window)

    # deactivate stencil write
    glEnable(GL_STENCIL_TEST)
    glStencilMask(0x00)
    GLAbstraction.render(window, true)
    glDisable(GL_STENCIL_TEST)

    # transfer color to final buffer and to fxaa
    glBindFramebuffer(GL_FRAMEBUFFER, fb.id2) # luma
    glDrawBuffer(GL_COLOR_ATTACHMENT0)
    glViewport(0, 0, w, h)
    GLAbstraction.render(fb.postprocess[1]) # add luma and preprocess

    glBindFramebuffer(GL_FRAMEBUFFER, fb.id1) # transfer back to initial color target with fxaa
    glDrawBuffer(GL_COLOR_ATTACHMENT0)
    GLAbstraction.render(fb.postprocess[2])

    #prepare for non anti aliasing pass
    glBindFramebuffer(GL_FRAMEBUFFER, fb.id1)
    glDrawBuffers(2, [GL_COLOR_ATTACHMENT0, GL_COLOR_ATTACHMENT1])
    glEnable(GL_STENCIL_TEST)
    glStencilOp(GL_KEEP, GL_KEEP, GL_REPLACE)
    glStencilMask(0x00)
    GLAbstraction.render(window, false)
    glDisable(GL_STENCIL_TEST)

    glViewport(0,0, wh...)
    #Read all the selection queries
    GLWindow.push_selectionqueries!(window)
    glBindFramebuffer(GL_FRAMEBUFFER, 0) # transfer back to window
    GLAbstraction.render(fb.postprocess[3])
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
            if fxaa # only clear in fxaa pass, because it gets called first
                render(x.renderlist_fxaa)
            else
                render(x.renderlist)
            end
            for window in x.children
                render(window, fxaa, x, sa)
            end
        end
    end
end
