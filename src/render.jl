
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

global get_shape
let _shape_cache = RenderObject[]
    function get_shape()
        if isempty(_shape_cache)
            push!(_shape_cache, visualize((RECTANGLE, Point2f0[0])))
        end
        _shape_cache[]
    end
end


function setup_window(window)
    glStencilFunc(GL_ALWAYS, window.id, 0xFF)
    shape = get_shape()
    area = window.area.value
    shape[:color] = window.color
    #shape[:stroke_width] = window.stroke
    shape[:position] = Point2f0(minimum(area))
    shape[:scale] = Vec2f0(widths(area))
    render(shape)

    for elem in window.children
        setup_window(window)
    end
end

"""
Renders a single frame of a `window`
"""
function render_frame(window)
    fb = GLWindow.framebuffer(window)

    wh = widths(window)
    resize!(fb, wh)

    #prepare for geometry in need of anti aliasing
    glBindFramebuffer(GL_FRAMEBUFFER, fb.id1)
    glDrawBuffers(2, [GL_COLOR_ATTACHMENT0, GL_COLOR_ATTACHMENT1])


    # setup stencil and backgrounds
    setup_window(window)
    glStencilOp(GL_KEEP, GL_KEEP, GL_REPLACE)
    glStencilMask(0xFF)



    GLAbstraction.render(window, true)

    # transfer color to final buffer and to fxaa
    glBindFramebuffer(GL_FRAMEBUFFER, fb.id2) # luma
    glDrawBuffer(GL_COLOR_ATTACHMENT0)
    glDisable(GL_SCISSOR_TEST)
    glViewport(0,0, widths(window)...)
    GLAbstraction.render(fb.postprocess[1]) # add luma and preprocess

    glBindFramebuffer(GL_FRAMEBUFFER, fb.id1) # transfer back to initial color target with fxaa
    glDrawBuffer(GL_COLOR_ATTACHMENT0)
    GLAbstraction.render(fb.postprocess[2])

    #prepare for non anti aliasing pass
    glBindFramebuffer(GL_FRAMEBUFFER, fb.fb.id2)
    glDrawBuffers(2, [GL_COLOR_ATTACHMENT0, GL_COLOR_ATTACHMENT1])
    GLAbstraction.render(window, false)

    glViewport(0,0, wh...)
    glDisable(GL_SCISSOR_TEST)
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
            glStencilFunc(GL_EQUAL, x.id, 0xFF)
            glEnable(GL_SCISSOR_TEST)
            glScissor(sa_pa)
            glViewport(sa)

            if fxaa # only clear in fxaa pass, because it gets called first
                bits = GL_DEPTH_BUFFER_BIT
                if alpha(x.color) > 0
                    glClearColor(red(x.color), green(x.color), blue(x.color), alpha(x.color))
                    bits = bits | GL_COLOR_BUFFER_BIT
                end
                glClear(bits)
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
