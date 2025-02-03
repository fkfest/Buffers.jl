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

## Creating a manually allocated Buffer with `MAllocBuffer`

The [`MAllocBuffer`](@ref) type is used to create a buffer with manually allocated memory. The buffer is not extended automatically, and you have to free the memory manually. It is highly recommended to use [`@buffer`](@ref) macro instead of directly using `MAllocBuffer` to avoid memory leaks.
The advantage of using `MAllocBuffer` is that the allocated arrays are simple
`Array` objects, which can be passed to C functions without any issues, i.e.,
the `neuralyze` function is not needed.

[!WARNING]
After freeing the memory, the allocated arrays are no longer valid and should not be used.

```julia
buffer = MAllocBuffer(1000) # Create a manually allocated buffer of type Float64
...
free!(buffer) # Free the memory, the buffer and allocated arrays are no longer valid
```

## Creating a ThreadsBuffer

The [`ThreadsBuffer`](@ref) type extends the functionality of `Buffer` to support multi-threaded environments. It provides thread-safe operations for concurrent data manipulation.

```julia
tbuffer = ThreadsBuffer(1000) # Create a ThreadsBuffer of type Float64
```

All operations on `Buffer` can be performed on `ThreadsBuffer` as well.

The buffers in `ThreadsBuffer` are thread-local, meaning each task uses its own buffer. This allows for concurrent allocation and deallocation of memory without causing data corruption. After the task is done, the buffer has to be released with [`reset!`](@ref) or [`Buffers.release!`](@ref) to be reused by another task.

[`ThreadsMAllocBuffer`](@ref) is the manually allocated version of `ThreadsBuffer`, and it is highly recommended to use the [`@threadsbuffer`](@ref) macro instead of directly using `ThreadsMAllocBuffer` to avoid memory leaks.

```julia
@threadsbuffer buf(1000) begin # Create a manually allocated ThreadsBuffer of type Float64
...
end
```

## @buffer and @threadsbuffer macros

The [`@buffer`](@ref) and [`@threadsbuffer`](@ref) macros are used to create a manually allocated buffer with the specified size and type. The buffer is automatically freed when the scope of the macro ends.

```julia
@buffer buf(Int, 1000) begin # Create a manually allocated buffer of type Int with 1000 elements
A = alloc!(buf, 10, 10)
...
end
```

Two buffers can be created in the same scope, and they are automatically freed when the scope ends.

```julia
@buffer buf1(Int, 1000) buf2(Float64, 2000) begin
A = alloc!(buf1, 10, 10)
B = alloc!(buf2, 20, 5)
...
end
```

The [`@threadsbuffer`](@ref) macro is used to create a manually allocated buffer in a threaded environment. The buffer is automatically released when the scope of the macro ends.

```julia
@threadsbuffer tbuf(Float64, 1000) begin 
  @sync for i in 1:4
    Threads.@spawn begin
      A = alloc!(tbuf, 10, 10)
      ...
      drop!(tbuf, A)
      reset!(tbuf) # Release the buffer for the current thread
    end
  end
  ...
end
```

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

For [`ThreadsBuffer`](@ref) and [`ThreadsMAllocBuffer`](@ref), the [`Buffers.release!`](@ref) function is used to release the buffer of the current thread.
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

The [`neuralyze`](@ref) function is used to wipe the memory about the origin of a tensor. This can be helpful when you need to bypass Julia's aliasing checks or ensure that a tensor is treated as an independent array for example in a C call. This function is not needed when using `MAllocBuffer` or `ThreadsMAllocBuffer`.

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

# Create a ThreadsMAllocBuffer
@threadsbuffer tbuffer(1000) begin
  # Use ThreadsMAllocBuffer in a threaded loop
  @sync for i in 1:4
    Threads.@spawn begin
      A = alloc!(tbuffer, 10, 10)
      B = alloc!(tbuffer, 20, 5)
      drop!(tbuffer, A, B)
      reset!(tbuffer) # Release the buffer for the current thread
    end
  end
end 

# Reshape the buffer
C = reshape_buf!(buffer, 10, 10)
D = reshape_buf!(buffer, 20, 5, offset=100)
```

For more detailed information, please refer to the other sections of the documentation.
