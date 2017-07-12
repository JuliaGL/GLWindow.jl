"""
Returns a signal, which is true as long as the window is open.
returns `Signal{Bool}`
[GLFW Docs](http://www.glfw.org/docs/latest/group__window.html#gaade9264e79fae52bdb78e2df11ee8d6a)
"""
function window_open(window, s::Signal{Bool}=Signal(true))
    GLFW.SetWindowCloseCallback(window, (window,) -> begin
        push!(s, false)
    end)
    s
end
"""
Size of the window. Must not correlate to the real pixel size.
This is why there is also framebuffer_size.
returns `Signal{Vec{2,Int}}`
[GLFW Docs](http://www.glfw.org/docs/latest/group__window.html#gaaca1c2715759d03da9834eac19323d4a)
"""
function window_size(window, s::Signal{Vec{2,Int}}=Signal(Vec{2,Int}( GLFW.GetWindowSize(window))))
    GLFW.SetWindowSizeCallback(window, (window, w::Cint, h::Cint,) -> begin
        push!(s, Vec{2,Int}(w, h))
    end)
    s
end
"""
Size of window in pixel.
returns `Signal{Vec{2,Int}}`
[GLFW Docs](http://www.glfw.org/docs/latest/group__window.html#ga311bb32e578aa240b6464af494debffc)
"""
function framebuffer_size(window, s::Signal{Vec{2, Int}}=Signal(Vec{2, Int}(GLFW.GetFramebufferSize(window))))
    GLFW.SetFramebufferSizeCallback(window, (window, w::Cint, h::Cint) -> begin
        push!(s, Vec(Int(w), Int(h)))
    end)
    s
end
"""
Position of the window in screen coordinates.
returns `Signal{Vec{2,Int}}`
[GLFW Docs](http://www.glfw.org/docs/latest/group__window.html#ga1c36e52549efd47790eb3f324da71924)
"""
function window_position(window, s::Signal{Vec{2,Int}}=Signal(Vec(0,0)))
    GLFW.SetWindowPosCallback(window, (window, x::Cint, y::Cint,) -> begin
        push!(s, Vec(Int(x), Int(y)))
    end)
    s
end
"""
Registers a callback for the mouse buttons + modifiers
returns `Signal{NTuple{4, Int}}`
[GLFW Docs](http://www.glfw.org/docs/latest/group__input.html#ga1e008c7a8751cea648c8f42cc91104cf)
"""
function keyboard_buttons(window, s::Signal{NTuple{4, Int}}=Signal((0,0,0,0)))
    keydict = Dict{Int, Bool}()
    GLFW.SetKeyCallback(window, (window, button::Cint, scancode::Cint, action::Cint, mods::Cint) -> begin
        push!(s, (Int(button), Int(scancode), Int(action), Int(mods)))
    end)
    s
end
"""
Registers a callback for the mouse buttons + modifiers
returns an `Signal{NTuple{3, Int}}`,
containing the pressed button the action and modifiers.
[GLFW Docs](http://www.glfw.org/docs/latest/group__input.html#ga1e008c7a8751cea648c8f42cc91104cf)
"""
function mouse_buttons(window, s::Signal{NTuple{3, Int}}=Signal((0,0,0)))
    GLFW.SetMouseButtonCallback(window, (window, button::Cint, action::Cint, mods::Cint) -> begin
        push!(s, (Int(button), Int(action), Int(mods)))
    end)
    s
end
"""
Registers a callback for drag and drop of files.
returns `Signal{Vector{String}}`, which are absolute file paths
[GLFW Docs](http://www.glfw.org/docs/latest/group__input.html#gacc95e259ad21d4f666faa6280d4018fd)
"""
function dropped_files(window, s::Signal{Vector{String}}=Signal(String[]))
    GLFW.SetDropCallback(window, (window, files) -> begin
        push!(s, map(String, files))
    end)
    s
end

"""
Registers a callback for keyboard unicode input.
returns an `Signal{Vector{Char}}`,
containing the pressed char. Is empty, if no key is pressed.
[GLFW Docs](http://www.glfw.org/docs/latest/group__input.html#ga1e008c7a8751cea648c8f42cc91104cf)
"""
function unicode_input(window, s::Signal{Vector{Char}}=Signal(Char[]))
    GLFW.SetCharCallback(window, (window, c::Char) -> begin
        push!(s, Char[c])
        push!(s, Char[])
    end)
    s
end
"""
Registers a callback for the mouse cursor position.
returns an `Signal{Vec{2, Float64}}`,
which is not in screen coordinates, with the upper left window corner being 0
[GLFW Docs](http://www.glfw.org/docs/latest/group__input.html#ga1e008c7a8751cea648c8f42cc91104cf)
"""
function cursor_position(window, s::Signal{Vec{2, Float64}}=Signal(Vec(0.,0.)))
    GLFW.SetCursorPosCallback(window, (window, x::Cdouble, y::Cdouble) -> begin
        push!(s, Vec{2, Float64}(x, y))
    end)
    s
end
"""
Registers a callback for the mouse scroll.
returns an `Signal{Vec{2, Float64}}`,
which is an x and y offset.
[GLFW Docs](http://www.glfw.org/docs/latest/group__input.html#gacc95e259ad21d4f666faa6280d4018fd)
"""
function scroll(window, s::Signal{Vec{2, Float64}}=Signal(Vec(0.,0.)))
    GLFW.SetScrollCallback(window, (window, xoffset::Cdouble, yoffset::Cdouble) -> begin
        push!(s, Vec{2, Float64}(xoffset, yoffset))
        push!(s, Vec{2, Float64}(0))
    end)
    s
end
"""
Registers a callback for the focus of a window.
returns an `Signal{Bool}`,
which is true whenever the window has focus.
[GLFW Docs](http://www.glfw.org/docs/latest/group__window.html#ga6b5f973531ea91663ad707ba4f2ac104)
"""
function hasfocus(window, s::Signal{Bool}=Signal(false))
    GLFW.SetWindowFocusCallback(window, (window, focus::Bool) -> begin
        push!(s, focus)
    end)
    s
end
"""
Registers a callback for if the mouse has entered the window.
returns an `Signal{Bool}`,
which is true whenever the cursor enters the window.
[GLFW Docs](http://www.glfw.org/docs/latest/group__input.html#ga762d898d9b0241d7e3e3b767c6cf318f)
"""
function entered_window(window, s::Signal{Bool}=Signal(false))
    GLFW.SetCursorEnterCallback(window, (window, entered::Bool) -> begin
        push!(s, entered)
    end)
    s
end

"""
Takes a screen and registers a list of callback functions.
Returns a dict{Symbol, Signal}(name_of_callback => signal)
"""
function register_callbacks(window::GLFW.Window, callbacks::Vector{Function})
    tmp = map(callbacks) do f
        (Symbol(last(split(string(f),"."))), f(window))
    end
    Dict{Symbol, Any}(tmp)
end
function register_callbacks(window::Screen, callbacks::Vector{Function})
    register_callbacks(window.nativewindow, callbacks)
end
