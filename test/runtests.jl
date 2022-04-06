module TestingLibFLI

using Test, LibFLI

using LibFLI: FLIException

@testset "General functions" begin
    @test isa(LibFLI.get_lib_version(), String)
    @test isa(LibFLI.set_debug_level("dummy", :none), Nothing)
    @test_throws FLIException LibFLI.Device("dummy")
    @test FLI.list_devices(:serial, :camera)
end

end # module

nothing
