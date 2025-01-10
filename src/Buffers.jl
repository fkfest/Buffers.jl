"""
    Buffers module

This module contains functions to handle buffers.

The [`Buffer`](@ref) object is used to store data of type `T` with an offset,
while the [`ThreadsBuffer`](@ref) object is used to store data of type `T` with an offset for each thread.

The buffers are used to store data in a contiguous memory block and to avoid memory allocation in loops.
The buffers can be used with [`alloc!`](@ref) to allocate tensors of given dimensions,
[`drop!`](@ref) to drop tensors from the buffer, and [`reset!`](@ref) to reset the buffer to the initial state.

Alternativelly, the buffers can be reshaped with [`reshape_buf!`](@ref) to use the same memory block for different tensors
or to allocate tensors with a specific offset.

The size of the buffer can be extended if necessary, and the buffer can be set to be extendable (default) or not
at construction with [`Buffer`](@ref) or later with [`set_extendable!`](@ref).

In any case, the `::ThreadsBuffer` buffers should be released after use with [`Buffers.release!`](@ref) or [`reset!`](@ref).

If some functions complain about tensors being aliases or if the tensors will be used in C, 
the [`neuralyze`](@ref) function can be used to wipe the memory about the origin of the tensor.
Do not use this function if the size of the tensor might be changed in between,
i.e., neuralyze the tensor only after all necessary allocations are done.
"""
module Buffers

using PrecompileTools

export Buffer, ThreadsBuffer
export alloc!, drop!, reset!, repair!
export reshape_buf!
export used, nbuffers, with_buffer
export isextendable, set_extendable!
export neuralyze
export @print_buffer_usage
export pseudo_alloc!, pseudo_drop!, pseudo_reset!

include("buffer.jl")
include("threadsbuffer.jl")
include("usage.jl")

"""
    used(buf)

Return the number of elements used in buffer `buf`.

If the buffer is used with [`reshape_buf!`](@ref), `-1` is returned.

For `ThreadsBuffer`, return the number of elements used in the buffer of the current thread.
"""
function used end

"""
    alloc!(buf, dims...; extend=true)

  Allocate tensor of given dimensions in buffer `buf`.

  The tensor is allocated in the buffer starting at the current offset.
  The offset is increased by the length of the tensor.
  If `extend=true`, the buffer is extended if necessary.
  For `ThreadsBuffer`, the tensor is allocated in the buffer of the current thread.

  Return the allocated tensor.

```julia
julia> buf = Buffer(100000)
julia> A = alloc!(buf, 10, 10, 20) # 10x10x20 tensor
julia> B = alloc!(buf, 10, 10, 10) # 10x10x10 tensor starting after A
julia> C = alloc!(buf, 10, 20) # 10x20 tensor starting after B
julia> rand!(B)
julia> rand!(C)
julia> An = neuralyze(A) # tensor without origin
julia> @tensor An[i,j,k] = B[i,j,l] * C[l,k]
```
"""
function alloc!(buf, dims...; extend=true) end

"""
    drop!(buf, tensor...)

  Drop tensor(s) from buffer `buf`.

  Only last tensors can be dropped.
  For `ThreadsBuffer`, drop tensors from the buffer of the current thread.
"""
function drop!(buf, tensor...) end

"""
    reset!(buf)

  Reset buffer `buf` to the initial state.
  For `ThreadsBuffer`, reset the buffer of the current thread and release it.
"""
function reset!(buf) end

"""
    reshape_buf!(buf, dims...; offset=0, extend=true)

  Reshape (part of) a buffer to given dimensions (without copying),
  using `offset`.

  For `ThreadsBuffer`, reshape the buffer of the current thread.
  Call [`reset!(::ThreadsBuffer)`](@ref) or [`release!`](@ref) after use.

  It can be used, e.g., for itermediates in tensor contractions.

!!! warning "Warning" 
    Do not use this function together with [`alloc!`](@ref) or [`drop!`](@ref) on the same buffer!

# Example
```julia
julia> buf = Buffer(100000)
julia> A = reshape_buf!(buf, 10, 10, 20) # 10x10x20 tensor
julia> B = reshape_buf!(buf, 10, 10, 10, offset=2000) # 10x10x10 tensor starting at 2001
julia> B .= rand(10,10,10)
julia> C = rand(10,20)
julia> @tensor A[i,j,k] = B[i,j,l] * C[l,k]
```
"""
function reshape_buf!(buf, dims...; offset=0, extend=true) end

"""
    isextendable(buf)

  Check if buffer `buf` is extendable.
"""
function isextendable(buf) end

"""
    set_extendable!(buf, extend=true)

  Set buffer `buf` to be extendable or not.
"""
function set_extendable!(buf, extend=true) end

"""
    neuralyze(tensor::AbstractArray)

  Wipe the memory about origin of `tensor`.

  `tensor` is a (contiguous!) array that is a (possibly reshaped) view of a larger array.
  Return the same tensor pointing to the same memory, 
  but without the information about the origin.
  To be used together with [`alloc!`](@ref) or [`reshape_buf!`](@ref) to trick `Base.mightalias`.

!!! warning "Warning" 
    Note that this function is unsafe and should be used with caution!
    If too much memory is wiped, Julia might garbage-collect the
    original array and the tensor will point to invalid memory.
    Also don't use this function if the buffer-size might change in between.

!!! tip "Tip" 
    One can use `GC.@preserve` to prevent the garbage collection of the original array 
    (however, this shouldn't be necessary).

# Example
```julia
julia> buf = Buffer(100000)
julia> A = alloc(buf, 10, 10, 20) # 10x10x20 tensor
julia> B = alloc(buf, 10, 10, 10) # 10x10x10 tensor starting after A
julia> C = alloc(buf, 10, 20) # 10x20 tensor starting after B
julia> rand!(B)
julia> rand!(C)
julia> An = neuralyze(A) # tensor without origin but pointing to the same memory
julia> @tensor An[i,j,k] = B[i,j,l] * C[l,k]
```
"""
function neuralyze(tensor::AbstractArray)
  @assert iscontiguous_tensor(tensor) "Tensor must be contiguous!"
  return unsafe_wrap(Array, pointer(tensor), size(tensor); own=false)
end

"""
    iscontiguous_tensor(tensor::AbstractArray)

  Check if `tensor` is contiguous.

  Return `true` if `tensor` is a `Vector` or a `SubArray` that is contiguous.
"""
function iscontiguous_tensor(tensor::AbstractArray)
  vtensor = vec(tensor)
  return length(vtensor) == 0 || 
         (pointer(@view vtensor[end]) - pointer(vtensor)) / sizeof(eltype(vtensor)) ==
         length(vtensor) - 1
end

"""
    with_buffer(f::Function, buf::ThreadsBuffer)

  Execute function `f` with buffer `buf`.

  The buffer is released after the function is executed.

# Example
```julia
julia> buf = Buffer(10000)
julia> C = alloc!(buf, 10, 10, 20) # 10x10x20 destination tensor on a single thread
julia> tbuf = ThreadsBuffer(1000)
julia> Threads.@threads for k = 1:20
          with_buffer(tbuf) do bu
            A = alloc!(bu, 10, 10) # 10x10 tensor
            B = alloc!(bu, 10, 10) # 10x10 tensor
            rand!(A)
            rand!(B)
            @tensor C[:,:,k][i,j] = A[i,l] * B[l,j]
          end
        end
```
"""
function with_buffer(f::Function, buf::ThreadsBuffer)
  b = current_buffer(buf)
  try
    f(b)
  finally
    reset!(buf)
  end
end

@setup_workload begin
  @compile_workload begin
    buf = Buffer(100)
    A = alloc!(buf, 2)
    B = alloc!(buf, 2, 2)
    C = alloc!(buf, 2, 2, 2)
    D = alloc!(buf, 2, 2, 2, 2)
    drop!(buf, D)
    drop!(buf, B, C)
    len = used(buf)
    n!A = neuralyze(A)
    reset!(buf)
    A = reshape_buf!(buf, 2)
    B = reshape_buf!(buf, 2, 2)
    C = reshape_buf!(buf, 2, 2, 2)
    D = reshape_buf!(buf, 2, 2, 2, 2)
    reset!(buf)
    tbuf = ThreadsBuffer(100)
    @sync for i in 1:2
      Threads.@spawn begin
        A = alloc!(tbuf, 2)
        B = alloc!(tbuf, 2, 2)
        C = alloc!(tbuf, 2, 2, 2)
        D = alloc!(tbuf, 2, 2, 2, 2)
        drop!(tbuf, D)
        drop!(tbuf, B, C)
        len = used(tbuf)
        n!A = neuralyze(A)
        reset!(tbuf)
        A = reshape_buf!(tbuf, 2)
        B = reshape_buf!(tbuf, 2, 2)
        C = reshape_buf!(tbuf, 2, 2, 2)
        D = reshape_buf!(tbuf, 2, 2, 2, 2)
        reset!(tbuf)
      end
    end
  end
end

end # module
