using GLWindow, GLFW
using Base.Test  

# write your own tests here
window = createwindow("test", 10,10)

GLFW.SwapBuffers(window.glfwWindow)
GLFW.PollEvents()

GLFW.Terminate()


println("\033[32;1mSUCCESS\033[0m")

