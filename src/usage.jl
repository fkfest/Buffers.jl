"""
    @print_buffer_usage(buf, ex)

Print buffer `buf` usage in expression `ex`.

The macro generates a body of a function that calculates the length of buffer `buf` 
in expression `ex`.
It is possible to use the macro with multiple buffers, e.g., 
`@print_buffer_usage buf1 buf2 begin ... end`.

All function calls with `buf` as an argument are replaced with `pseudo_<function>` calls.
`pseudo_alloc!`,`pseudo_drop!`, and `pseudo_reset!` functions are pre-defined,
custom `pseudo_`functions can be defined if necessary.

# Example
```julia
buf = Buffer(100000)
@print_buffer_usage buf begin
if true
  A = alloc!(buf, 10, 10, 20)
else
  A = alloc!(buf, 10, 10, 30)
end
B = alloc!(buf, 10, 10, 10)
if true
  C = alloc!(buf, 10, 20)
else
  C = alloc!(buf, 10, 30)
end
rand!(B)
rand!(C)
An = neuralyze(A)
@tensor An[i,j,k] = B[i,j,l] * C[l,k]
drop!(buf, B, C)
reset!(buf)
end
"""
macro print_buffer_usage(buf, ex)
  _print_buffer_usage(ex, buf)
  quote
    $(esc(ex))
  end
end

macro print_buffer_usage(buf1, buf2, ex)
  _print_buffer_usage(ex, buf1, buf2)
  quote
    $(esc(ex))
  end
end

macro print_buffer_usage(buf1, buf2, buf3, ex)
  _print_buffer_usage(ex, buf1, buf2, buf3)
  quote
    $(esc(ex))
  end
end

macro print_buffer_usage(buf1, buf2, buf3, buf4, ex)
  _print_buffer_usage(ex, buf1, buf2, buf3, buf4)
  quote
    $(esc(ex))
  end
end

is_expr(ex, head::Symbol) = Meta.isexpr(ex, head)

function _print_buffer_usage(ex, bufs::Symbol...)
  print("# Function to calculate length for buffer(s)")
  for buf in bufs
    print(" $buf")
  end
  println()
  println("# autogenerated by @print_buffer_usage")
  println("=============================================")
  display(_peak_buffer_usage(ex, bufs))
  println("=============================================")
  return
end

function _peak_buffer_usage(ex, bufs)
  _ex = ex
  Base.remove_linenums!(_ex)
  exb = _buffer_usage(_ex, bufs)
  bargs = []
  for buf in bufs
    # [lenbuf, peakbuf] = [0, 0]
    push!(bargs, Expr(:(=), Symbol("$buf"), :([0, 0])))
  end
  if Base.is_expr(exb, :block)
    append!(bargs, exb.args)
  else
    push!(bargs, exb)
  end
  if length(bufs) == 1
    push!(bargs, Expr(:return, Expr(:ref, Symbol("$(bufs[1])"), 2)))
  else
    push!(bargs, Expr(:return, Expr(:tuple, [Expr(:ref, Symbol("$buf"), 2) for buf in bufs]...)))
  end
  return Expr(:block, bargs...)
end

"""
    _buffer_usage(ex, bufs)

Allocations and deallocations together with corresponding `if`s 
in expression `ex`.
"""
function _buffer_usage(ex, bufs)
  if !(ex isa Expr)
    return
  end
  # go through all expressions in the block and return expressions 
  # that contain alloc!/drop!/reset functions
  if is_expr(ex, :block)
    buf_args = []
    for i in 1:length(ex.args)
      arg = _buffer_usage(ex.args[i], bufs)
      if !isnothing(arg)
        push!(buf_args, arg)
      end
    end
    if length(buf_args) > 0
      return Expr(:block, buf_args...)
    end
  elseif is_expr(ex, :(=))
    arg = _buffer_usage(ex.args[2], bufs)
    if !isnothing(arg)
      return Expr(:(=), ex.args[1], arg)
    end
  elseif is_expr(ex, :call)
    if any(buf -> buf in bufs, ex.args)
      return Expr(:call, Symbol("pseudo_$(ex.args[1])"), ex.args[2:end]...)
    end
  elseif is_expr(ex, :if) || is_expr(ex, :elseif)
    arg = _buffer_usage(ex.args[2], bufs)
    if length(ex.args) == 3
      arg2 = _buffer_usage(ex.args[3], bufs)
      if !isnothing(arg2)
        return Expr(ex.head, ex.args[1], arg, arg2)
      end
    end
    if !isnothing(arg)
      return Expr(ex.head, ex.args[1], arg)
    end
  else
    # generic case
    buf_args = []
    for i in 1:length(ex.args)
      arg = _buffer_usage(ex.args[i], bufs)
      if !isnothing(arg)
        push!(buf_args, arg)
      end
    end
    if length(buf_args) == 1
      return buf_args[1]
    elseif length(buf_args) > 1
      return Expr(:block, buf_args...)
    end
  end
  return
end

"""
    pseudo_alloc!(buf, dims...)

  Pseudo allocation function to calculate length for buffer.

  The function is used in combination with `@print_buffer_usage`.
"""
function pseudo_alloc!(buf, dims...)
  len = prod(dims)
  buf[1] += len
  buf[2] = max(buf[1], buf[2])
  return len
end

"""
    pseudo_drop!(buf, lens...)

  Pseudo drop function to calculate length for buffer.

  The function is used in combination with `@print_buffer_usage`.
"""
function pseudo_drop!(buf, lens...)
  buf[1] -= sum(lens)
  return
end

"""
    pseudo_reset!(buf)

  Pseudo reset function to calculate length for buffer.

  The function is used in combination with `@print_buffer_usage`.
"""
function pseudo_reset!(buf)
  buf[1] = 0
  return
end
