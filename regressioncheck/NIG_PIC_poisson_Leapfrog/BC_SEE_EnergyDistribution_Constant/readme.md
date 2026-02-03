# Secondary Electron Emission - Energy of secondaries
* Particle emission using surface flux by defining an emission current of 2A at 40 eV
* Testing the energy of the secondary electrons (separate species with index = 3)
* Two options: subtract (default, SubtractWorkFunction = T) the work function or keep the impact energy (SubtractWorkFunction = F)
* Expected energy can be converted to energy per particle by 009-Ekin-003 / (004-NumDens-Spec-003 * 1E-15 * 1.602176634e-19) and should be
  * 20eV for SubtractWorkFunction = T
  * 40eV for SubtractWorkFunction = F