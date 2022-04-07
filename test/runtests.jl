module TestingLibFLI

using Test, LibFLI

using LibFLI: FLIException

@testset "General functions" begin
    @test LibFLI.get_lib_version() isa String
    @test LibFLI.set_debug_level("dummy", :none) isa Nothing
    @test_throws FLIException LibFLI.Device("dummy")
    @test FLI.list_devices(:serial, :camera) isa Nothing

    @test FLI.decode_domain(0) === (:none, :none)
    @test FLI.decode_domain(FLI.Lib.FLIDOMAIN_SERIAL) === (:serial, :none)
    @test FLI.decode_domain(FLI.Lib.FLIDOMAIN_USB |
                            FLI.Lib.FLIDEVICE_CAMERA) === (:usb, :camera)

    @test FLI.encode_domain() == 0
    @test FLI.encode_domain(()) == 0
    @test FLI.encode_domain(:none) == 0
    @test FLI.encode_domain(:none, :none) == 0
    @test FLI.encode_domain(:serial) == FLI.Lib.FLIDOMAIN_SERIAL
    @test FLI.encode_domain((:parallel_port,)) == FLI.Lib.FLIDOMAIN_PARALLEL_PORT
    @test FLI.encode_domain(:camera) == FLI.Lib.FLIDEVICE_CAMERA
    @test FLI.encode_domain((:filterwheel,)) == FLI.Lib.FLIDEVICE_FILTERWHEEL
    @test FLI.encode_domain(:usb, :focuser) == (FLI.Lib.FLIDOMAIN_USB |
                                                FLI.Lib.FLIDEVICE_FOCUSER)
    @test FLI.encode_domain(:focuser, :usb) == (FLI.Lib.FLIDOMAIN_USB |
                                                FLI.Lib.FLIDEVICE_FOCUSER)
    @test FLI.encode_domain((:focuser, :inet)) == (FLI.Lib.FLIDOMAIN_INET |
                                                   FLI.Lib.FLIDEVICE_FOCUSER)
    @test FLI.encode_domain((:inet, :focuser)) == (FLI.Lib.FLIDOMAIN_INET |
                                                   FLI.Lib.FLIDEVICE_FOCUSER)
end

end # module

nothing
