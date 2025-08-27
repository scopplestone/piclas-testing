# Photoionization: Surface Emission via SEE for ray tracing
* **Comparing**: RadiationSurfState.h5 with reference files, the total number of real electrons in the system with a numerical ref. solution
* Ray tracing model from which surface emission is calculated
* Particle emission due to secondary electron emission from a dielectric surface (inner BC)
* No deposition, no interpolation
* Comparison of the number of emitted electrons with the reference solution
* Different MPF and number of MPI ranks are tested to yield the same result
* Note: Because the volume is doubled due to dielectric, the calculated electron density is half the number of real electrons in the system
