
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


#Cfunction pointer for glut
_entryFunc          = cfunction(entryFunc, Void, (Cint,))
_motionFunc         = cfunction(motionFunc, Void, (Cint, Cint))
_passiveMotionFunc  = cfunction(passiveMotionFunc, Void, (Cint, Cint))
_mouseFunc          = cfunction(mouseFunc, Void, (Cint, Cint, Cint, Cint))
_specialFunc        = cfunction(specialFunc, Void, (Cint, Cint, Cint))
_specialUpFunc      = cfunction(specialUpFunc, Void, (Cint, Cint, Cint))
_keyboardFunc       = cfunction(keyboardFunc, Void, (Cuchar, Cint, Cint))
_keyboardUpFunc     = cfunction(keyboardUpFunc, Void, (Cuchar, Cint, Cint))
_reshapeFunc        = cfunction(reshapeFunc, Void, (Csize_t, Csize_t))
_displayFunc        = cfunction(displayFunc, Void, ())
_closeFunc          = cfunction(closeFunc, Void, ())


function displayFunc()
    glClearColor(1f0, 1f0, 1f0, 1f0)   
    glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT)
    for elem in RENDER_LIST
       render(elem)
    end
    for elem in RENDER_DICT
       render(elem[2]...)
    end
    
    glutSwapBuffers()
    return nothing
end

function createWindow(;
    name = "GLUT Window", 
    displayMode         = convert(Cint, (GLUT_DEPTH | GLUT_DOUBLE | GLUT_RGBA | GLUT_MULTISAMPLE | GLUT_ALPHA | GLUT_STENCIL)), 
    windowPosition      = Cint[0,0], 
    windowSize          = Cint[1000,1000],
    displayF=true, idleF=true, reshapeF=true, 
    entryF=true, keyboardF=true, specialF=true,
    keyboardUpF=true, specialUpF=true, mouseF=true, 
    motionF=true, passiveMotionF=true)

    glutInit()
    glutInitDisplayMode(displayMode)
    glutInitWindowPosition(windowPosition...)
    glutInitWindowSize(windowSize...)
    window = glutCreateWindow(name)

    initGLUtils()


    displayF         && glutDisplayFunc       (_displayFunc) 
    idleF            && glutIdleFunc          (_displayFunc)
    reshapeF         && glutReshapeFunc       (_reshapeFunc)
    keyboardF        && glutKeyboardFunc      (_keyboardFunc)
    specialF         && glutSpecialFunc       (_specialFunc)
    keyboardUpF      && glutKeyboardUpFunc    (_keyboardUpFunc)
    specialUpF       && glutSpecialUpFunc     (_specialUpFunc)
    mouseF           && glutMouseFunc         (_mouseFunc)
    motionF          && glutMotionFunc        (_motionFunc)
    passiveMotionF   && glutPassiveMotionFunc (_passiveMotionFunc)
    entryF           && glutEntryFunc         (_entryFunc)
    glutCloseFunc(_closeFunc)

    #(keyboardUpF | specialUpF) && glutSetKeyRepeat(GLUT_KEY_REPEAT_OFF)
    window
end

export left_click_up, right_click_down_inside, middle_click_down_inside, left_click_down