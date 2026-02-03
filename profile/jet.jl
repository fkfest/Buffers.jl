using Buffers
using LinearAlgebra
using JET

function jtest2(A, B)
  C = A + B
end

function mytest!(A::AbstractArray{Float64,2})
  A .+= 0.5
end

function jtest(lenbuf, d1, d2)
  buf = Buffer(lenbuf)
  A1 = alloc!(buf, d1,d2)
  B1 = alloc!(buf, d1,d2)
  A1 .= 1.0
  B1 .= 2.0
  mytest!(A1)
  #show(A1)
  #C = A1 + B1
  jtest2(A1, B1)
  drop!(buf, B1)
  drop!(buf, A1)
  @threadsbuffer tbuf(1000) begin # 1000 elements buffer for nthreads() threads each
    Threads.@threads for k = 1:20
      bbuf = reshape_buf!(tbuf, length(tbuf))
      reset!(tbuf)
      A = alloc!(tbuf, 10, 10) # 10x10 tensor
      B = alloc!(tbuf, 10, 10) # 10x10 tensor
      A .= 1.0
      B .= 2.0
    
      reset!(tbuf)
    end
  end
  @buffer mbuf(100) begin
    Am = alloc!(mbuf, 10, 10)
    Bm = alloc!(mbuf, 10, 10)
    Cm = alloc!(mbuf, 10, 10)
    Am .= 1.0
    Bm .= 2.0
    mul!(Cm, Am, Bm)
    drop!(mbuf, Bm, Am)
  end
  return 
end


function main()
lenbuf = 1000
d1 = d2 = 10
@report_opt ignored_modules=(Base,Threads,) target_modules=(@__MODULE__, Buffers) jtest(lenbuf, d1, d2)
# jtest(lenbuf, d1, d2)
end
@time main()
