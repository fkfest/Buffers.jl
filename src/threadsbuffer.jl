"""
    ThreadsBuffer{T}

Buffer object to store data of type `T` for each thread.

By default, the buffer is created for `nthreads()` threads,
i.e., each thread has its own buffer [`Buffer`](@ref).

Create the buffer with `ThreadsBuffer{T}(len, nbuf=Threads.nthreads())` and use it with [`alloc!`](@ref), [`drop!`](@ref), [`reset!`](@ref), etc.

!!! warning "Warning"
    Always [`reset!`](@ref) or [`Buffers.release!`](@ref) the buffer after use!

# Example
```julia
julia> buf = Buffer(10000)
julia> C = alloc!(buf, 10, 10, 20) # 10x10x20 destination tensor on a single thread
julia> tbuf = ThreadsBuffer(1000) # 1000 elements buffer for nthreads() threads each
julia> Threads.@threads for k = 1:20
          A = alloc!(tbuf, 10, 10) # 10x10 tensor
          B = alloc!(tbuf, 10, 10) # 10x10 tensor
          rand!(A)
          rand!(B)
          @tensor C[:,:,k][i,j] = A[i,l] * B[l,j]
          reset!(tbuf)
        end
```
"""
struct ThreadsBuffer{T}
  buffers::Vector{Buffer{T}}
  pool::Vector{Int}
  condition::Threads.Condition
  id::Symbol
  function ThreadsBuffer{T}(buffers::Vector{Buffer{T}}) where {T}
    return new(buffers, [1:length(buffers);], Threads.Condition(), gensym(:tbuffer))
  end
end

function ThreadsBuffer{T}(len::Int, n::Int=Threads.nthreads()) where {T}
  return ThreadsBuffer{T}([Buffer{T}(len) for _ in 1:n])
end
ThreadsBuffer(len::Int, n::Int=Threads.nthreads()) = ThreadsBuffer{Float64}(len, n)

"""
    nbuffers(buf::ThreadsBuffer)

Return the number of buffers in `buf::ThreadsBuffer`.
"""
nbuffers(buf::ThreadsBuffer) = length(buf.buffers)

"""
    current_buffer_index(buf::ThreadsBuffer)

Return the index of the buffer of the current thread.

If the buffer is not available, wait until it is released.
"""
function current_buffer_index(buf::ThreadsBuffer)
  get!(task_local_storage(), buf.id) do
    lock(buf.condition) do
      while isempty(buf.pool)
        wait(buf.condition)
      end
      return pop!(buf.pool)
    end
  end
end

"""
    current_buffer(buf::ThreadsBuffer{T})

Return the buffer of the current thread.

If the buffer is not available, wait until it is released.
"""
function current_buffer(buf::ThreadsBuffer{T}) where {T}
  return buf.buffers[current_buffer_index(buf)]
end

Base.length(buf::ThreadsBuffer) = length(current_buffer(buf))

used(buf::ThreadsBuffer) = used(current_buffer(buf))

function isextendable(buf::ThreadsBuffer)
  return isextendable(current_buffer(buf))
end

function set_extendable!(buf::ThreadsBuffer, extend::Bool=true)
  set_extendable!(current_buffer(buf), extend)
  return
end

function alloc!(buf::ThreadsBuffer{T}, dims...) where {T}
  return alloc!(current_buffer(buf), dims...)
end

function drop!(buf::ThreadsBuffer, tensor::AbstractArray...)
  return drop!(current_buffer(buf), tensor...)
end

function reset!(buf::ThreadsBuffer{T}) where {T}
  reset!(current_buffer(buf))
  return release!(buf)
end

"""
    release!(buf::ThreadsBuffer)

Release buffer of the current thread.
"""
function release!(buf::ThreadsBuffer)
  lock(buf.condition) do
    @assert used(current_buffer(buf)) == 0 "Buffer is not empty! Use reset! to release the buffer."
    push!(buf.pool, current_buffer_index(buf))
    delete!(task_local_storage(), buf.id)
    notify(buf.condition)
  end
  return
end

"""
    repair!(buf::ThreadsBuffer)

Repair ThreadsBuffer `buf` by releasing all buffers and resetting the pool.

This function should be used after the threaded loop 
if the buffers were not released properly.
"""
function repair!(buf::ThreadsBuffer)
  for i in 1:nbuffers(buf)
    reset!(buf.buffers[i])
    push!(buf.pool, i)
  end
end

function reshape_buf!(buf::ThreadsBuffer{T}, dims...; offset=0) where {T}
  return reshape_buf!(current_buffer(buf), dims...; offset=offset)
end
