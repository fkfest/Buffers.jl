using Buffers

buf = Buffer(100)

a = alloc!(buf, 10)
b = alloc!(buf, 9,10)
a .= 1.0
b[:,:] .= a'
drop!(buf, a,b)

@buffer buf1(10) begin
  A = alloc!(buf1, 10)
  A .= 1.0
  drop!(buf1, A)
end

@buffer buf1(10) buf2(10) begin
  A = alloc!(buf1, 10)
  B = alloc!(buf2, 10)
  A .= 1.0
  B .= A
  drop!(buf1, A)
  drop!(buf2, B)
end

C = alloc!(buf, 10, 10)
@threadsbuffer tbuf(100) begin
  @sync for i = 1:10
    Threads.@spawn begin
      A = alloc!(tbuf, 10)
      A .= 1.0
      C[:,i] .= A
      drop!(tbuf, A)
      reset!(tbuf)
    end
  end
end
@test C == ones(10,10)
drop!(buf, C)
