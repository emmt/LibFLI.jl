module Build

const destfile = joinpath(@__DIR__, "deps.jl")

if isfile(destfile)
    try
        include(destfile)
    catch
    end
end

function install()
    if isfile(destfile) && isdefined(@__MODULE__, :libfli) &&
        isa(libfli, AbstractString) && isfile(libfli)
        oldname = libfli
    else
        oldname = ""
    end
    libname = oldname
    while true
        if length(libname) < 1 || !isfile(libname)
            libname = "libfli.so"
        end
        print(stdout, "Where is the shared FLI library? [$libname] ")
        flush(stdout)
        str = strip(readline(stdin))
        if length(str) > 0
            libname = str
        end
        if isfile(libname)
            break
        end
    end
    if libname != oldname
        open(destfile, "w") do io
            println(io, "const libfli = \"", libname, "\"")
        end
        println(stderr, "File \"$destfile\" has been created.")
    else
        println(stderr, "File \"$destfile\" has been left unchanged.")
    end
end

end # module

Build.install()
nothing
