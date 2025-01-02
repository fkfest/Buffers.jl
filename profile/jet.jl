using Buffers
using JET


function test(lenbuf, d1, d2)
  buf = Buffer(lenbuf)
  A = alloc!(buf, d1,d2)
  B = alloc!(buf, d1,d2)
  A .= 1.0
  B .= 2.0
  test!(A)
  #show(A)
  #C = A + B
  test2(A, B)
  drop!(buf, B)
  drop!(buf, A)
end

function test2(A, B)
  C = A + B
end

function test!(A::AbstractArray{Float64,2})
  A .+= 0.5
end

function main()
lenbuf = 1000
d1 = d2 = 10
@report_opt target_modules=(@__MODULE__, Buffers) test(lenbuf, d1, d2)
#test(lenbuf, d1, d2)
end
@time main()
