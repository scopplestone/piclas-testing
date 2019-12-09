\hypertarget{visu_output}{}

# Visualization \& Output \label{chap:visu_output}

In general, simulation results are either available as particle data, spatially resolved variables based on the mesh (classic CFD results) and/or as integral values (e.g. for reservoir/heat bath simulations). The h5piclas2vtk tool converts the HDF5 files generated by **PICLas** to the binary VTK format, readable by many visualization tools like ParaView and VisIt. The tool is executed by

~~~~~~~
h5piclas2vtk [posti.ini] output.h5
~~~~~~~

Multiple HDF5 files can be passed to the h5piclas2vtk tool at once. The (optional) runtime parameters to be set in `posti.ini` are given below:

-----------------------------------------------------------------------------------------------
**Option**          **Default**   **Description**
------------------  -----------   ---------------------------------------------------------------
NVisu                         1   Number of points at which solution is sampled for visualization

VisuParticles               OFF   Converts the particle data (positions, velocity, species, internal energies)

NodeTypeVisu               VISU   Node type of the visualization basis: VISU,GAUSS,GAUSS-LOBATTO,CHEBYSHEV-GAUSS-LOBATTO

CalcDiffError                 F   Use first state file as reference state for L2 error calculation with the following state files

AllowChangedMesh              F   Neglect mesh changes, use inits of first mesh (ElemID must match!).

CalcDiffSigma                 F   Use last state file as state for L2 sigma calculation.

CalcAverage                   F   Calculate and write arithmetic mean of all state files.

VisuSource                    F   Use DG_Source instead of DG_Solution.

NAnalyze                    2*N   Polynomial degree at which analysis is performed (e.g. for L2 errors, required for CalcDiffError).
-----------------------------------------------------------------------------------------------

In the following, the parameters enabling the different output variables are described. It should be noted that these parameters are part of the `parameter.ini` required by **PICLas**.

## Particle Data

At each `Analyze_dt` as well as at the start and end of the simulation, the state file (`*_State_*.h5`) is written out, which contains the complete particle information such as their positions, velocity vector, species and internal energy values.

To sample the particles impinging on a certain surface between `Analyze_dt` outputs, the following option can be enabled per boundary condition

    Part-Boundary1-BoundaryParticleOutput = T

The particle data will then be written to `*_PartStateBoundary_*.h5` and includes besides the position, velocity vector and kinetic energy (in eV), additionally the impact obliqueness angle between particle trajectory and surface normal vector, e.g. an impact vector perpendicular to the surface corresponds to an impact angle of $0^{\circ}$.

## Field Variables

WIP

## Flow Field and Surface Variables \label{sec:visu_flowfield}

Flow field and surface outputs are available when the DSMC, BGK and FP methods are utilized (standalone or coupled with PIC) and stored in `*_DSMCHOState_*.h5`. A sampling over a certain number of iterations is performed to calculate the average macroscopic values such as number density, bulk velocity and temperature from the microscopic particle information. Two variants are available in PICLas, allowing to sample a certain amount of the simulation duration or to sample continuously during the simulation and output the result after the given number of iterations.

The first variant is usually utilized to sample at the end of a simulation, when the steady state condition is reached. The first parameter `Part-TimeFracForSampling` defines the percentage that shall be sampled relative to the simulation end time $T_\mathrm{end}$ (Parameter: `TEnd`)

    Part-TimeFracForSampling = 0.1
    Particles-NumberForDSMCOutputs = 2

`Particles-NumberForDSMCOutputs` defines the number of outputs during the sampling time. Example: The simulation end time is $T_\mathrm{end}=1$, thus sampling will begin at $T=0.9$ and the first output will be written at $T=0.95$. At this point the sample will NOT be resetted but continued. Therefore, the second and last output at $T=T_\mathrm{end}=1.0$ is not independent of the previous result but contains the sample of the complete sampling duration. It should be noted that if a simulation is continued at e.g. $T=0.95$, sampling with the given parameters will begin immediately.

The second variant can be used to produce outputs for unsteady simulations, while still to be able to sample for a number of iterations (Parameter: `Part-IterationForMacroVal`). The first two flags allow to enable the output of flowfield/volume and surface values, respectively.

    Part-WriteMacroVolumeValues = T
    Part-WriteMacroSurfaceValues = T
    Part-IterationForMacroVal = 100

Example: The simulation end time is $T_\mathrm{end}=1$ with a time step of $\Delta t = 0.001$. With the parameters given above, we would sample for 100 iterations up to $T = 0.1$ and get the first output. Afterwards, the sample is deleted and the sampling begins anew for the following output at $T=0.2$. This procedure is repeated until the simulation end, resulting in 10 outputs with independent samples.

Parameters indicating the quality of the simulation (e.g. the maximal collision probability in case of DSMC) can be enabled by

    Particles-DSMC-CalcQualityFactors = T

Output and sampling on surfaces can be enabled by

    Particles-DSMC-CalcSurfaceVal = T

By default this will include the impact counter, the force per area in $x$, $y$, and $z$ and the heat flux. The output of the surface-sampled data is written to `*_DSMCSurfState_*.h5`. Additional surface values can be sampled by using

    CalcSurfaceImpact = T

which calculates the species-dependent averaged impact energy (trans, rot, vib), impact vector, impact obliqueness angle (between particle trajectory and surface normal vector, e.g. an impact vector perpendicular to the surface corresponds to an impact angle of $0^{\circ}$) and number of impacts due to particle-surface collisions. 

## Integral Variables

WIP, PartAnalyze/FieldAnalyze

## Element-constant properties
The determined properties are given by a single value within each cell and are NOT sampled over time as opposed to the output described in Section \ref{sec:visu_flowfield}. These parameters are only available for PIC simulations, are part of the regular state file (as a separate container within the HDF5 file) and automatically included in the conversion to the VTK format.

**Power Coupled to Particles**
The energy transferred to particles during the push (acceleration due to electromagnetic fields) is
determined by using

    CalcCoupledPower = T

which calculates the time-averaged power (moving average) coupled to the particles in each cell (average power per cubic metre)
and stores it in `PCouplDensityAvgElem` for each species separately. Furthermore, the accumulated power over all particles of the same species is displayed in STD-out via

     Averaged coupled power per species [W]
     1     :    0.0000000000000000
     2     :    2.6614384806763068E-003
     3     :    2.6837037798108634E-006
     4     :    0.0000000000000000
     5     :    8.8039637450978475E-006
     Total :    2.6729261482012156E-003

for the time-averaged (moving average) power. Additionally, the properties `PCoupl` (instantaneous) and a time-averaged (moving average) value
`PCoupledMoAv` are stored in the `ParticleAnalyze.csv` output file. 

**Plasma Frequency**
The (cold) plasma frequency can be calculated via

$$\omega_{p}=\omega_{e}=\frac{e^{2}n_{e}}{\varepsilon_{0}m_{e}}$$

which is the frequency with which the charge density of the electrons oscillates, where
$\varepsilon_{0}$ is the permittivity of vacuum, $e$ is the elementary charge, $n_{e}$ and $m_{e}$
are the electron density and mass, respectively.
The calculation is activated by

    CalcPlasmaFreqeuncy = T

**PIC Particle Time Step**
The maximum allowed time step within the PIC schemes can be estimated by

$$\Delta_{t,\mathrm{PIC}}<\frac{0.2}{\omega_{p}}$$

where $\omega_{p}$ is the (cold) plasma frequency.
The calculation is activated by

    CalcPICTimeStep = T

**Debye length**
The Debye length can be calculated via

$$\lambda_{D}=\sqrt{\frac{\varepsilon_{0}k_{B}T_{e}}{e^{2}n_{e}}}$$

where $\varepsilon_{0}$ is the permittivity of vacuum, $k_{B}$ is the Boltzmann constant, $e$ is the
elementary charge and $T_{e}$ and $n_{e}$ are the electron temperature and density, respectively.
The Debye length measures the distance after which the magnitude of the electrostatic
potential of a single charge drops by $1/\text{e}$.
The calculation is activated by

    CalcDebyeLength = T

**Points per Debye Length**
The spatial resolution in terms of grid points per Debye length can be estimated via

$$\mathrm{PPD}=\frac{\lambda_{D}}{\Delta x}=\frac{(p+1)\lambda_{D}}{L}\sim 1$$

where $\Delta x$ is the grid spacing (average spacing between grid points),
$p$ is the polynomial degree of the solution, $\lambda_{D}$ is the Debye length and $L=V^{1/3}$
is the characteristic cell length, which is determined from the volume $V$ of the grid cell.
Furthermore, the calculation in each direction $x$, $y$ and $z$ is performed by setting
$L=\left\{ L_{x}, L_{y}, L_{z} \right\}$, which are the average distances of the bounding box of
each cell. These values are especially useful when dealing with Cartesian grids.
The calculation is activated by

    CalcPointsPerDebyeLength = T

**PIC CFL Condition**
The plasma frequency time step restriction and the spatial Debye length restriction can be merged
into a single parameter

$$\frac{\Delta t}{0.4 \Delta x}\sqrt{\frac{k_{b}T_{e}}{m_{e}}}= \frac{(p+1)\Delta t}{0.4 L}\sqrt{\frac{k_{b}T_{e}}{m_{e}}} \lesssim 1$$

where $\Delta t$ is the time step, $\Delta x$ is the grid spacing (average spacing between grid
points), $p$ is the polynomial degree of the solution, $k_{B}$ is the Boltzmann constant, $T_{e}$
and $m_{e}$ are the electron temperature and mass, respectively. Furthermore, the calculation in
each direction $x$, $y$ and $z$ is performed by setting $L=\left\{ L_{x}, L_{y}, L_{z} \right\}$,
which are the average distances of the bounding box of each cell.
These values are especially useful when dealing with Cartesian grids.
The calculation is activated by

    CalcPICCFLCondition = T

**Maximum Particle Displacement**
The largest displacement of a particle within one time step $\Delta t$ is estimated for each cell
via

$$\frac{\mathrm{max}(v_{\mathrm{iPart}})\Delta t}{\Delta x}=\frac{(p+1)\mathrm{max}(v_{\mathrm{iPart}})\Delta t}{L} < 1$$

which means that the fastest particle is not allowed to travel over the length of two grid points
separated by $\Delta x$.
Furthermore, the calculation in each direction $x$, $y$ and $z$ is performed by setting
$L=\left\{ L_{x}, L_{y}, L_{z} \right\}$, which are the average distances of the bounding box of
each cell.
These values are especially useful when dealing with Cartesian grids.
The calculation is activated by

    CalcMaxPartDisplacement = T