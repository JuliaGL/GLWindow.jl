#each backend should provide these callbacks i think.
include("GLFW/callbacks.jl")

"""
Standard set of callback functions
"""
function standard_callbacks()
    Function[
        window_open,
        window_size,
        window_position,
        keyboard_buttons,
        mouse_buttons,
        dropped_files,
        framebuffer_size,
        unicode_input,
        cursor_position,
        scroll,
        hasfocus,
        entered_window,
    ]
end