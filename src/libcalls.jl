# Low level bindings to the C library.
module Lib

let file = joinpath(@__DIR__, "..", "deps", "deps.jl")
    include(file)
end

# Status returned by all fucntion of the FLI SDK.  A negative value indicates
# an error (the value is `-errno`).
struct Status
    code::Clong
end

const flidev_t = Clong

const FLI_INVALID_DEVICE = flidev_t(-1)

"""

The domain of an FLI device. This consists of a bitwise ORed combination of
interface method and device type. Valid interfaces are
[`FLIDOMAIN_PARALLEL_PORT`](@ref), [`FLIDOMAIN_USB`](@ref),
[`FLIDOMAIN_SERIAL`](@ref), and [`FLIDOMAIN_INET`](@ref). Valid device types
are [`FLIDEVICE_CAMERA`](@ref), {FLIDOMAIN\\_FILTERWHEEL}, and
{FLIDOMAIN\\_FOCUSER}.

### See also
[`FLIOpen`](@ref), [`FLIList`](@ref)
"""
const flidomain_t = Clong

const FLIDOMAIN_NONE                    = flidomain_t(0x00)
const FLIDOMAIN_PARALLEL_PORT           = flidomain_t(0x01)
const FLIDOMAIN_USB                     = flidomain_t(0x02)
const FLIDOMAIN_SERIAL                  = flidomain_t(0x03)
const FLIDOMAIN_INET                    = flidomain_t(0x04)
const FLIDOMAIN_SERIAL_19200            = flidomain_t(0x05)
const FLIDOMAIN_SERIAL_1200             = flidomain_t(0x06)

const FLIDEVICE_NONE                    = flidomain_t(0x0000)
const FLIDEVICE_CAMERA                  = flidomain_t(0x0100)
const FLIDEVICE_FILTERWHEEL             = flidomain_t(0x0200)
const FLIDEVICE_FOCUSER                 = flidomain_t(0x0300)
const FLIDEVICE_HS_FILTERWHEEL          = flidomain_t(0x0400)
const FLIDEVICE_RAW                     = flidomain_t(0x0f00)
const FLIDEVICE_ENUMERATE_BY_CONNECTION = flidomain_t(0x8000)

"""

The frame type for an FLI CCD camera device. Valid frame types are
[`FLI_FRAME_TYPE_NORMAL`](@ref) and [`FLI_FRAME_TYPE_DARK`](@ref).

### See also
[`FLISetFrameType`](@ref)

"""
const fliframe_t = Clong

const FLI_FRAME_TYPE_NORMAL = fliframe_t(0)
const FLI_FRAME_TYPE_DARK   = fliframe_t(1)
const FLI_FRAME_TYPE_FLOOD  = fliframe_t(2)
const FLI_FRAME_TYPE_RBI_FLUSH = FLI_FRAME_TYPE_FLOOD | FLI_FRAME_TYPE_DARK

"""
The gray-scale bit depth for an FLI camera device. Valid bit depths are [`FLI_MODE_8BIT`](@ref) and [`FLI_MODE_16BIT`](@ref).

### See also
[`FLISetBitDepth`](@ref)
"""
const flibitdepth_t = Clong

const FLI_MODE_8BIT  = flibitdepth_t(0)
const FLI_MODE_16BIT = flibitdepth_t(1)

"""

Type used for shutter operations for an FLI camera device. Valid shutter types
are [`FLI_SHUTTER_CLOSE`](@ref), [`FLI_SHUTTER_OPEN`](@ref),
[`FLI_SHUTTER_EXTERNAL_TRIGGER`](@ref),
[`FLI_SHUTTER_EXTERNAL_TRIGGER_LOW`](@ref), and
[`FLI_SHUTTER_EXTERNAL_TRIGGER_HIGH`](@ref).

### See also
[`FLIControlShutter`](@ref)

"""
const flishutter_t = Clong

const FLI_SHUTTER_CLOSE                     = flishutter_t(0x0000)
const FLI_SHUTTER_OPEN                      = flishutter_t(0x0001)
const FLI_SHUTTER_EXTERNAL_TRIGGER          = flishutter_t(0x0002)
const FLI_SHUTTER_EXTERNAL_TRIGGER_LOW      = flishutter_t(0x0002)
const FLI_SHUTTER_EXTERNAL_TRIGGER_HIGH     = flishutter_t(0x0004)
const FLI_SHUTTER_EXTERNAL_EXPOSURE_CONTROL = flishutter_t(0x0008)

"""

Type used for background flush operations for an FLI camera device. Valid
bgflush types are [`FLI_BGFLUSH_STOP`](@ref) and [`FLI_BGFLUSH_START`](@ref).

### See also
[`FLIControlBackgroundFlush`](@ref)

"""
const flibgflush_t = Clong

const FLI_BGFLUSH_STOP  = flibgflush_t(0x0000)
const FLI_BGFLUSH_START = flibgflush_t(0x0001)

"""

Type used to determine which temperature channel to read. Valid channel types
are [`FLI_TEMPERATURE_INTERNAL`](@ref) and [`FLI_TEMPERATURE_EXTERNAL`](@ref).

### See also
[`FLIReadTemperature`](@ref)

"""
const flichannel_t = Clong

const FLI_TEMPERATURE_INTERNAL = flichannel_t(0x0000)
const FLI_TEMPERATURE_EXTERNAL = flichannel_t(0x0001)
const FLI_TEMPERATURE_CCD      = flichannel_t(0x0000)
const FLI_TEMPERATURE_BASE     = flichannel_t(0x0001)

"""

Type specifying library debug levels. Valid debug levels are
[`FLIDEBUG_NONE`](@ref), [`FLIDEBUG_INFO`](@ref), [`FLIDEBUG_WARN`](@ref), and
[`FLIDEBUG_FAIL`](@ref).

### See also
[`FLISetDebugLevel`](@ref)

"""
const flidebug_t = Clong

const FLIDEBUG_NONE = 0x00
const FLIDEBUG_INFO = 0x01
const FLIDEBUG_WARN = 0x02
const FLIDEBUG_FAIL = 0x04
const FLIDEBUG_IO   = 0x08
const FLIDEBUG_ALL  = (FLIDEBUG_INFO | FLIDEBUG_WARN) | FLIDEBUG_FAIL

const flimode_t = Clong

const flistatus_t = Clong

const flitdirate_t = Clong

const flitdiflags_t = Clong

function FLIOpen(dev, name, domain)
    @ccall libfli.FLIOpen(dev::Ptr{flidev_t}, name::Cstring, domain::flidomain_t)::Status
end

function FLISetDebugLevel(host, level)
    @ccall libfli.FLISetDebugLevel(host::Cstring, level::flidebug_t)::Status
end

function FLIClose(dev)
    @ccall libfli.FLIClose(dev::flidev_t)::Status
end

function FLIGetLibVersion(ver, len)
    # FIXME: @ccall libfli.FLIGetLibVersion(ver::Cstring, len::Csize_t)::Status
    @ccall libfli.FLIGetLibVersion(ver::Ptr{UInt8}, len::Csize_t)::Status
end

function FLIGetModel(dev, model, len)
    # FIXME: @ccall libfli.FLIGetModel(dev::flidev_t, model::Cstring, len::Csize_t)::Status
    @ccall libfli.FLIGetModel(dev::flidev_t, model::Ptr{UInt8}, len::Csize_t)::Status
end

function FLIGetPixelSize(dev, pixel_x, pixel_y)
    @ccall libfli.FLIGetPixelSize(dev::flidev_t, pixel_x::Ptr{Cdouble}, pixel_y::Ptr{Cdouble})::Status
end

function FLIGetHWRevision(dev, hwrev)
    @ccall libfli.FLIGetHWRevision(dev::flidev_t, hwrev::Ptr{Clong})::Status
end

function FLIGetFWRevision(dev, fwrev)
    @ccall libfli.FLIGetFWRevision(dev::flidev_t, fwrev::Ptr{Clong})::Status
end

function FLIGetArrayArea(dev, ul_x, ul_y, lr_x, lr_y)
    @ccall libfli.FLIGetArrayArea(dev::flidev_t, ul_x::Ptr{Clong}, ul_y::Ptr{Clong}, lr_x::Ptr{Clong}, lr_y::Ptr{Clong})::Status
end

function FLIGetVisibleArea(dev, ul_x, ul_y, lr_x, lr_y)
    @ccall libfli.FLIGetVisibleArea(dev::flidev_t, ul_x::Ptr{Clong}, ul_y::Ptr{Clong}, lr_x::Ptr{Clong}, lr_y::Ptr{Clong})::Status
end

function FLISetExposureTime(dev, exptime)
    @ccall libfli.FLISetExposureTime(dev::flidev_t, exptime::Clong)::Status
end

function FLISetImageArea(dev, ul_x, ul_y, lr_x, lr_y)
    @ccall libfli.FLISetImageArea(dev::flidev_t, ul_x::Clong, ul_y::Clong, lr_x::Clong, lr_y::Clong)::Status
end

function FLISetHBin(dev, hbin)
    @ccall libfli.FLISetHBin(dev::flidev_t, hbin::Clong)::Status
end

function FLISetVBin(dev, vbin)
    @ccall libfli.FLISetVBin(dev::flidev_t, vbin::Clong)::Status
end

function FLISetFrameType(dev, frametype)
    @ccall libfli.FLISetFrameType(dev::flidev_t, frametype::fliframe_t)::Status
end

function FLICancelExposure(dev)
    @ccall libfli.FLICancelExposure(dev::flidev_t)::Status
end

function FLIGetExposureStatus(dev, timeleft)
    @ccall libfli.FLIGetExposureStatus(dev::flidev_t, timeleft::Ptr{Clong})::Status
end

function FLISetTemperature(dev, temperature)
    @ccall libfli.FLISetTemperature(dev::flidev_t, temperature::Cdouble)::Status
end

function FLIGetTemperature(dev, temperature)
    @ccall libfli.FLIGetTemperature(dev::flidev_t, temperature::Ptr{Cdouble})::Status
end

function FLIGetCoolerPower(dev, power)
    @ccall libfli.FLIGetCoolerPower(dev::flidev_t, power::Ptr{Cdouble})::Status
end

function FLIGrabRow(dev, buff, width)
    @ccall libfli.FLIGrabRow(dev::flidev_t, buff::Ptr{Cvoid}, width::Csize_t)::Status
end

function FLIExposeFrame(dev)
    @ccall libfli.FLIExposeFrame(dev::flidev_t)::Status
end

function FLIFlushRow(dev, rows, repeat)
    @ccall libfli.FLIFlushRow(dev::flidev_t, rows::Clong, repeat::Clong)::Status
end

function FLISetNFlushes(dev, nflushes)
    @ccall libfli.FLISetNFlushes(dev::flidev_t, nflushes::Clong)::Status
end

function FLISetBitDepth(dev, bitdepth)
    @ccall libfli.FLISetBitDepth(dev::flidev_t, bitdepth::flibitdepth_t)::Status
end

function FLIReadIOPort(dev, ioportset)
    @ccall libfli.FLIReadIOPort(dev::flidev_t, ioportset::Ptr{Clong})::Status
end

function FLIWriteIOPort(dev, ioportset)
    @ccall libfli.FLIWriteIOPort(dev::flidev_t, ioportset::Clong)::Status
end

function FLIConfigureIOPort(dev, ioportset)
    @ccall libfli.FLIConfigureIOPort(dev::flidev_t, ioportset::Clong)::Status
end

function FLILockDevice(dev)
    @ccall libfli.FLILockDevice(dev::flidev_t)::Status
end

function FLIUnlockDevice(dev)
    @ccall libfli.FLIUnlockDevice(dev::flidev_t)::Status
end

function FLIControlShutter(dev, shutter)
    @ccall libfli.FLIControlShutter(dev::flidev_t, shutter::flishutter_t)::Status
end

function FLIControlBackgroundFlush(dev, bgflush)
    @ccall libfli.FLIControlBackgroundFlush(dev::flidev_t, bgflush::flibgflush_t)::Status
end

function FLISetDAC(dev, dacset)
    @ccall libfli.FLISetDAC(dev::flidev_t, dacset::Culong)::Status
end

function FLIList(domain, names)
    @ccall libfli.FLIList(domain::flidomain_t, names::Ptr{Ptr{Cstring}})::Status
end

function FLIFreeList(names)
    @ccall libfli.FLIFreeList(names::Ptr{Cstring})::Status
end

function FLIGetFilterName(dev, filter, name, len)
    # FIXME: @ccall libfli.FLIGetFilterName(dev::flidev_t, filter::Clong, name::Cstring, len::Csize_t)::Status
    @ccall libfli.FLIGetFilterName(dev::flidev_t, filter::Clong, name::Ptr{UInt8}, len::Csize_t)::Status
end

function FLISetActiveWheel(dev, wheel)
    @ccall libfli.FLISetActiveWheel(dev::flidev_t, wheel::Clong)::Status
end

function FLIGetActiveWheel(dev, wheel)
    @ccall libfli.FLIGetActiveWheel(dev::flidev_t, wheel::Ptr{Clong})::Status
end

function FLISetFilterPos(dev, filter)
    @ccall libfli.FLISetFilterPos(dev::flidev_t, filter::Clong)::Status
end

function FLIGetFilterPos(dev, filter)
    @ccall libfli.FLIGetFilterPos(dev::flidev_t, filter::Ptr{Clong})::Status
end

function FLIGetFilterCount(dev, filter)
    @ccall libfli.FLIGetFilterCount(dev::flidev_t, filter::Ptr{Clong})::Status
end

function FLIStepMotor(dev, steps)
    @ccall libfli.FLIStepMotor(dev::flidev_t, steps::Clong)::Status
end

function FLIStepMotorAsync(dev, steps)
    @ccall libfli.FLIStepMotorAsync(dev::flidev_t, steps::Clong)::Status
end

function FLIGetStepperPosition(dev, position)
    @ccall libfli.FLIGetStepperPosition(dev::flidev_t, position::Ptr{Clong})::Status
end

function FLIGetStepsRemaining(dev, steps)
    @ccall libfli.FLIGetStepsRemaining(dev::flidev_t, steps::Ptr{Clong})::Status
end

function FLIHomeFocuser(dev)
    @ccall libfli.FLIHomeFocuser(dev::flidev_t)::Status
end

function FLICreateList(domain)
    @ccall libfli.FLICreateList(domain::flidomain_t)::Status
end

function FLIDeleteList()
    @ccall libfli.FLIDeleteList()::Status
end

function FLIListFirst(domain, filename, fnlen, name, namelen)
    @ccall libfli.FLIListFirst(domain::Ptr{flidomain_t}, filename::Cstring, fnlen::Csize_t, name::Cstring, namelen::Csize_t)::Status
end

function FLIListNext(domain, filename, fnlen, name, namelen)
    @ccall libfli.FLIListNext(domain::Ptr{flidomain_t}, filename::Cstring, fnlen::Csize_t, name::Cstring, namelen::Csize_t)::Status
end

function FLIReadTemperature(dev, channel, temperature)
    @ccall libfli.FLIReadTemperature(dev::flidev_t, channel::flichannel_t, temperature::Ptr{Cdouble})::Status
end

function FLIGetFocuserExtent(dev, extent)
    @ccall libfli.FLIGetFocuserExtent(dev::flidev_t, extent::Ptr{Clong})::Status
end

function FLIUsbBulkIO(dev, ep, buf, len)
    @ccall libfli.FLIUsbBulkIO(dev::flidev_t, ep::Cint, buf::Ptr{Cvoid}, len::Ptr{Clong})::Status
end

function FLIGetDeviceStatus(dev, status)
    @ccall libfli.FLIGetDeviceStatus(dev::flidev_t, status::Ptr{Clong})::Status
end

function FLIGetCameraModeString(dev, mode_index, mode_string, siz)
    # FIXME: @ccall libfli.FLIGetCameraModeString(dev::flidev_t, mode_index::flimode_t, mode_string::Cstring, siz::Csize_t)::Status
    @ccall libfli.FLIGetCameraModeString(dev::flidev_t, mode_index::flimode_t, mode_string::Ptr{UInt8}, siz::Csize_t)::Status
end

function FLIGetCameraMode(dev, mode_index)
    @ccall libfli.FLIGetCameraMode(dev::flidev_t, mode_index::Ptr{flimode_t})::Status
end

function FLISetCameraMode(dev, mode_index)
    @ccall libfli.FLISetCameraMode(dev::flidev_t, mode_index::flimode_t)::Status
end

function FLIHomeDevice(dev)
    @ccall libfli.FLIHomeDevice(dev::flidev_t)::Status
end

function FLIGrabFrame(dev, buff, buffsize, bytesgrabbed)
    @ccall libfli.FLIGrabFrame(dev::flidev_t, buff::Ptr{Cvoid}, buffsize::Csize_t, bytesgrabbed::Ptr{Csize_t})::Status
end

function FLISetTDI(dev, tdi_rate, flags)
    @ccall libfli.FLISetTDI(dev::flidev_t, tdi_rate::flitdirate_t, flags::flitdiflags_t)::Status
end

function FLIGrabVideoFrame(dev, buff, size)
    @ccall libfli.FLIGrabVideoFrame(dev::flidev_t, buff::Ptr{Cvoid}, size::Csize_t)::Status
end

function FLIStopVideoMode(dev)
    @ccall libfli.FLIStopVideoMode(dev::flidev_t)::Status
end

function FLIStartVideoMode(dev)
    @ccall libfli.FLIStartVideoMode(dev::flidev_t)::Status
end

function FLIGetSerialString(dev, serial, len)
    # FIXME: @ccall libfli.FLIGetSerialString(dev::flidev_t, serial::Cstring, len::Csize_t)::Status
    @ccall libfli.FLIGetSerialString(dev::flidev_t, serial::Ptr{UInt8}, len::Csize_t)::Status
end

function FLIEndExposure(dev)
    @ccall libfli.FLIEndExposure(dev::flidev_t)::Status
end

function FLITriggerExposure(dev)
    @ccall libfli.FLITriggerExposure(dev::flidev_t)::Status
end

function FLISetFanSpeed(dev, fan_speed)
    @ccall libfli.FLISetFanSpeed(dev::flidev_t, fan_speed::Clong)::Status
end

function FLISetVerticalTableEntry(dev, index, height, bin, mode)
    @ccall libfli.FLISetVerticalTableEntry(dev::flidev_t, index::Clong, height::Clong, bin::Clong, mode::Clong)::Status
end

function FLIGetVerticalTableEntry(dev, index, height, bin, mode)
    @ccall libfli.FLIGetVerticalTableEntry(dev::flidev_t, index::Clong, height::Ptr{Clong}, bin::Ptr{Clong}, mode::Ptr{Clong})::Status
end

function FLIGetReadoutDimensions(dev, width, hoffset, hbin, height, voffset, vbin)
    @ccall libfli.FLIGetReadoutDimensions(dev::flidev_t, width::Ptr{Clong}, hoffset::Ptr{Clong}, hbin::Ptr{Clong}, height::Ptr{Clong}, voffset::Ptr{Clong}, vbin::Ptr{Clong})::Status
end

function FLIEnableVerticalTable(dev, width, offset, flags)
    @ccall libfli.FLIEnableVerticalTable(dev::flidev_t, width::Clong, offset::Clong, flags::Clong)::Status
end

function FLIReadUserEEPROM(dev, loc, address, length, rbuf)
    @ccall libfli.FLIReadUserEEPROM(dev::flidev_t, loc::Clong, address::Clong, length::Clong, rbuf::Ptr{Cvoid})::Status
end

function FLIWriteUserEEPROM(dev, loc, address, length, wbuf)
    @ccall libfli.FLIWriteUserEEPROM(dev::flidev_t, loc::Clong, address::Clong, length::Clong, wbuf::Ptr{Cvoid})::Status
end

const FLI_CAMERA_STATUS_UNKNOWN = 0xffffffff
const FLI_CAMERA_STATUS_MASK = 0x00000003
const FLI_CAMERA_STATUS_IDLE = 0x00
const FLI_CAMERA_STATUS_WAITING_FOR_TRIGGER = 0x01
const FLI_CAMERA_STATUS_EXPOSING = 0x02
const FLI_CAMERA_STATUS_READING_CCD = 0x03

const FLI_CAMERA_DATA_READY = 0x80000000

const FLI_FOCUSER_STATUS_UNKNOWN = 0xffffffff
const FLI_FOCUSER_STATUS_HOMING = 0x00000004
const FLI_FOCUSER_STATUS_MOVING_IN = 0x00000001
const FLI_FOCUSER_STATUS_MOVING_OUT = 0x00000002
const FLI_FOCUSER_STATUS_MOVING_MASK = 0x00000007
const FLI_FOCUSER_STATUS_HOME = 0x00000080
const FLI_FOCUSER_STATUS_LIMIT = 0x00000040
const FLI_FOCUSER_STATUS_LEGACY = 0x10000000

const FLI_FILTER_WHEEL_PHYSICAL = 0x0100
const FLI_FILTER_WHEEL_VIRTUAL = 0
const FLI_FILTER_WHEEL_LEFT = FLI_FILTER_WHEEL_PHYSICAL | 0x00
const FLI_FILTER_WHEEL_RIGHT = FLI_FILTER_WHEEL_PHYSICAL | 0x01

const FLI_FILTER_STATUS_MOVING_CCW = 0x01
const FLI_FILTER_STATUS_MOVING_CW = 0x02

const FLI_FILTER_POSITION_UNKNOWN = 0xff
const FLI_FILTER_POSITION_CURRENT = 0x0200

const FLI_FILTER_STATUS_HOMING = 0x00000004
const FLI_FILTER_STATUS_HOME = 0x00000080
const FLI_FILTER_STATUS_HOME_LEFT = 0x00000080
const FLI_FILTER_STATUS_HOME_RIGHT = 0x00000040
const FLI_FILTER_STATUS_HOME_SUCCEEDED = 0x00000008

const FLI_IO_P0 = 0x01
const FLI_IO_P1 = 0x02
const FLI_IO_P2 = 0x04
const FLI_IO_P3 = 0x08

const FLI_FAN_SPEED_OFF = 0x00
const FLI_FAN_SPEED_ON = 0xffffffff

const FLI_EEPROM_USER = 0x00
const FLI_EEPROM_PIXEL_MAP = 0x01

const FLI_PIXEL_DEFECT_COLUMN = 0x00
const FLI_PIXEL_DEFECT_CLUSTER = 0x10
const FLI_PIXEL_DEFECT_POINT_BRIGHT = 0x20
const FLI_PIXEL_DEFECT_POINT_DARK = 0x30

# exports
const PREFIXES = ["FLI", "fli"]
for name in names(@__MODULE__; all=true), prefix in PREFIXES
    if startswith(string(name), prefix)
        @eval export $name
    end
end

end # module
