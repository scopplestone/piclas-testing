# 2D_HET_Taccogna2022
- HET setup with neutralization injection current based on "Taccogna et al. - Coupling plasma physics and chemistry in the PIC model of 
  electric propulsion: Application to an air-breathing, low-power Hall thruster (2022)"
- Test two different meshes
  - block-structured Cartesian mesh HET_SPT20_mesh.h5
  - unstructured region-refined gmsh-generated mesh HET_SPT20_gmsh_extruded_mesh.h5
- When using a distribution from a DSMCState file. Note that the grid cannot be built on-the-fly as
  the gmsh refinement and smoothing algorithm changes the number and position of the elements slightly.
  Therefore, a fixed BGGas with n=1e20 and T=300K ist used instead of a pre-defined result from a DSMC simulation.
- For testing, a different magnetic field than that in the paper is used.
- New in this reggie: Testing of the neutralization injection current based on the model in the paper, which is activated via
    
      ! Neutralization current
      Part-Species2-Init2-SpaceIC              = 2D_Taccogna2022_neutralization
      Part-Species2-Init2-MWTemperatureIC      = 2.3209E+04  ! 2.0 eV
      Part-Species2-Init2-NeutralizationSource = BC_ANODE    ! left boundary
      Part-Species2-Init2-velocityDistribution = maxwell_lpn ! Maxwell-Boltzmann distribution

  and injectes electrons in the right part of the domain with a fixed temperature of 2 eV.
  The current on the anode is measured and of more electrons than ions are removed at this boundary, the overhead of electrons is
  injected in the neutralization emission region (right part of the domain).
  As a result of this model, the total current at the outflow boundary should become zero, effectively neutralizing the outflow of
  ions.
