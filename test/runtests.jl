using GLWindow, GLFW
using Base.Test  

# write your own tests here
window = createwindow("test", 512,512)

GLFW.SwapBuffers(window.nativewindow)
while window.inputs[:open].value
	yield()
	GLFW.PollEvents()
end
GLFW.Terminate()


println("\033[32;1mSUCCESS\033[0m")

