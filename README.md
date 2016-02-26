# GLWindow
Simple package to create an OpenGL window.
It also wraps the window events into Reactive signals.
Supposedly more than one window creation library will be suppported, but so far it just creates them with GLFW.
`Screen()` will return a screen object which basically just wraps all the signals and exposes the handle to the underlying glfw window.
These are the exposed Signals:
```Julia

Inputs:
  framebuffer_size => Reactive.Signal{FixedSizeArrays.Vec{2,Int64}}
  scroll => Reactive.Signal{FixedSizeArrays.Vec{2,Float64}}
  hasfocus => Reactive.Signal{Bool}
  keyboard_buttons => Reactive.Signal{Tuple{Int64,Int64,Int64,Int64}}
  window_size => Reactive.Signal{FixedSizeArrays.Vec{2,Int64}}
  dropped_files => Reactive.Signal{Array{UTF8String,1}}
  unicode_input => Reactive.Signal{Array{Char,1}}
  cursor_position => Reactive.Signal{FixedSizeArrays.Vec{2,Float64}}
  window_area => Reactive.Signal{GeometryTypes.SimpleRectangle{Int64}}
  mouseposition => Reactive.Signal{FixedSizeArrays.Vec{2,Float64}}
  window_open => Reactive.Signal{Bool}
  mouse2id => Reactive.Signal{GLWindow.SelectionID{Int64}}
  mouse_buttons => Reactive.Signal{Tuple{Int64,Int64,Int64}}
  entered_window => Reactive.Signal{Bool}
  window_position => Reactive.Signal{FixedSizeArrays.Vec{2,Int64}}

```
You can supply the following keyword arguments:
```Julia
name = "GLWindow";
resolution = standard_screen_resolution(),
debugging = false,
major = 3,
minor = 3,# this is what GLVisualize needs to offer all features
windowhints = standard_window_hints(),
contexthints = standard_context_hints(major, minor)
```

