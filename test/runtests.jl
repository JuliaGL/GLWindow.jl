using GLWindow, GLFW, Reactive
using Base.Test  

# write your own tests here
GLFW.Init()
window = createwindow("test", 500,500)

while window.inputs[:open].value

	GLFW.SwapBuffers(window.nativewindow)

	GLFW.PollEvents()
end
GLFW.Terminate()

