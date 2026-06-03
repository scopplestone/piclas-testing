# DCBC 2D Neumann BC deposition split2hex
- check that the symmetry sides for the field solver (Neumann BC type 10) correctly mirror the deposited charged.
  One symmetry side doubles the deposited charge on the wall and two symmetry sides quadruple the deposited chare.
- the surface charge density should be 1e-2 for all DCBC surfaces, which is checked via vtu comparison
- the mesh is a split2hex mesh with 132 elements (2D tets split to hex elements and extruded into the third dimension)