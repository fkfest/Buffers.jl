
abstract type AbstractThreadsBuffer end

"""
    ThreadsBuffer{T}

Buffer object to store data of type `T` for each thread.

By default, the buffer is created for `nthreads()` threads,
i.e., each thread has its own buffer [`Buffer`](@ref).

Create the buffer with `ThreadsBuffer{T}(len, nbuf=Threads.nthreads())` and use it with [`alloc!`](@ref), [`drop!`](@ref), [`reset!`](@ref), etc.

!!! warning "Warning"
    Always [`reset!`](@ref) or [`Buffers.release!`](@ref) the buffer after use!


!!! warning "Warning"
    The memory is allocated manually, therefore the buffer must be freed manually as well.
    The buffer is intended to be used with [`@threadsbuffer`](@ref) macro, which frees the buffer after use.

# Example
```julia
julia> buf = Buffer(10000)
julia> C = alloc!(buf, 10, 10, 20) # 10x10x20 destination tensor on a single thread
julia> @threadsbuffer tbuf(1000) begin # 1000 elements buffer for nthreads() threads each
julia>  Threads.@threads for k = 1:20
          A = alloc!(tbuf, 10, 10) # 10x10 tensor
          B = alloc!(tbuf, 10, 10) # 10x10 tensor
          rand!(A)
          rand!(B)
          @tensor C[:,:,k][i,j] = A[i,l] * B[l,j]
          reset!(tbuf)
        end
       end
```
"""
struct ThreadsBuffer{T} <: AbstractThreadsBuffer
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
    ThreadsMAllocBuffer{T}

[`MAllocBuffer`](@ref) object to store data of type `T` for each thread.

By default, the buffer is created for `nthreads()` threads,
i.e., each thread has its own buffer [`MAllocBuffer`](@ref).

Create the buffer with `ThreadsMAllocBuffer{T}(len, nbuf=Threads.nthreads())` and use it with [`alloc!`](@ref), [`drop!`](@ref), [`reset!`](@ref), etc.

!!! warning "Warning"
    Always [`reset!`](@ref) or [`Buffers.release!`](@ref) the buffer after use in each thread!

!!! warning "Warning"
    The memory is allocated manually, therefore the buffer must be freed manually as well.
    The buffer is intended to be used with [`@threadsbuffer`](@ref) macro, which frees the buffer after use.

# Example
```julia
@buffer buf(10000) begin
  C = alloc!(buf, 10, 10, 20) # 10x10x20 destination tensor on a single thread
  @threadsbuffer tbuf(1000) begin # 1000 elements buffer for nthreads() threads each
    @sync for k = 1:20
      Threads.@spawn begin
        A = alloc!(tbuf, 10, 10) # 10x10 tensor
        B = alloc!(tbuf, 10, 10) # 10x10 tensor
        rand!(A)
        rand!(B)
        @tensor C[:,:,k][i,j] = A[i,l] * B[l,j]
        reset!(tbuf)
      end 
    end
  end # free threadsbuffer tbuf
end # free buffer buf
```
"""
struct ThreadsMAllocBuffer{T} <: AbstractThreadsBuffer
  buffers::Vector{MAllocBuffer{T}}
  pool::Vector{Int}
  condition::Threads.Condition
  id::Symbol
  function ThreadsMAllocBuffer{T}(buffers::Vector{MAllocBuffer{T}}) where {T}
    return new(buffers, [1:length(buffers);], Threads.Condition(), gensym(:tbuffer))
  end
end

function ThreadsMAllocBuffer{T}(len::Int, n::Int=Threads.nthreads()) where {T}
  return ThreadsMAllocBuffer{T}([MAllocBuffer{T}(len) for _ in 1:n])
end
ThreadsMAllocBuffer(len::Int, n::Int=Threads.nthreads()) = ThreadsMAllocBuffer{Float64}(len, n)

free!(buf::ThreadsMAllocBuffer) = free!.(buf.buffers)


"""
    nbuffers(buf::AbstractThreadsBuffer)

Return the number of buffers in `buf::ThreadsBuffer`.
"""
nbuffers(buf::AbstractThreadsBuffer) = length(buf.buffers)

"""
    current_buffer_index(buf::AbstractThreadsBuffer)

Return the index of the buffer of the current thread.

If the buffer is not available, wait until it is released.
"""
function current_buffer_index(buf::AbstractThreadsBuffer)
  index::Int = get!(task_local_storage(), buf.id) do
    lock(buf.condition) do
      while isempty(buf.pool)
        wait(buf.condition)
      end
      return pop!(buf.pool)
    end
  end
  return index
end

"""
    current_buffer(buf::AbstractThreadsBuffer)

Return the buffer of the current thread.

If the buffer is not available, wait until it is released.
"""
function current_buffer(buf::AbstractThreadsBuffer)
  return buf.buffers[current_buffer_index(buf)]
end

Base.length(buf::AbstractThreadsBuffer) = length(current_buffer(buf))

used(buf::AbstractThreadsBuffer) = used(current_buffer(buf))

function isextendable(buf::AbstractThreadsBuffer)
  return isextendable(current_buffer(buf))
end

function set_extendable!(buf::AbstractThreadsBuffer, extend::Bool=true)
  set_extendable!(current_buffer(buf), extend)
  return
end

function alloc!(buf::AbstractThreadsBuffer, dims...)
  return alloc!(current_buffer(buf), dims...)
end

function drop!(buf::AbstractThreadsBuffer, tensor::AbstractArray...)
  return drop!(current_buffer(buf), tensor...)
end

function reset!(buf::AbstractThreadsBuffer)
  reset!(current_buffer(buf))
  return release!(buf)
end

"""
    release!(buf::AbstractThreadsBuffer)

Release buffer of the current thread.
"""
function release!(buf::AbstractThreadsBuffer)
  lock(buf.condition) do
    @assert used(current_buffer(buf)) == 0 "Buffer is not empty! Use reset! to release the buffer."
    push!(buf.pool, current_buffer_index(buf))
    delete!(task_local_storage(), buf.id)
    notify(buf.condition)
  end
  return
end

"""
    repair!(buf::AbstractThreadsBuffer)

Repair ThreadsBuffer `buf` by releasing all buffers and resetting the pool.

This function should be used after the threaded loop 
if the buffers were not released properly.
"""
function repair!(buf::AbstractThreadsBuffer)
  for i in 1:nbuffers(buf)
    reset!(buf.buffers[i])
    push!(buf.pool, i)
  end
end

function reshape_buf!(buf::AbstractThreadsBuffer, dims...; offset=0)
  return reshape_buf!(current_buffer(buf), dims...; offset=offset)
end

"""
    @threadsbuffer(specs, ex)

Create a [`ThreadsMAllocBuffer`](@ref) object with the given specifications and execute the expression `ex`.

The specifications `specs` can be:
- `buf(100)` creates a buffer `buf` of type `Float64` with length `100`.
- `buf(Int, 100)` creates a buffer `buf` of type `Int` with length `100`.
- `buf(Int, 100, 4)` creates a buffer `buf` of type `Int` with length `100` for `4` threads.
"""
macro threadsbuffer(specs, ex)
  buf, T, len, n = _parse_specs_tb(specs)
  quote
    $(esc(buf)) = ThreadsMAllocBuffer{$(esc(T))}($(esc(len)), $(esc(n)))
    $(esc(ex))
    free!($(esc(buf)))
    $(esc(buf)) = nothing
  end
end

"""
    @threadsbuffer(specs, specs2, ex)

Create two [`ThreadsMAllocBuffer`](@ref) objects with the given specifications and execute the expression `ex`.
"""
macro threadsbuffer(specs, specs2, ex)
  buf, T, len, n = _parse_specs_tb(specs)
  buf2, T2, len2, n2 = _parse_specs_tb(specs2)
  quote
    $(esc(buf)) = ThreadsMAllocBuffer{$(esc(T))}($(esc(len)), $(esc(n)))
    $(esc(buf2)) = ThreadsMAllocBuffer{$(esc(T2))}($(esc(len2)), $(esc(n2)))
    $(esc(ex))
    free!($(esc(buf2)))
    free!($(esc(buf)))
    $(esc(buf2)) = nothing
    $(esc(buf)) = nothing
  end
end

function _parse_specs_tb(specs)
  @assert Meta.isexpr(specs, :call) "Invalid buffer specification!"
  if length(specs.args) == 2
    name = specs.args[1] 
    T = :Float64
    len = specs.args[2]
    n = :(Threads.nthreads())
  elseif length(specs.args) == 3
    name = specs.args[1]
    T = specs.args[2]
    len = specs.args[3]
    n = :(Threads.nthreads())
  elseif length(specs.args) == 4
    name = specs.args[1]
    T = specs.args[2]
    len = specs.args[3]
    n = specs.args[4]
  else
    "Invalid buffer specification!"
  end
  return name, T, len, n
end