
"""
    MAllocBuffer{T}

Buffer object to store data of type `T` with an offset. The buffer memory is manually allocated and deallocated
and is not extendable.

The buffer allocates an extra element at the beginning which is used to check 
if the buffer can be extended and to ensure that pointers to the allocated 
arrays will never point to the same memory as the buffer.

If the buffer is used with [`reshape_buf!`](@ref), the offset is set to zero.

!!! warning "Warning"
    The memory is allocated manually, therefore the buffer must be freed manually as well.

!!! tip "Tip"
    The buffer is intended to be used with [`@buffer`](@ref) macro, which frees the buffer after use.

# Example
```julia
julia> @buffer buf(100) begin
         A = alloc!(buf, 10, 10)
         B = alloc!(buf, 10, 10)
         C = alloc!(buf, 10, 10)
         A .= 1.0
         B .= 2.0
         @tensor C[i,j] = A[i,l] * B[l,j]
       end
```
"""
struct MAllocBuffer{T} <: AbstractBuffer
  data::Ptr{T}
  data_length::Int
  offset::Base.RefValue{Int}
  function MAllocBuffer{T}(len; extend=false) where {T}
    @assert !extend "MAllocBuffer is not extendable!"
    data_length = len + 1
    data = malloc(T, data_length)
    unsafe_store!(data, zero(T))
    return new(data, data_length, Ref(1))
  end
end

malloc(T, len) = Ptr{T}(Libc.malloc(Int(sizeof(T) * len)))
free(ptr::Ptr{T}) where {T} = Libc.free(ptr)

"""
    free!(buf)

Free the memory of buffer `buf`.
"""
free!(buf::MAllocBuffer) = free(buf.data)

MAllocBuffer(len=0) = MAllocBuffer{Float64}(len)

Base.length(buf::MAllocBuffer) = buf.data_length - 1

function isextendable(buf::MAllocBuffer)
  return false
end

function set_extendable!(buf::MAllocBuffer, extend::Bool=true)
  if extend
    error("MAllocBuffer is not extendable!")
  end
  return
end

Base.@propagate_inbounds function alloc!(buf::MAllocBuffer{T}, dims...) where {T}
  @boundscheck(@assert buf.offset[] >= 1 "Buffer is used with reshape_buf! and must be reset!")
  start = buf.offset[] 
  len = prod(dims)
  @boundscheck begin
    if start + len > buf.data_length
      error("Buffer overflow!")
    end
  end
  buf.offset[] += len
  return unsafe_wrap(Array, buf.data + start*sizeof(T), dims; own=false)
end

function drop!(buf::MAllocBuffer{T}, tensor::AbstractArray...) where {T}
  # order tensor from last to first (and if they have the same pointer, from largest to smallest)
  order = sortperm([(pointer(t)=>length(t)) for t in tensor]; rev=true)
  for i in order
    len = length(tensor[i])
    @assert pointer(tensor[i]) == buf.data + sizeof(T)*(buf.offset[] - len) "Tensor must be the last allocated!"
    buf.offset[] -= len
  end
end

Base.@propagate_inbounds function reshape_buf!(buf::MAllocBuffer{T}, dims...; offset=0) where {T}
  @boundscheck(@assert buf.offset[] <= 1 "Buffer is used with alloc! and must be reset!")
  buf.offset[] = 0
  len = prod(dims)
  start = offset + 1
  @boundscheck begin
    if start + len > buf.data_length
      error("Buffer overflow!")
    end
  end
  return unsafe_wrap(Array, buf.data + start*sizeof(T), dims; own=false)
end

"""
    @buffer(specs, ex)

Create a [`MAllocBuffer`](@ref) object with the given specifications `specs` 
and execute the expression `ex` with the buffer.

The `specs` have the following format:
- `buf(100)` creates a buffer `buf` of type `Float64` with length `100`.
- `buf(Int, 100)` creates a buffer `buf` of type `Int` with length `100`.

The buffer is freed after the expression is executed.

# Example
```julia
@buffer buf(Float64, 300) begin
  A = alloc!(buf, 10, 10)
  B = alloc!(buf, 10, 10)
  C = alloc!(buf, 10, 10)
  rand!(A)
  rand!(B)
  @tensor C[i,j] = A[i,l] * B[l,j]
end
```
"""
macro buffer(specs, ex)
  buf, T, len = _parse_specs(specs)
  quote
    let $(esc(buf)) = MAllocBuffer{$(esc(T))}($(esc(len)))
      try
        $(esc(ex))
      finally
        free!($(esc(buf)))
      end
    end
  end
end

"""
    @buffer(specs, specs2, ex)

Create two [`MAllocBuffer`](@ref) objects with the given specifications `specs` and `specs2` 
and execute the expression `ex` with the buffers.
"""
macro buffer(specs, specs2, ex)
  buf, T, len = _parse_specs(specs)
  buf2, T2, len2 = _parse_specs(specs2)
  quote
    let $(esc(buf)) = MAllocBuffer{$(esc(T))}($(esc(len))),
        $(esc(buf2)) = MAllocBuffer{$(esc(T2))}($(esc(len2)))
      try
        $(esc(ex))
      finally
        free!($(esc(buf2)))
        free!($(esc(buf)))
      end
    end
  end
end

function _parse_specs(specs)
  @assert Meta.isexpr(specs, :call) "Invalid buffer specification!"
  if length(specs.args) == 2
    name = specs.args[1] 
    T = :Float64
    len = specs.args[2]
  elseif length(specs.args) == 3
    name = specs.args[1]
    T = specs.args[2]
    len = specs.args[3]
  else
    error("Invalid buffer specification!")
  end
  return name, T, len
end