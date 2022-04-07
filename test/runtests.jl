module TestingLibFLI

using Test, LibFLI

using LibFLI: FLIException

@testset "General functions" begin
    @test LibFLI.get_lib_version() isa String
    @test LibFLI.set_debug_level("dummy", :none) isa Nothing
    @test_throws FLIException LibFLI.Device("dummy")
    @test FLI.list_devices(:serial, :camera) isa Nothing
end

end # module

nothing
