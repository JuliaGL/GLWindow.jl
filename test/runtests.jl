using GLWindow
using Base.Test  

# write your own tests here
@test createWindow() == 1

println("    \033[32;1mSUCCESS\033[0m")
