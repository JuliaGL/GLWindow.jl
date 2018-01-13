import GLFW: Window

"""
Returns a signal, which is true as long as the window is open.
returns `Bool`
[GLFW Docs](http://www.glfw.org/docs/latest/group__window.html#gaade9264e79fae52bdb78e2df11ee8d6a)
"""
function window_open(window::Window, s::Bool=false)
    GLFW.SetWindowCloseCallback(window, (window,) -> s)
    s
end

"""
Size of the window. Must not correlate to the real pixel size.
This is why there is also framebuffer_size.
returns `NTuple{2,Int}}`
[GLFW Docs](http://www.glfw.org/docs/latest/group__window.html#gaaca1c2715759d03da9834eac19323d4a)
"""
function window_size(window::Window, s::NTuple{2,Int}=GLFW.GetWindowSize(window))
    GLFW.SetWindowSizeCallback(window, (window, w::Cint, h::Cint,) -> begin
        s = Vec{2,Int}(w, h)
    end)
    s
end
"""
Size of window in pixel.
returns `NTuple{2,Int}}`
[GLFW Docs](http://www.glfw.org/docs/latest/group__window.html#ga311bb32e578aa240b6464af494debffc)
"""
function framebuffer_size(window::Window, s::NTuple{2, Int}=GLFW.GetFramebufferSize(window))
    GLFW.SetFramebufferSizeCallback(window, (window, w::Cint, h::Cint) -> begin
        s = (Int(w), Int(h))
    end)
    s
end
"""
Position of the window in screen coordinates.
returns `NTuple{2,Int}}`
[GLFW Docs](http://www.glfw.org/docs/latest/group__window.html#ga1c36e52549efd47790eb3f324da71924)
"""
function window_position(window::Window, s::NTuple{2,Int}=(0,0))
    GLFW.SetWindowPosCallback(window, (window, x::Cint, y::Cint,) -> begin
        s = (Int(x), Int(y))
    end)
    s
end
"""
Registers a callback for the mouse buttons + modifiers
returns `NTuple{4, Int}`
[GLFW Docs](http://www.glfw.org/docs/latest/group__input.html#ga1e008c7a8751cea648c8f42cc91104cf)
"""
function keyboard_buttons(window::Window, s::NTuple{4, Int}=(0,0,0,0))
    keydict = Dict{Int, Bool}()
    GLFW.SetKeyCallback(window, (window, button::Cint, scancode::Cint, action::Cint, mods::Cint) -> begin
        s = (Int(button), Int(scancode), Int(action), Int(mods))
    end)
    s
end
"""
Registers a callback for the mouse buttons + modifiers
returns an `NTuple{3, Int}`,
containing the pressed button the action and modifiers.
[GLFW Docs](http://www.glfw.org/docs/latest/group__input.html#ga1e008c7a8751cea648c8f42cc91104cf)
"""
function mouse_buttons(window::Window, s::NTuple{3, Int}=(0,0,0))
    GLFW.SetMouseButtonCallback(window, (window, button::Cint, action::Cint, mods::Cint) -> begin
        s = (Int(button), Int(action), Int(mods))
    end)
    s
end
"""
Registers a callback for drag and drop of files.
returns `Vector{String}`, which are absolute file paths
[GLFW Docs](http://www.glfw.org/docs/latest/group__input.html#gacc95e259ad21d4f666faa6280d4018fd)
"""
function dropped_files(window::Window, s::Vector{String}=String[])
    GLFW.SetDropCallback(window, (window, files) -> begin
        s = map(String, files)
    end)
    s
end

"""
Registers a callback for keyboard unicode input.
returns an `Vector{Char}`,
containing the pressed char. Is empty, if no key is pressed.
[GLFW Docs](http://www.glfw.org/docs/latest/group__input.html#ga1e008c7a8751cea648c8f42cc91104cf)
"""
function unicode_input(window::Window, s::Vector{Char}=Char[])
    GLFW.SetCharCallback(window, (window, c::Char) -> begin
        push!(s, c)
    end)
    s
end
"""
Registers a callback for the mouse cursor position.
returns an `NTuple{2, Float64}`,
which is not in screen coordinates, with the upper left window corner being 0
[GLFW Docs](http://www.glfw.org/docs/latest/group__input.html#ga1e008c7a8751cea648c8f42cc91104cf)
"""
function cursor_position(window::Window, s::NTuple{2, Float64}=(0.,0.))
    GLFW.SetCursorPosCallback(window, (window, x::Cdouble, y::Cdouble) -> begin
        s = (x, y)
    end)
    s
end
"""
Registers a callback for the mouse scroll.
returns an `NTuple{2, Float64}`,
which is an x and y offset.
[GLFW Docs](http://www.glfw.org/docs/latest/group__input.html#gacc95e259ad21d4f666faa6280d4018fd)
"""
function scroll(window::Window, s::NTuple{2, Float64}=(0.,0.))
    GLFW.SetScrollCallback(window, (window, xoffset::Cdouble, yoffset::Cdouble) -> begin
        s = (xoffset, yoffset)
    end)
    s
end
"""
Registers a callback for the focus of a window.
returns a `Bool`,
which is true whenever the window has focus.
[GLFW Docs](http://www.glfw.org/docs/latest/group__window.html#ga6b5f973531ea91663ad707ba4f2ac104)
"""
function hasfocus(window::Window, s::Bool=false)
    GLFW.SetWindowFocusCallback(window, (window, focus::Bool) -> begin
        s = focus
    end)
    s
end
"""
Registers a callback for if the mouse has entered the window.
returns a `Bool`,
which is true whenever the cursor enters the window.
[GLFW Docs](http://www.glfw.org/docs/latest/group__input.html#ga762d898d9b0241d7e3e3b767c6cf318f)
"""
function entered_window(window::Window, s::Bool=false)
    GLFW.SetCursorEnterCallback(window, (window, entered::Bool) -> begin
        s = entered
    end)
    s
end

"""
Takes a window and registers a list of callback functions.
Returns a dict{Symbol, Signal}(name_of_callback => signal)
"""
function register_callbacks(window::Window, callbacks::Vector{Function})
    tmp = map(callbacks) do f
        (Symbol(last(split(string(f),"."))), f(window))
    end
    Dict{Symbol, Any}(tmp)
end

#Came from GLWindow/events.jl
"""
Builds a Set of keys, accounting for released and pressed keys
"""
function currently_pressed_keys(v0::Set{Int}, button_action_mods)
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

#question: do we need this?
# """
# Creates high level signals from the raw GLFW button signals.
# Returns a dictionary with button released and down signals.
# It also creates a signal, which is the set of all currently pressed buttons.
# `name` is used to name the dictionary keys.
# `buttons` is a tuple of (button, action, mods)::NTuple{3, Int}
# """
# function button_signals(buttons::NTuple{3, Int}, name::Symbol)
#     keyset = Set{Int}()
#     sizehint!(keyset, 10) # make it less suspicable to growing/shrinking
#     released = filter(isreleased, buttons.value, buttons)
#     down     = filter(isdown, buttons.value, buttons)
#     Dict{Symbol, Any}(
#         Symbol("$(name)_released") => map(first, released),
#         Symbol("$(name)_down")     => map(first, down),
#         Symbol("$(name)s_pressed") => foldp(
#             currently_pressed_keys, keyset, buttons
#         )
#     )
# end

