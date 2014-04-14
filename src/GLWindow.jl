module GLWindow
using ModernGL, GLUT, GLUtil, Events



include("glutEvents.jl")

global RENDER_LIST = GLRenderObject[]

function displayFunc()
    glClearColor(1f0, 1f0, 1f0, 1f0)   
    glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT)

    for elem in RENDER_LIST
       render(elem)
    end
    glutSwapBuffers()
    return nothing
end

glDisplay(x::GLRenderObject) = push!(RENDER_LIST, x)
export glDisplay


function closeFunc()
    println("bye...!")
    for elem in RENDER_LIST
       delete!(elem)
    end
    return nothing
end

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


function createWindow(;
    name = "GLUT Window", 
    displayMode         = convert(Cint, (GLUT_DEPTH | GLUT_DOUBLE | GLUT_RGBA | GLUT_MULTISAMPLE | GLUT_ALPHA)), 
    windowPosition      = convert(Array{Cint,1}, [0,0]), 
    windowSize          = convert(Array{Cint,1}, [1000,1000]),
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

    (keyboardUpF | specialUpF) && glutSetKeyRepeat(GLUT_KEY_REPEAT_OFF)
    window
end

export createWindow
end
