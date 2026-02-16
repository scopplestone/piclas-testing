# Maxwell-PIC p-adaption
- non-orthogonal mesh: pyhope split2hex 1x1x1 -> 24 elements
- 1,2,3,4,5 processes
- N=1,2,3
- load balance (not via H5 I/O)
- no particles used in the test case, but load balance requires compiling with PARTICLES=ON