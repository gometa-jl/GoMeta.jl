# load_basic_renderer.jl — THE ONE PATH by which the basic renderer (a development tool; R-V04B-13/-24)
# is loaded. Include this file at the consumer's TOP LEVEL — never inside a function — before any code
# that calls Main.BasicRenderer.outputs is compiled (Julia's world age: a method defined while a function
# is already running is invisible to that function). `Base.include(Main, …)` — never a bare `include` —
# so the module lands in Main whatever module reaches this loader; every consumer spells the call
# `Main.BasicRenderer.outputs` (inside a module it is the ONLY spelling that resolves). A second include
# through this file is a no-op; a load through ANY other path trips the sentinel inside basic_renderer.jl.
if !isdefined(Main, :BasicRenderer)
    Base.include(Main, joinpath(@__DIR__, "basic_renderer.jl"))
end
