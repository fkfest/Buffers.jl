# Buffers.jl Documentation

Buffers.jl is a Julia package designed to provide efficient and flexible buffer management for various data types. It offers a range of functionalities to handle dynamic data storage needs, including resizing, appending, and accessing elements with minimal overhead. This package is particularly useful for applications that require high-performance data manipulation and storage solutions.

## Key Features

- **Dynamic Buffer Management**: Efficiently allocate and deallocate memory for multidimensional arrays.
- **Thread-Safe Operations**: Support for multi-threaded environments with `ThreadsBuffer`.
- **High Performance**: Minimize overhead and maximize performance for data-intensive applications.
- **Flexible Usage**: Easily reshape buffers and manage memory without frequent reallocations.
- **Advanced Memory Manipulation**: Use `neuralyze` to manipulate tensor aliasing and optimize performance in complex computations.

Buffers.jl is ideal for scientific computing, data analysis, and any application where efficient memory management is crucial.

## Installation

To install Buffers.jl, use the Julia package manager. From the Julia REPL, type `]` to enter the Pkg REPL mode and run:

```julia
pkg> add Buffers
```

## Usage

To use Buffers.jl, import the package and create a buffer object:

```julia
using Buffers

buffer = Buffer{Int}()
```

The size of the buffer is automatically adjusted based on the elements added to it. However, to avoid reallocation you can specify the initial size of the buffer (number of elements) when creating it:

```julia
buffer = Buffer(100)
```

You can then perform various operations on the buffer, such as allocating memory and clearing the buffer:

```julia
A = alloc!(buffer, 10, 10)
drop!(buffer, A)
reset!(buffer) # To clear all tensors from the buffer
```

For multi-threaded environments, you can use `ThreadsBuffer` to create thread-safe buffers:

```julia
tbuffer = ThreadsBuffer(1000)
```

All operations on `Buffer` can be performed on `ThreadsBuffer` as well. The buffers in `ThreadsBuffer` are thread-local, allowing for concurrent allocation and deallocation of memory without data corruption.

Buffers.jl also provides the `@buffer` and `@threadsbuffer` macros to create manually allocated buffers with the specified size and type. The buffer is automatically freed when the scope of the macro ends:

```julia
@buffer buf(Int, 1000) begin
  A = alloc!(buf, 10, 10)
  B = alloc!(buf, 10, 5)
  A .= 0.0
  B .= 1.0
  drop!(buf, A)
  drop!(buf, B)
end
```

For more detailed usage instructions and examples, please refer to the following sections of the documentation.
