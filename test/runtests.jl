using GLWindow
using Base.Test

function is_ci()
	get(ENV, "TRAVIS", "") == "true" || get(ENV, "APPVEYOR", "") == "true" || get(ENV, "CI", "") == "true"
end

if !is_ci() # only do test if not CI... this is for automated testing environments which fail for OpenGL stuff, but I'd like to test if at least including works

GLFW.Init()
window = Screen("test", resolution=(500,500))

swapbuffers(window)

pollevents()

end
println("success")
