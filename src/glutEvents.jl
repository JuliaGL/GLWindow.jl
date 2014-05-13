
#push events from glut to our event queue
function keyboardFunc(key::Cuchar, x::Cint, y::Cint) 
    publishEvent(KeyDown{0}(false, char(key), x, WINDOW_SIZE[2] - y))
    return nothing
end

function keyboardUpFunc(key::Cuchar, x::Cint, y::Cint) 
    publishEvent(KeyUp{0}(false, char(key), x, WINDOW_SIZE[2] - y))
    return nothing
end


function specialFunc(key::Cint, x::Cint, y::Cint)                 
    publishEvent(KeyDown{0}(true, char(key), x, WINDOW_SIZE[2] - y))
    return nothing
end

function specialUpFunc(key::Cint, x::Cint, y::Cint)
    publishEvent(KeyUp{0}(true, char(key), x, WINDOW_SIZE[2] - y))
    return nothing
end


function mouseFunc(button::Cint, status::Cint, x::Cint, y::Cint) 
    global lastClick = MouseClicked{0}(int(button), int(status), int(x), WINDOW_SIZE[2] - int(y))
    publishEvent(lastClick)
    return nothing
end
function motionFunc(x::Cint, y::Cint)
    publishEvent(MouseDragged{0}(lastClick, int(x), WINDOW_SIZE[2] - int(y)))
    return nothing
end

function passiveMotionFunc(x::Cint, y::Cint) 
    publishEvent(MouseMoved{0}(int(x), WINDOW_SIZE[2] - int(y)))
    return nothing
end

function entryFunc(state::Cint)                                    
    publishEvent(EnteredWindow{0}(bool(state), glutGetWindow()))
    return nothing
end

const WINDOW_SIZE = [0,0]

function reshapeFunc(w::Csize_t, h::Csize_t)
    WINDOW_SIZE[1] = int(w)
    WINDOW_SIZE[2] = int(h)
    glViewport(0, 0, w, h)
    publishEvent(WindowResized{0}(int(w),int(h)))
    return nothing
end
#KeyDownMouseClicked Event generation 		##############################################################################

global currentMouseClicked 	= Dict{Int, (Int, Int)}()
global currentKeyDown 		= Dict{Int, Bool}()

function fillCurrentMouseClicked(event)
	if event.status == 0
		currentMouseClicked[int(event.key)] = (int(event.x), int(event.y))
		if ~isempty(currentKeyDown)
			publishEvent(KeyDownMouseClicked(deepcopy(currentMouseClicked), deepcopy(currentKeyDown), int(event.x), int(event.y)))
		end
	else
		pop!(currentMouseClicked, int(event.key), ())
	end
end
function fillCurrentKeyDown(event, status::Int)
	if status == 1
		currentKeyDown[int(event.key)] = event.special
		if ~isempty(currentMouseClicked)
			publishEvent(KeyDownMouseClicked(deepcopy(currentMouseClicked), deepcopy(currentKeyDown), int(event.x), int(event.y)))
		end
	else
		pop!(currentKeyDown, int(event.key), ())
	end
end
registerEventAction(EventAction{KeyDown}		(x-> true, (), fillCurrentKeyDown, (1,)))
registerEventAction(EventAction{KeyUp}			(x-> true, (), fillCurrentKeyDown, (0,)))
registerEventAction(EventAction{MouseClicked} 	(x-> true, (), fillCurrentMouseClicked, ()))


left_click_down(event::MouseClicked) = event.key == 0 && event.status == 0

middle_click_down_inside(event::MouseDragged, rect) = event.start.key == 1 && event.start.status == 0 && inside(rect, event.start.x, event.start.y)
right_click_down_inside(event::MouseDragged, rect) = event.start.key == 2 && event.start.status == 0 && inside(rect, event.start.x, event.start.y)

left_click_up(event::MouseClicked) = event.key == 0 && event.status == 1

export left_click_up, right_click_down_inside, middle_click_down_inside, left_click_down