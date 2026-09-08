# DCBC_2D_Cartesian
- Split2hex mesh with 480 elements
- periodic mesh in y- and z-direction
- Cuboid domain
  x: 0 to 0.001 (delta: 0.001)
  y: 0 to 5e-05 (delta: 5e-05)
  z: 0 to 0.0005 (delta: 0.0005)
- Random polynomial degree between 1 and 2
- A group of particles moves towards the left boundary condition where a DCBC is employed, which absorbes the particles resulting in
  a surface charge distribution on the dielectric
- A linear electric potential is used in combination with the DCBC, setting a bias voltage on the electrode behind the DCBC