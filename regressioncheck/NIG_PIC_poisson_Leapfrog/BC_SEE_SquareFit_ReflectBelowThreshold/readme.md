# Secondary Electron Emission - Square-fit model (ReflectElectron = T)
* Particle emission using surface flux by defining an emission current of 2A
* Testing the Part-Boundary1-SurfMod-ReflectElectron = T feature, where the electron is reflected with the yield probability if the energy is below the work function
* Testing the calculation of the yield (through the comparison of the SEE current at the surface) for a square-fit expression a*E + b*E^2 + c
  * SEE current divided by the emission current should yield the yield
  * Comparison with the analytical expression using the reference values is shown in yield.png (in BC_SEE_SquareFit case)
* Test case is reduced to two energies: one below (10eV) and one above (40eV) the work function
  * SEE current is still zero for 10eV since no secondaries are emitted
  * Reflection probability (yield) can be verified by subtracting the ratio the number of absorbed electrons (004-N_Ads-Spec-001) by the number of impacts (002-nSurfColl-Spec-001) from 1
  * Consequently, for the 40eV, the number of absorbed electrons (004-N_Ads-Spec-001) is equal to the number of impacts since the expected yield is above 1