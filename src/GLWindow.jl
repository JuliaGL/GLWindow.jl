VERSION >= v"0.4.0-dev+6521" && __precompile__(true)
module GLWindow

using ModernGL
using GLAbstraction
using GLFW
using Reactive
using GeometryTypes
using Compat

import GLFW.Window
import GLFW.Monitor
import GLAbstraction.render

include("reactglfw.jl")

export createwindow
export Screen
export UnicodeInput
export KeyPressed
export MouseClicked
export MouseMoved
export EnteredWindow
export WindowResized
export MouseDragged
export Scrolled
export Window
export leftclickdown
export Screen
export primarymonitorresolution

function __init__()
    global WINDOW_TO_SCREEN_DICT = Dict{Window, Screen}()
    global GLFW_SCREEN_STACK     = Screen[]
end


end
