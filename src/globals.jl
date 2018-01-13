
using Base.RefValue
#This should be put in some kind of globals.jl file, like where the contexts are being counted.
const screen_id_counter = RefValue(0)
# start from new and hope we don't display all displays at once.
# TODO make it clearer if we reached max num, or if we just created
# a lot of small screens and display them simultanously
new_id() = (screen_id_counter[] = mod1(screen_id_counter[] + 1, 255); screen_id_counter[])[]