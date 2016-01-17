pressed(keys, key) = key in keys

function mouse_dragg(v0, mouse_pressed)
    startpoint, diff = v0
    isreleased, isdown, ispressed, position = mouse_pressed
    isdown && return (position, position*0)
    ispressed && return (startpoint, startpoint-position)
    isreleased && return (startpoint*0, startpoint*0)
end

mouse_dragg(v0, args) = mouse_dragg(v0..., args...)
function mouse_dragg(
        started::Bool, startpoint, 
        ispressed::Bool, position, start_condition::Bool
    )
    if !started && ispressed && start_condition
        return (true, position, position*0)
    end
    started && ispressed && return (true, startpoint, startpoint-position)
    (false, startpoint*0, startpoint*0)
end

function dragged(mouseposition, key_pressed, start_condition=true)
    v0 = (false, Vec2f0(0), Vec2f0(0))
    args = const_lift(tuple, key_pressed, mouseposition, start_condition)
    dragg_sig = map(mouse_dragg, v0, args)
    is_dragg = map(first, dragg_sig)
    dragg_diff = map(last, dragg_sig)
    keepwhen(is_dragg, Vec2f0(0), dragg_diff)
end

function dragged(mouse, key, start_condition=true)
    v0 = (false, Vec2f0(0), Vec2f0(0), value(sample_signal))
    args = map(tuple, key_pressed, mouseposition, start_condition)
    dragg_sig = map(mouse_dragg, v0, args)
    is_dragg = map(first, dragg_sig)
    dragg_diff = map(last, dragg_sig)
    keepwhen(is_dragg, Vec2f0(0), dragg_diff)
end

function mousedragg_objectid(mouse_dragg, mouse_hover)
    map(mouse_dragg) do dragg
        value(mouse_hover), dragg
    end
end

function to_arrow_symbol(button_set)
    for b in button_set
        GLFW.KEY_RIGHT == b && return :right
        GLFW.KEY_LEFT  == b && return :left
        GLFW.KEY_DOWN  == b && return :down
        GLFW.KEY_UP    == b && return :up
    end
    return :nothing
end

function add_complex_signals!(screen)
    @materialize keyboard_buttons, mouse_buttons = screen.inputs
    no_scancode = map(remove_scancode, keyboard_buttons)
    button_s = merge(
        button_signals(no_scancode, :button),
        button_signals(mouse_buttons, :mouse_button)
    )
    mousedragdiff_id = mousedragg_objectid(screen.inputs, mouse2id(screen))
    #selection        = foldp(drag2selectionrange, 0:0, mousedragdiff_id)
    arrow_navigation = const_lift(to_arrow_symbol, keyboard_buttons)
    merge!(
        screen.inputs, 
        Dict{Symbol, Any}(
            :mousedragg_objectid => mousedragdiff_id,
           # :selection           => selection,
            :arrow_navigation    => arrow_navigation
        ),
        button_s
    )
    screen
end


"""
Builds a Set of keys, accounting for released and pressed keys
"""
function currently_pressed_keys(v0::IntSet, button_action_mods)
    button, action, mods = button_action_mods
    if button != GLFW.KEY_UNKNOWN
        if action == GLFW.PRESS
            push!(v0, button)
        elseif action == GLFW.RELEASE
            delete!(v0, button)
        elseif action == GLFW.REPEAT
            # nothing needs to be done, besides returning the same set of keys
        else
            error("Unrecognized enum value for GLFW button press action: $action")
        end
    end
    return v0
end

function remove_scancode(button_scancode_action_mods)
    button, scancode, action, mods = button_scancode_action_mods
    button, action, mods
end
isreleased(button) = button[2] == GLFW.RELEASE
isdown(button) = button[2] == GLFW.PRESS

"""
Creates high level signals from the raw GLFW button signals.
Returns a dictionary with button released and down signals.
It also creates a signal, which is the set of all currently pressed buttons.
`name` is used to name the dictionary keys.
`buttons` is a tuple of (button, action, mods)::NTuple{3, Int}
"""
function button_signals(buttons::Signal{NTuple{3, Int}}, name::Symbol)
    keyset = IntSet()
    sizehint!(keyset, 10) # make it less suspicable to growing/shrinking
    released = filter(isreleased, buttons.value, buttons)
    down     = filter(isdown, buttons.value, buttons)
    Dict{Symbol, Any}(
        symbol("$(name)_released") => map(first, released),
        symbol("$(name)_down")     => map(first, down),
        symbol("$(name)s_pressed") => foldp(
            currently_pressed_keys, keyset, buttons
        )
    )
end

"""
Selection of random objects on the screen is realized by rendering an
object id + plus an arbitrary index into the framebuffer.
The index can be used for e.g. instanced geometries.
"""
immutable SelectionID{T <: Integer} <: FixedVectorNoTuple{2, T}
    id::T
    index::T
end

begin
global push_selectionqueries!

const selection_data = Array(SelectionID{UInt16}, 1, 1)
const old_mouse_position = Array(Vec{2, Float64}, 1)

function push_selectionqueries!(screen)
    mouse_position   = value(mouseposition(screen))
    selection_signal = mouse2id(screen)
    window_size      = width(screen)
    buff  = framebuffer(screen).objectid
    if old_mouse_position[] != mouse_position
        glReadBuffer(GL_COLOR_ATTACHMENT1)
        x,y = Vec{2, Int}(map(floor, mouse_position))
        w,h = window_size
        if x > 0 && y > 0 && x <= w && y <= h
            glReadPixels(x, y, 1, 1, buff.format, buff.pixeltype, selection_data)
            val = convert(Matrix{SelectionID{Int}}, selection_data)[1,1]
            push!(selection_signal, val)
        end
        old_mouse_position[] = mouse_position
    end
end

end




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
        if current_id.id == id_start.id
            return current_id.index:0 # this is the type stable way of indicating, that the selection is between currend_index
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
    clicked_on = const_lift(mouse_hover, mousebuttonspressed) do mh, mbp
        mh.id == robj.id && in(button, mbp)
    end
    clicked_on_obj = keepwhen(clicked_on, false, clicked_on)
    clicked_on_obj = const_lift((mh, x)->(x,robj,mh), mouse_hover, clicked_on)
    clicked_on, clicked_on_obj
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
   save(path, screenbuffer(window, channel), true)

function screenbuffer(window, channel=:color)
    fb = window.framebuffer
    channels = fieldnames(fb)[2:end]
    if channel in channels
        img = gpu_data(fb.(channel))[window.area.value]
        return rotl90(img)
    end
    error("Channel $channel does not exist. Only these channels are available: $channels")
end

export screenshot, screenbuffer


