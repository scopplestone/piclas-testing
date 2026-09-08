# DCBC_h_N1_pAdaptionType1
- distribtued capacitance boundary on the left
- convergence test with four different meshes
    - pAdaptionType = 1 with N=1 and NMax=2 to randomly dsitribute between N=1 and N=2 to test p-adaption functionality
    - resulting order of convergence is somewhere between O(1) and O(2) and the tolerance in the analysis must be set high enough.
    - When p-adaption is deactivated and a fixed N=1 is used, the resulting order of convergence is O(2)
- particles are initalised near the left boundary and are moving towards it until they are absorbed and the charge is deposited on
  the surface. Note that if even a single particle remains in the domain, the L2 norm is extremely high because the electric
  potential is changed dramatically.
- Neuman BCs (no periodic boundary conditions are used here)