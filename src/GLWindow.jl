__precompile__(true)
module GLWindow

using ModernGL
using GLAbstraction
using GLFW
using Reactive
using StaticArrays
using GeometryTypes
using ColorTypes
using FixedPointNumbers
using FileIO

import GLFW: Window, Monitor
import GLAbstraction: render, N0f8
import GeometryTypes: widths

#compatibility with the GLFW revamp
#things that might be used somewhere in GLWindow, all from GLFW/types.jl
import GLFW: Window, MonitorProperties
const create_glcontext = Window
import GLFW: swapbuffers, make_windowed!, make_fullscreen!, set_visibility!
#things that might be used somewhere in GLWindow, all from GLFW/extensions.jl
import GLFW: register_callbacks,
             standard_screen_resolution, standard_context_hints, standard_window_hints,
             full_screen_usage_message, poll_glfw, to_arrow_symbol, primarymonitorresolution
include("types.jl")

include("core.jl")
include("events.jl")
export pressed, dragged, clicked

include("callbacks.jl")
include("render.jl")
include("screen.jl")

export createwindow
export swapbuffers
export poll_glfw
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
export renderloop
export render_frame
export screenshot
export screenbuffer
export zeroposition
export create_glcontext
export renderlist
export destroy!
export robj_from_camera
export AbstractContext

end
