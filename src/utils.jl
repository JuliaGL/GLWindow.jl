#Came from screen.jl
#I think in general at this level, GeometryTypes is fine to be using'd. What I did remove is all the signal stuff, where it made sense to remove them,
#the rest I'm throwing in the junkyard for now.
"""
On OSX retina screens, the window size is different from the
pixel size of the actual framebuffer. With this function we
can find out the scaling factor.
"""
function scaling_factor(window::NTuple{2, Int}, fb::NTuple{2, Int})
    (window[1] == 0 || window[2] == 0) && return (1.0, 1.0)
    fb ./ window
end

"""
Correct OSX scaling issue and move the 0,0 coordinate to left bottom.
"""
function corrected_coordinates(
        window_size::NTuple{2,Int},
        framebuffer_width::NTuple{2,Int},
        mouse_position::NTuple{2,Float64}
    )
    s = scaling_factor(window_size, framebuffer_width)
    (mouse_position[1], window_size.value[2] - mouse_position[2]) .* s
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