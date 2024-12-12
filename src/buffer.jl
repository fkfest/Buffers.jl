
"""
    Buffer{T}

Buffer object to store data of type `T` with an offset.

The buffer allocates an extra element at the beginning which is used to check 
if the buffer can be extended and to ensure that pointers to the allocated 
arrays will never point to the same memory as the buffer.

If the buffer is used with [`reshape_buf!`](@ref), the offset is set to zero.
"""
struct Buffer{T}
  data::Vector{T}
  offset::Ref{Int}
  function Buffer{T}(len; extend=true) where {T}
    data = Vector{T}(undef, len + 1)
    data[1] = extend ? one(T) : zero(T)
    return new(data, 1)
  end
end

Buffer(len=0) = Buffer{Float64}(len)

Base.length(buf::Buffer) = length(buf.data) - 1

function used(buf::Buffer)
  return buf.offset[] - 1
end

function isextendable(buf::Buffer)
  return buf.data[1] == one(eltype(buf.data))
end

function set_extendable!(buf::Buffer, extend::Bool=true)
  buf.data[1] = extend ? one(eltype(buf.data)) : zero(eltype(buf.data))
  return
end

function alloc!(buf::Buffer{T}, dims...) where {T}
  @assert buf.offset[] >= 1 "Buffer is used with reshape_buf! and must be reset!"
  start = buf.offset[] + 1
  len = prod(dims)
  stop = start + len - 1
  if stop > length(buf.data)
    if isextendable(buf)
      resize!(buf.data, stop)
    else
      error("Buffer overflow!")
    end
  end
  buf.offset[] += len
  return reshape(view(buf.data, start:stop), dims)
end

function drop!(buf::Buffer, tensor::AbstractArray...)
  # order tensor from last to first
  order = sortperm([pointer(t) for t in tensor]; rev=true)
  for i in order
    len = length(tensor[i])
    @assert pointer(tensor[i]) == pointer(buf.data, buf.offset[] - len + 1) "Tensor must be the last allocated!"
    buf.offset[] -= len
  end
end

function reset!(buf::Buffer{T}) where {T}
  buf.offset[] = 1
  return
end

function reshape_buf!(buf::Buffer{T}, dims...; offset=0) where {T}
  @assert buf.offset[] <= 1 "Buffer is used with alloc! and must be reset!"
  buf.offset[] = 0
  len = prod(dims)
  start = offset + 2
  stop = offset + len + 1
  if stop > length(buf.data)
    if isextendable(buf)
      resize!(buf.data, stop)
    else
      error("Buffer overflow!")
    end
  end
  return reshape(view(buf.data, start:stop), dims)
end
