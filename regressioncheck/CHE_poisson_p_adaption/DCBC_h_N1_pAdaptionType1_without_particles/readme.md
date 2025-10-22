# DCBC_h_N1_pAdaptionType1
- distribtued capacitance boundary on the left
- convergence test with four different meshes
    - pAdaptionType = 1 with N=1 and NMax=2 to randomly dsitribute between N=1 and N=2 to test p-adaption functionality
    - resulting order of convergence is somewhere between O(1) and O(2) and the tolerance in the analysis must be set high enough.
    - When p-adaption is deactivated and a fixed N=1 is used, the resulting order of convergence is O(2)
- no particles are used for this test, instead a fixed surface charge on the boundary is enforced using DC-SurfaceCharge = 0.01
