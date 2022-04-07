# highlevel.jl -
#
# Higher level interface to FLI C library.  This part provides methods not
# available fro the library.
#

"""
    FLI.print_camera_info([io=stdout,] cam)

prints detailed information to output stream `io` about camera `cam`.

Keywords `pfx1` and `pfx2` can be used to customize the output.

"""
print_camera_info(cam::Device; kwds...) =
    print_camera_info(stdout, cam; kwds...)

function print_camera_info(io::IO, cam::Device; pfx1 = " ├─ ", pfx2 = " └─ ")
    print(io, pfx1, "Device Model: \"", get_model(cam), "\"\n")
    print(io, pfx1, "Serial Number: \"", get_serial_string(cam), "\"\n")
    print(io, pfx1, "Hardware Revision: ", get_hardware_revision(cam), "\n")
    print(io, pfx1, "Firmware Revision: ", get_firmware_revision(cam), "\n")
    print(io, pfx1, "Library Version: \"", get_lib_version(), "\"\n")
    x0, y0, x1, y1 = get_array_area(cam)
    print(io, pfx1, "Detector Area: ", x1 - x0, " × ", y1 - y0, " pixels, [",
          x0, ":", x1 - 1, "] × [", y0, ":", y1 - 1, "]\n")
    x0, y0, x1, y1 = get_visible_area(cam)
    print(io, pfx1, "Visible Area: ", x1 - x0, " × ", y1 - y0, " pixels, [",
          x0, ":", x1 - 1, "] × [", y0, ":", y1 - 1, "]\n")
    width, x0, xbin, height, y0, ybin = get_readout_dimensions(cam)
    print(io, pfx1, "Image Area: $width × $height pixels at ",
          "offsets ($x0,$y0) and with $xbin×$ybin binning\n")
    xsize, ysize = get_pixel_size(cam)
    print(io, pfx1, "Pixel Size: $(1e6*xsize) µm × $(1e6*ysize) µm\n")
    print(io, pfx2, "Temperature: $(get_temperature(cam))°C\n")
end

"""
    FLI.foreach_device(f, args...)

calls function `f` for each FLI device matching interfaces and/or device types
listed in `args...` which are symbolic names as the ones accepted by the
keywords of the [`FLI.Device`](@ref) constructor.   The function
is called as:

    f(domain, filename, devname)

with `domain` an integer specifying the interface and device type, `filename`
the associated file name, and `devname` the name of the device.

For instance to list all USB connected cameras:

    function walker(domain, filename, devname)
        dev = FLI.Device(filename, domain)
        println("File: \"\$filename\", name: \"\$devname\", domain: \$domain")
        FLI.print_camera_info(dev)
        close(dev)
    end
    FLI.foreach_device(walker, :usb, :camera)

Thanks to the do-block syntax of Julia, it is possible to do the same thing
more directly (without defining an auxiliary `walker` function):

    FLI.foreach_device(:usb, :camera) do domain, filename, devname
        dev = FLI.Device(filename, domain)
        println("File: \"\$filename\", name: \"\$devname\", domain: \$domain")
        FLI.print_camera_info(dev)
        close(dev)
    end

"""
function foreach_device(f::Function, args::Symbol...)
    bits = encode_domain(args...)
    @check FLICreateList(bits)
    try
        len = 260
        domr = Ref{Lib.flidomain_t}()
        buf1 = Array{UInt8}(undef, len)
        buf2 = Array{UInt8}(undef, len)
        status = Lib.FLIListFirst(domr, buf1, len, buf2, len)
        while status.code == 0
            domain = domr[]
            filename = unsafe_string(pointer(buf1))
            devname = unsafe_string(pointer(buf2))
            f(domain, filename, devname)
            status = Lib.FLIListNext(domr, buf1, len, buf2, len)
        end
    finally
        @check FLIDeleteList()
    end
end

"""
    FLI.list_devices([io::stdout,] args::Symbol...)

lists connected FLI devices whose interface and/or device type match `args...`.

For example:

    FLI.list_devices(:usb, :camera) # list connected USB cameras
    FLI.list_devices(:serial)       # list devices connected to the serial port

"""
list_devices(args::Symbol...) = list_devices(stdout, args...)
function list_devices(io::IO, args::Symbol...)
    foreach_device(args...) do domain, filename, devname
        print(io, "File: \"$filename\", name: \"$devname\", domain: ",
              (domain % UInt16), " ", decode_domain(domain))
        if (domain & Lib.FLIDEVICE_CAMERA) != 0
            dev = Device(filename, domain)
            FLI.print_camera_info(io, dev)
            close(dev)
        end
    end
end

"""
    FLI.configure_camera(cam; key=val, ...)

configures camera `cam` with settings specified by any of the following
keywords:

- `temperature` to specify the target temperature (in °C);

- `exposuretime` to specify the exposure time (in seconds);

- `width` to specify the width of the image area (in macro-pixels);

- `height` to specify the height of the image area (in macro-pixels);

- `xoff` to specify the horizontal offset of the image area (in pixels);

- `yoff` to specify the vertical offset of the image area (in pixels);

- `xbin` to specify the horizontal binning factor (in pixels);

- `ybin` to specify the vertical binning factor (in pixels);

- `frametype` to specify the frame type;

- `nflushes` to specify the number of background flushes;

- `bgflush` to specify whether to start or stop background flushing;

- `pixeltype` to specify the pixel type;

- `fanspeed` to specify whether to switch on or off the fan;

- `shutter` to control the shutter;

"""
function configure_camera(cam::Device;
                          temperature::Union{Nothing,Real} = nothing,
                          exposuretime::Union{Nothing,Real} = nothing,
                          width::Union{Nothing,Integer} = nothing,
                          height::Union{Nothing,Integer} = nothing,
                          xoff::Union{Nothing,Integer} = nothing,
                          yoff::Union{Nothing,Integer} = nothing,
                          xbin::Union{Nothing,Integer} = nothing,
                          ybin::Union{Nothing,Integer} = nothing,
                          frametype::Union{Nothing,Symbol,Integer} = nothing,
                          nflushes::Union{Nothing,Integer} = nothing,
                          bgflush::Union{Nothing,Symbol,Integer} = nothing,
                          pixeltype = nothing,
                          fanspeed = nothing,
                          shutter = nothing)
    # Auxiliary function to get a possibly new option value preserving the
    # type.
    getopt(newval, oldval) =
        (newval === nothing ? oldval : oftype(oldval, newval))

    temperature === nothing || set_temperature(cam, temperature)
    exposuretime === nothing || set_exposure_time(cam, exposuretime)
    if (width !== nothing || height !== nothing || xoff !== nothing ||
        yoff !== nothing || xbin !== nothing || ybin !== nothing)
        # Some ROI parameters have been specified.
        cur_width, cur_xoff, cur_xbin, cur_height, cur_yoff, cur_ybin =
            get_readout_dimensions(cam)
        new_width  = getopt(width,  cur_width)
        new_height = getopt(height, cur_height)
        new_xoff   = getopt(xoff,   cur_xoff)
        new_yoff   = getopt(yoff,   cur_yoff)
        new_xbin   = getopt(xbin,   cur_xbin)
        new_ybin   = getopt(ybin,   cur_ybin)
        new_xbin != cur_xbin && @check FLISetHBin(cam.dev, new_xbin)
        new_ybin != cur_ybin && @check FLISetVBin(cam.dev, new_ybin)
        if (new_width != cur_width || new_height != cur_height ||
            new_xoff != cur_xoff ||  new_yoff != cur_yoff)
            x0 = new_xoff
            y0 = new_yoff
            x1 = x0 + new_width
            y1 = y0 + new_height
            set_image_area(cam, x0, y0, x1, y1)
        end
    end
    frametype === nothing || set_frame_type(cam, frametype)
    nflushes === nothing || set_nflushes(cam, nflushes)
    bgflush === nothing || control_background_flush(cam, bgflush)
    pixeltype === nothing || set_bit_depth(cam, pixeltype)
    fanspeed === nothing || set_fan_speed(cam, fanspeed)
    shutter === nothing || control_shutter(cam, shutter)
    nothing
end
