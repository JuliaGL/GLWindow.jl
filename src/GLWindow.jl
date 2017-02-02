VERSION >= v"0.4.0-dev+6521" && __precompile__(true)

module GLWindow

using ModernGL
using GLAbstraction
using GLFW
using Reactive
using GeometryTypes
using ColorTypes
using FixedPointNumbers
using FixedSizeArrays
using Compat
using FileIO

import GLFW: Window, Monitor
import GLAbstraction.render
import GeometryTypes.widths

if isdefined(FixedPointNumbers, :N0f8)
    import FixedPointNumbers: N0f8
else
    const N0f8 = FixedPointNumbers.UFixed8
end

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
