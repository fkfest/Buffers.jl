using Buffers

buf = Buffer(100)

a = alloc!(buf, 10)
b = alloc!(buf, 9,10)
a .= 1.0
b[:,:] .= a'
drop!(buf, a,b)
