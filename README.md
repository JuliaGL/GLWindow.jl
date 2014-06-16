# GLWindow
Simple package to create an OpenGL window, which also allows to emit events.

I'm in the middle of integrating React.jl for the Events.

The source for that is in src/reactglfw.jl and will be soon the standard way of creating a window.

Simple example:
```Julia
using GLWindow, GLUtil, ModernGL, Events

window = createWindow("Mesh Display", 1000, 1000 )

#Register some events (will be replaced by React.jl pretty soon)
registerEventAction(WindowResized{Window}, x -> true, resize, (perspectiveCam,))

#Puts some RenderObject from GLUtil or a function into the render queue, which is so far a Dict{Symbol, Any}
# For an easy deletion of renderobjects with glDelete
glDisplay(:clearScreen, () -> glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT))

glRemove(:clearScreen)
# Another signature for glDisplay:
glDisplay(:funcWithArgs, someFunction, arg1, arg2, arg3)


glClearColor(1,1,1,0)

#Enter renderloop
renderloop(window)
```
