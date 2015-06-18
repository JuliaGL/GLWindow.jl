using GLWindow, GLFW, Reactive
using Base.Test  

# write your own tests here
window = createwindow("test", 500,500)
lift(println, window.inputs[:droppedfiles])

while window.inputs[:open].value

	GLFW.SwapBuffers(window.nativewindow)
	GLFW.PollEvents()
end
GLFW.Terminate()

