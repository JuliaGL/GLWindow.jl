
function to_arrow_symbol(button_set)
    for b in button_set
        GLFW.KEY_RIGHT == b && return :right
        GLFW.KEY_LEFT  == b && return :left
        GLFW.KEY_DOWN  == b && return :down
        GLFW.KEY_UP    == b && return :up
    end
    return :nothing
end

function mousedragg_objectid(mouse_dragg, mouse_hover)
    map(mouse_dragg) do dragg
        value(mouse_hover), dragg
    end
end

function add_complex_signals!(screen)
    @materialize keyboard_buttons, mouse_buttons = screen.inputs

    no_scancode = map(remove_scancode, keyboard_buttons)

    button_s = merge(
        button_signals(no_scancode, :button),
        button_signals(mouse_buttons, :mouse_button)
    )

    arrow_navigation = const_lift(to_arrow_symbol, button_s[:buttons_pressed])

    merge!(
        screen.inputs,
        Dict{Symbol, Any}(
            :arrow_navigation => arrow_navigation
        ),
        button_s
    )
    screen.inputs[:key_pressed] = const_lift(GLAbstraction.singlepressed,
        screen.inputs[:mouse_buttons_pressed],
        GLFW.MOUSE_BUTTON_LEFT
    )
    return
end


"""
Builds a Set of keys, accounting for released and pressed keys
"""
function currently_pressed_keys(v0::Set{Int}, button_action_mods)
    button, action, mods = button_action_mods
    if button != Int(GLFW.KEY_UNKNOWN)
        if action == Int(GLFW.PRESS)
            push!(v0, button)
        elseif action == Int(GLFW.RELEASE)
            delete!(v0, button)
        elseif action == Int(GLFW.REPEAT)
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
    keyset = Set{Int}()
    sizehint!(keyset, 10) # make it less suspicable to growing/shrinking
    released = filter(isreleased, buttons.value, buttons)
    down     = filter(isdown, buttons.value, buttons)
    Dict{Symbol, Any}(
        Symbol("$(name)_released") => map(first, released),
        Symbol("$(name)_down")     => map(first, down),
        Symbol("$(name)s_pressed") => foldp(
            currently_pressed_keys, keyset, buttons
        )
    )
end

"""
Selection of random objects on the screen is realized by rendering an
object id + plus an arbitrary index into the framebuffer.
The index can be used for e.g. instanced geometries.
"""
struct SelectionID{T <: Integer} <: FieldVector{2, T}
    id::T
    index::T
    # function SelectionID(args::NTuple{2, T})
    #     new{T}(args[1], args[2])
    # end
end

const selection_data = Base.RefValue{SelectionID{UInt16}}()
const old_mouse_position = Base.RefValue(Vec{2, Float64}(0))

function push_selectionqueries!(screen)
    mouse_position = value(mouseposition(screen))
    selection_signal = mouse2id(screen)
    window_size = widths(screen)
    buff = framebuffer(screen).objectid
    if old_mouse_position[] != mouse_position
        glReadBuffer(GL_COLOR_ATTACHMENT1)
        x, y = Vec{2, Int}(floor.(mouse_position))
        w, h = window_size
        if x > 0 && y > 0 && x <= w && y <= h
            glReadPixels(x, y, 1, 1, buff.format, buff.pixeltype, selection_data)
            val = convert(SelectionID{Int}, selection_data[])
            push!(selection_signal, val)
        end
        old_mouse_position[] = mouse_position
    end
end


export screenshot, screenbuffer
