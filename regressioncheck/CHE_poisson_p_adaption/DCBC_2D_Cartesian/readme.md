# DCBC_2D_Cartesian
- Cartesian mesh with 8x1x10 elements in x-y-z
- Periodic mesh in z-direction and symmetry condition in y-direction
- Cuboid domain
  x: 0 to 0.001 (delta: 0.001)
  y: 0 to 5e-05 (delta: 5e-05)
  z: 0 to 0.0005 (delta: 0.0005)
- Random polynomial degree between 1 and 2
- A group of particles moves towards the left boundary condition where a DCBC is employed, which absorbes the particles resulting in
  a surface charge distribution on the dielectric
- A linear electric potential (0V to 1000V) is used in combination with the DCBC, setting a bias voltage on the electrode behind the DCBC