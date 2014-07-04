module GLWindow
using ModernGL, GLUtil
export gldisplay, glremove, createwindow


global const RENDER_DICT = Dict{Symbol, Any}()

#current render loop... Will definitely not stay like this
function renderloop()
    for (ind,elem) in enumerate(RENDER_DICT)
        if isa(elem[2], Tuple)
            if isa(elem[2][1], Function)
                elem[2][1](elem[2][2:end]...)
            else
        	   render(elem[2]...)
            end
        else
            render(elem[2]...)
        end
    end
end

function gldisplay(id::Symbol, x...) 
    RENDER_DICT[id] = x
    nothing
end
function glremove(id::Symbol)
    delete!(RENDER_DICT, id)
    nothing
end

include("reactglfw.jl")


end
