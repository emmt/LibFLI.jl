# basics.jl -
#
# Basic interface to FLI C library.  This part attempts to provide all the
# functions of the library with not too much enhancements.
#

# FLI cameras are either 8 or 16 bits.
const PixelType = Union{UInt8,UInt16}

"""
    FLIException(func, code)

yields a exception representing an error `code` returned by function `func` of
the LibFLI C library.

"""
struct FLIException <: Exception
    func::Symbol
    code::Clong
end

function Base.showerror(io::IO, ex::FLIException)
    print(io, "FLIException(", ex.code, "): ",
          Libc.strerror(-ex.code), " in `", ex.func, "`")
end

"""
    FLI.check(func, status)

checks the status returned by function `func` of the LibFLI C library and
throws a `FLIException` exception in case of error.

"""
function check(func::Symbol, status::Lib.Status)
    status.code < 0 && throw(FLIException(func, status.code))
    nothing
end

"""
    FLI.@check FLIFunc(args...)

calls the function `FLIFunc` of the LibFLI SDK and check its status.

"""
macro check(ex::Expr)
    ex.head === :call || error("expecting a function call")
    startswith(String(ex.args[1]), "FLI") || error(
        "called function must be a function of the LibFLI SDK")
    func = QuoteNode(ex.args[1])
    return Expr(:call, :check, func,
                Expr(:call, Expr(:(.), :Lib, func),
                     map(esc, ex.args[2:end])...))
end

mutable struct Device
    dev::Lib.flidev_t  # device handle
    buf::Vector{UInt8} # buffer to avoid segmentation fault
    Device() = new(Lib.FLI_INVALID_DEVICE, UInt8[])
end

"""
    FLI.Device(name, args...) -> obj

opens FLI device `name` for the interface and device type specified in
subsequent arguments which can be:

- Symbolic names (or a tuple of symbolic names) specifying an interface
  (`:none`, `:parallel_port`, `:usb`, `:serial`, `:inet`, `:serial_19200`, or
  `:serial_1200`) and a device type (`:none`, `:camera`, `:filterwheel`,
  `:focuser`, `:hs_filterwheel`, `:raw`, or `:enumerate_by_interface`).

- An integer consisting in a bitwise combination of an interface and a device
  type.

By default, the device is assumed to be an USB connected camera.

Method `close(obj)` can be called to eventually close the device but this is
not mandatory as the returned object is automatically closed when it is
reclaimed by garbage collector.

Examples:

    dev = FLI.Device("/dev/fliusb0", :serial, :focuser)
    cam = FLI.Device("/dev/fliusb0", :usb, :camera)

See also [`FLI.foreach_device`](@ref) and [`FLI.list_devices`](@ref) for
listing available devices.

"""
Device(name::AbstractString) = Device(name, :usb, :camera)
Device(name::AbstractString, syms::Symbol...) =  Device(name, syms)
Device(name::AbstractString, syms::Tuple{Vararg{Symbol}}) =
    Device(name, encode_domain(syms))
function Device(name::AbstractString, domain::Integer)
    dev = Ref{Lib.flidev_t}(Lib.FLI_INVALID_DEVICE)
    @check FLIOpen(dev, name, domain)
    obj = Device()
    obj.dev = dev[]
    finalizer(_finalize, obj)
    return obj
end

# Close device when object is garbage collected but do not throw errors.
_finalize(obj::Device) = close(obj; throwerrors=false)

function Base.close(obj::Device; throwerrors::Bool = true)
    dev = obj.dev
    if dev != Lib.FLI_INVALID_DEVICE
        obj.dev = Lib.FLI_INVALID_DEVICE
        status = Lib.FLIClose(dev)
        if throwerrors && status.code < 0
            throw(FLIException(:FLIClose, status.code))
        end
    end
end

"""
    FLI.encode_interface_domain(sym) -> bits

yields the unsigned integer corresponding to the symbolic name `sym` of an
interface.

"""
encode_interface_domain(sym::Symbol) = (
    sym === :none          ? Lib.FLIDOMAIN_NONE :
    sym === :parallel_port ? Lib.FLIDOMAIN_PARALLEL_PORT :
    sym === :usb           ? Lib.FLIDOMAIN_USB :
    sym === :serial        ? Lib.FLIDOMAIN_SERIAL :
    sym === :inet          ? Lib.FLIDOMAIN_INET :
    sym === :serial_19200  ? Lib.FLIDOMAIN_SERIAL_19200 :
    sym === :serial_1200   ? Lib.FLIDOMAIN_SERIAL_1200 :
    error("unknown interface `:", sym, "`"))

"""
    FLI.decode_interface_domain(domain) -> sym

yields the symbolic name of the interface indicated in `domain`.

"""
function decode_interface_domain(domain::Integer)
    bits = (domain & 0x00ff) % UInt16
    return (
        bits == Lib.FLIDOMAIN_NONE          ? :none :
        bits == Lib.FLIDOMAIN_PARALLEL_PORT ? :parallel_port :
        bits == Lib.FLIDOMAIN_USB           ? :usb :
        bits == Lib.FLIDOMAIN_SERIAL        ? :serial :
        bits == Lib.FLIDOMAIN_INET          ? :inet :
        bits == Lib.FLIDOMAIN_SERIAL_19200  ? :serial_19200 :
        bits == Lib.FLIDOMAIN_SERIAL_1200   ? :serial_1200 :
        error("invalid interface bits ", bits))
end

"""
    FLI.encode_device_domain(sym) -> bits

yields the unsigned integer corresponding to the symbolic name `sym` of a
device type.

"""
encode_device_domain(sym::Symbol) = (
    sym === :none                    ? Lib.FLIDEVICE_NONE :
    sym === :camera                  ? Lib.FLIDEVICE_CAMERA :
    sym === :filterwheel             ? Lib.FLIDEVICE_FILTERWHEEL :
    sym === :focuser                 ? Lib.FLIDEVICE_FOCUSER :
    sym === :hs_filterwheel          ? Lib.FLIDEVICE_HS_FILTERWHEEL :
    sym === :raw                     ? Lib.FLIDEVICE_RAW :
    sym === :enumerate_by_connection ? Lib.FLIDEVICE_ENUMERATE_BY_CONNECTION :
    error("unknown device type `:", sym, "`"))

"""
    FLI.decode_device_domain(domain) -> sym

yields the symbolic name of the device type indicated in `domain`.

"""
function decode_device_domain(domain::Integer)
    bits = (domain & 0xff00) % UInt16
    return (
        bits == Lib.FLIDEVICE_NONE                    ? :none :
        bits == Lib.FLIDEVICE_CAMERA                  ? :camera :
        bits == Lib.FLIDEVICE_FILTERWHEEL             ? :filterwheel :
        bits == Lib.FLIDEVICE_FOCUSER                 ? :focuser :
        bits == Lib.FLIDEVICE_HS_FILTERWHEEL          ? :hs_filterwheel :
        bits == Lib.FLIDEVICE_RAW                     ? :raw :
        bits == Lib.FLIDEVICE_ENUMERATE_BY_CONNECTION ? :enumerate_by_connection :
        error("invalid device type bits ", bits))
end

Lib.FLIDOMAIN_NONE == 0 || throw(AssertionError("Lib.FLIDOMAIN_NONE != 0"))
Lib.FLIDEVICE_NONE == 0 || throw(AssertionError("Lib.FLIDEVICE_NONE != 0"))

"""
    FLI.encode_domain(sym) -> bits

yields the unsigned integer corresponding to the symbolic name `sym` of an
interface or of a device type.

Argument(s) can also be 0, 1 or 2 symbols (or a tuple of 0, 1 or 2 symbols)
specifying the interface and device type to yield a bitwise combination of
interface and device type.

"""
encode_domain(sym::Symbol) = (
    sym === :none                    ? Lib.FLIDOMAIN_NONE :
    sym === :parallel_port           ? Lib.FLIDOMAIN_PARALLEL_PORT :
    sym === :usb                     ? Lib.FLIDOMAIN_USB :
    sym === :serial                  ? Lib.FLIDOMAIN_SERIAL :
    sym === :inet                    ? Lib.FLIDOMAIN_INET :
    sym === :serial_19200            ? Lib.FLIDOMAIN_SERIAL_19200 :
    sym === :serial_1200             ? Lib.FLIDOMAIN_SERIAL_1200 :
    sym === :camera                  ? Lib.FLIDEVICE_CAMERA :
    sym === :filterwheel             ? Lib.FLIDEVICE_FILTERWHEEL :
    sym === :focuser                 ? Lib.FLIDEVICE_FOCUSER :
    sym === :hs_filterwheel          ? Lib.FLIDEVICE_HS_FILTERWHEEL :
    sym === :raw                     ? Lib.FLIDEVICE_RAW :
    sym === :enumerate_by_connection ? Lib.FLIDEVICE_ENUMERATE_BY_CONNECTION :
    error("unknown interface or device type `:", sym, "`"))

function encode_domain(sym1::Symbol, sym2::Symbol)
    bits = (encode_domain(sym1) % UInt16)
    if (bits & 0x00ff) != 0
        # Fist argument was interface.
        bits |= (encode_device_domain(sym2) % UInt16)
    elseif (bits & 0xff00) != 0
        # Fist argument was device type.
        bits |= (encode_interface_domain(sym2) % UInt16)
    else
        bits |= (encode_domain(sym2) % UInt16)
    end
    return bits
end

encode_domain() = zero(UInt16)

encode_domain(sym::Union{Tuple{},Tuple{Symbol},Tuple{Symbol,Symbol}}) =
    encode_domain(sym...)

"""
    FLI.decode_domain(bits) -> (int, dev)

decodes the interface and device type indicated in `bits`.  The result is a
2-tuple of symbols: `int` is the interface and `dev` is the device type.

"""
decode_domain(bits::Integer) = (decode_interface_domain(bits),
                                decode_device_domain(bits))

"""
    FLI.get_lib_version() -> str

yields the version of the FLI C library.

"""
function get_lib_version()
    buf = Array{UInt8}(undef, 256)
    @check FLIGetLibVersion(buf, length(buf))
    return unsafe_string(pointer(buf))
end

"""
    FLI.set_debug_level(host, level)

enables debugging of API operations and communications.  Use this function in
combination with `FLIDebug` to assist in diagnosing problems that may be
encountered during programming.

When usings Microsoft Windows operating systems, creating an empty file
`C:/FLIDBG.TXT` will override this option. All debug output will then be
directed to this file.

Argument `host` is the name of the file to send debugging information to.  This
parameter is ignored under Linux where `syslog(3)` is used to send debug
messages (see `syslog.conf(5)` for how to configure `syslogd`).

Argument `level` specifies the debug level.  Possible values are: `:none` to
disable, `:fail`, `:warn`, `:info`, `:io`, and `:all` to enable progressively
more verbose debug messages.

"""
set_debug_level(host::AbstractString, level::Symbol) =
    @check FLISetDebugLevel(host, encode_debug_level(level))

encode_debug_level(sym::Symbol) = (
    sym === :none ? Lib.FLIDEBUG_NONE :
    sym === :fail ? Lib.FLIDEBUG_FAIL :
    sym === :warn ? Lib.FLIDEBUG_WARN :
    sym === :info ? Lib.FLIDEBUG_INFO :
    sym === :io   ? Lib.FLIDEBUG_IO   :
    sym === :all  ? Lib.FLIDEBUG_ALL  :
    error("unknown debug level"))

function get_model(obj::Device)
    buf = Array{UInt8}(undef, 256)
    @check FLIGetModel(obj.dev, buf, length(buf))
    return unsafe_string(pointer(buf))
end

"""
    FLI.get_pixel_size(cam) -> (xsiz, ysiz)

yields the pixel size (in meters) of the camera `cam`.

"""
function get_pixel_size(cam::Device)
    xsiz = Ref{Cdouble}()
    ysiz = Ref{Cdouble}()
    @check FLIGetPixelSize(cam.dev, xsiz, ysiz)
    return (xsiz[], ysiz[])
end

function get_hardware_revision(obj::Device)
    rev = Ref{Clong}()
    @check FLIGetHWRevision(obj.dev, rev)
    return rev[]
end

function get_firmware_revision(obj::Device)
    rev = Ref{Clong}()
    @check FLIGetFWRevision(obj.dev, rev)
    return rev[]
end

"""
    FLI.get_array_area(cam) -> (x0, y0, x1, y1)

yields the area of the sensor array of camera `cam`.  Coordinates `(x0,y0)` and
`(x1,y1)` respectively define the upper-left and lower-right corner of the
sensor array.

"""
function get_array_area(cam::Device)
    x0 = Ref{Clong}()
    y0 = Ref{Clong}()
    x1 = Ref{Clong}()
    y1 = Ref{Clong}()
    @check FLIGetArrayArea(cam.dev, x0, y0, x1, y1)
    return (x0[], y0[], x1[], y1[])
end

"""
    FLI.get_visible_area(cam) -> (x0, y0, x1, y1)

yields the visible area of the sensor array of camera `cam`.  Coordinates
`(x0,y0)` and `(x1,y1)` respectively define the upper-left and lower-right
corner of the visible area.  Visible pixels have coordinates `(x,y)` such that:

    x0 ??? x < x1
    y0 ??? y < y1

"""
function get_visible_area(cam::Device)
    x0 = Ref{Clong}()
    y0 = Ref{Clong}()
    x1 = Ref{Clong}()
    y1 = Ref{Clong}()
    @check FLIGetVisibleArea(cam.dev, x0, y0, x1, y1)
    return (x0[], y0[], x1[], y1[])
end

function get_readout_dimensions(cam::Device)
    width   = Ref{Clong}()
    hoffset = Ref{Clong}()
    hbin    = Ref{Clong}()
    height  = Ref{Clong}()
    voffset = Ref{Clong}()
    vbin    = Ref{Clong}()
    @check FLIGetReadoutDimensions(
        cam.dev, width, hoffset, hbin, height, voffset, vbin)
    return (width[], hoffset[], hbin[], height[], voffset[], vbin[])
end

"""
    FLI.set_image_area(cam, x0, y0, x1, y1)

sets the image area for camera `cam`.  The image area include the (physical)
pixels whose coordinates `(x,y)` are such that:

    x0 ??? x < x0 + (x1 - x0)*xbin
    y0 ??? y < y0 + (y1 - y0)*ybin

where `xbin` and `ybin` are the binning factors (see
[`FLI.set_binning`](@ref)).  In other words, the image area starts at offset
`(x0,y0)` (in physical pixels), and is a rectangle of `width??height`
macro-pixels with:

    width = x1 - x0
    height = y1 - y0

The macro-pixels are `xbin??ybin` physical pixels each.

"""
function set_image_area(cam::Device,
                        x0::Integer, y0::Integer,
                        x1::Integer, y1::Integer)
    @check FLISetImageArea(cam.dev, x0, y0, x1, y1)
end

"""
    FLI.set_binning(cam, xbin, ybin)

sets the size (in physical pixels) of the macro-pixels for subsequent images
acquirred by camera `cam`.

"""
function set_binning(cam::Device, xbin::Integer, ybin::Integer)
    @check FLISetHBin(cam.dev, xbin)
    @check FLISetVBin(cam.dev, ybin)
end

"""
    FLI.set_exposure_time(cam, secs)

sets the exposure time to be `secs` seconds for camera `cam`.

"""
function set_exposure_time(cam::Device, secs::Real)
    # Exposure time is in milliseconds in the C library.
    @check FLISetExposureTime(cam.dev, round(Clong, 1e3*secs))
end

"""
    FLI.set_frame_type(cam, sym)

sets the frame type for camera `cam`.  Argument `sym` can be `:normal` for a
normal frame where the shutter opens, `:dark` for a dark frame where the
shutter remains closed, `:flood`, or `:rbi_flush`.

"""
set_frame_type(cam::Device, sym::Symbol) =
    @check FLISetFrameType(cam.dev, encode_frame_type(sym))

encode_frame_type(sym::Symbol) = (
    sym === :normal    ? Lib.FLI_FRAME_TYPE_NORMAL :
    sym === :dark      ? Lib.FLI_FRAME_TYPE_DARK :
    sym === :flood     ? Lib.FLI_FRAME_TYPE_FLOOD :
    sym === :rbi_flush ? Lib.FLI_FRAME_TYPE_RBI_FLUSH :
    error("unknown frame type"))

cancel_exposure(cam::Device) = @check FLICancelExposure(cam.dev)

"""
    FLI.get_exposure_status(cam) -> secs

yields the number of seconds to wait for the end of the exposure by camera
`cam`.

"""
function get_exposure_status(cam::Device)
    timeleft = Ref{Clong}()
    @check FLIGetExposureStatus(cam.dev, timeleft)
    return timeleft[]/1e3
end

"""
    FLI.set_temperature(cam, temp)

sets the target temperature for camera `cam` to be `temp` in ??C.  The valid
range of temperatures is from -55??C to 45??C.

"""
set_temperature(cam::Device, temp::Real) =
    @check FLISetTemperature(cam.dev, temp)

"""
    FLI.get_temperature(cam) -> temp

yields the current temperature of camera `cam` in ??C.

"""
function get_temperature(cam::Device)
    temp = Ref{Cdouble}()
    @check FLIGetTemperature(cam.dev, temp)
    return temp[]
end

"""
    FLI.read_temperature(obj, chn) -> temp

yields the current temperature of device `obj` in ??C and for channel `chn`.
Argument `chn` is one of `:internal`, `:external`, `:ccd`, or `:base`.

"""
function read_temperature(obj::Device, channel::Symbol)
    temp = Ref{Cdouble}()
    @check FLIReadTemperature(
        obj.dev, encode_temperature_channel(channel), temp)
    return temp[]
end

encode_temperature_channel(sym::Symbol) = (
    sym === :internal ? Lib.FLI_TEMPERATURE_INTERNAL :
    sym === :external ? Lib.FLI_TEMPERATURE_EXTERNAL :
    sym === :ccd      ? Lib.FLI_TEMPERATURE_CCD :
    sym === :base     ? Lib.FLI_TEMPERATURE_BASE :
    error("unknown temperature channel"))

"""
    FLI.get_cooler_power(cam) -> temp

yields the current  cooler power level of camera `cam` in percent.

"""
function get_cooler_power(cam::Device)
    val = Ref{Cdouble}()
    @check FLIGetCoolerPower(cam.dev, val)
    return val[]
end

"""
    FLI.grab_frame([T=UInt16,] cam) -> img

downloads the frame from camera `cam`.  Optional argument `T` is to specify the
pixel type (either `UInt8` or `UInt16`).  Specifying the wrong pixel type may
result in unexpected pixel values.

"""
grab_frame(cam::Device) = grab_frame(UInt16, cam)
function grab_frame(T::Type{<:PixelType}, cam::Device)
    width, x0, xbin, height, y0, ybin = get_readout_dimensions(cam)
    return unsafe_grab_frame!(cam, Array{T}(undef, width, height))
end

"""
    FLI.grab_frame!(cam, img) -> img

downloads the frame from camera `cam` to the image `img` and returns the image.
The element type of the image (either `UInt8` or `UInt16`) must match the pixel
type of the camera.  Using the wrong pixel type may result in unexpected pixel
values.

"""
function grab_frame!(cam::Device, img::Matrix{<:PixelType})
    width, x0, xbin, height, y0, ybin = get_readout_dimensions(cam)
    size(img) == (width, height) || error(
        "destination image has incompatible dimensions")
    return unsafe_grab_frame!(cam, img)
end

"""
    FLI.unsafe_grab_frame!(cam, img) -> img

downloads the frame from camera `cam` to image `img` and returns the image.

The method is *unsafe* because it assumes that the size of the destination
image is correct.

""" unsafe_grab_frame!

# NOTE: We do not use the function `FLIGrabFrame` because it does nothing but
#       throwing an error.  So we use `FLIGrabRow` to download the image row by
#       row.

function unsafe_grab_frame!(cam::Device, img::Matrix{UInt8})
    # Use internal row buffer large enough to avoid segmentation fault.
    width, height = size(img)
    nbytes = width*sizeof(UInt16)
    buf = cam.buf
    length(buf) ??? nbytes || resize!(buf, nbytes)
    ptr = pointer(buf)
    for j in 1:height
        # Download row of pixels into the buffer and then copy the row into the
        # destination image.
        @check FLIGrabRow(cam.dev, ptr, width)
        @inbounds @simd for i in 1:width
            img[i,j] = buf[i]
        end
    end
    return img
end

function unsafe_grab_frame!(cam::Device, img::Matrix{UInt16})
    # Download pixels row by row directly into the destination image.
    width, height = size(img)
    stride = width*sizeof(eltype(img))
    ptr = pointer(img)
    for j in 1:height
        @check FLIGrabRow(cam.dev, ptr + (j - 1)*stride, width)
    end
    return img
end

"""
    FLI.unsafe_grab_row!(cam, img, j)

downloads the next available row of the image acquirred by camera `cam`
and stores it in the stores the `j`-th row of image `img`.

The method is *unsafe* because it assumes that its arguments are correct.

"""
function unsafe_grab_row!(cam::Device, img::Matrix{<:PixelType}, row::Integer)
    width, height = size(img)
    1 ??? row ??? height || error("out of range row index")
    stride = width*sizeof(eltype(img))
    ptr = pointer(img) + (row - 1)*stride
    @check FLIGrabRow(cam.dev, ptr, width)
end

stop_video_mode(cam::Device) = @check FLIStopVideoMode(cam.dev)
start_video_mode(cam::Device) = @check FLIStartVideoMode(cam.dev)

"""
    FLI.grab_video_frame([T = UInt16,] cam) -> img

yields a video frame from camera `cam`.  Optional argument `T` is to specify
the pixel type (either `UInt8` or `UInt16`).  Specifying the wrong pixel type
may cause a segmentation fault.

"""
grab_video_frame(cam::Device) = grab_video_frame(UInt16, cam)
function grab_video_frame(T::Type{<:PixelType}, cam::Device)
    width, x0, xbin, height, y0, ybin = get_readout_dimensions(cam)
    return unsafe_grab_video_frame!(cam, Array{T}(undef, width, height))
end

"""
    FLI.unsafe_grab_video_frame!(cam, img) -> img

stores video frame from camera `cam` into image `img` and retuns it.

The method is *unsafe* because it assumes that its arguments are correct.

"""
function unsafe_grab_video_frame!(cam::Device, img::Matrix{<:PixelType})
    @check FLIGrabVideoFrame(cam.dev, img, sizeof(img))
    return img
end

expose_frame(cam::Device) = @check FLIExposeFrame(cam.dev)

flush_row(cam::Device, rows::Integer, repeat::Integer) =
    @check FLIFlushRow(cam.dev, rows, repeat)

set_nflushes(cam::Device, nflushes::Integer) =
    @check FLISetNFlushes(cam.dev, nflushes)

"""
    FLI.set_bit_depth(cam, T)

sets the bit depth for camera `cam` for pixels of type `T` (either `UInt8` or
`UInt16`).

""" set_bit_depth

for (T, bitdepth) in ((UInt8, Lib.FLI_MODE_8BIT),
                      (UInt16, Lib.FLI_MODE_16BIT))
    @eval set_bit_depth(cam::Device, ::Type{$T}) =
        @check FLISetBitDepth(cam.dev, $bitdepth)
end

Base.lock(obj::Device) = @check FLILockDevice(obj.dev)
Base.unlock(obj::Device) = @check FLIUnLockDevice(obj.dev)

# This is for the do-block syntax.
function Base.lock(f::Function, obj::Device)
    lock(obj)
    try
        return f()
    finally
        unlock(obj)
    end
end

"""
    FLI.control_shutter(cam, ctrl)

controls the shutter of camera `cam`, argument `ctrl` can be one of `:close`,
`:open`, `:external_trigger`, `:external_trigger_low`,
`:external_trigger_high`, or `:external_exposure_control`.

"""
control_shutter(cam::Device, ctrl::Symbol) =
    @check FLIControlShutter(cam.dev, encode_shutter(ctrl))

encode_shutter(sym::Symbol) = (
    sym === :close ? Lib.FLI_SHUTTER_CLOSE :
    sym === :open ? Lib.FLI_SHUTTER_OPEN :
    sym === :external_trigger ? Lib.FLI_SHUTTER_EXTERNAL_TRIGGER :
    sym === :external_trigger_low ? Lib.FLI_SHUTTER_EXTERNAL_TRIGGER_LOW :
    sym === :external_trigger_high ? Lib.FLI_SHUTTER_EXTERNAL_TRIGGER_HIGH :
    sym === :external_exposure_control ? Lib.FLI_SHUTTER_EXTERNAL_EXPOSURE_CONTROL :
    error("unknown shutter control"))

control_background_flush(cam::Device, ctrl::Symbol) =
    @check FLIControlBackgroundFlush(cam.dev, encode_background_flush(ctrl))

encode_background_flush(sym::Symbol) = (
    sym === :stop  ? Lib.FLI_BGFLUSH_STOP :
    sym === :start ? Lib.FLI_BGFLUSH_START :
    error("unknown background flush control"))

set_dac(obj::Device, dacset::Integer) =
    @check FLISetDAC(obj.dev, dacset)

function get_device_status(obj::Device)
    mode = Ref{Lib.flimode_t}()
    @check FLIGetDeviceStatus(obj.dev, mode)
    return mode[]
end

function get_camera_mode_string(cam::Device, mode::Integer)
    buf = Array{UInt8}(undef, 256)
    @check FLIGetCameraModeString(cam.dev, mode, buf, length(buf))
    return unsafe_string(pointer(buf))
end

function get_camera_mode(cam::Device)
    mode = Ref{Lib.flimode_t}()
    @check FLIGetCameraMode(cam.dev, mode)
    return mode[]
end

get_camera_mode(cam::Device, mode::Integer) =
    @check FLISetCameraMode(cam.dev, mode)

set_tdi(obj::Device, rate::Integer, flags::Integer) =
    @check FLISetTDI(obj.dev, rate, flags)

home_device(obj::Device) = @check FLIHomeDevice(obj.dev)

function get_serial_string(obj::Device)
    buf = Array{UInt8}(undef, 256)
    @check FLIGetSerialString(obj.dev, buf, length(buf))
    return unsafe_string(pointer(buf))
end

end_exposure(cam::Device) = @check FLIEndExposure(cam.dev)
trigger_exposure(cam::Device) = @check FLITriggerExposure(cam.dev)

"""
    FLI.set_fan_speed(cam, onoff)

sets the fan speed of camera `cam`, argument `onoff` is `:on` or `:off`.

"""
set_fan_speed(cam::Device, onoff::Symbol) =
    @check FLISetFanSpeed(cam.dev, encode_fan_speed(onoff))

encode_fan_speed(sym::Symbol) = (
    sym === :off ? Lib.FLI_FAN_SPEED_OFF :
    sym === :on  ? Lib.FLI_FAN_SPEED_ON :
    error("unknown fan speed"))

"""
    FLI.read_io_port(cam)

reads the I/O port of a camera `cam` and yields the resulting i/o data.

"""
function read_io_port(cam::Device)
    ioportset = Ref{Clong}()
    @check FLIReadIOPort(cam.dev, ioportset)
    return ioportset[]
end

"""
    FLI.write_io_port(cam, ioportset)

writes `ioportset` to the I/O port of a camera `cam`.

"""
write_io_port(cam::Device, ioportset::Integer) =
    @check FLIWriteIOPort(cam.dev, ioportset)

"""
    FLI.configure_io_port(cam, data)

writes `data` to the I/O port of a camera `cam`.

"""
configure_io_port(cam::Device, ioportset::Integer) =
    @check FLIConfigureIOPort(cam.dev, ioportset)

function get_filter_name(obj::Device)
    buf = Array{UInt8}(undef, 256)
    @check FLIGetFilterName(obj.dev, buf, length(buf))
    return unsafe_string(pointer(buf))
end

set_filter_pos(obj::Device, pos::Integer) =
    @check FLISetFilterPos(obj.dev, pos)

function get_filter_pos(obj::Device)
    pos = Ref{Clong}()
    @check FLIGetFilterPos(obj.dev, pos)
    return pos[]
end

function get_filter_count(obj::Device)
    cnt = Ref{Clong}()
    @check FLIGetFilterCount(obj.dev, cnt)
    return cnt[]
end

set_active_wheel(obj::Device, wheel::Integer) =
    @check FLISetActiveWheel(obj.dev, wheel)

function get_active_wheel(obj::Device)
    wheel = Ref{Clong}()
    @check FLIGetActiveWheel(obj.dev, wheel)
    return wheel[]
end

step_motor(obj::Device, steps::Integer) =
    @check FLIStepMotor(obj.dev, steps)

step_motor_async(obj::Device, steps::Integer) =
    @check FLIStepMotorAsync(obj.dev, steps)

function get_stepper_position(obj::Device)
    pos = Ref{Clong}()
    @check FLIGetStepperPosition(obj.dev, pos)
    return pos[]
end

function get_steps_remaining(obj::Device)
    steps = Ref{Clong}()
    @check FLIGetStepsRemaining(obj.dev, steps)
    return steps[]
end

home_focuser(obj::Device) = @check FLIHomeFocuser(obj.dev)

function get_focuser_extent(obj::Device)
    extent = Ref{Clong}()
    @check FLIGetFocuserExtent(obj.dev, extent)
    return extent[]
end

function set_vertical_table_entry(obj::Device, index::Integer, height::Integer,
                                  bin::Integer, mode::Integer)
    @check FLISetVerticalTableEntry(obj.dev, index, height, bin, mode)
end

function get_vertical_table_entry(obj::Device, index::Integer)
    height = Ref{Clong}()
    bin = Ref{Clong}()
    mode = Ref{Clong}()
    @check FLIGetVerticalTableEntry(obj.dev, index, height, bin, mode)
    return (height[], bin[], mode[])
end

function enable_vertical_table(obj::Device, width::Integer,
                               offset::Integer, flags::Integer)
    @check FLIEnableVerticalTable(obj.dev, width, offset, flags)
end

#=
# FIXME: Don't known what is this function.
function usb_bulk_io(obj::Device, ep::Integer, buf::Ptr)
    len = Ref{Clong}()
    @check FLIUsbBulkIO(obj.dev, ep, buf, len)
    return len[]
end
=#

"""
    FLI.read_user_eeprom(obj, loc, nbytes) -> data

reads user EEPROM.

"""
function read_user_eeprom(obj::Device, loc::Symbol, address::Integer,
                          nbytes::Integer)
    return read_user_eeprom!(obj, loc, address, Array{UInt8}(undef, nbytes))
end

function read_user_eeprom!(obj::Device, loc::Symbol, address::Integer,
                           data::Vector{UInt8})
    @check FLIReadUserEEPROM(obj.dev, encode_eeprom_location(loc),
                             address, sizeof(data), data)
    return data
end

"""
    FLI.write_user_eeprom(obj, loc, data)

writes user EEPROM.

"""
function write_user_eeprom(obj::Device, loc::Symbol, address::Integer,
                           data::Vector{UInt8})
    @check FLIWriteUserEEPROM(obj.dev, encode_eeprom_location(loc),
                              address, sizeof(data), data)
end

encode_eeprom_location(sym::Symbol) = (
    sym === :user ? Lib.FLI_EEPROM_USER :
    sym === :pixel_map ? Lib.FLI_EEPROM_PIXEL_MAP :
    error("unknown EEPROM location"))
