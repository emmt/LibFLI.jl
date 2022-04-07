module LibFLI

export FLI, FLIException

const FLI = LibFLI

include("libcalls.jl")
include("basics.jl")
include("highlevel.jl")

end # module
