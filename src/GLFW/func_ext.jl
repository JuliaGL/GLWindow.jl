#Extensions to GLFW functionality
import GLFW: Window

function Base.isopen(window::Window)
    window.handle == C_NULL && return false
    !WindowShouldClose(window)
end

function Base.resize!(x::Window, w::Integer, h::Integer)
    SetWindowSize(x, w, h)
end


function swapbuffers(window::Window)
    window.handle == C_NULL && return
    SwapBuffers(window)
    return
end
#Came from GLWindow.jl/screen.jl
#question: Is this correct?
"""
Takes a Window and registers a list of callback functions.
Returns a Dict{Symbol, Any}(name_of_callback => signal)
"""
function register_callbacks(window::Window, callbacks::Vector{Function})
    tmp = map(callbacks) do f
        (Symbol(last(split(string(f),"."))), f(window))
    end
    Dict{Symbol, Any}(tmp)
end

function poll_glfw()
    PollEvents()
end

function to_arrow_symbol(button_set)
    for b in button_set
        KEY_RIGHT == b && return :right
        KEY_LEFT  == b && return :left
        KEY_DOWN  == b && return :down
        KEY_UP    == b && return :up
    end
    return :nothing
end