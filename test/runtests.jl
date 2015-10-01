using GLWindow, GLFW, Reactive
using Base.Test  

function is_ci()
	get(ENV, "TRAVIS", "") == "true" || get(ENV, "APPVEYOR", "") == "true" || get(ENV, "CI", "") == "true"
end

if !is_ci() # only do test if not CI... this is for automated testing environments which fail for OpenGL stuff, but I'd like to test if at least including works

GLFW.Init()
window = createwindow("test", 500,500)

while window.inputs[:open].value

	GLFW.SwapBuffers(window.nativewindow)

	GLFW.PollEvents()
end
GLFW.Terminate()

end
