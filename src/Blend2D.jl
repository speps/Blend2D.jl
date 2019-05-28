module Blend2D

using Libdl

depsfile = joinpath(dirname(@__DIR__), "deps", "deps.jl")
if isfile(depsfile)
    include(depsfile)
else
    error("Package \"Blend2D\" is not properly installed (missing deps/deps.jl). Please run Pkg.build(\"Blend2D\") first.")
end

include("gen/enums.jl")
include("gen/structs.jl")

mutable struct BLMatrix2D
    m00::Cdouble
    m01::Cdouble
    m10::Cdouble
    m11::Cdouble
    m20::Cdouble
    m21::Cdouble
    BLMatrix2D() = new(0, 0, 0, 0, 0, 0)
end

include("gen/funcs.jl")

function blImageCodecBuiltInCodecs()
    ptr = ccall((:blImageCodecBuiltInCodecs, libblend2d), Ptr{BLArrayCore}, ())
    ret = BLArrayCore()
    blArrayInit(ret, Cuint(0))
    ccall((:blArrayAssignWeak, libblend2d), Cuint, (Ref{BLArrayCore}, Ptr{BLArrayCore}), ret, ptr)
    return ret
end

include("gen/export.jl")

function __init__()
    if Libdl.dlopen(libblend2d, throw_error=false) in (C_NULL, nothing)
        error("$(libblend2d) cannot be opened, Please re-run Pkg.build(\"Blend2D\"), and restart Julia.")
    end
end

end # module Blend2D