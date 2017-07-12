function is_ci()
    get(ENV, "TRAVIS", "") == "true" ||
    get(ENV, "APPVEYOR", "") == "true" ||
    get(ENV, "CI", "") == "true"
end
if is_ci()
    cd(Pkg.dir("GLAbstraction")) do
        run(`git fetch origin`)
        run(`git checkout master`)
    end
end

using GLWindow
using Base.Test



if !is_ci() # only do test if not CI... this is for automated testing environments which fail for OpenGL stuff, but I'd like to test if at least including works

GLFW.Init()
window = Screen("test", resolution=(500,500))

swapbuffers(window)

poll_glfw()

end
println("success")
