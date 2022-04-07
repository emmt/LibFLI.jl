# Julia interface to the Finger Lakes Instrumentation devices

This package provides a Julia interface to [Finger Lakes Instrumentation
(FLI)](https://www.flicamera.com/) devices, notably their cameras.


## Usage

### Basic usage

```julia
using LibFLI
FLI.set_debug_level("", :all)    # set the debug level
FLI.get_lib_version()            # get the library version
cam = FLI.Device("/dev/usbfli0", :usb, :camera) # open 1st USB camera
FLI.print_camera_info(cam)       # print characteristics of camera
```

Method `close(cam)` can be called to eventually close the device associated to
object `cam` but this is not mandatory as this is automatically done when the
object is reclaimed by the garbage collector.

As you may have noticed, `using LibFLI` exports symbol `FLI` which is an alias
for `LibFLI`.  This simplifies the writing of code as it allows you to write
`FLI.func` instead of `LibFLI.func` for calling function `func`.  If you do not
want this feature, call `import LibFLI` instead.


### Naming conventions

The API attempts to reflect that of the C library.  For readability, function
names are in [*snake case*](https://en.wikipedia.org/wiki/Snake_case) style and
without the `FLI` prefix (which is replaced by the name of the module); as an
example, `FLITriggerExposure` becomes `FLI.trigger_exposure`.  Constants are
replaced by symbolic names.  For example:

```julia
FLI.set_fan_speed(cam, :on)  # to switch the fan on
FLI.set_fan_speed(cam, :off) # to switch the fan off
```


### Camera configuration

Camera settings can be tuned individually via the functions of the SDK.  For
instance, to configure the camera `cam`, the following functions are available:

```julia
FLI.set_temperature(cam, degs) # to set the temperature in °C
FLI.set_exposure_time(cam, secs) # to set the exposure time in seconds
FLI.set_binning(cam, xbin, ybin) # to set the binning factors (in pixels)
FLI.set_image_area(cam, x0, y0, x1, y1) # to set the image area
FLI.set_frame_type(cam, frametype) # to set the frame type
FLI.set_nflushes(cam, nflushes) # to set the number of background flushes
FLI.control_background_flush(cam, bgflush) # to start/stop background flushing
FLI.set_bit_depth(cam, pixeltype) # to set the pixel type
FLI.set_fan_speed(cam, fanspeed) # to switch on/off the fan
FLI.control_shutter(cam, shutter) # to control the shutter
```

But calling these functions may be tedious, plus some functions (e.g.,
`FLI.set_image_area`) have weird parameters not directly understandable.  To
solve for these issues, a higher level interface is provided by:

```julia
FLI.configure_camera(cam; key=val, ...)
```

which takes the settings as any of the following keywords:

- `temperature` to specify the target temperature (in °C);

- `exposuretime` to specify the exposure time (in seconds);

- `width` to specify the width of the image area (in macro-pixels);

- `height` to specify the height of the image area (in macro-pixels);

- `xoff` to specify the horizontal offset of the image area (in pixels);

- `yoff` to specify the vertical offset of the image area (in pixels);

- `xbin` to specify the horizontal binning factor (in pixels);

- `ybin` to specify the vertical binning factor (in pixels);

- `frametype` to specify the frame type (value can be `:normal` for a normal
  frame where the shutter opens, `:dark` for a dark frame where the shutter
  remains closed, `:flood`, or `:rbi_flush`);

- `nflushes` to specify the number of background flushes;

- `bgflush` to control background flushing (value can be `:start` or `:stop`);

- `pixeltype` to specify the pixel type (value can be `UInt8` or `UInt16`);

- `fanspeed` to control the fan speed (value can be `:on` or `:off`);

- `shutter` to control the shutter (value can be `:close`, `:open`,
  `:external_trigger`, `:external_trigger_low`, `:external_trigger_high`, or
  `:external_exposure_control`);


### Taking images

To take an image with camera `cam`, call:

```julia
img = FLI.take_image(cam)
```

which starts an exposure, waits for this exposure to complete, and returns the
acquired image.

The pixel type, say `T`, may be specified:


```julia
img = FLI.take_image(T, cam)
```

will yield an image whose pixels have type `T`.  If unspecifed, `T = UInt16` is
assumed.  Beware that using the wrong pixel type may result in unexpected pixel
values (an internal buffer is however used to prevent segmentation faults).

The current camera settings (pixel type, exposure time, etc.) are used for the
image, they can be changed prior to taking the image with
`FLI.cobfigure_camera` (see above).

To avoid allocations, an exiting image can be reused with:

```julia
img = FLI.take_image!(cam, img)
```

which behaves as `FLI.take_image` except that is stores the acquired image in
`img` (and returns it).


### Connected devices

To quickly list connected devices, just call:

```julia
FLI.list_devices(:usb, :camera) # list connected USB cameras
FLI.list_devices(:serial)       # list devices connected to the serial port
```

For more control over connected devices, the method `FLI.foreach_device` can be
used to execute arbitrary code on connected devices.  This method takes a
function and any number of symbolic names specifying the interface(s) and
device type(s) to consider.  The function is called for each connected device
matching the requirements.  For example, `FLI.list_devices` can be emulated to
list all connected USB cameras:

```julia
FLI.foreach_device(:usb, :camera) do domain, filename, devname
    cam = FLI.Device(filename, domain)
    println("File: \"$filename\", name: \"$devname\", domain: $domain")
    FLI.print_camera_info(cam)
    close(cam)
end
```


## Completeness

Almost all functions of the FLI SDK are available.  Function `FLIUsbBulkIO` is
only available in the `Lib` sub-module.  List oriented functions
(`FLICreateList`, `FLIListFirst`, `FLIListNext`, `FLIFreeList`, `FLIList`, and
`FLIFreeList`) are not directly available as their usage is superseded by
`FLI.foreach_device` which provides a much better interface and internally
calls `FLICreateList`, `FLIListFirst`, `FLIListNext`, and `FLIFreeList`.


## Installation

### Installation of the FLI SDK

You have to compile and install the kernel modules for FLI devices and a shared
version of the LibFLI library.  The FLI SDK is open source but the [original
version](https://www.flicamera.com/software) compiles as a static library.  See
[libfli](https://git-cral.univ-lyon1.fr/tao/libfli) for an easy way to compile
a shared FLI library.


### Installation of the Julia interface

You have to clone the [`LibFLI`](https://github.com/emmt/LibFLI) repository:

```sh
git clone https://github.com/emmt/LibFLI.jl.git
```

In the `deps` sub-directory, create a file `deps.jl` which defines the constant
`libfli` with the path to the shared library.  For example:

```julia
const libfli = "/usr/local/lib/libfli.so"
```

Running:

```sh
julia LibFLI.jl/deps/build.jl
```

my be used to do this almost automatically.


## External links

If you are a Python user, you may be interested in the following projects:

- [pyfli](https://github.com/charris/pyfli);

- [python-FLI](https://github.com/cversek/python-FLI).

The place where to download official FLI software is
[here](https://www.flicamera.com/software).
