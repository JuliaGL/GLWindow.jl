using GLWindow, GLFW, Reactive
using Base.Test  

# write your own tests here
if isinteractive() # only do test if called from REPL... this is for automated testing environments which fail for OpenGL stuff, but I'd like to test if at least including works

GLFW.Init()
window = createwindow("test", 500,500)

while window.inputs[:open].value

	GLFW.SwapBuffers(window.nativewindow)

	GLFW.PollEvents()
end
GLFW.Terminate()

end
