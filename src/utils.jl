#Came from screen.jl
#I think in general at this level, GeometryTypes is fine to be using'd. What I did remove is all the signal stuff, where it made sense to remove them,
#the rest I'm throwing in the junkyard for now.
"""
On OSX retina screens, the window size is different from the
pixel size of the actual framebuffer. With this function we
can find out the scaling factor.
"""
function scaling_factor(window::Vec{2, Int}, fb::Vec{2, Int})
    (window[1] == 0 || window[2] == 0) && return Vec{2, Float64}(1.0)
    Vec{2, Float64}(fb) ./ Vec{2, Float64}(window)
end
function scaling_factor(nw)
    w, fb = GLFW.GetWindowSize(nw), GLFW.GetFramebufferSize(nw)
    scaling_factor(Vec{2, Int}(w), Vec{2, Int}(fb))
end

"""
Correct OSX scaling issue and move the 0,0 coordinate to left bottom.
"""
function corrected_coordinates(
        window_size::Vec{2,Int},
        framebuffer_width::Vec{2,Int},
        mouse_position::Vec{2,Float64}
    )
    s = scaling_factor(window_size.value, framebuffer_width.value)
    Vec{2,Float64}(mouse_position[1], window_size.value[2] - mouse_position[2]) .* s
end

#Can these two next things stay here, seems like a nice thing to have 
"""
Function that creates a screenshot from `window` and saves it to `path`.
You can choose the channel of the framebuffer, which is usually:
`color`, `depth` and `objectid`
"""
function screenshot(window; path="screenshot.png", channel=:color)
    save(path, screenbuffer(window, channel), true)
end

"""
Returns the contents of the framebuffer of `window` as a Julia Array.
You can choose the channel of the framebuffer, which is usually:
`color`, `depth` and `objectid`
"""
function screenbuffer(window, channel = :color)
    fb = framebuffer(window)
    channels = fieldnames(fb)[2:end]
    area = abs_area(window)
    w = widths(area)
    x1, x2 = max(area.x, 1), min(area.x + w[1], size(fb.color, 1))
    y1, y2 = max(area.y, 1), min(area.y + w[2], size(fb.color, 2))
    if channel == :depth
        w, h = x2 - x1 + 1, y2 - y1 + 1
        data = Matrix{Float32}(w, h)
        glBindFramebuffer(GL_FRAMEBUFFER, fb.id[1])
        glDisable(GL_SCISSOR_TEST)
        glDisable(GL_STENCIL_TEST)
        glReadPixels(x1 - 1, y1 - 1, w, h, GL_DEPTH_COMPONENT, GL_FLOAT, data)
        return rotl90(data)
    elseif channel in channels
        buff = gpu_data(getfield(fb, channel))
        img = view(buff, x1:x2, y1:y2)
        if channel == :color
            img = RGB{N0f8}.(img)
        end
        return rotl90(img)
    end
    error("Channel $channel does not exist. Only these channels are available: $channels")
end

"""
Sleep is pretty imprecise. E.g. anything under `0.001s` is not guaranteed to wake
up before `0.001s`. So this timer is pessimistic in the way, that it will never
sleep more than `time`.
"""
@inline function sleep_pessimistic(sleep_time)
    st = convert(Float64,sleep_time) - 0.002
    start_time = time()
    while (time() - start_time) < st
        sleep(0.001) # sleep for the minimal amount of time
    end
end

zeroposition(area::NamedTuple) = (x=0, y=0, w=area[:w], h=area[:h])