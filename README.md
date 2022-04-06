# Julia interface to the Finger Lakes Instrumentation devices

This package provides a Julia interface to [Finger Lakes Instrumentation
(FLI)](https://www.flicamera.com/) devices, notably their cameras.


## Usage

```julia
using LibFLI
LibFLI.set_debug_level("", :all)    # set the debug level
LibFLI.get_lib_version()            # get the library version
cam = LibFLI.Device("/dev/usbfli0") # open 1st USB camera
LibFLI.print_camera_info(cam)       # print may characteristics of camera
```

Method `close(cam)` can be called to eventually close the device associated to
object `cam` but this is not mandatory as this is automatically done when the
object is reclaimed by garbage collector.

The API attempts to reflect that of the C library.  Constants are replaced by
symbolic names.  For example:

```julia
LibFLI.set_fan_speed(cam, :on)  # to switch the fan on
LibFLI.set_fan_speed(cam, :off) # to switch the fan off
```

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
