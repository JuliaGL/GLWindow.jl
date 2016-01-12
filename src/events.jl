
"""
Calculates mouse drag and supplies ID
"""
function to_mousedragg_id(t0, mouse_down1, mouseposition1, objectid)
    mouse_down0, draggstart, objectidstart, mouseposition0, objectid0 = t0
    if !mouse_down0 && mouse_down1
        return (mouse_down1, mouseposition1, objectid, mouseposition1, objectid)
    elseif mouse_down0 && mouse_down1
        return (mouse_down1, draggstart, objectidstart, mouseposition1, objectid)
    end
    (false, Vec2f0(0), Vec(0,0), Vec2f0(0), Vec(0,0))
end

function diff_mouse(mouse_down_draggstart_mouseposition)
    mouse_down, draggstart, objectid_start, mouseposition, objectid_end = mouse_down_draggstart_mouseposition
    (draggstart - mouseposition, objectid_start, objectid_end)
end
function mousedragdiff_objectid(inputs, mouse_hover)
    @materialize mousebuttonspressed, mousereleased, mouseposition = inputs
    mousedown      = const_lift(isnotempty, mousebuttonspressed)
    mousedraggdiff = const_lift(diff_mouse,
        foldp(to_mousedragg_id, (false, Vec2f0(0), Vec(0,0), Vec2f0(0), Vec(0,0)),
            mousedown, mouseposition, mouse_hover
        )
    )
    return filterwhen(mousedown, (Vec2f0(0), Vec(0,0), Vec(0,0)), mousedraggdiff)
end

function to_arrow_symbol(button_set)
    GLFW.KEY_RIGHT in button_set && return :right
    GLFW.KEY_LEFT  in button_set && return :left
    GLFW.KEY_DOWN  in button_set && return :down
    GLFW.KEY_UP    in button_set && return :up
    return :nothing
end

function add_complex_signals(screen, selection)
    mouse_hover = const_lift(first, selection[:mouse_hover])

    mousedragdiff_id = mousedragdiff_objectid(screen.inputs, mouse_hover)
    selection        = foldp(drag2selectionrange, 0:0, mousedragdiff_id)
    arrow_navigation = const_lift(to_arrow_symbol, screen.inputs[:buttonspressed])

    screen.inputs[:mouse_hover]             = mouse_hover
    screen.inputs[:mousedragdiff_objectid]  = mousedragdiff_id
    screen.inputs[:selection]               = selection
    screen.inputs[:arrow_navigation]        = arrow_navigation
end

"""
Selection of random objects on the screen is realized by rendering an
object id + plus an arbitrary index into the framebuffer.
The index can be used for e.g. instanced geometries.
"""
immutable SelectionID{T} <: FixedVectorNoTuple{2, T}
    objectid::T
    index::T
end

begin

const selection_data = Array(SelectionID{UInt16}, 1, 1)
const old_mouse_position = Vec(0., 0.)
global update_selectionqueries
function push_selectionqueries!(
        objectid_buffer, mouse_position,
        window_size, selection_signal
    )
    if old_mouse_position != mouse_position
        glReadBuffer(GL_COLOR_ATTACHMENT1)
        x,y = Vec{2, Int}(map(floor, mouse_position))
        w,h = window_size
        if x > 0 && y > 0 && x <= w && y <= h
            glReadPixels(x, y, 1, 1, objectid_buffer.format, objectid_buffer.pixeltype, selection_data)
            val = convert(Matrix{SelectionID{Int}}, selection_data)[1,1]
            push!(selection_signal, val)
        end
        old_mouse_position = mouse_position
    end
end

end


@enum MouseButton MOUSE_LEFT MOUSE_MIDDLE MOUSE_RIGHT


"""
Transforms a mouse drag into a selection from drag start to drag end
"""
function drag2selectionrange(v0, selection)
    mousediff, id_start, current_id = selection
    if mousediff != Vec2f0(0) # Mouse Moved
        if current_id[1] == id_start[1]
            return min(id_start[2],current_id[2]):max(id_start[2],current_id[2])
        end
    else # if mouse did not move while dragging, make a single point selection
        if current_id[1] == id_start[1]
            return current_id[2]:0 # this is the type stable way of indicating, that the selection is between currend_index
        end
    end
    v0
end


"""
Returns two signals, one boolean signal if clicked over `robj` and another
one that consists of the object clicked on and another argument indicating that it's the first click
"""
function clicked(robj::RenderObject, button::MouseButton, window::Screen)
    @materialize mouse_hover, mousebuttonspressed = window.inputs
    leftclicked = const_lift(mouse_hover, mousebuttonspressed) do mh, mbp
        mh[1] == robj.id && mbp == Int[button]
    end
    clicked_on_obj = keepwhen(leftclicked, false, leftclicked)
    clicked_on_obj = const_lift((mh, x)->(x,robj,mh), mouse_hover, leftclicked)
    leftclicked, clicked_on_obj
end

is_same_id(id, robj) = id[1] == robj.id
"""
Returns a boolean signal indicating if the mouse hovers over `robj`
"""
is_hovering(robj::RenderObject, window::Screen) =
    droprepeats(const_lift(is_same_id, window.inputs[:mouse_hover], robj))

function dragon_tmp(past, mh, mbp, mpos, robj, button, start_value)
    diff, dragstart_index, was_clicked, dragstart_pos = past
    over_obj = mh[1] == robj.id
    is_clicked = mbp == Int[button]
    if is_clicked && was_clicked # is draggin'
        return (dragstart_pos-mpos, dragstart_index, true, dragstart_pos)
    elseif over_obj && is_clicked && !was_clicked # drag started
        return (Vec2f0(0), mh[2], true, mpos)
    end
    return start_value
end

"""
Returns a signal with the difference from dragstart and current mouse position,
and the index from the current ROBJ id.
"""
function dragged_on(robj::RenderObject, button::MouseButton, window::Screen)
    @materialize mouse_hover, mousebuttonspressed, mouseposition = window.inputs
    start_value = (Vec2f0(0), mouse_hover.value[2], false, Vec2f0(0))
    tmp_signal = foldp(dragon_tmp,
        start_value, mouse_hover,
        mousebuttonspressed, mouseposition,
        Signal(robj), Signal(button), Signal(start_value)
    )
    droprepeats(const_lift(getindex, tmp_signal, 1:2))
end


"""
returns a signal which becomes true whenever there is a doublecklick
"""
function doubleclick(mouseclick::Signal{Vector{MouseButton}}, threshold::Real)
    ddclick = foldp((time(), mouseclick.value, false), mouseclick) do v0, mclicked
        t0, lastc, _ = v0
        t1 = time()
        if length(mclicked) == 1 && length(lastc) == 1 && lastc[1] == mclicked[1] && t1-t0 < threshold
            return (t1, mclicked, true)
        else
            return (t1, mclicked, false)
        end
    end
    dd = const_lift(last, ddclick)
    return dd
end

screenshot(window; path="screenshot.png", channel=:color) =
   save(path, screenbuffer(window, channel=channel), true)

function screenbuffer(window; channel=:color)
    fb = window.framebuffer
    channels = fieldnames(fb)[2:end]
    if channel in channels
        img = gpu_data(fb.(channel))[window.area.value]
        return rotl90(img)
    end
    error("Channel $channel does not exist. Only these channels are available: $channels")
end

export screenshot, screenbuffer
