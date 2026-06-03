# 2D Variable External Field (magnetic field)
- Magnetic field is read from reggie-linear-rot-symmetry.h5
  - Transformation from Cartesian coordinates to cylinder coordinates due to function B(r,z)
  - `PIC-variableExternalFieldSymAxis = 3` indicates which axis in 3D corresponds to the symmetry axis of the external field
- Comparison of interpolated field output with TE28_8_PIC-EMField_ref.h5
- Electrons are randomly inserted to check if the interpolation of the read-in external field works
