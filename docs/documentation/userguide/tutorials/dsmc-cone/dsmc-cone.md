# Hypersonic Flow around the 70° Cone (DSMC)

A widespread validation case for rarefied gas flows is the wind tunnel test of the 70° blunted cone in a hypersonic, diatomic nitrogen flow {cite}`Allegre1997`, {cite}`Moss1995`.
Before beginning with the tutorial, copy the `dsmc-cone` directory from the tutorial folder in the top level directory to a separate location

    cp -r $PICLAS_PATH/tutorials/dsmc-cone .
    cd dsmc-cone

The general information needed to setup a DSMC simulation is given in the previous tutorial {ref}`sec:tutorial-dsmc-reservoir`. The following focuses on case-specific differences.

## Mesh Generation with HOPR (pre-processing)

Before the actual simulation is conducted, a mesh file in the HDF5 format has to be supplied. The mesh files used by **piclas** are created by supplying an input file `hopr.ini` with the required information for a mesh that has either been created by an external mesh generator or directly from block-structured information in the `hopr.ini` file itself. Here, a conversion from an external mesh generator is required. The mesh needed for this tutorial is already generated and converted to *70degCone_2D_mesh.h5*. The mesh and the corresponding boundaries are depicted in {numref}`fig:dsmc-cone-mesh`.

```{figure} mesh/dsmc-cone-mesh-bcs.jpg
---
name: fig:dsmc-cone-mesh
width: 90%
---

Mesh of the 70° Cone.
```

To get the mesh, copy it from the corresponding weekly regression test

    cp $PICLAS_PATH/regressioncheck/WEK_DSMC/Flow_N2_70degCone/mesh_70degCone2D_Set1_noWake_mesh.h5 ./70degCone_2D_mesh.h5

However, an example setup for such a conversion is given in *hopr.ini*. In difference to a direct generation the `FileName` of the original mesh has to be specified and the `Mode` has to be set to 3, to read a CGNS mesh. For unstructured ANSA CGNS meshes the `BugFix_ANSA_CGNS` needs to be active.

    !=============================================================================== !
    ! MESH
    !=============================================================================== !
    FileName         = 70degCone_2D_mesh.cgns
    Mode             = 3
    BugFix_ANSA_CGNS = T

The `BoundaryName` needs to be the same as in the CGNS file.

    !=============================================================================== !
    ! BOUNDARY CONDITIONS
    !=============================================================================== !
    BoundaryName = IN
    BoundaryType = (/2,0,0,0/)
    BoundaryName = OUT
    BoundaryType = (/3,0,0,0/)
    BoundaryName = WALL
    BoundaryType = (/4,0,0,0/)
    BoundaryName = SYMAXIS
    BoundaryType = (/4,0,0,0/)
    BoundaryName = ROTSYM
    BoundaryType = (/4,0,0,0/)

To create the .h5 mesh file, simply run

    hopr hopr.ini

This would create the mesh file *70degCone_2D_mesh.h5* in HDF5 format. For more information see directly at [https://github.com/hopr-framework/hopr](https://github.com/hopr-framework/hopr).

## Flow simulation with DSMC

Install **piclas** by compiling the source code as described in Section {ref}`userguide/installation:Installation` and make sure to set the correct compile flags. For this setup, we are utilizing the regular Direct Simulation Monte Carlo (DSMC) method

    PICLAS_TIMEDISCMETHOD = DSMC

or simply run the following command from inside the *build* directory

    cmake ../ -DPICLAS_TIMEDISCMETHOD=DSMC

to configure the build process and run `make` afterwards to build the executable. An overview over the available solver and discretization options is given in Section {ref}`sec:solver-settings`. The values of the general physical properties are listed in {numref}`tab:dsmc_cone_phys`.

```{table} Physical properties at the simulation start
---
name: tab:dsmc_cone_phys
---
|                  Property                    | Value (initial and surfaceflux) |
| -------------------------------------------- | :-----------------------------: |
| Species                                      | $\text{N}_2$                    |
| Molecule mass $m_{\text{N}_2}$               | $\pu{4.65e-26 kg}$              |
| Number density  $n$                          | $\pu{3.715e+20 m^{-3}}$         |
| Translational temperature $T_{\text{trans}}$ | $\pu{13.3 K}$                   |
| Rotational temperature $T_{\text{rot}}$      | $\pu{13.3 K}$                   |
| Vibrational temperature $T_{\text{vib}}$     | $\pu{13.3 K}$                   |
| Velocity $v_{\text{x}}$                      | $\pu{1502.57 \frac{m}{s}}$      |
```

To define an incoming, continuous flow, the procedure is similar to that for initialization sets. For each species, the number of inflows is specified via `Part-Species[$]-nSurfaceFluxBCs`. Subsequently, the boundary from which it should flow in is selected via `Part-Species[$]-Surfaceflux[$]-BC`. The rest is identical to the initialization explained in Section {ref}`sec:tutorial-dsmc-particle-solver`.

    Part-Species1-nSurfaceFluxBCs = 1

    Part-Species1-Surfaceflux1-BC                   = 1
    Part-Species1-Surfaceflux1-velocityDistribution = maxwell_lpn
    Part-Species1-Surfaceflux1-MWTemperatureIC      = 13.3
    Part-Species1-Surfaceflux1-TempVib              = 13.3
    Part-Species1-Surfaceflux1-TempRot              = 13.3
    Part-Species1-Surfaceflux1-PartDensity          = 3.715E+20
    Part-Species1-Surfaceflux1-VeloIC               = 1502.57
    Part-Species1-Surfaceflux1-VeloVecIC            = (/1.,0.,0./)

### MPI and Load Balancing

When using several cores, piclas divides the computing load by distributing the computing cells to the various cores. If a particle leaves the boundaries of a core, it is necessary that the surrounding grid is also known. This region is defined by the `Particles-HaloEpsVelo` and the time step. In general, it can be said that this velocity should be greater than or equal to the maximum velocity of any particle in the simulation. This prevents a particle from completely flying through this halo region during a time step.

    Particles-HaloEpsVelo = 8.0E+4

If the conditions change, it could make sense to redistribute the computing load. An example is the build-up of a bow shock during the simulation time: While all cells have the same particle density during initialization, an imbalance will develop after a short time. The cores with cells in the area of the bow shock have significantly more computational effort, since the particle density is significantly higher. As mentioned at the beginning, **piclas** redistributes the computing load each time it is started. To perform a restart, the state file (Projectname_State_Timestamp.h5) must be appended to the standard start command.

    mpirun -np 8 piclas parameter.ini DSMC.ini Projectname_State_Timestamp.h5 > std.out

The parameter `Particles-MPIWeight` indicates whether the distribution should be oriented more towards a uniform distribution of the cells (values less than 1) or a uniform distribution of the particles (values greater than 1). There are options in piclas to automate this process by defining load balancing steps during a single program call. For this, load balancing must have been activated when compiling piclas (which is the default). To activate load balancing based on the number of particles, `DoLoadBalance = T` and `PartWeightLoadBalance = T` must be set. **piclas** then decides after each `Analyze_dt` whether a redistribution is required. This is done using the definable `Load DeviationThreshold`. Should the maximum relative deviation of the calculation load be greater than this value, a load balancing step is carried out. If `DoInitialAutoRestart = T` and `InitialAutoRestart-PartWeightLoadBalance = T` are set, a restart is carried out after the first `Analyze_dt` regardless of the calculated imbalance. To restrict the number of restarts, `LoadBalanceMaxSteps` limits the number of all load balancing steps to the given number.

    ! Load Balancing
    Particles-MPIWeight                      = 1000
    DoLoadBalance                            = T
    PartWeightLoadBalance                    = T
    DoInitialAutoRestart                     = T
    InitialAutoRestart-PartWeightLoadBalance = T
    LoadBalanceMaxSteps                      = 2

Information about the imbalance are shown in the *std.out* and the *ElemTimeStatistics.csv* file.

### Exploiting symmetry

In axially symmetrical cases, the simulation effort can be greatly reduced. For this, 2D must first be activated via `Particles-Symmetry-Order = 2`. `Particles-Symmetry2DAxisymmetric = T` enables axisymmetric simulations.

    ! Symmetry
    Particles-Symmetry-Order         = 2
    Particles-Symmetry2DAxisymmetric = T

First of all, certain requirements are placed on the grid. The $y$-axis acts as the symmetry axis, while the $x$-axis defines the radial direction. Therefore grid lies in the $xy$-plane and should have an extension of one cell in the $z$-direction, the extent in $z$-direction is irrelevant whilst it is centered on $z=0$. In addition, the boundary at $y = 0$ must be provided with the condition `symmetric_axis` and the two boundaries parallel to the $xy$-plane with the condition `symmetric`. 

    Part-Boundary4-SourceName  = SYMAXIS
    Part-Boundary4-Condition   = symmetric_axis
    Part-Boundary5-SourceName  = ROTSYM
    Part-Boundary5-Condition   = symmetric

To fully exploit rotational symmetry, a radial weighting can be enabled via `Particles-RadialWeighting = T`, which will linearly increase the weighting factor towards $y_{\text{max}}$, depending on the current $y$-position of the particle. Thereby the `Particles-RadialWeighting-PartScaleFactor` multiplied by the `MacroParticleFactor` is the weighting factor at $y_{\text{max}}$. Since this position based weighting requires an adaptive weighting factor, particle deletion and cloning is necessary. `Particles-RadialWeighting-CloneDelay` defines the number of iterations in which the information of the particles to be cloned are stored and `Particles-RadialWeighting-CloneMode = 2` ensures that the particles from this list are inserted randomly after the delay.

    ! Radial Weighting
    Particles-RadialWeighting                 = T
    Particles-RadialWeighting-PartScaleFactor = 60
    Particles-RadialWeighting-CloneMode       = 2
    Particles-RadialWeighting-CloneDelay      = 5

For further information see {ref}`sec:2D-axisymmetric`.

### Octree

By default, a conventional statistical pairing algorithm randomly pairs particles within a cell. Here, the mesh should resolve the mean free path to avoid numerical diffusion. To circumvent this requirement, an octree-based sorting and cell refinement can be enabled by `Particles-DSMC-UseOctree = T`. The resulting grid is defined by the maximum number `Particles-OctreePartNumNode` and minimum number `Particles-OctreePartNumNodeMin` of particles in each subcell. Furthermore, the search for the nearest neighbour can be enabled by `Particles-DSMC-UseNearestNeighbour = T`.

    ! Octree
    Particles-DSMC-UseOctree           = T
    Particles-DSMC-UseNearestNeighbour = T
    Particles-OctreePartNumNode        = 40
    Particles-OctreePartNumNodeMin     = 28

For further information see {ref}`sec:DSMC-collision`.

### Sampling

The outputs of the *Projectname_DSMCState_Timestamp.h5* (data in domain) and *Projectname_DSMCSurfState_Timestamp.h5* (surface data) files are based on sampling over several time steps. There are two different approaches that can not be used at the same time. The first method is based on specifying the sampling duration via `Part-TimeFracForSampling` as the fraction of the simulation end time (as defined by `TEnd`) between 0 and 1, where 0 means that no sampling occurs and 1 that sampling starts directly at the beginning of the simulation

$t_\text{samp,start} = T_\text{end} \cdot \left(1 - f_\text{samp}\right)$

`Particles-NumberForDSMCOutputs` then indicates how many samples are written in this period. The data is not discarded after the respective output and the sampling is continued. In other words, the last output contains the data for the entire sampling period.

    Part-TimeFracForSampling          = 0.5
    Particles-NumberForDSMCOutputs    = 2

The second method is activated via `Part-WriteMacroValues = T`. In this approach, `Part-IterationForMacroVal` defines the number of iterations that are used for one sample. After the first sample has been written, the data is discarded and the next sampling process is started.

    Part-WriteMacroValues             = T
    Part-IterationForMacroVal         = 1250

For further information see {ref}`sec:sampled-flow-field-and-surface-variables`.

## Visualization (post-processing)

### Ensuring physical simulation results

After running a simulation, especially if done for the first time it is strongly recommended to ensure the quality of the results. For this purpose, the `Particles-DSMC-CalcQualityFactors = T` should be set, to enable the calculation of quality factors such as the maximum collision probability and the mean collision separation distance over the mean free path. All needed datasets can be found in the `*_DSMCState_*.h5` or the converted `*_visuDSMC_*.vtu`.

First of all, it should be ensured that a sufficient number of simulation particles were available for the averaging, which forms the basis of the shown data. The value `*_SimPartNum` indicates the average number of simulated particles in the respective cell. For a sufficient sampling size, it should be guaranteed that at least 10 particles are in each cell, however, this number is very case-specific. The value `DSMC_MCSoverMFP` is an other indicator for the quality of the particle discretization of the simulation area. A value above 1 indicates that the mean collision separation distance is greater than the mean free path, which is a signal for too few simulation particles. For 3D simulations it is sufficient to adjust the `Part-Species[$]-MacroParticleFactor` accordingly in **parameter.ini**. In 2D axisymmetric simulations, the associated scaling factors such as `Particles-RadialWeighting-PartScaleFactor` can also be optimized (see Section {ref}`sec:2D-axisymmetric`). 

Similarly, the values `DSMC_MeanCollProb` and` DSMC_MaxCollProb` should be below 1 in order to avoid nonphysical values. While the former indicates the averaged collision probability per timestep, the latter stores the maximum collision probability. If this limit is not met, more collisions should have ocurred within a time step than possible. A refinement of the time step `ManualTimeStep` in **parameter.ini** is therefore necessary. If a variable timestep is also used in the simulation, there are further options (see Section {ref}`sec:variable-time-step`). 

```{table} Target value to ensure physical results and a connected input parameter
---
name: tab:dsmc_cone_ensuring
---
|     Property      |  Target   |      Connected Input Parameter      |
| ----------------- | :-------: | :---------------------------------: |
| *_SimPartNum      | $\gt 10$  | Part-Species[$]-MacroParticleFactor |
| DSMC_MCSoverMFP   | $\lt 1$   | Part-Species[$]-MacroParticleFactor |
| DSMC_MaxCollProb  | $\lt 1$   | ManualTimeStep                      |
```
Finally, the time step and particle discretization choice is a trade-off between accuracy and computational time.
For further information see Section {ref}`sec:DSMC-quality`.

### Visualizing flow field variables (DSMCState)

To visualize the data which represents the properties in the domain (e.g. temperatures, velocities, ...) the *DSMCState*-files are needed. They are converted using the program **piclas2vtk** into the VTK format suitable for **ParaView**, **VisIt** or many other visualisation tools. Run the command

    piclas2vtk dsmc_cone_DSMCState_000.00*

to generate the corresponding VTK files, which can then be loaded into your visualization tool. The resulting translational temperature and velocity in the domain are shown in {numref}`fig:dsmc-cone-visu`. The visualized variables are `Total_TempTransMean`, which is mean translational temperature and the magnitude of the velocities `Total_VeloX`, `Total_VeloX`, `Total_VeloX` (which is automatically generated by ParaView). Since the data is stored on the original mesh (and not the internally refined octree mesh), the data initially looks as shown in the two upper halves. **ParaView** offers the possibility to interpolate this data using the `CellDatatoPointData` filter. The data visualized in this way can be seen in the lower half of the image. 

```{figure} results/dsmc-cone-visu.jpg
---
name: fig:dsmc-cone-visu
width: 90%
---

Translational temperature and velocity in front of the 70° Cone, top: original data; bottom: interpolated data.
```

### Visualizing surface variables (DSMCSurfState)

To visualize the data which represents the properties at closed boundaries (e.g. heat flux, force per area, etc. the *DSMCSurfState*-files are needed. They are converted using the program **piclas2vtk** into the VTK format suitable for **ParaView**, **VisIt** or many other visualization tools. Run the command

    piclas2vtk dsmc_cone_DSMCSurfState_000.00*

to generate the corresponding VTK files, which can then be loaded into your visualization tool. A comparison between experimental data by {cite}`Allegre1997` and the simulation data stored in `dsmc_cone_visuSurf_000.00200000000000000.vtu` is shown at {numref}`fig:dsmc-cone-heatflux`. Further information about this comparison can be found at {cite}`Nizenkov2017`.

```{figure} results/dsmc-cone-heatflux.svg
---
name: fig:dsmc-cone-heatflux
width: 50%
---

Experimental heat flux data compared with simulation results from PIClas.
```