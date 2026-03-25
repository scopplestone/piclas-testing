# Interplane in combination with multi rotationally periodic BCs
- Boundary conditions for particles that perform a 90 degree periodic and a 45 degree periodic transformation
- Checks if the interplane bounds have been determined correctly
- Run different number of MPI ranks (1,2,7,15,25) to test single- and multi-node functionality
- (could be tested in RotPeriodicBCMulti if reggie functionality is extended)
- Attention: h5diff_allow_reorder=T is used for analysis, because the reference files were built using a different space-filling
  curve (hopr), which differently orders the mesh elements. Now pyhope is used. Therefore, the references files cannot be converted to
  vtu using the new mesh format created by pyhope.