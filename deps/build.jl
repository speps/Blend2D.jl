using BinDeps, Compat, CMake
import BinDeps:satisfy!
import BinDeps:_find_library
import BinDeps:bindir

@BinDeps.setup

source_url = "https://blend2d.com/download/blend2d-beta5.zip"
source_dir = "blend2d"
# source_url = "https://github.com/blend2d/blend2d/archive/master.zip"
# source_dir = "blend2d-master"

# aliases also mean output file names that are checked
config = "RelWithDebInfo"
if Compat.Sys.iswindows()
    liboutput = "blend2d.dll"
elseif Compat.Sys.islinux()
    liboutput = "blend2d.so"
elseif Compat.Sys.isapple()
    liboutput = "blend2d.dylib"
else
    error("Unsupported system of $(Sys.ARCH)")
end
blend2d = library_dependency("libblend2d", aliases=[liboutput])
srcdir = joinpath(BinDeps.srcdir(blend2d), source_dir)
libdir = joinpath(BinDeps.builddir(blend2d), blend2d.name)
libpath = joinpath(libdir, config, liboutput)
cmake_args = []
if Sys.ARCH == :i686
	push!(cmake_args, "-DCMAKE_GENERATOR_PLATFORM=x86")
elseif Sys.ARCH == :x86_64
	push!(cmake_args, "-DCMAKE_GENERATOR_PLATFORM=x64")
else
	error("Unsupported Sys.ARCH of $(Sys.ARCH)")
end
provides(Sources, URI(source_url), blend2d, unpacked_dir=source_dir)

bindir(::BuildProcess, dep::BinDeps.LibraryDependency) = joinpath(BinDeps.builddir(dep), dep.name, config)

provides(BuildProcess, (@build_steps begin
    GetSources(blend2d)
    CreateDirectory(libdir)
    @build_steps begin
        ChangeDirectory(libdir)
        FileRule(libpath, @build_steps begin
            `$(CMake.cmake) $(join(cmake_args, " ")) $srcdir`
            `$(CMake.cmake) --build . --config $config`
        end)
    end
end), blend2d)

# call directly because the defaults on windows don't include BuildProcess
p = BinDeps.satisfy!(blend2d, [BuildProcess])
libs = BinDeps._find_library(blend2d; provider = p)

# generate "deps.jl" file for runtime loading
depsfile_location = joinpath(splitdir(Base.source_path())[1],"deps.jl")
depsfile_buffer = IOBuffer()
println(depsfile_buffer,
    """
    # This is an auto-generated file; do not edit and do not check-in to version control
    """)
println(depsfile_buffer,
    """
    using Libdl
    # Macro to load a library
    macro checked_lib(libname, path)
        if Libdl.dlopen_e(path) == C_NULL
            error("Unable to load \\n\\n\$libname (\$path)\\n\\nPlease ",
                  "re-run Pkg.build(package), and restart Julia.")
        end
        quote
            const \$(esc(libname)) = \$path
        end
    end
    """)
println(depsfile_buffer, "# Load dependencies")
for (provider, path) in libs
    println(depsfile_buffer, "@checked_lib ", blend2d.name, " \"", escape_string(path), "\"")
end
depsfile_content = chomp(String(take!(depsfile_buffer)))
if !isfile(depsfile_location) || readchomp(depsfile_location) != depsfile_content
    # only overwrite if deps.jl file does not yet exist or content has changed
    open(depsfile_location, "w") do depsfile
        println(depsfile, depsfile_content)
    end
end

include("bindings.jl")
