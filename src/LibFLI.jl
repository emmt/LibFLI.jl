module LibFLI

export FLI, FLIException

include("libcalls.jl")

const FLI = LibFLI

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
    dev::Lib.flidev_t
    Device() = new(Lib.FLI_INVALID_DEVICE)
end

"""
    FLI.Device(name; interface = :usb, device = :camera) -> obj

opens FLI device `name`.  Keywords `interface` and `device` are to specifiy the
interface and the type of device as symbolic names.  The possibilities are:

- For `interface`: `:none`, `:parallel_port`, `:usb`, `:serial`, `:inet`,
  `:serial_19200`, or `:serial_1200`.

- For `device`: `:none`, `:camera`, `:filterwheel`, `:focuser`,
  `:hs_filterwheel`, `:raw`, or `:enumerate_by_interface`.

Method `close(obj)` can be called to eventually close the device but this is
not mandatory as the returned object is automatically closed when it is
reclaimed by garbage collector.

Examples:

    cam = FLI.Device("/dev/fliusb0"; device = :camera, interface = :usb)

"""
function Device(name::AbstractString,;
                interface::Symbol = :usb,
                device::Symbol = :camera)
    domain = parse_interface_domain(interface)|parse_device_domain(device)
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

parse_interface_domain(sym::Symbol) = (
    sym === :none          ? Lib.FLIDOMAIN_NONE :
    sym === :parallel_port ? Lib.FLIDOMAIN_PARALLEL_PORT :
    sym === :usb           ? Lib.FLIDOMAIN_USB :
    sym === :serial        ? Lib.FLIDOMAIN_SERIAL :
    sym === :inet          ? Lib.FLIDOMAIN_INET :
    sym === :serial_19200  ? Lib.FLIDOMAIN_SERIAL_19200 :
    sym === :serial_1200   ? Lib.FLIDOMAIN_SERIAL_1200 :
    error("unknown interface"))

parse_device_domain(sym::Symbol) = (
    sym === :none                    ? Lib.FLIDEVICE_NONE :
    sym === :camera                  ? Lib.FLIDEVICE_CAMERA :
    sym === :filterwheel             ? Lib.FLIDEVICE_FILTERWHEEL :
    sym === :focuser                 ? Lib.FLIDEVICE_FOCUSER :
    sym === :hs_filterwheel          ? Lib.FLIDEVICE_HS_FILTERWHEEL :
    sym === :raw                     ? Lib.FLIDEVICE_RAW :
    sym === :enumerate_by_connection ? Lib.FLIDEVICE_ENUMERATE_BY_CONNECTION :
    error("unknown device type"))

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
    @check FLISetDebugLevel(host, parse_debug_level(level))

parse_debug_level(sym::Symbol) = (
    sym === :none ? Lib.FLIDEBUG_NONE :
    sym === :fail ? Lib.FLIDEBUG_FAIL :
    sym === :warn ? Lib.FLIDEBUG_WARN :
    sym === :info ? Lib.FLIDEBUG_INFO :
    sym === :io   ? Lib.FLIDEBUG_IO   :
    sym === :all  ? Lib.FLIDEBUG_ALL  :
    error("unknown debug level"))

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
    xsiz = Ref{Cdouble}()
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

    x0 ≤ x < x1
    y0 ≤ y < y1

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

    x0 ≤ x < x0 + (x1 - x0)*xbin
    y0 ≤ y < y0 + (y1 - y0)*ybin

where `xbin` and `ybin` are the binning factors (see
[`FLI.set_binning`](@ref)).  In other words, the image area starts at offset
`(x0,y0)` (in physical pixels), and is a rectangle of `width×height`
macro-pixels with:

    width = x1 - x0
    height = y1 - y0

The macro-pixels are `xbin×ybin` physical pixels each.

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
    @check FLISetFrameType(cam.dev, parse_frame_type(sym))

parse_frame_type(sym::Symbol) = (
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

# Set temperature (in °C).
set_temperature(obj::Device, temp::Real) =
    @check FLISetTemperature(obj.dev, temp)

# Get temperature (in °C).
function get_temperature(obj::Device)
    val = Ref{Cdouble}()
    @check FLIGetTemperature(obj.dev, val)
    return val[]
end

function read_temperature(obj::Device, channel::Symbol)
    temp = Ref{Cdouble}()
    @check FLIReadTemperature(
        obj.dev, parse_temperature_channel(channel), temp)
    return temp[]
end

parse_temperature_channel(sym::Symbol) = (
    sym === :internal ? Lib.FLI_TEMPERATURE_INTERNAL :
    sym === :external ? Lib.FLI_TEMPERATURE_EXTERNAL :
    sym === :ccd      ? Lib.FLI_TEMPERATURE_CCD :
    sym === :base     ? Lib.FLI_TEMPERATURE_BASE :
    error("unknown temerature channel"))

function get_cooler_power(obj::Device)
    val = Ref{Cdouble}()
    @check FLIGetCoolerPower(obj.dev, val)
    return val[]
end

"""
    FLI.grab_frame([T=UInt16,] cam) -> img

downloads the frame from camera `cam`.  Optional argument `T` is to specify the
pixel type (either `UInt8` or `UInt16`).  Specifying the wrong pixel type may
cause a segmentation fault.

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
type of the camera.  Using the wrong pixel type may cause a segmentation fault.

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

The method is *unsafe* because it assumes that its arguments are correct.

"""
function unsafe_grab_frame!(cam::Device, img::Matrix{<:PixelType})
    # NOTE: We do not use the function `FLIGrabFrame` because it does nothing
    #       but throwing an error.
    width, height = size(img)
    stride = width*sizeof(eltype(img))
    ptr = pointer(img)
    for row in 1:height
        @check FLIGrabRow(cam.dev, ptr + (row - 1)*stride, width)
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
    1 ≤ row ≤ height || error("out of range row index")
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

"""
    FLI.control_shutter(cam, ctrl)

controls the shutter of camera `cam`, argument `ctrl` can be one of `:close`,
`:open`, `:external_trigger`, `:external_trigger_low`,
`:external_trigger_high`, or `:external_exposure_control`.

"""
control_shutter(cam::Device, ctrl::Symbol) =
    @check FLIControlShutter(cam.dev, parse_shutter(ctrl))

parse_shutter(sym::Symbol) = (
    sym === :close ? Lib.FLI_SHUTTER_CLOSE :
    sym === :open ? Lib.FLI_SHUTTER_OPEN :
    sym === :external_trigger ? Lib.FLI_SHUTTER_EXTERNAL_TRIGGER :
    sym === :external_trigger_low ? Lib.FLI_SHUTTER_EXTERNAL_TRIGGER_LOW :
    sym === :external_trigger_high ? Lib.FLI_SHUTTER_EXTERNAL_TRIGGER_HIGH :
    sym === :external_exposure_control ? Lib.FLI_SHUTTER_EXTERNAL_EXPOSURE_CONTROL :
    error("unknown shutter control"))

control_background_flush(cam::Device, ctrl::Symbol) =
    @check FLIControlBackgroundFlush(cam.dev, parse_background_flush(ctrl))

parse_background_flush(sym::Symbol) = (
    sym === :stop ? FLI_BGFLUSH_STOP :
    sym === :start ? FLI_BGFLUSH_START :
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
    @check FLISetFanSpeed(cam.dev, parse_fan_speed(onoff))

parse_fan_speed(sym::Symbol) = (
    sym === :off ? Lib.FLI_FAN_SPEED_OFF :
    sym === :on  ? Lib.FLI_FAN_SPEED_ON :
    error("unknown fan speed"))

# FIXME: FLIReadIOPort(flidev_t dev, long *ioportset);
# FIXME: FLIWriteIOPort(flidev_t dev, long ioportset);
# FIXME: FLIConfigureIOPort(flidev_t dev, long ioportset);

# FIXME: FLIList(flidomain_t domain, char ***names);
# FIXME: FLIFreeList(char **names);

# FIXME: FLIGetFilterName(flidev_t dev, long filter, char *name, size_t len);
# FIXME: FLISetActiveWheel(flidev_t dev, long wheel);
# FIXME: FLIGetActiveWheel(flidev_t dev, long *wheel);

# FIXME: FLISetFilterPos(flidev_t dev, long filter);
# FIXME: FLIGetFilterPos(flidev_t dev, long *filter);
# FIXME: FLIGetFilterCount(flidev_t dev, long *filter);

# FIXME: FLIStepMotor(flidev_t dev, long steps);
# FIXME: FLIStepMotorAsync(flidev_t dev, long steps);
# FIXME: FLIGetStepperPosition(flidev_t dev, long *position);
# FIXME: FLIGetStepsRemaining(flidev_t dev, long *steps);
# FIXME: FLIHomeFocuser(flidev_t dev);

# FIXME: FLICreateList(flidomain_t domain);
# FIXME: FLIDeleteList(void);
# FIXME: FLIListFirst(flidomain_t *domain, char *filename, size_t fnlen, char *name, size_t namelen);
# FIXME: FLIListNext(flidomain_t *domain, char *filename, size_t fnlen, char *name, size_t namelen);

# FIXME: FLIGetFocuserExtent(flidev_t dev, long *extent);
# FIXME: FLIUsbBulkIO(flidev_t dev, int ep, void *buf, long *len);

# FIXME: FLISetVerticalTableEntry(flidev_t dev, long index, long height, long bin, long mode);
# FIXME: FLIGetVerticalTableEntry(flidev_t dev, long index, long *height, long *bin, long *mode);

# FIXME: FLIEnableVerticalTable(flidev_t dev, long width, long offset, long flags);
# FIXME: FLIReadUserEEPROM(flidev_t dev, long loc, long address, long length, void *rbuf);
# FIXME: FLIWriteUserEEPROM(flidev_t dev, long loc, long address, long length, void *wbuf);

end # module
