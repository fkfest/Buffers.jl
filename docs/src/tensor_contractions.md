# Tensor Contractions Using Buffers.jl

This guide demonstrates how to perform efficient tensor contractions using Buffers.jl with two separate buffers. By managing input and output tensors in different buffers, you can optimize memory usage and improve performance, especially in high-performance computing applications.

## Overview

When performing tensor contractions, it's common to have intermediate tensors and output tensors. Allocating these tensors in separate buffers allows for better control over memory and can prevent memory fragmentation. As a simple rule of thumb, for each tensor contraction operation, **allocate input tensors in one buffer and the output tensor in another buffer.** This allows you to free memory efficiently after each operation.

## Example Use Case

In this example use case, we will perform tensor contraction operations using Buffers.jl. Consider the following tensor contraction operation:

```math
E_{ij}^{kl} = A_{ij}^{ab} B_{ab}^{cd} C_{cd}^{ef} D_{ef}^{kl}
```

where `A`, `B`, `C`, and `D` are input tensors and `E` is the output tensor.
We will perform binary tensor contractions using the `@tensor` macro from the TensorOperations.jl package.
We will allocate `A` and `B` in one buffer, `AB` and `C` in another buffer, `ABC` and `D` in the first buffer and so on.

## Setting Up Buffers

First, create two buffers (`buf1`) and (`buf2`) which will be used interchangeably for input and output tensors. The size of each buffer should be based on the memory requirements of your tensors (use [`@print_buffer_usage`](@ref) to calculate the sizes or let the buffers grow automatically if using `Buffer`). In this example, we will use `MAllocBuffer` buffers, which are non-extendable manually allocated buffers.

```julia
using Buffers

# Create buffers with appropriate sizes
@buffer buf1(100000) buf2(50000) begin
```

## Performing Tensor Contractions

Allocate tensors in the input buffer for your computations. The input tensors should be allocated in the buffer `buf1`, and the output tensor should be allocated in the buffer `buf2`.

```julia
  # Allocate input tensors in the input buffer
  A = alloc!(buf1, ni, nj, na, nb)   # ni*nj*na*nb tensor
  B = alloc!(buf1, na, nb, nc, nd)   # na*nb*nc*nd tensor
  AB = alloc!(buf2, ni, nj, nc, nd)  # ni*nj*nc*nd tensor

  # Initialize tensors with random values or data
  rand!(B)
  rand!(C)
```

Perform the tensor contraction using the allocated input tensors and drop the input tensors from the input buffer.

```julia
# Perform tensor contraction (example using @tensor macro from TensorOperations.jl)
using TensorOperations

  @tensor AB[i, j, c, d] = A[i, j, a, b] * B[a, b, c, d]
  drop!(buf1, A, B)
```

Allocate the new input tensor `C` in the buffer `buf2` and the new output tensor `ABC` in the buffer `buf1` and perform the next tensor contraction, etc.

```julia
  # Allocate new input tensor in the output buffer
  C = alloc!(buf2, nc, nd, ne, nf)   # nc*nd*ne*nf tensor
  ABC = alloc!(buf1, ni, nj, ne, nf) # ni*nj*ne*nf tensor
  @tensor ABC[i, j, e, f] = AB[i, j, c, d] * C[c, d, e, f]
  drop!(buf2, C, AB)
  D = alloc!(buf1, ne, nf, nk, nl)   # ne*nf*nk*nl tensor
  E = alloc!(buf2, ni, nj, nk, nl)   # ni*nj*nk*nl output tensor
  @tensor E[i, j, k, l] = ABC[i, j, e, f] * D[e, f, k, l]
  drop!(buf1, D, ABC)
  # store E to disk
end # end of buffer scope, automatically frees the buffers, releasing all memory
```
