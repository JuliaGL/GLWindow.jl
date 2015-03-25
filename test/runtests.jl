using GLWindow, GLFW
using Base.Test  

# write your own tests here
window = createwindow("test", 10,10)

GLFW.SwapBuffers(window.nativewindow)
GLFW.PollEvents()

GLFW.Terminate()

