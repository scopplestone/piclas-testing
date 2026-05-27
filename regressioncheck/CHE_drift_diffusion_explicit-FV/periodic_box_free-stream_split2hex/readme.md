# FV Drift-diffusion Free Stream
- most basic test with constant initial conditions, which must not change
- periodic box
- split2hex settings in hopr.ini with 3x3x3 elements that are split into a total of 648 hex elements

    elemtype   = 104 ! element type (108: Hexahedral)
    SplitToHex = T
    nFineHexa  = 1
