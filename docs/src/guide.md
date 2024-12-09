# Buffers.jl Usage Guide

This guide provides detailed instructions and examples on how to use the Buffers.jl package.

## Creating a Buffer

To create a buffer, you can use the [`Buffer`](@ref) type. The buffer is automatically resized based on the elements added to it.

```julia
using Buffers

buffer = Buffer{Int}() # Create a buffer of type Int
```

You can also specify the initial size of the buffer (number of elements) to avoid reallocation.

```julia
buffer = Buffer(100) # Create a buffer with an initial size of 100 elements
```

## Creating a ThreadsBuffer

The [`ThreadsBuffer`](@ref) type extends the functionality of `Buffer` to support multi-threaded environments. It provides thread-safe operations for concurrent data manipulation.

```julia
tbuffer = ThreadsBuffer(1000) # Create a ThreadsBuffer of type Float64
```

All operations on `Buffer` can be performed on `ThreadsBuffer` as well.

The buffers in `ThreadsBuffer` are thread-local, meaning each task uses its own buffer. This allows for concurrent allocation and deallocation of memory without causing data corruption. After the task is done, the buffer has to be released with [`reset!`](@ref) or [`Buffers.release!`](@ref) to be reused by another task.

## Allocation with `alloc!`

The [`alloc!`](@ref) function is used to allocate memory for tensors in the buffer.

```julia
using Buffers

buffer = Buffer(1000)
A = alloc!(buffer, 10, 10) # Allocate a 10x10 tensor
B = alloc!(buffer, 20, 5)  # Allocate a 20x5 tensor
```

## Deallocation with `drop!`

The [`drop!`](@ref) function is used to deallocate memory for tensors from the buffer.

```julia
drop!(buffer, A) # Deallocate tensor A
drop!(buffer, B) # Deallocate tensor B
```

## Resetting the Buffer with `reset!`

The [`reset!`](@ref) function is used to reset the buffer to its initial state, clearing all allocated memory.

```julia
reset!(buffer) # Reset the buffer
```

## Releasing the Buffer with `Buffers.release!`

For [`ThreadsBuffer`](@ref), the [`Buffers.release!`](@ref) function is used to release the buffer of the current thread.
Note: the [`reset!`](@ref) function includes a call to `release!`.

```julia
tbuffer = ThreadsBuffer(1000)
Threads.@threads for i in 1:4
    A = alloc!(tbuffer, 10, 10)
    drop!(tbuffer, A)
    Buffers.release!(tbuffer) # Release the buffer for the current thread
end
```

## Reshaping the Buffer with `reshape_buf!`

The [`reshape_buf!`](@ref) function is used to reshape the buffer to a new set of dimensions without copying the data or explicitly allocating a tensor on the buffer.

```julia
buffer = Buffer(1000)
A = reshape_buf!(buffer, 10, 10) # Reshape buffer to a 10x10 tensor
B = reshape_buf!(buffer, 20, 5, offset=100) # Reshape buffer to a 20x5 tensor starting at offset 100
```

## Neuralyzing Tensors with `neuralyze`

The [`neuralyze`](@ref) function is used to wipe the memory about the origin of a tensor. This can be helpful when you need to bypass Julia's aliasing checks or ensure that a tensor is treated as an independent array for example in a C call.

```julia
A = alloc!(buffer, 10, 10)
An = neuralyze(A) # Neuralyze tensor A
```

## Complete Example

Here is a complete example demonstrating the usage of [`alloc!`](@ref), [`drop!`](@ref), [`reset!`](@ref), and [`reshape_buf!`](@ref) functions:

```julia
using Buffers

# Create a buffer
buffer = Buffer(1000)

# Allocate tensors
A = alloc!(buffer, 10, 10)
B = alloc!(buffer, 20, 5)

# Perform operations on tensors
rand!(A)
rand!(B)

# Deallocate tensors
drop!(buffer, A)
drop!(buffer, B)

# Create a ThreadsBuffer
tbuffer = ThreadsBuffer(1000)

# Use ThreadsBuffer in a threaded loop
@sync for i in 1:4
  Threads.@spawn begin
    A = alloc!(tbuffer, 10, 10)
    B = alloc!(tbuffer, 20, 5)
    drop!(tbuffer, A, B)
    reset!(tbuffer) # Release the buffer for the current thread
  end
end

# Reshape the buffer
C = reshape_buf!(buffer, 10, 10)
D = reshape_buf!(buffer, 20, 5, offset=100)
```

For more detailed information, please refer to the other sections of the documentation.
