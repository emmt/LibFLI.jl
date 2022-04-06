using Clang.Generators
using Clang.LibClang.Clang_jll

# Header files.
headers = map(normpath, ["/apps/include/libfli.h"])

# List of (unique and in order) include directories.
include_dirs = String[]
for dir in Iterators.map(dirname, headers)
    dir in include_dirs || push!(include_dirs, dir)
end

# The rest is pretty standard.
cd(@__DIR__)
options = load_options(joinpath(@__DIR__, "generator.toml"))
args = get_default_args()
for dir in include_dirs
    push!(args, "-I$dir")
end
ctx = create_context(headers, args, options)
build!(ctx)
