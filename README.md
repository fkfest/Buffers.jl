# Buffers.jl
  
  [![Stable](https://img.shields.io/badge/docs-stable-blue.svg)](https://fkfest.github.io/Buffers.jl)

Buffers.jl is a Julia package that provides efficient and flexible buffer management for various data types. It is designed to handle dynamic data storage needs, offering functionalities such as resizing, appending, and accessing elements with minimal overhead. This package is ideal for applications requiring high-performance data manipulation and storage solutions.

## Types

### `Buffer`

The `Buffer` type in Buffers.jl is a dynamic array-like structure that allows efficient storage and manipulation of data. It supports various operations such as:

- **Allocation**: Create a multidimensional array on the buffer.
- **Deallocation**: Free the buffer's memory.
- **Clearing**: Remove all elements from the buffer.

The `Buffer` type is designed to minimize overhead and maximize performance, making it suitable for high-performance applications.

### `ThreadsBuffer`

The `ThreadsBuffer` type extends the functionality of `Buffer` to support multi-threaded environments. It provides thread-safe operations, ensuring that multiple threads can interact with the buffer without causing data corruption or inconsistencies. Key features include:

- **Thread-Safe allocation**: Multiple threads can allocate memory concurrently.
- **Thread-Safe deallocation**: Safely free memory without causing data corruption.
- **Thread-Safe clearing**: Remove all elements from the buffer.

`ThreadsBuffer` is ideal for applications that require concurrent data manipulation and high throughput.

## Installation

You can install Buffers.jl using the Julia package manager. From the Julia REPL, type `]` to enter the Pkg REPL mode and run:

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

You can then perform various operations on the buffer, such as allocating memory, appending elements, and clearing the buffer:

```julia
A = alloc!(buffer, 10, 10)
drop!(buffer, A)
reset!(buffer) # To clear all tensors from the buffer
```

You can also use the `neuralyze` function to remove aliasing information from tensors allocated in the buffer. This is useful in advanced scenarios where you need to ensure tensors are treated as independent.

For more information on how to use Buffers.jl, please refer to the [documentation](fkfest.github.io/Buffers.jl).
