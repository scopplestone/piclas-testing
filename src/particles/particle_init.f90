!==================================================================================================================================
! Copyright (c) 2010 - 2018 Prof. Claus-Dieter Munz and Prof. Stefanos Fasoulas
!
! This file is part of PICLas (gitlab.com/piclas/piclas). PICLas is free software: you can redistribute it and/or modify
! it under the terms of the GNU General Public License as published by the Free Software Foundation, either version 3
! of the License, or (at your option) any later version.
!
! PICLas is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty
! of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License v3.0 for more details.
!
! You should have received a copy of the GNU General Public License along with PICLas. If not, see <http://www.gnu.org/licenses/>.
!==================================================================================================================================
#include "piclas.h"

MODULE MOD_ParticleInit
!===================================================================================================================================
! Add comments please!
!===================================================================================================================================
! MODULES
! IMPLICIT VARIABLE HANDLING
IMPLICIT NONE
PRIVATE
!-----------------------------------------------------------------------------------------------------------------------------------
! GLOBAL VARIABLES
!-----------------------------------------------------------------------------------------------------------------------------------
! Private Part ---------------------------------------------------------------------------------------------------------------------
! Public Part ----------------------------------------------------------------------------------------------------------------------

INTERFACE InitParticleGlobals
  MODULE PROCEDURE InitParticleGlobals
END INTERFACE

INTERFACE InitParticles
  MODULE PROCEDURE InitParticles
END INTERFACE

INTERFACE FinalizeParticles
  MODULE PROCEDURE FinalizeParticles
END INTERFACE

INTERFACE rotx
  MODULE PROCEDURE rotx
END INTERFACE

INTERFACE roty
  MODULE PROCEDURE roty
END INTERFACE

INTERFACE InitialIonization
  MODULE PROCEDURE InitialIonization
END INTERFACE

!INTERFACE rotz
!  MODULE PROCEDURE rotz
!END INTERFACE

INTERFACE Ident
  MODULE PROCEDURE Ident
END INTERFACE

INTERFACE InitRandomSeed
  MODULE PROCEDURE InitRandomSeed
END INTERFACE

INTERFACE PortabilityGetPID
  FUNCTION GetPID_C() BIND (C, name='getpid')
    !GETPID() is an intrinstic compiler function in gnu. This routine ensures the portability with other compilers.
    USE ISO_C_BINDING,         ONLY: PID_T => C_INT
    IMPLICIT NONE
    INTEGER(KIND=PID_T)        :: GetPID_C
  END FUNCTION GetPID_C
END INTERFACE

PUBLIC::InitParticleGlobals
PUBLIC::InitParticles
PUBLIC::FinalizeParticles
PUBLIC::DefineParametersParticles
PUBLIC::InitialIonization
!===================================================================================================================================

CONTAINS

!==================================================================================================================================
!> Define parameters for particles
!==================================================================================================================================
SUBROUTINE DefineParametersParticles()
! MODULES
USE MOD_ReadInTools ,ONLY: prms,addStrListEntry
USE MOD_part_RHS    ,ONLY: DefineParametersParticleRHS
IMPLICIT NONE
!==================================================================================================================================
CALL DefineParametersParticleRHS()

CALL prms%SetSection("Particle")

CALL prms%CreateRealOption(     'Particles-ManualTimeStep'  , 'Manual timestep [sec]. This variable is deprecated. '//&
                                                              'Use ManualTimestep instead.', '-1.0')
CALL prms%CreateRealOption(     'Part-AdaptiveWeightingFactor', 'Weighting factor theta for weighting of average'//&
                                                                ' instantaneous values with those of previous iterations.', '0.001')
CALL prms%CreateIntOption(      'Particles-nPointsMCVolumeEstimate', 'Number of points used to calculate volume portion '//&
                                'occupied by Macroparticle with Monte Carlo algorithm (per octree sub-cell)',  '1000')
CALL prms%CreateIntOption(      'Part-nSpecies' ,                 'Number of species used in calculation', '1')
! Ionization
CALL prms%CreateLogicalOption(  'Part-DoInitialIonization'    , 'When restarting from a state, ionize the species to a '//&
                                                                'specific degree', '.FALSE.')
CALL prms%CreateIntOption(      'InitialIonizationSpecies', 'Supply the number of species that are considered for automatic '//&
                                                            'ionization')
CALL prms%CreateIntArrayOption( 'InitialIonizationSpeciesID', 'Supply a vector with the species IDs that are used for the '//&
                                                              'initial ionization.')
CALL prms%CreateRealOption(     'InitialIonizationChargeAverage' , 'Average charge for each atom/molecule in the cell '//&
                                                                   '(corresponds to the ionization degree)')

CALL prms%CreateIntOption(      'Part-MaxParticleNumber', 'Maximum number of Particles per proc (used for array init)'&
                                                                 , '1')
CALL prms%CreateIntOption(      'Part-NumberOfRandomSeeds'    , 'Number of Seeds for Random Number Generator'//&
                                                                'Choose nRandomSeeds \n'//&
                                                                '=-1    Random \n'//&
                                                                '= 0    Debugging-friendly with hard-coded deterministic numbers\n'//&
                                                                '> 0    Debugging-friendly with numbers from ini. ', '0')
CALL prms%CreateIntOption(      'Particles-RandomSeed[$]'     , 'Seed [$] for Random Number Generator', '1', numberedmulti=.TRUE.)

CALL prms%CreateLogicalOption(  'Particles-DoPoissonRounding' , 'TODO-DEFINE-PARAMETER\n'//&
                                                                'Flag to perform Poisson sampling'//&
                                                                ' instead of random rounding', '.FALSE.')
CALL prms%CreateLogicalOption(  'Particles-DoTimeDepInflow'   , 'TODO-DEFINE-PARAMETER\n'//&
                                                                'Insertion and SurfaceFlux with'//&
                                                                ' simple random rounding. Linearly ramping of'//&
                                                                ' inflow-number-of-particles is only possible with'//&
                                                                ' PoissonRounding or DoTimeDepInflow', '.FALSE.')
CALL prms%CreateIntOption(      'Part-RotPeriodicAxi'         , 'Axis of rotational periodicity:'//&
                                                                   'x=1, y=2, z=3', '1')
CALL prms%CreateRealOption(     'Part-RotPeriodicAngle'       , 'TODO-DEFINE-PARAMETER\n'//&
                                                                'Angle for rotational periodicity [Grad]'&
                                                              , '1.0')
CALL prms%CreateIntOption(      'Part-nPeriodicVectors'       , 'TODO-DEFINE-PARAMETER\n'//&
                                                                'Number of the periodic vectors j=1,...,n.'//&
                                                                   ' Value has to be the same as defined in preprog.ini', '0')
CALL prms%CreateRealArrayOption('Part-PeriodicVector[$]'      , 'TODO-DEFINE-PARAMETER\nVector for periodic boundaries.'//&
                                                                   'Has to be the same as defined in preproc.ini in their'//&
                                                                   ' respective order. ', '1. , 0. , 0.', numberedmulti=.TRUE.)

CALL prms%CreateRealOption(     'Part-DelayTime'              , "TODO-DEFINE-PARAMETER\n"//&
                                                                "During delay time the particles,"//&
                                                                    " won't be moved so the EM field can be evolved", '0.0')

CALL prms%CreateRealOption(     'Part-SafetyFactor'           , 'TODO-DEFINE-PARAMETER\n'//&
                                                                'Factor to scale the halo region with MPI'&
                                                              , '1.0')
CALL prms%CreateRealOption(     'Particles-HaloEpsVelo'       , 'TODO-DEFINE-PARAMETER\n'//&
                                                                'Halo region radius', '0.')

CALL prms%CreateIntOption(      'NbrOfRegions'                , 'TODO-DEFINE-PARAMETER\n'//&
                                                                'Number of regions to be mapped to Elements', '0')
CALL prms%CreateRealArrayOption('RegionBounds[$]'                , 'TODO-DEFINE-PARAMETER\nRegionBounds ((xmin,xmax,ymin,...)'//&
                                                                '|1:NbrOfRegions)'&
                                                                , '0. , 0. , 0. , 0. , 0. , 0.', numberedmulti=.TRUE.)
CALL prms%CreateRealArrayOption('Part-RegionElectronRef[$]'   , 'rho_ref, phi_ref, and Te[eV] for Region#'&
                                                              , '0. , 0. , 1.', numberedmulti=.TRUE.)
CALL prms%CreateRealOption('Part-RegionElectronRef[$]-PhiMax'   , 'max. expected phi for Region#\n'//&
                                                                '(linear approx. above! def.: phi_ref)', numberedmulti=.TRUE.)

CALL prms%CreateLogicalOption(  'PrintrandomSeeds'            , 'Flag defining if random seeds are written.', '.FALSE.')
#if (PP_TimeDiscMethod==508) || (PP_TimeDiscMethod==509)
CALL prms%CreateLogicalOption(  'velocityOutputAtTime'        , 'Flag if leapfrog uses a velocity-output at real time' , '.FALSE.')
#endif

CALL prms%CreateLogicalOption(  'Part-DoFieldIonization'      , 'Do Field Ionization by quantum tunneling.', '.FALSE.')
CALL prms%CreateIntOption(      'FieldIonizationModel'        , 'Field Ionization models. Implemented models are:\n'//&
                                                                ' * Ammosov-Delone-Krainov (ADK) model Bruhwiler 2003\n'//&
                                                                ' * Ammosov-Delone-Krainov (ADK) model Yu 2018')

CALL prms%SetSection("IMD")
! IMD things
CALL prms%CreateRealOption(     'IMDTimeScale'                , 'Time unit of input file.\n The default value is'//&
                                                                ' ~10.18 fs which comes from the unit system in IMD', '10.18e-15')
CALL prms%CreateRealOption(     'IMDLengthScale'              , 'Length unit scale used by IMD which is 1 angstrom'&
                                                              , '1.0e-10')
CALL prms%CreateStringOption(   'IMDAtomFile'                 , 'IMD data file containing the atomic states for PartState(1:6)'&
                                                              , 'no file found')
CALL prms%CreateStringOption(   'IMDCutOff'                   , 'Atom cut-off parameter for reducing the number of improrted '//&
                                                                'IMD particles\n'//&
                                                                '1.) no_cutoff\n'//&
                                                                '2.) Epot\n'//&
                                                                '3.) coordinates\n'//&
                                                                '4.) velocity', 'no_cutoff')
CALL prms%CreateRealOption(     'IMDCutOffxValue'              ,"Cut-off coordinate for"//&
                                                                " IMDCutOff='coordiantes'" &
                                                              , '-999.9')
CALL prms%CreateIntOption(      'IMDnSpecies'                 , 'Count of IMD species', '1')
CALL prms%CreateStringOption(   'IMDInputFile'                , 'Laser data file name containing '//&
                                                                'PartState(1:6) ' &
                                                              , 'no file found')
CALL prms%SetSection("VMPF")

! vmpf stuff
CALL prms%CreateLogicalOption(  'Part-vMPF'                      , 'TODO-DEFINE-PARAMETER\n'//&
                                                                'Flag to use variable '//&
                                                                'Macro Particle Factor.', '.FALSE.')
CALL prms%CreateLogicalOption(  'Part-vMPFPartMerge'              , 'TODO-DEFINE-PARAMETER\n'//&
                                                                'Enable Particle Merge routines.'&
                                                              , '.FALSE.')
CALL prms%CreateIntOption(      'Part-vMPFMergePolOrder'      , 'TODO-DEFINE-PARAMETER\n'//&
                                                                'Polynomial degree for vMPF particle merge.'&
                                                              , '2')
CALL prms%CreateIntOption(      'Part-vMPFCellSplitOrder'     , 'TODO-DEFINE-PARAMETER\n'//&
                                                                'Order for cell splitting of variable MPF'&
                                                              , '15')
CALL prms%CreateIntOption(      'Part-vMPFMergeParticleTarget', 'TODO-DEFINE-PARAMETER\n'//&
                                                                'Count of particles wanted after merge.', '0')
CALL prms%CreateIntOption(      'Part-vMPFSplitParticleTarget', 'TODO-DEFINE-PARAMETER\n'//&
                                                                'Number of particles wanted after split.','0')
CALL prms%CreateIntOption(      'Part-vMPFMergeParticleIter'  , 'TODO-DEFINE-PARAMETER\n'//&
                                                                'Number of iterations between particle '//&
                                                                'merges.', '100')
CALL prms%CreateStringOption(   'Part-vMPFvelocityDistribution','TODO-DEFINE-PARAMETER\n'//&
                                                                'Velocity distribution for variable '//&
                                                                'MPF.' , 'OVDR')
CALL prms%CreateLogicalOption(  'Part-vMPFrelativistic'              , 'TODO-DEFINE-PARAMETER', '.FALSE.')


CALL prms%SetSection("Particle Sampling")

! output of macroscopic values
CALL prms%CreateLogicalOption(  'Part-WriteMacroValues'&
  , 'Set [T] to activate ITERATION DEPENDANT h5 output of macroscopic values sampled every [Part-IterationForMacroVal] iterat'//&
  'ions from particles. Sampling starts from simulation start. Can not be enabled together with Part-TimeFracForSampling.\n'//&
  'If Part-WriteMacroValues is true, WriteMacroVolumeValues and WriteMacroSurfaceValues are forced to be true.\n'//&
  '(HALOWIKI:)Write macro values (e.g. rotational Temperature).'&
  , '.FALSE.')
CALL prms%CreateLogicalOption(  'Part-WriteMacroVolumeValues'&
  , 'Similar to Part-WriteMacroValues. Set [T] to activate iteration dependant sampling and h5 output for each element.'//&
  ' Is automatically set true if Part-WriteMacroValues is true.\n'//&
  'Can not be enabled if Part-TimeFracForSampling is set.', '.FALSE.')
CALL prms%CreateLogicalOption(  'Part-WriteMacroSurfaceValues'&
  , 'Similar to Part-WriteMacroValues. Set [T] to activate iteration dependant sampling and h5 output on surfaces.'//&
  ' Is automatically set true if Part-WriteMacroValues is true.\n'//&
  'Can not be enbaled if Part-TimeFracForSampling is set.', '.FALSE.')
CALL prms%CreateIntOption(      'Part-IterationForMacroVal'&
  , 'Set number of iterations used for sampling if Part-WriteMacroValues is set true.', '1')

CALL prms%CreateRealOption(     'Part-TimeFracForSampling'&
  , 'Set value greater 0.0 to enable TIME DEPENDANT sampling. The given simulation time fraction will be sampled. Sampling'//&
  ' starts after TEnd*(1-Part-TimefracForSampling).\n'//&
  'Can not be enabled together with Part-WriteMacroValues.' , '0.0')
CALL prms%CreateIntOption(      'Particles-NumberForDSMCOutputs'&
  , 'Give the number of outputs for time fraction sampling.\n'//&
  'Default value is 1 if Part-TimeFracForSampling is enabled.', '0')

CALL prms%CreateLogicalOption(  'Particles-DSMC-CalcSurfaceVal'&
  , 'Set [T] to activate sampling, analyze and h5 output for surfaces. Therefore either time fraction or iteration sampling'//&
  ' have to be enabled as well.', '.FALSE.')

CALL prms%SetSection("Particle Species")
! species inits
CALL prms%CreateIntOption(      'Part-Species[$]-nInits'  &
                                , 'Number of different initial particle placements for Species [$]', '0', numberedmulti=.TRUE.)
CALL prms%CreateLogicalOption(  'Part-Species[$]-Reset'  &
                                , 'Flag for resetting species distribution with init during restart' &
                                , '.FALSE.', numberedmulti=.TRUE.)
CALL prms%CreateRealOption(     'Part-Species[$]-ChargeIC'  &
                                , '[TODO-DEFINE-PARAMETER]\n'//&
                                  'Particle Charge (without MPF) of species[$] dim' &
                                , '0.', numberedmulti=.TRUE.)
CALL prms%CreateRealOption(     'Part-Species[$]-MassIC'  &
                                , 'Particle Mass (without MPF) of species [$] [kg]', numberedmulti=.TRUE.)
CALL prms%CreateRealOption(     'Part-Species[$]-MacroParticleFactor' &
                                , 'Number of Microparticle per Macroparticle for species [$]', '1.', numberedmulti=.TRUE.)
CALL prms%CreateLogicalOption(  'Part-Species[$]-IsImplicit'  &
                                , 'TODO-DEFINE-PARAMETER\n'//&
                                  'Flag if specific particle is implicit', '.FALSE.', numberedmulti=.TRUE.)
CALL prms%CreateLogicalOption(  'Part-Species[$]-IsIMDSpecies' &
                                , 'TODO-DEFINE-PARAMETER', '.FALSE.', numberedmulti=.TRUE.)



CALL prms%SetSection("Particle Species nInits")
! if Ninit>0 some variables have to be defined twice
CALL prms%CreateLogicalOption(  'Part-Species[$]-Init[$]-UseForInit' &
                                , 'TODO-DEFINE-PARAMETER\n'//&
                                  'Flag to use Init/Emission for init', '.TRUE.', numberedmulti=.TRUE.)
CALL prms%CreateLogicalOption(  'Part-Species[$]-Init[$]-UseForEmission' &
                                , 'TODO-DEFINE-PARAMETER\n'//&
                                  'Flag to use Init/Emission for emission', '.FALSE.', numberedmulti=.TRUE.)
CALL prms%CreateStringOption(   'Part-Species[$]-Init[$]-SpaceIC' &
                                , 'Specifying Keyword for particle space condition of species [$] in case of multiple inits' &
                                , 'cuboid', numberedmulti=.TRUE.)
CALL prms%CreateStringOption(   'Part-Species[$]-Init[$]-velocityDistribution'  &
                                , 'TODO-DEFINE-PARAMETER\n'//&
                                  'Specifying keyword for velocity distribution', 'constant'&
                                , numberedmulti=.TRUE.)
CALL prms%CreateRealOption(     'Part-Species[$]-Init[$]-InflowRiseTime' &
                                , 'TODO-DEFINE-PARAMETER\n'//&
                                  'Time to ramp the number of inflow particles linearly from zero to unity'&
                                , '0.', numberedmulti=.TRUE.)
CALL prms%CreateIntOption(      'Part-Species[$]-Init[$]-initialParticleNumber' &
                                , 'TODO-DEFINE-PARAMETER\n'//&
                                  'Number of Particles at time 0.0', '0', numberedmulti=.TRUE.)
CALL prms%CreateRealOption(     'Part-Species[$]-Init[$]-RadiusIC'  &
                                , 'TODO-DEFINE-PARAMETER\n'//&
                                  'Radius for IC circle', '1.', numberedmulti=.TRUE.)
CALL prms%CreateRealOption(     'Part-Species[$]-Init[$]-Radius2IC' &
                                , 'TODO-DEFINE-PARAMETER\n'//&
                                  'Radius2 for IC cylinder (ring)', '0.', numberedmulti=.TRUE.)
CALL prms%CreateRealOption(     'Part-Species[$]-Init[$]-RadiusICGyro' &
                                , 'TODO-DEFINE-PARAMETER\n'//&
                                  'Radius for Gyrotron gyro radius', '1.', numberedmulti=.TRUE.)
CALL prms%CreateRealArrayOption('Part-Species[$]-Init[$]-NormalIC'  &
                                , 'TODO-DEFINE-PARAMETER\n'//&
                                  'Normal / Orientation of circle', '0. , 0. , 1.', numberedmulti=.TRUE.)
CALL prms%CreateRealArrayOption('Part-Species[$]-Init[$]-BasePointIC'  &
                                , 'TODO-DEFINE-PARAMETER\n'//&
                                  'Base point for IC cuboid and IC sphere ', '0. , 0. , 0.'&
                                , numberedmulti=.TRUE.)
CALL prms%CreateRealArrayOption('Part-Species[$]-Init[$]-BaseVector1IC'  &
                                , 'TODO-DEFINE-PARAMETER\n'//&
                                  'First base vector for IC cuboid', '1. , 0. , 0.'&
                                , numberedmulti=.TRUE.)
CALL prms%CreateRealArrayOption('Part-Species[$]-Init[$]-BaseVector2IC'  &
                                , 'TODO-DEFINE-PARAMETER\n'//&
                                  'Second base vector for IC cuboid', '0. , 1. , 0.'&
                                , numberedmulti=.TRUE.)
CALL prms%CreateRealOption(     'Part-Species[$]-Init[$]-CuboidHeightIC'  &
                                , 'TODO-DEFINE-PARAMETER\n'//&
                                  'Height of cuboid if SpaceIC = cuboid. (set 0 for flat rectangle)'//&
                                  ',negative value = opposite direction', '1.', numberedmulti=.TRUE.)
CALL prms%CreateRealOption(     'Part-Species[$]-Init[$]-CylinderHeightIC'  &
                                , 'TODO-DEFINE-PARAMETER\n'//&
                                  'Third measure of cylinder  (set 0 for flat rectangle),'//&
                                  ' negative value = opposite direction', '1.', numberedmulti=.TRUE.)
CALL prms%CreateLogicalOption(  'Part-Species[$]-Init[$]-CalcHeightFromDt'  &
                                , 'TODO-DEFINE-PARAMETER\n'//&
                                  'Calculate cuboid/cylinder height from v and dt?', '.FALSE.'&
                                , numberedmulti=.TRUE.)
CALL prms%CreateRealOption(     'Part-Species[$]-Init[$]-VeloIC'  &
                                , 'TODO-DEFINE-PARAMETER\n'//&
                                  'Velocity for inital Data', '0.', numberedmulti=.TRUE.)
CALL prms%CreateRealArrayOption('Part-Species[$]-Init[$]-VeloVecIC'  &
                                , 'TODO-DEFINE-PARAMETER\n'//&
                                  'Normalized velocity vector', '0. , 0. , 0.', numberedmulti=.TRUE.)
CALL prms%CreateRealOption(     'Part-Species[$]-Init[$]-Amplitude'  &
                                , 'TODO-DEFINE-PARAMETER\n'//&
                                  'Amplitude for sin-deviation initiation.', '0.01', numberedmulti=.TRUE.)
CALL prms%CreateRealOption(     'Part-Species[$]-Init[$]-WaveNumber'  &
                                , 'TODO-DEFINE-PARAMETER\n'//&
                                  'WaveNumber for sin-deviation initiation', '2.', numberedmulti=.TRUE.)
CALL prms%CreateIntOption(      'Part-Species[$]-Init[$]-maxParticleNumber-x'  &
                                , 'TODO-DEFINE-PARAMETER\n'//&
                                  'Maximum Number of all Particles in x direction', '0', numberedmulti=.TRUE.)
CALL prms%CreateIntOption(      'Part-Species[$]-Init[$]-maxParticleNumber-y'  &
                                , 'TODO-DEFINE-PARAMETER\n'//&
                                  'Maximum Number of all Particles in y direction', '0', numberedmulti=.TRUE.)
CALL prms%CreateIntOption(      'Part-Species[$]-Init[$]-maxParticleNumber-z'  &
                                , 'TODO-DEFINE-PARAMETER\n'//&
                                  'Maximum Number of all Particles in z direction', '0', numberedmulti=.TRUE.)
CALL prms%CreateRealOption(     'Part-Species[$]-Init[$]-Alpha' &
                                , 'TODO-DEFINE-PARAMETER\n'//&
                                  'WaveNumber for sin-deviation initiation.', '0.', numberedmulti=.TRUE.)
CALL prms%CreateRealOption(     'Part-Species[$]-Init[$]-MWTemperatureIC' &
                                , 'TODO-DEFINE-PARAMETER\n'//&
                                  'Temperature for Maxwell Distribution', '0.', numberedmulti=.TRUE.)
CALL prms%CreateRealOption(     'Part-Species[$]-Init[$]-PartDensity' &
                                , 'TODO-DEFINE-PARAMETER\n'//&
                                  'PartDensity (real particles per m^3)', '0.', numberedmulti=.TRUE.)
CALL prms%CreateIntOption(      'Part-Species[$]-Init[$]-ParticleEmissionType'  &
                                , 'TODO-DEFINE-PARAMETER\n'//&
                                  'Emission Type \n'//&
                                  '1 = emission rate in 1/s,\n'//&
                                  '2 = emission rate 1/iteration\n', '2', numberedmulti=.TRUE.)
CALL prms%CreateRealOption(     'Part-Species[$]-Init[$]-ParticleEmission' &
                                , 'TODO-DEFINE-PARAMETER\n'//&
                                  'Emission in [1/s] or [1/Iteration]', '0.', numberedmulti=.TRUE.)
CALL prms%CreateIntOption(      'Part-Species[$]-Init[$]-NumberOfExcludeRegions'  &
                                , 'TODO-DEFINE-PARAMETER\n'//&
                                  'Number of different regions to be excluded', '0', numberedmulti=.TRUE.)

CALL prms%SetSection("Particle Species Init RegionExculdes")
! some inits or exluded in some regions
CALL prms%CreateStringOption(   'Part-Species[$]-Init[$]-ExcludeRegion[$]-SpaceIC' &
                                , 'TODO-DEFINE-PARAMETER\n'//&
                                  'Specified keyword for excluded particle space condition of'//&
                                  ' species[$] in case of multiple inits  ', 'cuboid', numberedmulti=.TRUE.)
CALL prms%CreateRealOption(     'Part-Species[$]-Init[$]-ExcludeRegion[$]-RadiusIC'  &
                                , 'TODO-DEFINE-PARAMETER\n'//&
                                  'Radius for excluded IC circle', '1.', numberedmulti=.TRUE.)
CALL prms%CreateRealOption(     'Part-Species[$]-Init[$]-ExcludeRegion[$]-Radius2IC' &
                                , 'TODO-DEFINE-PARAMETER\n'//&
                                  'Radius2 for excluded IC cylinder (ring)', '0.', numberedmulti=.TRUE.)
CALL prms%CreateRealArrayOption('Part-Species[$]-Init[$]-ExcludeRegion[$]-NormalIC'  &
                                , 'TODO-DEFINE-PARAMETER\n'//&
                                  'Normal orientation of excluded circle', '0. , 0. , 1.'&
                                , numberedmulti=.TRUE.)
CALL prms%CreateRealArrayOption('Part-Species[$]-Init[$]-ExcludeRegion[$]-BasePointIC'  &
                                , 'TODO-DEFINE-PARAMETER\n'//&
                                  'Base point for excluded IC cuboid and IC sphere', '0. , 0. , 0.'&
                                , numberedmulti=.TRUE.)
CALL prms%CreateRealArrayOption('Part-Species[$]-Init[$]-ExcludeRegion[$]-BaseVector1IC'  &
                                , 'TODO-DEFINE-PARAMETER\n'//&
                                  'First base vector for excluded IC cuboid', '1. , 0. , 0.'&
                                , numberedmulti=.TRUE.)
CALL prms%CreateRealArrayOption('Part-Species[$]-Init[$]-ExcludeRegion[$]-BaseVector2IC'  &
                                , 'TODO-DEFINE-PARAMETER\n'//&
                                  'Second base vector for excluded IC cuboid', '0. , 1. , 0.'&
                                , numberedmulti=.TRUE.)
CALL prms%CreateRealOption(     'Part-Species[$]-Init[$]-ExcludeRegion[$]-CuboidHeightIC'  &
                                , 'TODO-DEFINE-PARAMETER\n'//&
                                  'Height of excluded cuboid, if'//&
                                  ' Part-Species[$]-Init[$]-ExcludeRegion[$]-SpaceIC=cuboid (set 0 for flat rectangle),'//&
                                  ' negative value = opposite direction', '1.', numberedmulti=.TRUE.)
CALL prms%CreateRealOption(     'Part-Species[$]-Init[$]-ExcludeRegion[$]-CylinderHeightIC'  &
                                , 'TODO-DEFINE-PARAMETER\n'//&
                                  'Height of excluded cylinder, if'//&
                                  ' Part-Species[$]-Init[$]-ExcludeRegion[$]-SpaceIC=cylinder (set 0 for flat circle),'//&
                                  'negative value = opposite direction ', '1.', numberedmulti=.TRUE.)

CALL prms%SetSection("Particle Boundaries")

CALL prms%CreateIntOption(      'Part-nBounds'     , 'TODO-DEFINE-PARAMETER\n'//&
                                                       'Number of particle boundaries.', '1')
CALL prms%CreateStringOption(   'Part-Boundary[$]-SourceName'  &
                                , 'TODO-DEFINE-PARAMETER'//&
                                  'No Default. Source Name of Boundary[i]. Has to be selected for all'//&
                                  'nBounds. Has to be same name as defined in preproc tool', numberedmulti=.TRUE.)
CALL prms%CreateStringOption(   'Part-Boundary[$]-Condition'  &
                                , 'TODO-DEFINE-PARAMETER\n'//&
                                  'Used boundary condition for boundary[$].\n'//&
                                  '- open\n'//&
                                  '- reflective\n'//&
                                  '- periodic\n'//&
                                  '- simple_anode\n'//&
                                  '- simple_cathode.\n'//&
                                  '- rot_periodic.\n'//&
                                 'If condition=open, the following parameters are'//&
                                  ' used: (Part-Boundary[$]-=PB) PB-Voltage\n'//&
                                 'If condition=reflective: PB-MomentumACC,PB-WallTemp,PB-TransACC,PB-VibACC,PB-RotACC,'//&
                                  'PB-WallVelo,Voltage,SpeciesSwaps.If condition=periodic:Part-nPeriodicVectors,'//&
                                  'Part-PeriodicVector[$]', 'open', numberedmulti=.TRUE.)
CALL prms%CreateLogicalOption('Part-Boundary[$]-Dielectric' , 'Define if particle boundary [$] is a '//&
                              'dielectric interface, i.e. an interface between a dielectric and a non-dielectric or a between two'//&
                              ' different dielectrics [.TRUE.] or not [.FALSE.] (requires reflective BC and species swap for nSpecies)'&
                              , '.FALSE.', numberedmulti=.TRUE.)
CALL prms%CreateLogicalOption('Part-Boundary[$]-BoundaryParticleOutput' , 'Define if the properties of particles impacting on '//&
                              'boundary [$] are to be stored in an additional .h5 file for post-processing analysis [.TRUE.] '//&
                              'or not [.FALSE.].'&
                              , '.FALSE.', numberedmulti=.TRUE.)
CALL prms%CreateRealOption(     'Part-Boundary[$]-Voltage'  &
                                , 'TODO-DEFINE-PARAMETER'//&
                                  'Voltage on boundary [$]', '1.0e20', numberedmulti=.TRUE.)
CALL prms%CreateRealOption(     'Part-Boundary[$]-WallTemp'  &
                                , 'Wall temperature (in [K]) of reflective particle boundary [$].' &
                                , '0.', numberedmulti=.TRUE.)
CALL prms%CreateRealOption(     'Part-Boundary[$]-MomentumACC'  &
                                , 'Momentum accommodation coefficient of reflective particle boundary [$].' &
                                , '0.', numberedmulti=.TRUE.)
CALL prms%CreateRealOption(     'Part-Boundary[$]-TransACC'  &
                                , 'Translation accommodation coefficient of reflective particle boundary [$].' &
                                , '0.', numberedmulti=.TRUE.)
CALL prms%CreateRealOption(     'Part-Boundary[$]-VibACC'  &
                                , 'Vibrational accommodation coefficient of reflective particle boundary [$].' &
                                , '0.', numberedmulti=.TRUE.)
CALL prms%CreateRealOption(     'Part-Boundary[$]-RotACC'  &
                                , 'Rotational accommodation coefficient of reflective particle boundary [$].' &
                                , '0.', numberedmulti=.TRUE.)
CALL prms%CreateRealOption(     'Part-Boundary[$]-ElecACC '  &
                                , 'Electronic accommodation coefficient of reflective particle boundary [$].' &
                                , '0.', numberedmulti=.TRUE.)
CALL prms%CreateLogicalOption(  'Part-Boundary[$]-Resample'  &
                                , 'TODO-DEFINE-PARAMETER'//&
                                  'Resample Equilibrum Distribution with reflection', '.FALSE.'&
                                , numberedmulti=.TRUE.)
CALL prms%CreateRealArrayOption('Part-Boundary[$]-WallVelo'  &
                                , 'Velocity (global x,y,z in [m/s]) of reflective particle boundary [$].' &
                                , '0. , 0. , 0.', numberedmulti=.TRUE.)                                
CALL prms%CreateLogicalOption(  'Part-Boundary[$]-RotVelo'  &
                                , 'Flag for rotating walls:'//&
                                  ' Particles will be accelerated additionaly to the boundary interaction'//&
                                  ' through the rotating wall depending on their POI, rotation frequency and rotation axis.'//&
                                  ' In that case Part-Boundary[$]-WallVelo will be overwritten.' &
                                , '.FALSE.'&
                                , numberedmulti=.TRUE.)
CALL prms%CreateRealOption(     'Part-Boundary[$]-RotFreq'  &
                                , 'Rotation frequency of the wall in [Hz].' &
                                , '0.', numberedmulti=.TRUE.)
CALL prms%CreateRealArrayOption('Part-Boundary[$]-RotOrg'  &
                                , 'Origin of rotation axis (global x,y,z).' &
                                , '0. , 0. , 0.', numberedmulti=.TRUE.)
CALL prms%CreateRealArrayOption('Part-Boundary[$]-RotAxi'  &
                                , 'Direction of rotation axis (global x,y,z). Note: Rotation direction based on Right-hand rule!' &
                                , '0. , 0. , 0.', numberedmulti=.TRUE.)
CALL prms%CreateIntOption(      'Part-Boundary[$]-RotPeriodicDir'  &
                                , 'Angular degree of rotation periodicity in [deg].' &
                                , '0', numberedmulti=.TRUE.)
CALL prms%CreateRealOption(     'Part-Boundary[$]-WallTemp2'  &
                                , 'Second wall temperature (in [K]) of reflective particle boundary for a temperature gradient.' &
                                , '0.', numberedmulti=.TRUE.)
CALL prms%CreateRealArrayOption('Part-Boundary[$]-TemperatureGradientStart'  &
                                , 'Impose a temperature gradient by supplying a start/end vector and a second wall temperature.' &
                                , '0. , 0. , 0.', numberedmulti=.TRUE.)
CALL prms%CreateRealArrayOption('Part-Boundary[$]-TemperatureGradientEnd'  &
                                , 'Impose a temperature gradient by supplying a start/end vector and a second wall temperature.' &
                                , '0. , 0. , 0.', numberedmulti=.TRUE.)
CALL prms%CreateIntOption(      'Part-Boundary[$]-SurfaceModel'  &
                                , 'Defining surface to be treated reactively by defining Model used '//&
                                'for particle surface interaction. If any >0 then look in section SurfaceModel.\n'//&
                                '0: Maxwell scattering\n'//&
                                '5: SEE-E and SEE-I (secondary e- emission due to e- or i+ bombardment) '//&
                                    'by Levko2015 for copper electrodes\n'//&
                                '6: SEE-E (secondary e- emission due to e- bombardment) '//&
                                    'by Pagonakis2016 for molybdenum (originally from Harrower1956)'//&
                                '7: SEE-I (bombarding electrons are removed, Ar+ on different materials is considered for '//&
                                'secondary e- emission with 0.13 probability) by Depla2009\n' &
                                , '0', numberedmulti=.TRUE.)
CALL prms%CreateIntOption(      'Part-Boundary[$]-NbrOfSpeciesSwaps'  &
                                , 'TODO-DEFINE-PARAMETER\n'//&
                                  'Number of Species to be changed at wall.', '0', numberedmulti=.TRUE.)
CALL prms%CreateRealOption(     'Part-Boundary[$]-ProbOfSpeciesSwaps'  &
                                , 'TODO-DEFINE-PARAMETER'//&
                                  'Probability of SpeciesSwaps at wall', '1.', numberedmulti=.TRUE.)
CALL prms%CreateIntArrayOption( 'Part-Boundary[$]-SpeciesSwaps[$]'  &
                                , 'TODO-DEFINE-PARAMETER'//&
                                  'Species to be changed at wall (out=: delete)', '0 , 0'&
                                , numberedmulti=.TRUE.)
CALL prms%CreateLogicalOption(  'Part-Boundary[$]-UseForQCrit'  &
                                , 'TODO-DEFINE-PARAMETER'//&
                                  'Flag to use Boundary for Q-Criterion', '.TRUE.', numberedmulti=.TRUE.)

CALL prms%CreateIntOption(      'Part-nAuxBCs'  &
                                , 'TODO-DEFINE-PARAMETER'//&
                                  'Number of auxillary BCs that are checked during tracing',  '0')
CALL prms%CreateIntOption(      'Part-AuxBC[$]-NbrOfSpeciesSwaps'  &
                                , 'TODO-DEFINE-PARAMETER'//&
                                  'Number of Species to be changed at wall.',  '0', numberedmulti=.TRUE.)
CALL prms%CreateStringOption(   'Part-AuxBC[$]-Condition'  &
                                , 'TODO-DEFINE-PARAMETER'//&
                                  'Used auxillary boundary condition for boundary[$].'//&
                                  '- open'//&
                                  '- reflective'//&
                                  '- periodic)'//&
                                  '-> more details see also Part-Boundary[$]-Condition',  'open', numberedmulti=.TRUE.)
CALL prms%CreateRealOption(     'Part-AuxBC[$]-MomentumACC'  &
                                , 'TODO-DEFINE-PARAMETER'//&
                                  'Momentum accommodation',  '0.', numberedmulti=.TRUE.)
CALL prms%CreateRealOption(     'Part-AuxBC[$]-WallTemp'  &
                                , 'TODO-DEFINE-PARAMETER'//&
                                  'Wall temperature of boundary[$]',  '0.', numberedmulti=.TRUE.)
CALL prms%CreateRealOption(     'Part-AuxBC[$]-TransACC'  &
                                , 'TODO-DEFINE-PARAMETER'//&
                                  'Translation accommodation on boundary [$]',  '0.', numberedmulti=.TRUE.)
CALL prms%CreateRealOption(     'Part-AuxBC[$]-VibACC'  &
                                , 'TODO-DEFINE-PARAMETER'//&
                                  'Vibrational accommodation on boundary [$]',  '0.', numberedmulti=.TRUE.)
CALL prms%CreateRealOption(     'Part-AuxBC[$]-RotACC'  &
                                , 'TODO-DEFINE-PARAMETER'//&
                                  'Rotational accommodation on boundary [$]',  '0.', numberedmulti=.TRUE.)
CALL prms%CreateRealOption(     'Part-AuxBC[$]-ElecACC'  &
                                , 'TODO-DEFINE-PARAMETER'//&
                                  'Electronic accommodation on boundary [$]',  '0.', numberedmulti=.TRUE.)
CALL prms%CreateLogicalOption(  'Part-AuxBC[$]-Resample'  &
                                , 'TODO-DEFINE-PARAMETER'//&
                                  'Resample Equilibirum Distribution with reflection',  '.FALSE.'&
                                , numberedmulti=.TRUE.)
CALL prms%CreateRealArrayOption('Part-AuxBC[$]-WallVelo'  &
                                , 'TODO-DEFINE-PARAMETER'//&
                                  'Emitted velocity on boundary [$]', '0. , 0. , 0.', numberedmulti=.TRUE.)
CALL prms%CreateRealOption(     'Part-AuxBC[$]-ProbOfSpeciesSwaps'  &
                                , 'TODO-DEFINE-PARAMETER'//&
                                  'Probability of SpeciesSwaps at wall',  '1.', numberedmulti=.TRUE.)
CALL prms%CreateIntArrayOption( 'Part-AuxBC[$]-SpeciesSwaps[$]'  &
                                , 'TODO-DEFINE-PARAMETER'//&
                                  'Species to be changed at wall (out=: delete)', '0 , 0'&
                                , numberedmulti=.TRUE.)
CALL prms%CreateStringOption(   'Part-AuxBC[$]-Type'  &
                                , 'TODO-DEFINE-PARAMETER'//&
                                  'Type of BC (plane, ...)',  'plane', numberedmulti=.TRUE.)
CALL prms%CreateRealArrayOption('Part-AuxBC[$]-r_vec'  &
                                , 'TODO-DEFINE-PARAMETER', '0. , 0. , 0.', numberedmulti=.TRUE.)
CALL prms%CreateRealOption(     'Part-AuxBC[$]-radius'  &
                                , 'TODO-DEFINE-PARAMETER', numberedmulti=.TRUE.) !def. might be calculated!!!
CALL prms%CreateRealArrayOption('Part-AuxBC[$]-n_vec'  &
                                , 'TODO-DEFINE-PARAMETER', '1. , 0. , 0.', numberedmulti=.TRUE.)
CALL prms%CreateRealArrayOption('Part-AuxBC[$]-axis'  &
                                , 'TODO-DEFINE-PARAMETER', '1. , 0. , 0.', numberedmulti=.TRUE.)
CALL prms%CreateRealOption(     'Part-AuxBC[$]-lmin'  &
                                , 'TODO-DEFINE-PARAMETER', numberedmulti=.TRUE.) !def. might be calculated!!!
CALL prms%CreateRealOption(     'Part-AuxBC[$]-lmax'  &
                                , 'TODO-DEFINE-PARAMETER', numberedmulti=.TRUE.) !def. is calculated!!!
CALL prms%CreateLogicalOption(  'Part-AuxBC[$]-inwards'  &
                                , 'TODO-DEFINE-PARAMETER',  '.TRUE.', numberedmulti=.TRUE.)
CALL prms%CreateRealOption(     'Part-AuxBC[$]-rmax'  &
                                , 'TODO-DEFINE-PARAMETER',  '0.', numberedmulti=.TRUE.)
CALL prms%CreateRealOption(     'Part-AuxBC[$]-halfangle'  &
                                , 'TODO-DEFINE-PARAMETER',  '45.', numberedmulti=.TRUE.)
CALL prms%CreateRealOption(     'Part-AuxBC[$]-zfac'  &
                                , 'TODO-DEFINE-PARAMETER',  '1.', numberedmulti=.TRUE.)

! ====================================== photoionization =================================================================
CALL prms%CreateLogicalOption('Part-Species[$]-Init[$]-FirstQuadrantOnly','Only insert particles in the first quadrant that is'//&
                              ' spanned by the vectors x=BaseVector1IC and y=BaseVector2IC in the interval x,y in [0,R]',  '.FALSE.', numberedmulti=.TRUE.)
CALL prms%CreateRealOption('Part-Species[$]-Init[$]-PulseDuration',&
                           'Pulse duration tau for a Gaussian-tpye pulse with I~exp(-(t/tau)^2) [s]', numberedmulti=.TRUE.)
CALL prms%CreateRealOption('Part-Species[$]-Init[$]-WaistRadius',&
                           'Beam waist radius (in focal spot) w_b for Gaussian-tpye pulse with I~exp(-(r/w_b)^2) [m]',&
                            numberedmulti=.TRUE.)
CALL prms%CreateRealOption('Part-Species[$]-Init[$]-IntensityAmplitude',&
                           'Beam intensity maximum I0 Gaussian-tpye pulse with I=I0*exp(-(t/tau)^2)exp(-(r/w_b)^2) [W/m^2]','-1.0',&
                            numberedmulti=.TRUE.)
CALL prms%CreateRealOption('Part-Species[$]-Init[$]-WaveLength','Beam wavelength [m]',numberedmulti=.TRUE.)
CALL prms%CreateRealOption('Part-Species[$]-Init[$]-YieldSEE','Secondary photoelectron yield [-]',numberedmulti=.TRUE.)
CALL prms%CreateRealOption('Part-Species[$]-Init[$]-RepetitionRate','Pulse repetition rate (pulses per second) [Hz]',numberedmulti=.TRUE.)
CALL prms%CreateRealOption('Part-Species[$]-Init[$]-Power','Average pulse power (energy of a single pulse times repetition rate) [W]',&
                           '-1.0',numberedmulti=.TRUE.)
CALL prms%CreateRealOption('Part-Species[$]-Init[$]-Energy','Single pulse energy [J]','-1.0',numberedmulti=.TRUE.)
CALL prms%CreateIntOption( 'Part-Species[$]-Init[$]-NbrOfPulses','Number of pulses [-]','1',numberedmulti=.TRUE.)
CALL prms%CreateRealOption('Part-Species[$]-Init[$]-WorkFunctionSEE','Photoelectron work function [eV]', numberedmulti=.TRUE.)
!CALL prms%CreateRealOption('Part-Species[$]-Init[$]-AngularBetaSEE',&
                           !'Orbital configuration of the solid from which the photoelectrons emerge','0.0', numberedmulti=.TRUE.)
CALL prms%CreateRealOption('Part-Species[$]-Init[$]-EffectiveIntensityFactor', 'Scaling factor that increases I0 [-]',&
                            '1.', numberedmulti=.TRUE.)

END SUBROUTINE DefineParametersParticles


!===================================================================================================================================
! Global particle parameters needed for other particle inits
!===================================================================================================================================
SUBROUTINE InitParticleGlobals()
! MODULES
USE MOD_Globals
USE MOD_ReadInTools
USE MOD_Particle_Tracking_Vars,     ONLY: TrackingMethod,TriaTracking,DoRefMapping
USE MOD_Particle_Vars              ,ONLY: Symmetry
! IMPLICIT VARIABLE HANDLING
IMPLICIT NONE
!-----------------------------------------------------------------------------------------------------------------------------------
! INPUT VARIABLES
!-----------------------------------------------------------------------------------------------------------------------------------
! OUTPUT VARIABLES
!-----------------------------------------------------------------------------------------------------------------------------------
! LOCAL VARIABLES
!===================================================================================================================================

SWRITE(UNIT_stdOut,'(A)')' INIT PARTICLE GLOBALS...'

! Find tracking method immediately, a lot of the later variables depend on it
TrackingMethod = GETINTFROMSTR('TrackingMethod')
SELECT CASE(TrackingMethod)
CASE(REFMAPPING)
  DoRefMapping=.TRUE.
  TriaTracking=.FALSE.
CASE(TRACING)
  DoRefMapping=.FALSE.
  TriaTracking=.FALSE.
CASE(TRIATRACKING)
  DoRefMapping=.FALSE.
  TriaTracking=.TRUE.
CASE DEFAULT
  SWRITE(UNIT_stdOut,'(A)')' TrackingMethod not implemented! Select refmapping (1), tracing (2) or triatracking (3).'
  CALL abort(&
  __STAMP__&
  ,'TrackingMethod not implemented! TrackingMethod=',IntInfoOpt=TrackingMethod)
END SELECT
IF (Symmetry%Order.LE.2) THEN
  DoRefMapping=.FALSE.
  TriaTracking=.TRUE.
  SWRITE(UNIT_stdOut,'(A)') "TrackingMethod set to TriaTracking due to Symmetry2D."
END IF

SWRITE(UNIT_stdOut,'(A)')' INIT PARTICLE GLOBALS DONE'

END SUBROUTINE InitParticleGlobals


SUBROUTINE InitParticles()
!===================================================================================================================================
! Glue Subroutine for particle initialization
!===================================================================================================================================
! MODULES
USE MOD_Globals
USE MOD_ReadInTools
USE MOD_DSMC_Init                  ,ONLY: InitDSMC
USE MOD_DSMC_Vars                  ,ONLY: useDSMC,DSMC,DSMC_Solution
USE MOD_IO_HDF5                    ,ONLY: AddToElemData,ElementOut
USE MOD_LoadBalance_Vars           ,ONLY: nPartsPerElem
USE MOD_Mesh_Vars                  ,ONLY: nElems
USE MOD_Part_Emission              ,ONLY: InitializeParticleEmission,AdaptiveBCAnalyze
USE MOD_SurfaceModel_Porous        ,ONLY: InitPorousBoundaryCondition
USE MOD_Particle_Boundary_Sampling ,ONLY: InitParticleBoundarySampling
USE MOD_SurfaceModel_Vars          ,ONLY: nPorousBC
USE MOD_Particle_Boundary_Vars     ,ONLY: PartBound
USE MOD_Particle_Tracking_Vars     ,ONLY: TrackingMethod
USE MOD_Particle_Vars              ,ONLY: ParticlesInitIsDone,WriteMacroVolumeValues,WriteMacroSurfaceValues,nSpecies
USE MOD_Restart_Vars               ,ONLY: DoRestart
USE MOD_Surface_Flux               ,ONLY: InitializeParticleSurfaceflux
USE MOD_SurfaceModel_Init          ,ONLY: InitSurfaceModel
USE MOD_Particle_Surfaces          ,ONLY: InitParticleSurfaces
USE MOD_Particle_Mesh_Vars         ,ONLY: GEO
#if USE_MPI
USE MOD_Particle_MPI               ,ONLY: InitParticleCommSize
!USE MOD_Particle_MPI_Emission      ,ONLY: InitEmissionParticlesToProcs
#endif
#if (PP_TimeDiscMethod==300)
USE MOD_FPFlow_Init                ,ONLY: InitFPFlow
USE MOD_Particle_Vars              ,ONLY: Symmetry
#endif
#if (PP_TimeDiscMethod==400)
USE MOD_BGK_Init                   ,ONLY: InitBGK
USE MOD_Particle_Vars              ,ONLY: Symmetry
#endif
! IMPLICIT VARIABLE HANDLING
 IMPLICIT NONE
!-----------------------------------------------------------------------------------------------------------------------------------
! INPUT VARIABLES
!-----------------------------------------------------------------------------------------------------------------------------------
! OUTPUT VARIABLES
!-----------------------------------------------------------------------------------------------------------------------------------
! LOCAL VARIABLES
!===================================================================================================================================
IF(ParticlesInitIsDone)THEN
   SWRITE(*,*) "InitParticles already called."
   RETURN
END IF
SWRITE(UNIT_StdOut,'(132("-"))')
SWRITE(UNIT_stdOut,'(A)') ' INIT PARTICLES ...'

IF(TrackingMethod.NE.TRIATRACKING) THEN
  CALL InitParticleSurfaces()
END IF

IF(.NOT.ALLOCATED(nPartsPerElem))THEN
  ALLOCATE(nPartsPerElem(1:nElems))
  nPartsPerElem=0
  CALL AddToElemData(ElementOut,'nPartsPerElem',LongIntArray=nPartsPerElem(:))
END IF

CALL InitializeVariables()

!#if USE_MPI
!CALL InitEmissionParticlesToProcs()
!#endif

CALL InitializeParticleEmission()
CALL InitializeParticleSurfaceflux()

! Initialize volume sampling
IF(useDSMC .OR. WriteMacroVolumeValues) THEN
! definition of DSMC sampling values
  DSMC%SampNum = 0
  ALLOCATE(DSMC_Solution(1:11,1:nElems,1:nSpecies))
  DSMC_Solution = 0.0
END IF

! Initialize surface sampling / rotational periodic mapping
IF (WriteMacroSurfaceValues.OR.DSMC%CalcSurfaceVal.OR.(ANY(PartBound%Reactive)).OR.(nPorousBC.GT.0).OR.GEO%RotPeriodicBC) THEN
  CALL InitParticleBoundarySampling()
  CALL InitParticleBoundaryRotPeriodic()
END IF

! Initialize porous boundary condition (requires BCdata_auxSF and SurfMesh from InitParticleBoundarySampling)
IF(nPorousBC.GT.0) CALL InitPorousBoundaryCondition()

IF (useDSMC) THEN
  CALL InitDSMC()
  CALL InitSurfaceModel()
#if (PP_TimeDiscMethod==300)
IF (Symmetry%Order.EQ.1) CALL abort(__STAMP__&
  ,'ERROR: 1D Fokker-Planck flow is not implemented yet')
  CALL InitFPFlow()
#endif
#if (PP_TimeDiscMethod==400)
IF (Symmetry%Order.EQ.1) CALL abort(__STAMP__&
  ,'ERROR: 1D BGK is not implemented yet')
  CALL InitBGK()
#endif
ELSE IF (WriteMacroVolumeValues.OR.WriteMacroSurfaceValues) THEN
  DSMC%ElectronicModel = 0
END IF

#if USE_MPI
! has to be called AFTER InitializeVariables and InitDSMC
CALL InitParticleCommSize()
#endif

! sampling of near adaptive boundary element values in the first time step to get initial distribution for porous BC
IF(.NOT.DoRestart) THEN
  IF(nPorousBC.GT.0) CALL AdaptiveBCAnalyze(initSampling_opt=.TRUE.)
END IF

ParticlesInitIsDone=.TRUE.
SWRITE(UNIT_stdOut,'(A)')' INIT PARTICLES DONE!'
SWRITE(UNIT_StdOut,'(132("-"))')
END SUBROUTINE InitParticles


SUBROUTINE InitializeVariables()
!===================================================================================================================================
! Initialize the variables first
!===================================================================================================================================
! MODULES
USE MOD_Globals
USE MOD_ReadInTools
USE MOD_Particle_Vars
USE MOD_DSMC_Symmetry          ,ONLY: DSMC_1D_InitVolumes, DSMC_2D_InitVolumes, DSMC_2D_InitRadialWeighting
USE MOD_DSMC_Vars              ,ONLY: RadialWeighting
USE MOD_Part_RHS               ,ONLY: InitPartRHS
USE MOD_Particle_Mesh          ,ONLY: GetMeshMinMax
USE MOD_Particle_Mesh          ,ONLY: InitParticleMesh
USE MOD_Particle_Tracking_Vars ,ONLY: TriaTracking
USE MOD_Particle_Surfaces_Vars ,ONLY: TriaSurfaceFlux
USE MOD_PICInit                ,ONLY: InitPIC
USE MOD_PICDepo_Vars           ,ONLY: DoDeposition
USE MOD_PICInterpolation_Vars  ,ONLY: DoInterpolation
#if USE_MPI
USE MOD_Particle_MPI           ,ONLY: InitEmissionComm
USE MOD_Particle_MPI_Halo      ,ONLY: IdentifyPartExchangeProcs
USE MOD_Particle_MPI_Vars      ,ONLY: PartMPI
#endif /*USE_MPI*/
#ifdef CODE_ANALYZE
USE MOD_PICInterpolation_Vars  ,ONLY: DoInterpolationAnalytic
#endif /*CODE_ANALYZE*/
USE MOD_DSMC_AmbipolarDiffusion,ONLY: InitializeVariablesAmbipolarDiff
USE MOD_TimeDisc_Vars          ,ONLY: ManualTimeStep,useManualTimeStep
! IMPLICIT VARIABLE HANDLING
 IMPLICIT NONE
!-----------------------------------------------------------------------------------------------------------------------------------
! INPUT VARIABLES
!-----------------------------------------------------------------------------------------------------------------------------------
! OUTPUT VARIABLES
!-----------------------------------------------------------------------------------------------------------------------------------
! LOCAL VARIABLES
REAL              :: ManualTimeStepParticle ! temporary variable
!===================================================================================================================================
! Read basic particle parameter
PDM%maxParticleNumber = GETINT('Part-maxParticleNumber','1')
CALL AllocateParticleArrays()
CALL InitializeVariablesRandomNumbers()

! initialization of surface model flags
DoPoissonRounding = GETLOGICAL('Particles-DoPoissonRounding','.FALSE.')
DoTimeDepInflow   = GETLOGICAL('Particles-DoTimeDepInflow','.FALSE.')
DelayTime = GETREAL('Part-DelayTime','0.')
!--- Read Manual Time Step: Old variable name still supported
ManualTimeStepParticle = GETREAL('Particles-ManualTimeStep')
IF(ManualTimeStepParticle.GT.0.0)THEN
  ManualTimeStep = ManualTimeStepParticle
  IF (ManualTimeStep.GT.0.0) useManualTimeStep=.True.
END IF ! ManualTimeStepParticle.GT.0.0

nSpecies = GETINT('Part-nSpecies','1')
IF (nSpecies.LE.0) THEN
  CALL abort(&
__STAMP__&
  ,'ERROR: nSpecies .LE. 0:', nSpecies)
END IF
ALLOCATE(Species(1:nSpecies))

CALL InitializeVariablesSpeciesInits()
! Which Lorentz boost method should be used?
CALL InitPartRHS()
CALL InitializeVariablesPartBoundary()


!-- AuxBCs
CALL InitializeVariablesAuxBC()

!-- Get PIC deposition (skip DSMC, FP-Flow and BGS-Flow related timediscs)
#if (PP_TimeDiscMethod==4) || (PP_TimeDiscMethod==42) || (PP_TimeDiscMethod==300) || (PP_TimeDiscMethod==400)
DoDeposition    = .FALSE.
!DoInterpolation = .FALSE.
CALL PrintOption('No PIC-related Time discretization, turning deposition off. DoDeposition','*CHANGE',LogOpt=DoDeposition)
!CALL PrintOption('No PIC-related Time discretization, turning interpolation off. DoInterpolation','*CHANGE',LogOpt=DoDeposition)
#else
DoDeposition    = GETLOGICAL('PIC-DoDeposition')
#endif /*(PP_TimeDiscMethod==4) || (PP_TimeDiscMethod==42) || (PP_TimeDiscMethod==300) || (PP_TimeDiscMethod==400)*/

!-- Get PIC interpolation (could be skipped above, but DSMC octree requires some interpolation variables, which are allocated before
! init DSMC determines whether DSMC%UseOctree is true or false)
DoInterpolation = GETLOGICAL('PIC-DoInterpolation')
#ifdef CODE_ANALYZE
! Check if an analytic function is to be used for interpolation
DoInterpolationAnalytic   = GETLOGICAL('PIC-DoInterpolationAnalytic')
IF(DoInterpolationAnalytic) DoInterpolation = DoInterpolationAnalytic
#endif /*CODE_ANALYZE*/

! Build BGM and initialize particle mesh
CALL InitParticleMesh()
#if USE_MPI
!-- Build MPI communication
CALL IdentifyPartExchangeProcs()
#endif
CALL InitPIC()

! === 2D/1D/Axisymmetric initialization
! Calculate the volumes for 2D simulation (requires the GEO%zminglob/GEO%zmaxglob from InitFIBGM)
IF(Symmetry%Order.EQ.1) THEN
  TriaEps = 2.22e-16
ELSE
  TriaEps = 0.0
END IF
IF(Symmetry%Order.EQ.2) CALL DSMC_2D_InitVolumes()
IF(Symmetry%Order.EQ.1) CALL DSMC_1D_InitVolumes()
IF(Symmetry%Axisymmetric) THEN
  IF(RadialWeighting%DoRadialWeighting) THEN
    ! Initialization of RadialWeighting in 2D axisymmetric simulations
    RadialWeighting%PerformCloning = .TRUE.
    CALL DSMC_2D_InitRadialWeighting()
  END IF
  IF(.NOT.TriaTracking) CALL abort(&
    __STAMP__&
    ,'ERROR: Axisymmetric simulation only supported with TriaTracking = T')
  IF(.NOT.TriaSurfaceFlux) CALL abort(&
    __STAMP__&
    ,'ERROR: Axisymmetric simulation only supported with TriaSurfaceFlux = T')
END IF

#if USE_MPI
CALL InitEmissionComm()
CALL MPI_BARRIER(PartMPI%COMM,IERROR)
#endif /*USE_MPI*/

CALL InitializeVariablesElectronFluidRegions()
CALL InitializeVariablesIMD()
CALL InitializeVariablesWriteMacroValues()
CALL InitializeVariablesvMPF()
CALL InitializeVariablesIonization()
CALL InitializeVariablesVarTimeStep()
CALL InitializeVariablesAmbipolarDiff()

END SUBROUTINE InitializeVariables


SUBROUTINE AllocateParticleArrays()
!===================================================================================================================================
! Initialize the variables first
!===================================================================================================================================
! MODULES
USE MOD_Globals
USE MOD_ReadInTools
USE MOD_Particle_Vars
USE MOD_Particle_Tracking_Vars  ,ONLY: DoRefMapping
USE MOD_Mesh_Vars               ,ONLY: nElems
USE MOD_DSMC_Vars               ,ONLY: useDSMC
! IMPLICIT VARIABLE HANDLING
 IMPLICIT NONE
!-----------------------------------------------------------------------------------------------------------------------------------
! INPUT VARIABLES
!-----------------------------------------------------------------------------------------------------------------------------------
! OUTPUT VARIABLES
!-----------------------------------------------------------------------------------------------------------------------------------
! LOCAL VARIABLES
INTEGER               :: ALLOCSTAT
!===================================================================================================================================
IF(DoRefMapping)THEN
  ALLOCATE(PartPosRef(1:3,PDM%MaxParticleNumber), STAT=ALLOCSTAT)
  IF (ALLOCSTAT.NE.0) CALL abort(&
  __STAMP__&
  ,' Cannot allocate partposref!')
  PartPosRef=-888.
END IF
#if (PP_TimeDiscMethod==508) || (PP_TimeDiscMethod==509)
velocityOutputAtTime = GETLOGICAL('velocityOutputAtTime','.FALSE.')
IF (velocityOutputAtTime) THEN
  ALLOCATE(velocityAtTime(1:3,1:PDM%maxParticleNumber), STAT=ALLOCSTAT)
  IF (ALLOCSTAT.NE.0) &
    CALL abort(__STAMP__,'ERROR in particle_init.f90: Cannot allocate velocityAtTime array!')
  velocityAtTime=0.
END IF
#endif
#if defined(LSERK)
ALLOCATE(Pt_temp(1:6,1:PDM%maxParticleNumber), STAT=ALLOCSTAT)
IF (ALLOCSTAT.NE.0) THEN
  CALL abort(&
__STAMP__&
  ,'ERROR in particle_init.f90: Cannot allocate Particle arrays!')
END IF
Pt_temp=0.
#endif
#if defined(IMPA) || defined(ROS)
CALL InitializeVariablesImplicit()
#endif

ALLOCATE(PartState(1:6,1:PDM%maxParticleNumber)       , &
         LastPartPos(1:3,1:PDM%maxParticleNumber)     , &
         Pt(1:3,1:PDM%maxParticleNumber)              , &
         PartSpecies(1:PDM%maxParticleNumber)         , &
         PDM%ParticleInside(1:PDM%maxParticleNumber)  , &
         PDM%nextFreePosition(1:PDM%maxParticleNumber), &
         PDM%dtFracPush(1:PDM%maxParticleNumber)      , &
         PDM%IsNewPart(1:PDM%maxParticleNumber), STAT=ALLOCSTAT)
IF (ALLOCSTAT.NE.0) THEN
  CALL abort(&
__STAMP__&
  ,'ERROR in particle_init.f90: Cannot allocate Particle arrays!')
END IF
PDM%ParticleInside(1:PDM%maxParticleNumber) = .FALSE.
PDM%dtFracPush(1:PDM%maxParticleNumber)     = .FALSE.
PDM%IsNewPart(1:PDM%maxParticleNumber)      = .FALSE.
LastPartPos(1:3,1:PDM%maxParticleNumber)    = 0.
PartState=0.
Pt=0.
PartSpecies        = 0
PDM%nextFreePosition(1:PDM%maxParticleNumber)=0

ALLOCATE(PEM%GlobalElemID(1:PDM%maxParticleNumber), STAT=ALLOCSTAT)
IF (ALLOCSTAT.NE.0) CALL abort(&
__STAMP__&
  ,' Cannot allocate PEM%GlobalElemID(1:PDM%maxParticleNumber) array!')

ALLOCATE(PEM%LastGlobalElemID(1:PDM%maxParticleNumber), STAT=ALLOCSTAT)
IF (ALLOCSTAT.NE.0) CALL abort(&
__STAMP__&
  ,' Cannot allocate PEM%LastGlobalElemID(1:PDM%maxParticleNumber) array!')

IF (useDSMC) THEN
  ALLOCATE(PEM%pStart(1:nElems)                         , &
           PEM%pNumber(1:nElems)                        , &
           PEM%pEnd(1:nElems)                           , &
           PEM%pNext(1:PDM%maxParticleNumber)           , STAT=ALLOCSTAT)
           !PDM%nextUsedPosition(1:PDM%maxParticleNumber)
  IF (ALLOCSTAT.NE.0) THEN
    CALL abort(&
__STAMP__&
    , ' Cannot allocate DSMC PEM arrays!')
  END IF
END IF
IF (useDSMC) THEN
  ALLOCATE(PDM%PartInit(1:PDM%maxParticleNumber), STAT=ALLOCSTAT)
           !PDM%nextUsedPosition(1:PDM%maxParticleNumber)
  IF (ALLOCSTAT.NE.0) THEN
    CALL abort(&
__STAMP__&
    ,' Cannot allocate DSMC PEM arrays!')
  END IF
END IF

END SUBROUTINE AllocateParticleArrays

SUBROUTINE InitializeVariablesIonization()
!===================================================================================================================================
! Initialize the variables first
!===================================================================================================================================
! MODULES
USE MOD_Globals
USE MOD_ReadInTools
USE MOD_Particle_Vars
! IMPLICIT VARIABLE HANDLING
 IMPLICIT NONE
!-----------------------------------------------------------------------------------------------------------------------------------
! INPUT VARIABLES
!-----------------------------------------------------------------------------------------------------------------------------------
! OUTPUT VARIABLES
!-----------------------------------------------------------------------------------------------------------------------------------
! LOCAL VARIABLES
!===================================================================================================================================
! Initial Ionization of species
DoInitialIonization = GETLOGICAL('Part-DoInitialIonization','.FALSE.')
IF(DoInitialIonization)THEN
  ! Supply the number of species that are considered for automatic ionization
  InitialIonizationSpecies = GETINT('InitialIonizationSpecies')
  ALLOCATE(InitialIonizationSpeciesID(1:InitialIonizationSpecies))

  ! Supply a vector with the species IDs
  InitialIonizationSpeciesID = GETINTARRAY('InitialIonizationSpeciesID',InitialIonizationSpecies)

  ! Average charge for each atom/molecule in the cell (corresponds to the ionization degree)
  InitialIonizationChargeAverage = GETREAL('InitialIonizationChargeAverage')
END IF
DoFieldIonization = GETLOGICAL('Part-DoFieldIonization')
IF(DoFieldIonization)THEN
  FieldIonizationModel = GETINT('FieldIonizationModel')
END IF

END SUBROUTINE InitializeVariablesIonization


SUBROUTINE InitializeVariablesElectronFluidRegions()
!===================================================================================================================================
! Initialize the variables first
!===================================================================================================================================
! MODULES
USE MOD_Globals
USE MOD_ReadInTools
USE MOD_Particle_Vars
USE MOD_Particle_Mesh          ,ONLY: MapRegionToElem
USE MOD_Particle_Mesh_Vars     ,ONLY: NbrOfRegions,RegionBounds
! IMPLICIT VARIABLE HANDLING
 IMPLICIT NONE
!-----------------------------------------------------------------------------------------------------------------------------------
! INPUT VARIABLES
!-----------------------------------------------------------------------------------------------------------------------------------
! OUTPUT VARIABLES
!-----------------------------------------------------------------------------------------------------------------------------------
! LOCAL VARIABLES
CHARACTER(32)         :: hilf, hilf2
INTEGER               :: iRegions
REAL                  :: phimax_tmp
!===================================================================================================================================
!-- Read parameters for region mapping
NbrOfRegions = GETINT('NbrOfRegions','0')
IF (NbrOfRegions .GT. 0) THEN
  ALLOCATE(RegionBounds(1:6,1:NbrOfRegions))
  DO iRegions=1,NbrOfRegions
    WRITE(UNIT=hilf2,FMT='(I0)') iRegions
    RegionBounds(1:6,iRegions) = GETREALARRAY('RegionBounds'//TRIM(hilf2),6,'0. , 0. , 0. , 0. , 0. , 0.')
  END DO
END IF

IF (NbrOfRegions .GT. 0) THEN
  CALL MapRegionToElem()
  ALLOCATE(RegionElectronRef(1:3,1:NbrOfRegions))
  DO iRegions=1,NbrOfRegions
    WRITE(UNIT=hilf2,FMT='(I0)') iRegions
    ! 1:3 - rho_ref, phi_ref, and Te[eV]
    RegionElectronRef(1:3,iRegions) = GETREALARRAY('Part-RegionElectronRef'//TRIM(hilf2),3,'0. , 0. , 1.')
    WRITE(UNIT=hilf,FMT='(G0)') RegionElectronRef(2,iRegions)
    phimax_tmp = GETREAL('Part-RegionElectronRef'//TRIM(hilf2)//'-PhiMax',TRIM(hilf))
    IF (phimax_tmp.NE.RegionElectronRef(2,iRegions)) THEN !shift reference point (rho_ref, phi_ref) to phi_max:
      RegionElectronRef(1,iRegions) = RegionElectronRef(1,iRegions) &
        * EXP((phimax_tmp-RegionElectronRef(2,iRegions))/RegionElectronRef(3,iRegions))
      RegionElectronRef(2,iRegions) = phimax_tmp
      SWRITE(*,*) 'WARNING: BR-reference point is shifted to:', RegionElectronRef(1:2,iRegions)
    END IF
  END DO
END IF

END SUBROUTINE InitializeVariablesElectronFluidRegions

SUBROUTINE InitializeVariablesVarTimeStep()
!===================================================================================================================================
! Initialize the variables first
!===================================================================================================================================
! MODULES
USE MOD_Globals
USE MOD_ReadInTools
USE MOD_Particle_Vars
USE MOD_Mesh_Vars               ,ONLY: nElems
USE MOD_Particle_Tracking_Vars  ,ONLY: TriaTracking
USE MOD_Particle_VarTimeStep    ,ONLY: VarTimeStep_CalcElemFacs
! IMPLICIT VARIABLE HANDLING
 IMPLICIT NONE
!-----------------------------------------------------------------------------------------------------------------------------------
! INPUT VARIABLES
!-----------------------------------------------------------------------------------------------------------------------------------
! OUTPUT VARIABLES
!-----------------------------------------------------------------------------------------------------------------------------------
! LOCAL VARIABLES
!===================================================================================================================================
! ------- Variable Time Step Initialization (parts requiring completed particle_init and readMesh)
IF(VarTimeStep%UseVariableTimeStep) THEN
  ! Initializing the particle time step array used during calculation for the distribution (after maxParticleNumber was read-in)
  ALLOCATE(VarTimeStep%ParticleTimeStep(1:PDM%maxParticleNumber))
  VarTimeStep%ParticleTimeStep = 1.
  IF(.NOT.TriaTracking) THEN
    CALL abort(&
      __STAMP__&
      ,'ERROR: Variable time step is only supported with TriaTracking = T')
  END IF
  IF(VarTimeStep%UseLinearScaling) THEN
    IF(Symmetry%Order.LE.2) THEN
      ! 2D: particle-wise scaling in the radial direction, ElemFac array only utilized for the output of the time step
      ALLOCATE(VarTimeStep%ElemFac(nElems))
      VarTimeStep%ElemFac = 1.0
    ELSE
      ! 3D: The time step for each cell is precomputed, ElemFac is allocated in the routine
      CALL VarTimeStep_CalcElemFacs()
    END IF
  END IF
  IF(VarTimeStep%UseDistribution) THEN
    ! ! Apply a min-mean filter combo if the distribution was adapted
    ! ! (is performed here to have the element neighbours already defined)
    ! IF(VarTimeStep%AdaptDistribution) CALL VarTimeStep_SmoothDistribution()
    ! Disable AdaptDistribution to avoid adapting during a load balance restart
    IF(VarTimeStep%AdaptDistribution) VarTimeStep%AdaptDistribution = .FALSE.
  END IF
END IF

END SUBROUTINE InitializeVariablesVarTimeStep


SUBROUTINE InitializeVariablesRandomNumbers()
!===================================================================================================================================
! Initialize the variables first
!===================================================================================================================================
! MODULES
USE MOD_Globals
USE MOD_ReadInTools
USE MOD_Particle_Vars
! IMPLICIT VARIABLE HANDLING
 IMPLICIT NONE
!-----------------------------------------------------------------------------------------------------------------------------------
! INPUT VARIABLES
!-----------------------------------------------------------------------------------------------------------------------------------
! OUTPUT VARIABLES
!-----------------------------------------------------------------------------------------------------------------------------------
! LOCAL VARIABLES
INTEGER               :: iSeed, nRandomSeeds, SeedSize
CHARACTER(32)         :: hilf
!===================================================================================================================================
!--- initialize randomization
! Read print flags
printRandomSeeds = GETLOGICAL('printRandomSeeds','.FALSE.')
nRandomSeeds = GETINT('Part-NumberOfRandomSeeds','0')
CALL RANDOM_SEED(Size = SeedSize)    ! specifies compiler specific minimum number of seeds
ALLOCATE(Seeds(SeedSize))
Seeds(:)=1 ! to ensure a solid run when an unfitting number of seeds is provided in ini
IF(nRandomSeeds.EQ.-1) THEN
  ! ensures different random numbers through irreproducable random seeds (via System_clock)
  CALL InitRandomSeed(nRandomSeeds,SeedSize,Seeds)
ELSE IF(nRandomSeeds.EQ.0) THEN
 !   IF (Restart) THEN
 !   CALL !numbers from state file
 ! ELSE IF (.NOT.Restart) THEN
  CALL InitRandomSeed(nRandomSeeds,SeedSize,Seeds)
ELSE IF(nRandomSeeds.GT.0) THEN
  ! read in numbers from ini
  IF(nRandomSeeds.GT.SeedSize) THEN
    SWRITE (*,*) 'Expected ',SeedSize,'seeds. Provided ',nRandomSeeds,'. Computer uses default value for all unset values.'
  ELSE IF(nRandomSeeds.LT.SeedSize) THEN
    SWRITE (*,*) 'Expected ',SeedSize,'seeds. Provided ',nRandomSeeds,'. Computer uses default value for all unset values.'
  END IF
  DO iSeed=1,MIN(SeedSize,nRandomSeeds)
    WRITE(UNIT=hilf,FMT='(I0)') iSeed
    Seeds(iSeed)= GETINT('Particles-RandomSeed'//TRIM(hilf))
  END DO
  IF (ALL(Seeds(:).EQ.0)) THEN
    CALL ABORT(&
     __STAMP__&
     ,'Not all seeds can be set to zero ')
  END IF
  CALL InitRandomSeed(nRandomSeeds,SeedSize,Seeds)
ELSE
  SWRITE (*,*) 'Error: nRandomSeeds not defined.'//&
  'Choose nRandomSeeds'//&
  '=-1    pseudo random'//&
  '= 0    hard-coded deterministic numbers'//&
  '> 0    numbers from ini. Expected ',SeedSize,'seeds.'
END IF

END SUBROUTINE InitializeVariablesRandomNumbers


SUBROUTINE InitializeVariablesWriteMacroValues()
!===================================================================================================================================
! Initialize the variables first
!===================================================================================================================================
! MODULES
USE MOD_Globals
USE MOD_ReadInTools
USE MOD_Particle_Vars
USE MOD_DSMC_Vars              ,ONLY: DSMC
USE MOD_TimeDisc_Vars          ,ONLY: TEnd
! IMPLICIT VARIABLE HANDLING
 IMPLICIT NONE
!-----------------------------------------------------------------------------------------------------------------------------------
! INPUT VARIABLES
!-----------------------------------------------------------------------------------------------------------------------------------
! OUTPUT VARIABLES
!-----------------------------------------------------------------------------------------------------------------------------------
! LOCAL VARIABLES
!===================================================================================================================================
! output of macroscopic values
WriteMacroValues = GETLOGICAL('Part-WriteMacroValues','.FALSE.')
IF(WriteMacroValues)THEN
  WriteMacroVolumeValues = GETLOGICAL('Part-WriteMacroVolumeValues','.TRUE.')
  WriteMacroSurfaceValues = GETLOGICAL('Part-WriteMacroSurfaceValues','.TRUE.')
  IF(.NOT.(WriteMacroVolumeValues.AND.WriteMacroSurfaceValues))THEN
     CALL abort(&
__STAMP__&
    ,'ERROR in particle_init.f90: Part-WriteMacroValues=T => WriteMacroVolumeValues and WriteMacroSurfaceValues must be T!')
  END IF
ELSE
  WriteMacroVolumeValues = GETLOGICAL('Part-WriteMacroVolumeValues','.FALSE.')
  WriteMacroSurfaceValues = GETLOGICAL('Part-WriteMacroSurfaceValues','.FALSE.')
  IF(WriteMacroVolumeValues.AND.WriteMacroSurfaceValues)THEN
    WriteMacroValues = .TRUE.
  END IF
END IF
MacroValSamplIterNum = GETINT('Part-IterationForMacroVal','1')
DSMC%TimeFracSamp = GETREAL('Part-TimeFracForSampling','0.0')
DSMC%CalcSurfaceVal = GETLOGICAL('Particles-DSMC-CalcSurfaceVal','.FALSE.')
IF(WriteMacroVolumeValues.OR.WriteMacroSurfaceValues)THEN
  IF(DSMC%TimeFracSamp.GT.0.0) CALL abort(&
__STAMP__&
    ,'ERROR: Init Macrosampling: WriteMacroValues and Time fraction sampling enabled at the same time')
  IF(WriteMacroSurfaceValues.AND.(.NOT.DSMC%CalcSurfaceVal)) DSMC%CalcSurfaceVal = .TRUE.
END IF
DSMC%NumOutput = GETINT('Particles-NumberForDSMCOutputs','0')
IF((DSMC%TimeFracSamp.GT.0.0).AND.(DSMC%NumOutput.EQ.0)) DSMC%NumOutput = 1
IF (DSMC%NumOutput.NE.0) THEN
  IF (DSMC%TimeFracSamp.GT.0.0) THEN
    DSMC%DeltaTimeOutput = (DSMC%TimeFracSamp * TEnd) / REAL(DSMC%NumOutput)
  ELSE
    DSMC%NumOutput=0
    SWRITE(UNIT_STDOUT,*)'DSMC_NumOutput was set to 0 because timefracsamp is 0.0'
  END IF
END IF

END SUBROUTINE InitializeVariablesWriteMacroValues

SUBROUTINE InitializeVariablesvMPF()
!===================================================================================================================================
! Initialize the variables first
!===================================================================================================================================
! MODULES
USE MOD_Globals
USE MOD_ReadInTools
USE MOD_Particle_Vars
USE MOD_Mesh_Vars              ,ONLY: nElems
USE MOD_Part_MPFtools          ,ONLY: DefinePolyVec, DefineSplitVec
! IMPLICIT VARIABLE HANDLING
 IMPLICIT NONE
!-----------------------------------------------------------------------------------------------------------------------------------
! INPUT VARIABLES
!-----------------------------------------------------------------------------------------------------------------------------------
! OUTPUT VARIABLES
!-----------------------------------------------------------------------------------------------------------------------------------
! LOCAL VARIABLES
INTEGER               :: ALLOCSTAT
!===================================================================================================================================
! init varibale MPF per particle
IF (usevMPF) THEN
  enableParticleMerge = GETLOGICAL('Part-vMPFPartMerge','.FALSE.')
  IF (enableParticleMerge) THEN
    vMPFMergePolyOrder = GETINT('Part-vMPFMergePolOrder','2')
    vMPFMergeCellSplitOrder = GETINT('Part-vMPFCellSplitOrder','15')
    vMPFMergeParticleTarget = GETINT('Part-vMPFMergeParticleTarget','0')
    IF (vMPFMergeParticleTarget.EQ.0) WRITE(*,*) 'vMPFMergeParticleTarget equals zero: no merging is performed!'
    vMPFSplitParticleTarget = GETINT('Part-vMPFSplitParticleTarget','0')
    IF (vMPFSplitParticleTarget.EQ.0) WRITE(*,*) 'vMPFSplitParticleTarget equals zero: no split is performed!'
    vMPFMergeParticleIter = GETINT('Part-vMPFMergeParticleIter','100')
    vMPF_velocityDistribution = TRIM(GETSTR('Part-vMPFvelocityDistribution','OVDR'))
    vMPF_relativistic = GETLOGICAL('Part-vMPFrelativistic','.FALSE.')
    IF(vMPF_relativistic.AND.(vMPF_velocityDistribution.EQ.'MBDR')) THEN
      CALL abort(&
__STAMP__&
      ,'Relativistic handling of vMPF is not possible using MBDR velocity distribution!')
    END IF
    ALLOCATE(vMPF_SpecNumElem(1:nElems,1:nSpecies))
    CALL DefinePolyVec(vMPFMergePolyOrder)
    CALL DefineSplitVec(vMPFMergeCellSplitOrder)
  END IF
  ALLOCATE(PartMPF(1:PDM%maxParticleNumber), STAT=ALLOCSTAT)
  IF (ALLOCSTAT.NE.0) THEN
    CALL abort(&
__STAMP__&
    ,'ERROR in particle_init.f90: Cannot allocate Particle arrays!')
  END IF
END IF
END SUBROUTINE InitializeVariablesvMPF


SUBROUTINE InitializeVariablesIMD()
!===================================================================================================================================
! Initialize the variables first
!===================================================================================================================================
! MODULES
USE MOD_ReadInTools
USE MOD_Particle_Vars
USE MOD_Globals_Vars            ,ONLY: ElementaryCharge
USE MOD_Particle_Tracking_Vars  ,ONLY: DoRefMapping
! IMPLICIT VARIABLE HANDLING
 IMPLICIT NONE
!-----------------------------------------------------------------------------------------------------------------------------------
! INPUT VARIABLES
!-----------------------------------------------------------------------------------------------------------------------------------
! OUTPUT VARIABLES
!-----------------------------------------------------------------------------------------------------------------------------------
! LOCAL VARIABLES
INTEGER               :: iIMDSpec, iSpec
LOGICAL               :: IsIMDSpecies
CHARACTER(32)         :: hilf
!===================================================================================================================================
! IMD data import from *.chkpt file
DoImportIMDFile=.FALSE. ! default
IMDLengthScale=0.0

IMDTimeScale          = GETREAL('IMDTimeScale','10.18e-15')
IMDLengthScale        = GETREAL('IMDLengthScale','1.0E-10')
IMDAtomFile           = GETSTR( 'IMDAtomFile','no file found')
IMDCutOff             = GETSTR( 'IMDCutOff','no_cutoff')
IMDCutOffxValue       = GETREAL('IMDCutOffxValue','-999.9')

IF(TRIM(IMDAtomFile).NE.'no file found')DoImportIMDFile=.TRUE.
IF(DoImportIMDFile)THEN
  DoRefMapping=.FALSE. ! for faster init don't use DoRefMapping!
  CALL PrintOption('DoImportIMDFile=T. Setting DoRefMapping =','*CHANGE',LogOpt=DoRefMapping)
END IF

! get information for IMD atom/ion charge determination and distribution
IMDnSpecies         = GETINT('IMDnSpecies','1')
IMDInputFile        = GETSTR('IMDInputFile','no file found')
ALLOCATE(IMDSpeciesID(IMDnSpecies))
ALLOCATE(IMDSpeciesCharge(IMDnSpecies))
iIMDSpec=1
DO iSpec = 1, nSpecies
  WRITE(UNIT=hilf,FMT='(I0)') iSpec
  IsIMDSpecies = GETLOGICAL('Part-Species'//TRIM(hilf)//'-IsIMDSpecies','.FALSE.')
  IF(IsIMDSpecies)THEN
    IMDSpeciesID(iIMDSpec)=iSpec
    IMDSpeciesCharge(iIMDSpec)=NINT(Species(iSpec)%ChargeIC/ElementaryCharge)
    iIMDSpec=iIMDSpec+1
  END IF
END DO
END SUBROUTINE InitializeVariablesIMD



SUBROUTINE InitializeVariablesAuxBC()
!===================================================================================================================================
! Initialize the variables first
!===================================================================================================================================
! MODULES
USE MOD_Globals
USE MOD_ReadInTools
USE MOD_Globals_Vars           ,ONLY: Pi
USE MOD_Particle_Boundary_Vars ,ONLY: PartAuxBC
USE MOD_Particle_Boundary_Vars ,ONLY: nAuxBCs,AuxBCType,AuxBCMap,AuxBC_plane,AuxBC_cylinder,AuxBC_cone,AuxBC_parabol,UseAuxBCs
USE MOD_Particle_Mesh          ,ONLY: MarkAuxBCElems
! IMPLICIT VARIABLE HANDLING
 IMPLICIT NONE
!-----------------------------------------------------------------------------------------------------------------------------------
! INPUT VARIABLES
!-----------------------------------------------------------------------------------------------------------------------------------
! OUTPUT VARIABLES
!-----------------------------------------------------------------------------------------------------------------------------------
! LOCAL VARIABLES
INTEGER               :: iPartBound, iSwaps, MaxNbrOfSpeciesSwaps
INTEGER               :: iAuxBC, nAuxBCplanes, nAuxBCcylinders, nAuxBCcones, nAuxBCparabols
CHARACTER(32)         :: hilf , hilf2
CHARACTER(200)        :: tmpString
REAL                  :: n_vec(3), cos2, rmax
REAL, DIMENSION(3,1)  :: norm,norm1,norm2
REAL, DIMENSION(3,3)  :: rot1, rot2
REAL                  :: alpha1, alpha2
!===================================================================================================================================
nAuxBCs=GETINT('Part-nAuxBCs','0')
IF (nAuxBCs.GT.0) THEN
  UseAuxBCs=.TRUE.
  ALLOCATE (AuxBCType(1:nAuxBCs) &
            ,AuxBCMap(1:nAuxBCs) )
  AuxBCMap=0
  !- Read in BC parameters
  ALLOCATE(PartAuxBC%TargetBoundCond(1:nAuxBCs))
  ALLOCATE(PartAuxBC%MomentumACC(1:nAuxBCs))
  ALLOCATE(PartAuxBC%WallTemp(1:nAuxBCs))
  ALLOCATE(PartAuxBC%TransACC(1:nAuxBCs))
  ALLOCATE(PartAuxBC%VibACC(1:nAuxBCs))
  ALLOCATE(PartAuxBC%RotACC(1:nAuxBCs))
  ALLOCATE(PartAuxBC%ElecACC(1:nAuxBCs))
  ALLOCATE(PartAuxBC%Resample(1:nAuxBCs))
  ALLOCATE(PartAuxBC%WallVelo(1:3,1:nAuxBCs))
  ALLOCATE(PartAuxBC%NbrOfSpeciesSwaps(1:nAuxBCs))
  !--determine MaxNbrOfSpeciesSwaps for correct allocation
  MaxNbrOfSpeciesSwaps=0
  DO iPartBound=1,nAuxBCs
    WRITE(UNIT=hilf,FMT='(I0)') iPartBound
    PartAuxBC%NbrOfSpeciesSwaps(iPartBound)= GETINT('Part-AuxBC'//TRIM(hilf)//'-NbrOfSpeciesSwaps','0')
    MaxNbrOfSpeciesSwaps=max(PartAuxBC%NbrOfSpeciesSwaps(iPartBound),MaxNbrOfSpeciesSwaps)
  END DO
  IF (MaxNbrOfSpeciesSwaps.gt.0) THEN
    ALLOCATE(PartAuxBC%ProbOfSpeciesSwaps(1:nAuxBCs))
    ALLOCATE(PartAuxBC%SpeciesSwaps(1:2,1:MaxNbrOfSpeciesSwaps,1:nAuxBCs))
  END IF
  !--
  DO iPartBound=1,nAuxBCs
    WRITE(UNIT=hilf,FMT='(I0)') iPartBound
    tmpString = TRIM(GETSTR('Part-AuxBC'//TRIM(hilf)//'-Condition','open'))
    SELECT CASE (TRIM(tmpString))
    CASE('open')
      PartAuxBC%TargetBoundCond(iPartBound) = PartAuxBC%OpenBC          ! definitions see typesdef_pic
    CASE('reflective')
      PartAuxBC%TargetBoundCond(iPartBound) = PartAuxBC%ReflectiveBC
      PartAuxBC%MomentumACC(iPartBound)     = GETREAL('Part-AuxBC'//TRIM(hilf)//'-MomentumACC')
      PartAuxBC%WallTemp(iPartBound)        = GETREAL('Part-AuxBC'//TRIM(hilf)//'-WallTemp')
      PartAuxBC%TransACC(iPartBound)        = GETREAL('Part-AuxBC'//TRIM(hilf)//'-TransACC')
      PartAuxBC%VibACC(iPartBound)          = GETREAL('Part-AuxBC'//TRIM(hilf)//'-VibACC')
      PartAuxBC%RotACC(iPartBound)          = GETREAL('Part-AuxBC'//TRIM(hilf)//'-RotACC')
      PartAuxBC%ElecACC(iPartBound)         = GETREAL('Part-AuxBC'//TRIM(hilf)//'-ElecACC')
      PartAuxBC%Resample(iPartBound)        = GETLOGICAL('Part-AuxBC'//TRIM(hilf)//'-Resample')
      PartAuxBC%WallVelo(1:3,iPartBound)    = GETREALARRAY('Part-AuxBC'//TRIM(hilf)//'-WallVelo',3)
      IF (PartAuxBC%NbrOfSpeciesSwaps(iPartBound).gt.0) THEN
        !read Species to be changed at wall (in, out), out=0: delete
        PartAuxBC%ProbOfSpeciesSwaps(iPartBound)= GETREAL('Part-AuxBC'//TRIM(hilf)//'-ProbOfSpeciesSwaps','1.')
        DO iSwaps=1,PartAuxBC%NbrOfSpeciesSwaps(iPartBound)
          WRITE(UNIT=hilf2,FMT='(I0)') iSwaps
          PartAuxBC%SpeciesSwaps(1:2,iSwaps,iPartBound) = &
            GETINTARRAY('Part-AuxBC'//TRIM(hilf)//'-SpeciesSwaps'//TRIM(hilf2),2,'0. , 0.')
        END DO
      END IF
    CASE DEFAULT
      SWRITE(*,*) ' AuxBC Condition does not exists: ', TRIM(tmpString)
      CALL abort(&
        __STAMP__&
        ,'AuxBC Condition does not exist')
    END SELECT
  END DO
  !- read and count types
  nAuxBCplanes = 0
  nAuxBCcylinders = 0
  nAuxBCcones = 0
  nAuxBCparabols = 0
  DO iAuxBC=1,nAuxBCs
    WRITE(UNIT=hilf,FMT='(I0)') iAuxBC
    AuxBCType(iAuxBC) = TRIM(GETSTR('Part-AuxBC'//TRIM(hilf)//'-Type','plane'))
    SELECT CASE (TRIM(AuxBCType(iAuxBC)))
    CASE ('plane')
      nAuxBCplanes = nAuxBCplanes + 1
      AuxBCMap(iAuxBC) = nAuxBCplanes
    CASE ('cylinder')
      nAuxBCcylinders = nAuxBCcylinders + 1
      AuxBCMap(iAuxBC) = nAuxBCcylinders
    CASE ('cone')
      nAuxBCcones = nAuxBCcones + 1
      AuxBCMap(iAuxBC) = nAuxBCcones
    CASE ('parabol')
      nAuxBCparabols = nAuxBCparabols + 1
      AuxBCMap(iAuxBC) = nAuxBCparabols
    CASE DEFAULT
      SWRITE(*,*) ' AuxBC does not exist: ', TRIM(AuxBCType(iAuxBC))
      CALL abort(&
        __STAMP__&
        ,'AuxBC does not exist')
    END SELECT
  END DO
  !- allocate type-specifics
  IF (nAuxBCplanes.GT.0) THEN
    ALLOCATE (AuxBC_plane(1:nAuxBCplanes))
  END IF
  IF (nAuxBCcylinders.GT.0) THEN
    ALLOCATE (AuxBC_cylinder(1:nAuxBCcylinders))
  END IF
  IF (nAuxBCcones.GT.0) THEN
    ALLOCATE (AuxBC_cone(1:nAuxBCcones))
  END IF
  IF (nAuxBCparabols.GT.0) THEN
    ALLOCATE (AuxBC_parabol(1:nAuxBCparabols))
  END IF
  !- read type-specifics
  DO iAuxBC=1,nAuxBCs
    WRITE(UNIT=hilf,FMT='(I0)') iAuxBC
    SELECT CASE (TRIM(AuxBCType(iAuxBC)))
    CASE ('plane')
      AuxBC_plane(AuxBCMap(iAuxBC))%r_vec = GETREALARRAY('Part-AuxBC'//TRIM(hilf)//'-r_vec',3,'0. , 0. , 0.')
      WRITE(UNIT=hilf2,FMT='(G0)') HUGE(AuxBC_plane(AuxBCMap(iAuxBC))%radius)
      AuxBC_plane(AuxBCMap(iAuxBC))%radius= GETREAL('Part-AuxBC'//TRIM(hilf)//'-radius',TRIM(hilf2))
      n_vec                               = GETREALARRAY('Part-AuxBC'//TRIM(hilf)//'-n_vec',3,'1. , 0. , 0.')
      IF (DOT_PRODUCT(n_vec,n_vec).EQ.0.) THEN
        CALL abort(&
          __STAMP__&
          ,'Part-AuxBC-n_vec is zero for AuxBC',iAuxBC)
      ELSE !scale vector
        AuxBC_plane(AuxBCMap(iAuxBC))%n_vec = n_vec/SQRT(DOT_PRODUCT(n_vec,n_vec))
      END IF
    CASE ('cylinder')
      AuxBC_cylinder(AuxBCMap(iAuxBC))%r_vec = GETREALARRAY('Part-AuxBC'//TRIM(hilf)//'-r_vec',3,'0. , 0. , 0.')
      n_vec                                  = GETREALARRAY('Part-AuxBC'//TRIM(hilf)//'-axis',3,'1. , 0. , 0.')
      IF (DOT_PRODUCT(n_vec,n_vec).EQ.0.) THEN
        CALL abort(&
          __STAMP__&
          ,'Part-AuxBC-axis is zero for AuxBC',iAuxBC)
      ELSE !scale vector
        AuxBC_cylinder(AuxBCMap(iAuxBC))%axis = n_vec/SQRT(DOT_PRODUCT(n_vec,n_vec))
      END IF
      AuxBC_cylinder(AuxBCMap(iAuxBC))%radius  = GETREAL('Part-AuxBC'//TRIM(hilf)//'-radius','1.')
      WRITE(UNIT=hilf2,FMT='(G0)') -HUGE(AuxBC_cylinder(AuxBCMap(iAuxBC))%lmin)
      AuxBC_cylinder(AuxBCMap(iAuxBC))%lmin  = GETREAL('Part-AuxBC'//TRIM(hilf)//'-lmin',TRIM(hilf2))
      WRITE(UNIT=hilf2,FMT='(G0)') HUGE(AuxBC_cylinder(AuxBCMap(iAuxBC))%lmin)
      AuxBC_cylinder(AuxBCMap(iAuxBC))%lmax  = GETREAL('Part-AuxBC'//TRIM(hilf)//'-lmax',TRIM(hilf2))
      AuxBC_cylinder(AuxBCMap(iAuxBC))%inwards = GETLOGICAL('Part-AuxBC'//TRIM(hilf)//'-inwards','.TRUE.')
    CASE ('cone')
      AuxBC_cone(AuxBCMap(iAuxBC))%r_vec = GETREALARRAY('Part-AuxBC'//TRIM(hilf)//'-r_vec',3,'0. , 0. , 0.')
      n_vec                              = GETREALARRAY('Part-AuxBC'//TRIM(hilf)//'-axis',3,'1. , 0. , 0.')
      IF (DOT_PRODUCT(n_vec,n_vec).EQ.0.) THEN
        CALL abort(&
          __STAMP__&
          ,'Part-AuxBC-axis is zero for AuxBC',iAuxBC)
      ELSE !scale vector
        AuxBC_cone(AuxBCMap(iAuxBC))%axis = n_vec/SQRT(DOT_PRODUCT(n_vec,n_vec))
      END IF
      AuxBC_cone(AuxBCMap(iAuxBC))%lmin  = GETREAL('Part-AuxBC'//TRIM(hilf)//'-lmin','0.')
      IF (AuxBC_cone(AuxBCMap(iAuxBC))%lmin.LT.0.) CALL abort(&
          __STAMP__&
          ,'Part-AuxBC-lminis .lt. zero for AuxBC',iAuxBC)
      WRITE(UNIT=hilf2,FMT='(G0)') HUGE(AuxBC_cone(AuxBCMap(iAuxBC))%lmin)
      AuxBC_cone(AuxBCMap(iAuxBC))%lmax  = GETREAL('Part-AuxBC'//TRIM(hilf)//'-lmax',TRIM(hilf2))
      rmax  = GETREAL('Part-AuxBC'//TRIM(hilf)//'-rmax','0.')
      ! either define rmax at lmax or the halfangle
      IF (rmax.EQ.0.) THEN
        AuxBC_cone(AuxBCMap(iAuxBC))%halfangle  = GETREAL('Part-AuxBC'//TRIM(hilf)//'-halfangle','45.')*PI/180.
      ELSE
        AuxBC_cone(AuxBCMap(iAuxBC))%halfangle  = ATAN(rmax/AuxBC_cone(AuxBCMap(iAuxBC))%lmax)
      END IF
      IF (AuxBC_cone(AuxBCMap(iAuxBC))%halfangle.LE.0.) CALL abort(&
          __STAMP__&
          ,'Part-AuxBC-halfangle is .le. zero for AuxBC',iAuxBC)
      AuxBC_cone(AuxBCMap(iAuxBC))%inwards = GETLOGICAL('Part-AuxBC'//TRIM(hilf)//'-inwards','.TRUE.')
      cos2 = COS(AuxBC_cone(AuxBCMap(iAuxBC))%halfangle)**2
      AuxBC_cone(AuxBCMap(iAuxBC))%geomatrix(:,1) &
        = AuxBC_cone(AuxBCMap(iAuxBC))%axis(1)*AuxBC_cone(AuxBCMap(iAuxBC))%axis - (/cos2,0.,0./)
      AuxBC_cone(AuxBCMap(iAuxBC))%geomatrix(:,2) &
        = AuxBC_cone(AuxBCMap(iAuxBC))%axis(2)*AuxBC_cone(AuxBCMap(iAuxBC))%axis - (/0.,cos2,0./)
      AuxBC_cone(AuxBCMap(iAuxBC))%geomatrix(:,3) &
        = AuxBC_cone(AuxBCMap(iAuxBC))%axis(3)*AuxBC_cone(AuxBCMap(iAuxBC))%axis - (/0.,0.,cos2/)
    CASE ('parabol')
      AuxBC_parabol(AuxBCMap(iAuxBC))%r_vec = GETREALARRAY('Part-AuxBC'//TRIM(hilf)//'-r_vec',3,'0. , 0. , 0.')
      n_vec                              = GETREALARRAY('Part-AuxBC'//TRIM(hilf)//'-axis',3,'1. , 0. , 0.')
      IF (DOT_PRODUCT(n_vec,n_vec).EQ.0.) THEN
        CALL abort(&
          __STAMP__&
          ,'Part-AuxBC-axis is zero for AuxBC',iAuxBC)
      ELSE !scale vector
        AuxBC_parabol(AuxBCMap(iAuxBC))%axis = n_vec/SQRT(DOT_PRODUCT(n_vec,n_vec))
      END IF
      AuxBC_parabol(AuxBCMap(iAuxBC))%lmin  = GETREAL('Part-AuxBC'//TRIM(hilf)//'-lmin','0.')
      IF (AuxBC_parabol(AuxBCMap(iAuxBC))%lmin.LT.0.) CALL abort(&
          __STAMP__&
          ,'Part-AuxBC-lmin is .lt. zero for AuxBC',iAuxBC)
      WRITE(UNIT=hilf2,FMT='(G0)') HUGE(AuxBC_parabol(AuxBCMap(iAuxBC))%lmin)
      AuxBC_parabol(AuxBCMap(iAuxBC))%lmax  = GETREAL('Part-AuxBC'//TRIM(hilf)//'-lmax',TRIM(hilf2))
      AuxBC_parabol(AuxBCMap(iAuxBC))%zfac  = GETREAL('Part-AuxBC'//TRIM(hilf)//'-zfac','1.')
      AuxBC_parabol(AuxBCMap(iAuxBC))%inwards = GETLOGICAL('Part-AuxBC'//TRIM(hilf)//'-inwards','.TRUE.')

      norm(:,1)=AuxBC_parabol(AuxBCMap(iAuxBC))%axis
      IF (.NOT.ALMOSTZERO(SQRT(norm(1,1)**2+norm(3,1)**2))) THEN !collinear with y?
        alpha1=ATAN2(norm(1,1),norm(3,1))
        CALL roty(rot1,alpha1)
        norm1=MATMUL(rot1,norm)
      ELSE
        alpha1=0.
        CALL ident(rot1)
        norm1=norm
      END IF
      IF (.NOT.ALMOSTZERO(SQRT(norm1(2,1)**2+norm1(3,1)**2))) THEN !collinear with x?
        alpha2=-ATAN2(norm1(2,1),norm1(3,1))
        CALL rotx(rot2,alpha2)
        norm2=MATMUL(rot2,norm1)
      ELSE
        CALL abort(&
          __STAMP__&
          ,'vector is collinear with x-axis. this should not be possible... AuxBC:',iAuxBC)
      END IF
      AuxBC_parabol(AuxBCMap(iAuxBC))%rotmatrix(:,:)=MATMUL(rot2,rot1)
      AuxBC_parabol(AuxBCMap(iAuxBC))%geomatrix4(:,:)=0.
      AuxBC_parabol(AuxBCMap(iAuxBC))%geomatrix4(1,1)=1.
      AuxBC_parabol(AuxBCMap(iAuxBC))%geomatrix4(2,2)=1.
      AuxBC_parabol(AuxBCMap(iAuxBC))%geomatrix4(3,3)=0.
      AuxBC_parabol(AuxBCMap(iAuxBC))%geomatrix4(3,4)=-0.5*AuxBC_parabol(AuxBCMap(iAuxBC))%zfac
      AuxBC_parabol(AuxBCMap(iAuxBC))%geomatrix4(4,3)=-0.5*AuxBC_parabol(AuxBCMap(iAuxBC))%zfac
    CASE DEFAULT
      SWRITE(*,*) ' AuxBC does not exist: ', TRIM(AuxBCType(iAuxBC))
      CALL abort(&
        __STAMP__&
        ,'AuxBC does not exist for AuxBC',iAuxBC)
    END SELECT
  END DO
  CALL MarkAuxBCElems()
ELSE
  UseAuxBCs=.FALSE.
END IF

END SUBROUTINE InitializeVariablesAuxBC


SUBROUTINE InitializeVariablesPartBoundary()
!===================================================================================================================================
! Initialize the variables first
!===================================================================================================================================
! MODULES
USE MOD_Globals
USE MOD_Globals_Vars           ,ONLY: PI
USE MOD_ReadInTools
USE MOD_Dielectric_Vars        ,ONLY: DoDielectricSurfaceCharge
USE MOD_DSMC_Vars              ,ONLY: useDSMC
USE MOD_Mesh_Vars              ,ONLY: BoundaryName,BoundaryType, nBCs
USE MOD_Particle_Vars
USE MOD_SurfaceModel_Vars      ,ONLY: nPorousBC
USE MOD_Particle_Boundary_Vars ,ONLY: PartBound,nPartBound,DoBoundaryParticleOutput,PartStateBoundary
USE MOD_Particle_Tracking_Vars ,ONLY: DoRefMapping
USE MOD_Particle_Surfaces_Vars ,ONLY: BCdata_auxSF
USE MOD_Particle_Mesh_Vars     ,ONLY: GEO
! IMPLICIT VARIABLE HANDLING
 IMPLICIT NONE
!-----------------------------------------------------------------------------------------------------------------------------------
! INPUT VARIABLES
!-----------------------------------------------------------------------------------------------------------------------------------
! OUTPUT VARIABLES
!-----------------------------------------------------------------------------------------------------------------------------------
! LOCAL VARIABLES
INTEGER               :: iPartBound, iBC, iPBC, iSwaps, MaxNbrOfSpeciesSwaps
INTEGER               :: ALLOCSTAT, dummy_int
CHARACTER(32)         :: hilf , hilf2
CHARACTER(200)        :: tmpString
LOGICAL               :: DeprecatedVoltage
!===================================================================================================================================
! Read in boundary parameters
dummy_int = CountOption('Part-nBounds')       ! check if Part-nBounds is present in .ini file
nPartBound = GETINT('Part-nBounds','1.') ! get number of particle boundaries
! Read-in number of porous boundaries
nPorousBC = GETINT('Surf-nPorousBC', '0')
IF ((nPartBound.LE.0).OR.(dummy_int.LT.0)) THEN
  CALL abort(&
__STAMP__&
  ,'ERROR: nPartBound .LE. 0:', nPartBound)
END IF

ALLOCATE(PartBound%SourceBoundName(  1:nPartBound))
PartBound%SourceBoundName = ''
ALLOCATE(PartBound%TargetBoundCond(  1:nPartBound))
PartBound%TargetBoundCond = -1
ALLOCATE(PartBound%MomentumACC(      1:nPartBound))
PartBound%MomentumACC = -1
ALLOCATE(PartBound%WallTemp(         1:nPartBound))
PartBound%WallTemp = -1.
ALLOCATE(PartBound%WallTemp2(        1:nPartBound))
PartBound%WallTemp2 = -1.
ALLOCATE(PartBound%WallTempDelta(    1:nPartBound))
PartBound%WallTempDelta = 0.
ALLOCATE(PartBound%TransACC(         1:nPartBound))
PartBound%TransACC = -1.
ALLOCATE(PartBound%VibACC(           1:nPartBound))
PartBound%VibACC = -1.
ALLOCATE(PartBound%RotACC(           1:nPartBound))
PartBound%RotACC = -1.
ALLOCATE(PartBound%ElecACC(          1:nPartBound))
PartBound%ElecACC = -1.
ALLOCATE(PartBound%Resample(         1:nPartBound))
PartBound%Resample = .FALSE.
ALLOCATE(PartBound%WallVelo(     1:3,1:nPartBound))
PartBound%WallVelo = 0.
ALLOCATE(PartBound%RotVelo(          1:nPartBound))
PartBound%RotVelo = .FALSE.
ALLOCATE(PartBound%RotFreq(          1:nPartBound))
PartBound%RotFreq = -1.
ALLOCATE(PartBound%RotOrg(       1:3,1:nPartBound))
PartBound%RotOrg = 0.
ALLOCATE(PartBound%RotAxi(       1:3,1:nPartBound))
PartBound%RotAxi = 0.
ALLOCATE(PartBound%RotPeriodicDir(  1:nPartBound))
PartBound%RotPeriodicDir = 0
ALLOCATE(PartBound%TempGradStart(1:3,1:nPartBound))
PartBound%TempGradStart = 0.
ALLOCATE(PartBound%TempGradEnd(  1:3,1:nPartBound))
PartBound%TempGradEnd = 0.
ALLOCATE(PartBound%TempGradVec(  1:3,1:nPartBound))
PartBound%TempGradVec = 0.
ALLOCATE(PartBound%SurfaceModel(     1:nPartBound))
PartBound%SurfaceModel = 0
ALLOCATE(PartBound%Reactive(         1:nPartBound))
PartBound%Reactive = .FALSE.
ALLOCATE(PartBound%Voltage(1:nPartBound))
PartBound%Voltage = 0.
DeprecatedVoltage = .FALSE.
ALLOCATE(PartBound%UseForQCrit(1:nPartBound))
PartBound%UseForQCrit = .FALSE.
ALLOCATE(PartBound%NbrOfSpeciesSwaps(1:nPartBound))
PartBound%NbrOfSpeciesSwaps = 0

!--determine MaxNbrOfSpeciesSwaps for correct allocation
MaxNbrOfSpeciesSwaps=0
DO iPartBound=1,nPartBound
  WRITE(UNIT=hilf,FMT='(I0)') iPartBound
  PartBound%NbrOfSpeciesSwaps(iPartBound)= GETINT('Part-Boundary'//TRIM(hilf)//'-NbrOfSpeciesSwaps','0')
  MaxNbrOfSpeciesSwaps=max(PartBound%NbrOfSpeciesSwaps(iPartBound),MaxNbrOfSpeciesSwaps)
END DO
IF (MaxNbrOfSpeciesSwaps.gt.0) THEN
  ALLOCATE(PartBound%ProbOfSpeciesSwaps(1:nPartBound))
  PartBound%ProbOfSpeciesSwaps = -1
  ALLOCATE(PartBound%SpeciesSwaps(1:2,1:MaxNbrOfSpeciesSwaps,1:nPartBound))
  PartBound%SpeciesSwaps = -1
END IF
! Dielectric Surfaces
ALLOCATE(PartBound%Dielectric(1:nPartBound))
PartBound%Dielectric=.FALSE.
DoDielectricSurfaceCharge=.FALSE.
! Surface particle output to .h5
ALLOCATE(PartBound%BoundaryParticleOutput(1:nPartBound))
PartBound%BoundaryParticleOutput=.FALSE.
DoBoundaryParticleOutput=.FALSE.

PartMeshHasPeriodicBCs=.FALSE.
GEO%RotPeriodicBC =.FALSE.
#if defined(IMPA) || defined(ROS)
PartMeshHasReflectiveBCs=.FALSE.
#endif
DO iPartBound=1,nPartBound
  WRITE(UNIT=hilf,FMT='(I0)') iPartBound
  tmpString = TRIM(GETSTR('Part-Boundary'//TRIM(hilf)//'-Condition','open'))

  SELECT CASE (TRIM(tmpString))
  CASE('open')
    PartBound%TargetBoundCond(iPartBound) = PartBound%OpenBC          ! definitions see typesdef_pic
    PartBound%Voltage(iPartBound)         = GETREAL('Part-Boundary'//TRIM(hilf)//'-Voltage')
    IF(ABS(PartBound%Voltage(iPartBound)).LT.1e20) DeprecatedVoltage=.TRUE.
  CASE('reflective')
#if defined(IMPA) || defined(ROS)
    PartMeshHasReflectiveBCs=.TRUE.
#endif
    PartBound%TargetBoundCond(iPartBound) = PartBound%ReflectiveBC
    PartBound%MomentumACC(iPartBound)     = GETREAL('Part-Boundary'//TRIM(hilf)//'-MomentumACC')
    PartBound%WallTemp(iPartBound)        = GETREAL('Part-Boundary'//TRIM(hilf)//'-WallTemp')
    PartBound%TransACC(iPartBound)        = GETREAL('Part-Boundary'//TRIM(hilf)//'-TransACC')
    PartBound%VibACC(iPartBound)          = GETREAL('Part-Boundary'//TRIM(hilf)//'-VibACC')
    PartBound%RotACC(iPartBound)          = GETREAL('Part-Boundary'//TRIM(hilf)//'-RotACC')
    PartBound%ElecACC(iPartBound)         = GETREAL('Part-Boundary'//TRIM(hilf)//'-ElecACC')
    PartBound%Resample(iPartBound)        = GETLOGICAL('Part-Boundary'//TRIM(hilf)//'-Resample')
    PartBound%WallVelo(1:3,iPartBound)    = GETREALARRAY('Part-Boundary'//TRIM(hilf)//'-WallVelo',3)
    PartBound%RotVelo(iPartBound)         = GETLOGICAL('Part-Boundary'//TRIM(hilf)//'-RotVelo')
    PartBound%RotFreq(iPartBound)         = GETREAL('Part-Boundary'//TRIM(hilf)//'-RotFreq')
    PartBound%RotOrg(1:3,iPartBound)      = GETREALARRAY('Part-Boundary'//TRIM(hilf)//'-RotOrg',3)
    PartBound%RotAxi(1:3,iPartBound)      = GETREALARRAY('Part-Boundary'//TRIM(hilf)//'-RotAxi',3)
    PartBound%Voltage(iPartBound)         = GETREAL('Part-Boundary'//TRIM(hilf)//'-Voltage')
    IF(ABS(PartBound%Voltage(iPartBound)).LT.1e20) DeprecatedVoltage=.TRUE.
    PartBound%SurfaceModel(iPartBound)    = GETINT('Part-Boundary'//TRIM(hilf)//'-SurfaceModel')
    PartBound%WallTemp2(iPartBound)         = GETREAL('Part-Boundary'//TRIM(hilf)//'-WallTemp2')
    IF(PartBound%WallTemp2(iPartBound).GT.0.) THEN
      PartBound%TempGradStart(1:3,iPartBound) = GETREALARRAY('Part-Boundary'//TRIM(hilf)//'-TemperatureGradientStart',3)
      PartBound%TempGradEnd(1:3,iPartBound)   = GETREALARRAY('Part-Boundary'//TRIM(hilf)//'-TemperatureGradientEnd',3)
      PartBound%WallTempDelta(iPartBound)   = PartBound%WallTemp2(iPartBound) - PartBound%WallTemp(iPartBound)
      PartBound%TempGradVec(1:3,iPartBound) = PartBound%TempGradEnd(1:3,iPartBound) - PartBound%TempGradStart(1:3,iPartBound)
    END IF
    ! check for correct surfacemodel input
    IF (PartBound%SurfaceModel(iPartBound).GT.0)THEN
      IF (.NOT.useDSMC) CALL abort(&
          __STAMP__&
          ,'Cannot use surfacemodel>0 with useDSMC=F for particle boundary: ',iPartBound)
      SELECT CASE (PartBound%SurfaceModel(iPartBound))
      CASE (0)
        PartBound%Reactive(iPartBound)        = .FALSE.
      CASE (5,6,7)
        PartBound%Reactive(iPartBound)        = .TRUE.
      CASE DEFAULT
        CALL abort(&
            __STAMP__&
            ,'Error in particle init: only allowed SurfaceModels: 0,5,6,7!')
      END SELECT
    END IF
    IF (PartBound%NbrOfSpeciesSwaps(iPartBound).gt.0) THEN
      !read Species to be changed at wall (in, out), out=0: delete
      PartBound%ProbOfSpeciesSwaps(iPartBound)= GETREAL('Part-Boundary'//TRIM(hilf)//'-ProbOfSpeciesSwaps','1.')
      DO iSwaps=1,PartBound%NbrOfSpeciesSwaps(iPartBound)
        WRITE(UNIT=hilf2,FMT='(I0)') iSwaps
        PartBound%SpeciesSwaps(1:2,iSwaps,iPartBound) = &
            GETINTARRAY('Part-Boundary'//TRIM(hilf)//'-SpeciesSwaps'//TRIM(hilf2),2,'0. , 0.')
      END DO
      IF(PartBound%Reactive(iPartBound)) THEN
        CALL abort(&
          __STAMP__&
          ,'ERROR: Species swap is only supported in combination with Maxwell scattering (SurfModel = 0). PartBound: ',iPartBound)
      END IF
    END IF
    ! Dielectric Surfaces
    PartBound%Dielectric(iPartBound)      = GETLOGICAL('Part-Boundary'//TRIM(hilf)//'-Dielectric')
    ! Sanity check: PartBound%Dielectric=T requires supplying species swap for every species
    IF(PartBound%Dielectric(iPartBound))THEN
      IF(PartBound%NbrOfSpeciesSwaps(iPartBound).NE.nSpecies)THEN
        CALL abort(&
            __STAMP__&
            ,'PartBound%NbrOfSpeciesSwaps(iPartBound).NE.nSpecies: PartBound%Dielectric=T requires supplying species swap for every species!')
      ELSE
        DoDielectricSurfaceCharge=.TRUE.
      END IF ! PartBound%NbrOfSpeciesSwaps(iPartBound).NE.nSpecies
    END IF ! PartBound%Dielectric(iPartBound)
  CASE('periodic')
    PartBound%TargetBoundCond(iPartBound) = PartBound%PeriodicBC
    PartMeshHasPeriodicBCs = .TRUE.
  CASE('simple_anode')
    PartBound%TargetBoundCond(iPartBound) = PartBound%SimpleAnodeBC
  CASE('simple_cathode')
    PartBound%TargetBoundCond(iPartBound) = PartBound%SimpleCathodeBC
  CASE('symmetric')
#if defined(IMPA) || defined(ROS)
    PartMeshHasReflectiveBCs=.TRUE.
#endif
    PartBound%TargetBoundCond(iPartBound) = PartBound%SymmetryBC
    PartBound%WallVelo(1:3,iPartBound)    = (/0.,0.,0./)
  CASE('symmetric_axis')
    PartBound%TargetBoundCond(iPartBound) = PartBound%SymmetryAxis
    PartBound%WallVelo(1:3,iPartBound)    = (/0.,0.,0./)
  CASE('rot_periodic')
    GEO%RotPeriodicBC = .TRUE.
    PartBound%TargetBoundCond(iPartBound)  = PartBound%RotPeriodicBC
    PartBound%RotPeriodicDir(iPartBound) = GETINT('Part-Boundary'//TRIM(hilf)//'-RotPeriodicDir','0.')
    IF(ABS(PartBound%RotPeriodicDir(iPartBound)).NE.1) THEN
      CALL abort(&
          __STAMP__&
          ,'Angle for for rotational periodicity must not be zero!')
    END IF
  CASE DEFAULT
    SWRITE(*,*) ' Boundary does not exists: ', TRIM(tmpString)
    CALL abort(&
        __STAMP__&
        ,'Particle Boundary Condition does not exist')
  END SELECT
  PartBound%SourceBoundName(iPartBound) = TRIM(GETSTR('Part-Boundary'//TRIM(hilf)//'-SourceName'))
  PartBound%UseForQCrit(iPartBound)     = GETLOGICAL('Part-Boundary'//TRIM(hilf)//'-UseForQCrit','.TRUE.')
  IF(PartBound%UseForQCrit(iPartBound))THEN
    SWRITE(*,*)"PartBound",iPartBound,"is used for the Q-Criterion"
  END IF ! PartBound%UseForQCrit(iPartBound)

  ! Surface particle output to .h5
  PartBound%BoundaryParticleOutput(iPartBound)      = GETLOGICAL('Part-Boundary'//TRIM(hilf)//'-BoundaryParticleOutput')
  IF(PartBound%BoundaryParticleOutput(iPartBound))THEN
    DoBoundaryParticleOutput=.TRUE.
  END IF ! PartBound%BoundaryParticleOutput(iPartBound)
END DO

IF(GEO%RotPeriodicBC) THEN
  GEO%RotPeriodicAxi   = GETINT('Part-RotPeriodicAxi')
  GEO%RotPeriodicAngle = GETREAL('Part-RotPeriodicAngle')
  IF(ALMOSTZERO(GEO%RotPeriodicAngle)) THEN
    CALL abort(&
        __STAMP__&
        ,'Angle for for rotational periodicity must not be zero!')
  END IF
  GEO%RotPeriodicAngle = GEO%RotPeriodicAngle / 180. * PI
END IF

! Surface particle output to .h5
IF(DoBoundaryParticleOutput)THEN
  ALLOCATE(PartStateBoundary(1:10,1:PDM%maxParticleNumber), STAT=ALLOCSTAT)
  IF (ALLOCSTAT.NE.0) THEN
    CALL abort(&
        __STAMP__&
        ,'ERROR in particle_init.f90: Cannot allocate PartStateBoundary array!')
  END IF
  PartStateBoundary=0.
END IF

! Set mapping from field boundary to particle boundary index
ALLOCATE(PartBound%MapToPartBC(1:nBCs))
PartBound%MapToPartBC(:)=-10
DO iPBC=1,nPartBound
  DO iBC = 1, nBCs
    IF (BoundaryType(iBC,BC_TYPE).EQ.0) THEN
      PartBound%MapToPartBC(iBC) = -1 !there are no internal BCs in the mesh, they are just in the name list!
      SWRITE(*,*)"... PartBound",iPBC,"is internal bound, no mapping needed"
    ELSEIF(BoundaryType(iBC,BC_TYPE).EQ.100)THEN
      IF(DoRefMapping)THEN
        SWRITE(UNIT_STDOUT,'(A)') ' Analyze sides are not implemented for DoRefMapping=T, because '//  &
                                  ' orientation of SideNormVec is unknown.'
     CALL abort(&
                __STAMP__&
                ,' Analyze-BCs cannot be used for internal reflection in general cases! ')
      END IF
    END IF
    IF (TRIM(BoundaryName(iBC)).EQ.TRIM(PartBound%SourceBoundName(iPBC))) THEN
      PartBound%MapToPartBC(iBC) = iPBC !PartBound%TargetBoundCond(iPBC)
      SWRITE(*,*)"... Mapped PartBound",iPBC,"on FieldBound",BoundaryType(iBC,1),",i.e.:",TRIM(BoundaryName(iBC))
    END IF
  END DO
END DO
! Errorhandler for PartBound-Types that could not be mapped to the
! FieldBound-Types.
DO iBC = 1,nBCs
  IF (PartBound%MapToPartBC(iBC).EQ.-10) THEN
    CALL abort(&
__STAMP__&
    ,' PartBound%MapToPartBC for Boundary is not set. iBC: :',iBC)
  END IF
END DO

!-- Floating Potential
ALLOCATE(BCdata_auxSF(1:nPartBound))
DO iPartBound=1,nPartBound
  BCdata_auxSF(iPartBound)%SideNumber=-1 !init value when not used
  BCdata_auxSF(iPartBound)%GlobalArea=0.
  BCdata_auxSF(iPartBound)%LocalArea=0.
END DO

!-- Sanity check: Deprecated voltage parameter
IF(DeprecatedVoltage) CALL abort(&
  __STAMP__&
  ,'Part-Boundary-Voltage is no longer supported. Use corresponding RefState parameter as described in the user guide.')

END SUBROUTINE InitializeVariablesPartBoundary

SUBROUTINE InitializeVariablesSpeciesInits()
!===================================================================================================================================
! Initialize the variables first
!===================================================================================================================================
! MODULES
USE MOD_Globals
USE MOD_Globals_Vars
USE MOD_ReadInTools
USE MOD_Particle_Vars
USE MOD_DSMC_Vars              ,ONLY: useDSMC, BGGas
USE MOD_DSMC_BGGas             ,ONLY: BGGas_Initialize
USE MOD_Mesh_Tools             ,ONLY: GetCNElemID
USE MOD_Particle_Mesh_Vars     ,ONLY: LocalVolume
#if USE_MPI
USE MOD_LoadBalance_Vars       ,ONLY: PerformLoadBalance
#endif /*USE_MPI*/
! IMPLICIT VARIABLE HANDLING
 IMPLICIT NONE
!-----------------------------------------------------------------------------------------------------------------------------------
! INPUT VARIABLES
!-----------------------------------------------------------------------------------------------------------------------------------
! OUTPUT VARIABLES
!-----------------------------------------------------------------------------------------------------------------------------------
! LOCAL VARIABLES
INTEGER               :: iSpec, iInit, iExclude
CHARACTER(32)         :: hilf , hilf2, hilf3
LOGICAL               :: PartDens_OnlyInit
REAL                  :: lineVector(3), v_drift_line, A_ins, factor
!===================================================================================================================================
BGGas%NumberOfSpecies = 0
ALLOCATE(BGGas%BackgroundSpecies(nSpecies))
BGGas%BackgroundSpecies = .FALSE.
ALLOCATE(BGGas%NumberDensity(nSpecies))
BGGas%NumberDensity = 0.
ALLOCATE(SpecReset(1:nSpecies))
SpecReset=.FALSE.

DO iSpec = 1, nSpecies
  SWRITE (UNIT_stdOut,'(66(". "))')
  WRITE(UNIT=hilf,FMT='(I0)') iSpec
  Species(iSpec)%NumberOfInits         = GETINT('Part-Species'//TRIM(hilf)//'-nInits','0')
#if USE_MPI
  IF(.NOT.PerformLoadBalance) THEN
#endif /*USE_MPI*/
    SpecReset(iSpec)                     = GETLOGICAL('Part-Species'//TRIM(hilf)//'-Reset','.FALSE.')
#if USE_MPI
  END IF
#endif /*USE_MPI*/
  Species(iSpec)%ChargeIC              = GETREAL('Part-Species'//TRIM(hilf)//'-ChargeIC','0.')
  Species(iSpec)%MassIC                = GETREAL('Part-Species'//TRIM(hilf)//'-MassIC')
  Species(iSpec)%MacroParticleFactor   = GETREAL('Part-Species'//TRIM(hilf)//'-MacroParticleFactor','1.')
#if defined(IMPA)
  Species(iSpec)%IsImplicit            = GETLOGICAL('Part-Species'//TRIM(hilf)//'-IsImplicit','.FALSE.')
#endif
  ALLOCATE(Species(iSpec)%Init(1:Species(iSpec)%NumberOfInits))
  DO iInit = 1, Species(iSpec)%NumberOfInits
    WRITE(UNIT=hilf2,FMT='(I0)') iInit
    hilf2=TRIM(hilf)//'-Init'//TRIM(hilf2)
    Species(iSpec)%Init(iInit)%SpaceIC               = TRIM(GETSTR('Part-Species'//TRIM(hilf2)//'-SpaceIC','cell_local'))
    !-------------------------------------------------------------------------------------------------------------------------------
    IF (TRIM(Species(iSpec)%Init(iInit)%SpaceIC).EQ.'cell_local') THEN
      ! get emission and init data
      Species(iSpec)%Init(iInit)%UseForInit            = GETLOGICAL('Part-Species'//TRIM(hilf2)//'-UseForInit')
      Species(iSpec)%Init(iInit)%UseForEmission        = .FALSE.
    ELSE ! SpaceIC not cell_local
      Species(iSpec)%Init(iInit)%UseForInit            = GETLOGICAL('Part-Species'//TRIM(hilf2)//'-UseForInit')
      Species(iSpec)%Init(iInit)%UseForEmission        = GETLOGICAL('Part-Species'//TRIM(hilf2)//'-UseForEmission')
      IF((Symmetry%Order.EQ.2).OR.VarTimeStep%UseVariableTimeStep) THEN
        CALL abort(__STAMP__&
            ,'ERROR: Particle insertion/emission for 2D/axisymmetric or variable time step only possible with'//&
             'cell_local-SpaceIC and/or surface flux!')
      END IF
    END IF
    !-------------------------------------------------------------------------------------------------------------------------------
    Species(iSpec)%Init(iInit)%velocityDistribution  = TRIM(GETSTR('Part-Species'//TRIM(hilf2)//'-velocityDistribution'&
      ,'maxwell_lpn'))
   IF(TRIM(Species(iSpec)%Init(iInit)%velocityDistribution).EQ.'photon_SEE_energy')THEN
      Species(iSpec)%Init(iInit)%WorkFunctionSEE  = GETREAL('Part-Species'//TRIM(hilf2)//'-WorkFunctionSEE')
    END IF
    Species(iSpec)%Init(iInit)%InflowRiseTime        = GETREAL('Part-Species'//TRIM(hilf2)//'-InflowRiseTime','0.')
    Species(iSpec)%Init(iInit)%initialParticleNumber = GETINT('Part-Species'//TRIM(hilf2)//'-initialParticleNumber','0')
    Species(iSpec)%Init(iInit)%RadiusIC              = GETREAL('Part-Species'//TRIM(hilf2)//'-RadiusIC','1.')
    Species(iSpec)%Init(iInit)%Radius2IC             = GETREAL('Part-Species'//TRIM(hilf2)//'-Radius2IC','0.')
    Species(iSpec)%Init(iInit)%RadiusICGyro          = GETREAL('Part-Species'//TRIM(hilf2)//'-RadiusICGyro','1.')
    Species(iSpec)%Init(iInit)%NormalIC              = GETREALARRAY('Part-Species'//TRIM(hilf2)//'-NormalIC',3,'0. , 0. , 1.')
    Species(iSpec)%Init(iInit)%BasePointIC           = GETREALARRAY('Part-Species'//TRIM(hilf2)//'-BasePointIC',3,'0. , 0. , 0.')
    Species(iSpec)%Init(iInit)%BaseVector1IC         = GETREALARRAY('Part-Species'//TRIM(hilf2)//'-BaseVector1IC',3,'1. , 0. , 0.')
    Species(iSpec)%Init(iInit)%BaseVector2IC         = GETREALARRAY('Part-Species'//TRIM(hilf2)//'-BaseVector2IC',3,'0. , 1. , 0.')
    Species(iSpec)%Init(iInit)%CuboidHeightIC        = GETREAL('Part-Species'//TRIM(hilf2)//'-CuboidHeightIC','1.')
    Species(iSpec)%Init(iInit)%CylinderHeightIC      = GETREAL('Part-Species'//TRIM(hilf2)//'-CylinderHeightIC','1.')
    Species(iSpec)%Init(iInit)%CalcHeightFromDt      = GETLOGICAL('Part-Species'//TRIM(hilf2)//'-CalcHeightFromDt','.FALSE.')
    Species(iSpec)%Init(iInit)%VeloIC                = GETREAL('Part-Species'//TRIM(hilf2)//'-VeloIC','0.')
    Species(iSpec)%Init(iInit)%VeloVecIC             = GETREALARRAY('Part-Species'//TRIM(hilf2)//'-VeloVecIC',3,'0. , 0. , 0.')
    Species(iSpec)%Init(iInit)%Amplitude             = GETREAL('Part-Species'//TRIM(hilf2)//'-Amplitude','0.01')
    Species(iSpec)%Init(iInit)%WaveNumber            = GETREAL('Part-Species'//TRIM(hilf2)//'-WaveNumber','2.')
    Species(iSpec)%Init(iInit)%maxParticleNumberX    = GETINT('Part-Species'//TRIM(hilf2)//'-maxParticleNumber-x','0')
    Species(iSpec)%Init(iInit)%maxParticleNumberY    = GETINT('Part-Species'//TRIM(hilf2)//'-maxParticleNumber-y','0')
    Species(iSpec)%Init(iInit)%maxParticleNumberZ    = GETINT('Part-Species'//TRIM(hilf2)//'-maxParticleNumber-z','0')
    Species(iSpec)%Init(iInit)%Alpha                 = GETREAL('Part-Species'//TRIM(hilf2)//'-Alpha','0.')
    Species(iSpec)%Init(iInit)%MWTemperatureIC       = GETREAL('Part-Species'//TRIM(hilf2)//'-MWTemperatureIC','0.')
    Species(iSpec)%Init(iInit)%PartDensity           = GETREAL('Part-Species'//TRIM(hilf2)//'-PartDensity','0.')
    ! Background gas definition
    IF(TRIM(Species(iSpec)%Init(iInit)%SpaceIC).EQ.'background') THEN
      IF(.NOT.BGGas%BackgroundSpecies(iSpec)) THEN
        BGGas%NumberOfSpecies = BGGas%NumberOfSpecies + 1
        BGGas%BackgroundSpecies(iSpec)  = .TRUE.
        BGGas%NumberDensity(iSpec)      = Species(iSpec)%Init(iInit)%PartDensity
      ELSE
        CALL abort(__STAMP__&
            ,'ERROR: Only one background definition per species is allowed!')
      END IF
    END IF
    IF (Species(iSpec)%Init(iInit)%UseForEmission) THEN
      Species(iSpec)%Init(iInit)%ParticleEmissionType  = GETINT('Part-Species'//TRIM(hilf2)//'-ParticleEmissionType','2')
      Species(iSpec)%Init(iInit)%ParticleEmission      = GETREAL('Part-Species'//TRIM(hilf2)//'-ParticleEmission','0.')
    ELSE
      Species(iSpec)%Init(iInit)%ParticleEmissionType  = 0 !dummy
      Species(iSpec)%Init(iInit)%ParticleEmission      = 0. !dummy
    END IF
    ! Photoionization in cylinderical volume (modelling a laser pulse) and SEE based on photon impact on a surface
    IF((TRIM(Species(iSpec)%Init(iInit)%SpaceIC).EQ.'photon_SEE_disc')          &
   .OR.(TRIM(Species(iSpec)%Init(iInit)%SpaceIC).EQ.'photon_cylinder')) THEN
      Species(iSpec)%Init(iInit)%ParticleEmissionType = 7
      Species(iSpec)%Init(iInit)%UseForEmission = .TRUE.
      ! Check coordinate system of normal vector and two tangential vectors (they must form an orthogonal basis)
      ASSOCIATE( v1 => UNITVECTOR(Species(iSpec)%Init(iInit)%NormalIC)      ,&
                 v2 => UNITVECTOR(Species(iSpec)%Init(iInit)%BaseVector1IC) ,&
                 v3 => UNITVECTOR(Species(iSpec)%Init(iInit)%BaseVector2IC))
        IF(DOT_PRODUCT(v1,v2).GT.1.e-4)CALL abort(&
            __STAMP__&
            ,'NormalIC and BaseVector1IC are not perpendicular! Their dot product yields',RealInfoOpt=DOT_PRODUCT(v1,v2))

        IF(DOT_PRODUCT(v1,v3).GT.1e-4) CALL abort(&
            __STAMP__&
            ,'NormalIC and BaseVector2IC are not perpendicular! Their dot product yields',RealInfoOpt=DOT_PRODUCT(v1,v3))

        IF(DOT_PRODUCT(v2,v3).GT.1e-4) CALL abort(&
            __STAMP__&
            ,'BaseVector1IC and BaseVector2IC are not perpendicular! Their dot product yields',RealInfoOpt=DOT_PRODUCT(v2,v3))
      END ASSOCIATE

      Species(iSpec)%Init(iInit)%FirstQuadrantOnly = GETLOGICAL('Part-Species'//TRIM(hilf2)//'-FirstQuadrantOnly')

      Species(iSpec)%Init(iInit)%PulseDuration      = GETREAL('Part-Species'//TRIM(hilf2)//'-PulseDuration')
      Species(iSpec)%Init(iInit)%tShift = SQRT(8.0) * Species(iSpec)%Init(iInit)%PulseDuration
      Species(iSpec)%Init(iInit)%WaistRadius        = GETREAL('Part-Species'//TRIM(hilf2)//'-WaistRadius')
      Species(iSpec)%Init(iInit)%WaveLength         = GETREAL('Part-Species'//TRIM(hilf2)//'-WaveLength')
      Species(iSpec)%Init(iInit)%NbrOfPulses        = GETINT('Part-Species'//TRIM(hilf2)//'-NbrOfPulses')
      Species(iSpec)%Init(iInit)%NINT_Correction    = 0.0

      Species(iSpec)%Init(iInit)%Power              = GETREAL('Part-Species'//TRIM(hilf2)//'-Power')
      Species(iSpec)%Init(iInit)%Energy             = GETREAL('Part-Species'//TRIM(hilf2)//'-Energy')
      Species(iSpec)%Init(iInit)%IntensityAmplitude = GETREAL('Part-Species'//TRIM(hilf2)//'-IntensityAmplitude')

      ! Set dummy value as it might not be read
      Species(iSpec)%Init(iInit)%RepetitionRate = -1.0

      IF(Species(iSpec)%Init(iInit)%Power.GT.0.0)THEN
        Species(iSpec)%Init(iInit)%RepetitionRate = GETREAL('Part-Species'//TRIM(hilf2)//'-RepetitionRate')
        Species(iSpec)%Init(iInit)%Period = 1./Species(iSpec)%Init(iInit)%RepetitionRate
        SWRITE(*,*) 'Photoionization in cylinderical volume: Selecting mode [RepetitionRate and Power]'

        Species(iSpec)%Init(iInit)%Energy = Species(iSpec)%Init(iInit)%Power / Species(iSpec)%Init(iInit)%RepetitionRate
        CALL PrintOption('Single pulse energy: Part-Species'//TRIM(hilf2)//'-Energy [J]','CALCUL.',&
                         RealOpt=Species(iSpec)%Init(iInit)%Energy)

        Species(iSpec)%Init(iInit)%IntensityAmplitude = Species(iSpec)%Init(iInit)%Energy / &
          (Species(iSpec)%Init(iInit)%WaistRadius**2 * Species(iSpec)%Init(iInit)%PulseDuration * PI**(3.0/2.0))

        CALL PrintOption('Intensity amplitude: I0 [W/m^2]','CALCUL.',RealOpt=Species(iSpec)%Init(iInit)%IntensityAmplitude)
      ELSEIF(Species(iSpec)%Init(iInit)%Energy.GT.0.0)THEN
        ! Check if more than one pulse is required
        IF(Species(iSpec)%Init(iInit)%NbrOfPulses.GT.1)THEN
          Species(iSpec)%Init(iInit)%RepetitionRate     = GETREAL('Part-Species'//TRIM(hilf2)//'-RepetitionRate')
          Species(iSpec)%Init(iInit)%Period = 1./Species(iSpec)%Init(iInit)%RepetitionRate
        ELSE
          Species(iSpec)%Init(iInit)%Period = 2.0 * Species(iSpec)%Init(iInit)%tShift
        END IF ! Species(iSpec)%Init(iInit)%NbrOfPulses
        SWRITE(*,*) 'Photoionization in cylinderical volume: Selecting mode [Energy]'

        Species(iSpec)%Init(iInit)%IntensityAmplitude = Species(iSpec)%Init(iInit)%Energy / &
          (Species(iSpec)%Init(iInit)%WaistRadius**2 * Species(iSpec)%Init(iInit)%PulseDuration * PI**(3.0/2.0))

        CALL PrintOption('Intensity amplitude: I0 [W/m^2]','CALCUL.',RealOpt=Species(iSpec)%Init(iInit)%IntensityAmplitude)
      ELSEIF(Species(iSpec)%Init(iInit)%IntensityAmplitude.GT.0.0)THEN
        ! Check if more than one pulse is required
        IF(Species(iSpec)%Init(iInit)%NbrOfPulses.GT.1)THEN
          Species(iSpec)%Init(iInit)%RepetitionRate     = GETREAL('Part-Species'//TRIM(hilf2)//'-RepetitionRate')
          Species(iSpec)%Init(iInit)%Period = 1./Species(iSpec)%Init(iInit)%RepetitionRate
        ELSE
          Species(iSpec)%Init(iInit)%Period = 2.0 * Species(iSpec)%Init(iInit)%tShift
        END IF ! Species(iSpec)%Init(iInit)%NbrOfPulses
        SWRITE(*,*) 'Photoionization in cylinderical volume: Selecting mode [IntensityAmplitude]'

        ! Calculate energy: E = I0*w_b**2*tau*PI**(3.0/2.0)
        Species(iSpec)%Init(iInit)%Energy = Species(iSpec)%Init(iInit)%IntensityAmplitude*Species(iSpec)%Init(iInit)%WaistRadius**2&
                                            *Species(iSpec)%Init(iInit)%PulseDuration*PI**(3.0/2.0)
        CALL PrintOption('Single pulse energy: Part-Species'//TRIM(hilf2)//'-Energy [J]','CALCUL.',&
                         RealOpt=Species(iSpec)%Init(iInit)%Energy)
      ELSE
        CALL abort(&
          __STAMP__&
          ,'Photoionization in cylinderical volume: Supply either power P and repetition rate f, or energy E or intensity maximum I0!')
      END IF ! use RepetitionRate and Power

      ! Sanity check: overlapping of pulses is not implemented (use multiple emissions for this)
      IF(2.0*Species(iSpec)%Init(iInit)%tShift.GT.Species(iSpec)%Init(iInit)%Period) CALL abort(&
        __STAMP__&
        ,'Pulse length (2*tShift) is greater than the pulse period. This is not implemented!')

      ! Calculate the corrected intensity amplitude (due to temporal "-tShift to tShift" and spatial cut-off "0 to R")
      factor = PI**(3.0/2.0) * Species(iSpec)%Init(iInit)%WaistRadius**2 * Species(iSpec)%Init(iInit)%PulseDuration * &
          (1.0-EXP(-Species(iSpec)%Init(iInit)%RadiusIC**2/(Species(iSpec)%Init(iInit)%WaistRadius**2)))*&
          ERF(Species(iSpec)%Init(iInit)%tShift/Species(iSpec)%Init(iInit)%PulseDuration)
      Species(iSpec)%Init(iInit)%IntensityAmplitude = Species(iSpec)%Init(iInit)%Energy / factor
      CALL PrintOption('Corrected Intensity amplitude: I0_corr [W/m^2]','CALCUL.',RealOpt=Species(iSpec)%Init(iInit)%IntensityAmplitude)

      CALL PrintOption('Pulse period (Time between maximum of two pulses) [s]','CALCUL.',RealOpt=Species(iSpec)%Init(iInit)%Period)

      CALL PrintOption('Temporal pulse width (pulse time) [s]','CALCUL.',RealOpt=2.0*Species(iSpec)%Init(iInit)%tShift)
      Species(iSpec)%Init(iInit)%tActive = REAL(Species(iSpec)%Init(iInit)%NbrOfPulses - 1)*Species(iSpec)%Init(iInit)%Period &
                                             + 2.0*Species(iSpec)%Init(iInit)%tShift
      CALL PrintOption('Pulse will end at tActive (pulse final time) [s]','CALCUL.',RealOpt=Species(iSpec)%Init(iInit)%tActive)

      IF(TRIM(Species(iSpec)%Init(iInit)%SpaceIC).EQ.'photon_cylinder') THEN
        Species(iSpec)%Init(iInit)%EffectiveIntensityFactor = GETREAL('Part-Species'//TRIM(hilf2)//'-EffectiveIntensityFactor')
      ELSE
        Species(iSpec)%Init(iInit)%YieldSEE           = GETREAL('Part-Species'//TRIM(hilf2)//'-YieldSEE')
      END IF
    END IF
    Species(iSpec)%Init(iInit)%NumberOfExcludeRegions= GETINT('Part-Species'//TRIM(hilf2)//'-NumberOfExcludeRegions','0')
    Species(iSpec)%Init(iInit)%InsertedParticle      = 0
    Species(iSpec)%Init(iInit)%InsertedParticleSurplus = 0

    !----------- various checks/calculations after read-in of Species(i)%Init(iInit)%-data ----------------------------------!
    !--- Check if Initial ParticleInserting is really used
    !IF ( ((Species(iSpec)%Init(iInit)%ParticleEmissionType.EQ.1).OR.(Species(iSpec)%Init(iInit)%ParticleEmissionType.EQ.2)) &
    !  .AND.
    IF (Species(iSpec)%Init(iInit)%UseForInit) THEN
      IF ( (Species(iSpec)%Init(iInit)%initialParticleNumber.EQ.0) .AND. (Species(iSpec)%Init(iInit)%PartDensity.EQ.0.)) THEN
        Species(iSpec)%Init(iInit)%UseForInit=.FALSE.
        SWRITE(*,*) "WARNING: Initial ParticleInserting disabled as neither ParticleNumber"
        SWRITE(*,*) "nor PartDensity detected for Species, Init ", iSpec, iInit
      END IF
    END IF
    !--- cuboid-/cylinder-height calculation from v and dt
    IF (.NOT.Species(iSpec)%Init(iInit)%CalcHeightFromDt) THEN
      IF((TRIM(Species(iSpec)%Init(iInit)%SpaceIC).EQ.'cuboid')) THEN
        IF (ALMOSTEQUAL(Species(iSpec)%Init(iInit)%CuboidHeightIC,-1.)) THEN ! flag is initialized with -1, compatibility issue
          Species(iSpec)%Init(iInit)%CalcHeightFromDt=.TRUE.
          SWRITE(*,*) "WARNING: Cuboid height will be calculated from v and dt!"
        END IF
      ELSE IF (TRIM(Species(iSpec)%Init(iInit)%SpaceIC).EQ.'cylinder') THEN
        IF (ALMOSTEQUAL(Species(iSpec)%Init(iInit)%CylinderHeightIC,-1.)) THEN !flag is initialized with -1, compatibility issue
          Species(iSpec)%Init(iInit)%CalcHeightFromDt=.TRUE.
          SWRITE(*,*) "WARNING: Cylinder height will be calculated from v and dt!"
        END IF
      END IF
    END IF
    IF (Species(iSpec)%Init(iInit)%CalcHeightFromDt) THEN
      IF ( (Species(iSpec)%Init(iInit)%ParticleEmissionType.NE.1) .AND. (Species(iSpec)%Init(iInit)%ParticleEmissionType.NE.2) ) &
        CALL abort(&
__STAMP__&
          ,' Calculating height from v and dt is only supported for EmiType1 or EmiType2(=default)!')
      IF ((TRIM(Species(iSpec)%Init(iInit)%SpaceIC).NE.'cuboid')        .AND.&
          (TRIM(Species(iSpec)%Init(iInit)%SpaceIC).NE.'cylinder'))          &
        CALL abort(&
__STAMP__&
          ,' Calculating height from v and dt is only supported for cuboid or cylinder!')
      IF (Species(iSpec)%Init(iInit)%UseForInit) &
        CALL abort(&
__STAMP__&
          ,' Calculating height from v and dt is not supported for initial ParticleInserting!')
    END IF
    ! 1D Simulation with cuboid-SpaceIC
    IF((TRIM(Species(iSpec)%Init(iInit)%SpaceIC).EQ.'cuboid').AND.Symmetry%Order.EQ.1) THEN
      IF(Species(iSpec)%Init(iInit)%BasePointIC(2).NE.-0.5 &
         .AND.Species(iSpec)%Init(iInit)%BasePointIC(3).NE.-0.5 &
         .AND.Species(iSpec)%Init(iInit)%BaseVector1IC(2).NE.1 &
         .AND.Species(iSpec)%Init(iInit)%BaseVector1IC(3).NE.0 &
         .AND.Species(iSpec)%Init(iInit)%BaseVector2IC(1).NE.0 &
         .AND.Species(iSpec)%Init(iInit)%BaseVector2IC(2).NE.0 &
         .AND.Species(iSpec)%Init(iInit)%BaseVector1IC(1).NE.0 &
         .AND.Species(iSpec)%Init(iInit)%BaseVector2IC(3).NE.1 ) THEN
        SWRITE(*,*) 'For 1D Simulation with SpaceIC cuboid, the vectors have to be defined in the following from:'
        SWRITE(*,*) 'Part-Species[$]-Init[$]-BasePointIC=(/x,-0.5,-0.5/), with x as the basepoint in x direction'
        SWRITE(*,*) 'Part-Species[$]-Init[$]-BaseVector1IC=(/0.,1.,0/)'
        SWRITE(*,*) 'Part-Species[$]-Init[$]-BaseVector2IC=(/0.,0.,1/)'
        SWRITE(*,*) 'Part-Species[$]-Init[$]-CuboidHeightIC is the extension of the insertion region and has to be positive'
        CALL abort(__STAMP__&
        ,'See above')
      END IF
    END IF
    !--- integer check for ParticleEmissionType 2
    IF((Species(iSpec)%Init(iInit)%ParticleEmissionType.EQ.2).AND. &
         (ABS(Species(iSpec)%Init(iInit)%ParticleEmission-INT(Species(iSpec)%Init(iInit)%ParticleEmission,8)).GT.0.0)) THEN
       CALL abort(&
__STAMP__&
       ,' If ParticleEmissionType = 2 (parts per iteration), ParticleEmission has to be an integer number')
    END IF
    !--- normalize VeloVecIC and NormalIC (and BaseVector 1 & 2 IC for cylinder) for Inits
    IF (.NOT. ALL(Species(iSpec)%Init(iInit)%VeloVecIC(:).eq.0.)) THEN
      Species(iSpec)%Init(iInit)%VeloVecIC = Species(iSpec)%Init(iInit)%VeloVecIC            / &
        SQRT(Species(iSpec)%Init(iInit)%VeloVecIC(1)*Species(iSpec)%Init(iInit)%VeloVecIC(1) + &
        Species(iSpec)%Init(iInit)%VeloVecIC(2)*Species(iSpec)%Init(iInit)%VeloVecIC(2)      + &
        Species(iSpec)%Init(iInit)%VeloVecIC(3)*Species(iSpec)%Init(iInit)%VeloVecIC(3))
    END IF
    Species(iSpec)%Init(iInit)%NormalIC = Species(iSpec)%Init(iInit)%NormalIC /                 &
      SQRT(Species(iSpec)%Init(iInit)%NormalIC(1)*Species(iSpec)%Init(iInit)%NormalIC(1) + &
      Species(iSpec)%Init(iInit)%NormalIC(2)*Species(iSpec)%Init(iInit)%NormalIC(2) + &
      Species(iSpec)%Init(iInit)%NormalIC(3)*Species(iSpec)%Init(iInit)%NormalIC(3))
    IF ((TRIM(Species(iSpec)%Init(iInit)%SpaceIC).EQ.'cylinder')&
        .OR.(TRIM(Species(iSpec)%Init(iInit)%SpaceIC).EQ.'sphere')) THEN
        Species(iSpec)%Init(iInit)%BaseVector1IC =&
                  Species(iSpec)%Init(iInit)%RadiusIC * Species(iSpec)%Init(iInit)%BaseVector1IC /     &
        SQRT(Species(iSpec)%Init(iInit)%BaseVector1IC(1)*Species(iSpec)%Init(iInit)%BaseVector1IC(1) + &
        Species(iSpec)%Init(iInit)%BaseVector1IC(2)*Species(iSpec)%Init(iInit)%BaseVector1IC(2) + &
        Species(iSpec)%Init(iInit)%BaseVector1IC(3)*Species(iSpec)%Init(iInit)%BaseVector1IC(3))
        Species(iSpec)%Init(iInit)%BaseVector2IC =&
                   Species(iSpec)%Init(iInit)%RadiusIC * Species(iSpec)%Init(iInit)%BaseVector2IC /    &
        SQRT(Species(iSpec)%Init(iInit)%BaseVector2IC(1)*Species(iSpec)%Init(iInit)%BaseVector2IC(1) + &
        Species(iSpec)%Init(iInit)%BaseVector2IC(2)*Species(iSpec)%Init(iInit)%BaseVector2IC(2)      + &
        Species(iSpec)%Init(iInit)%BaseVector2IC(3)*Species(iSpec)%Init(iInit)%BaseVector2IC(3))
    END IF
    IF ((TRIM(Species(iSpec)%Init(iInit)%SpaceIC).EQ.'sphere')) THEN
        Species(iSpec)%Init(iInit)%NormalIC =&
                  Species(iSpec)%Init(iInit)%RadiusIC * Species(iSpec)%Init(iInit)%NormalIC /     &
        SQRT(Species(iSpec)%Init(iInit)%NormalIC(1)*Species(iSpec)%Init(iInit)%NormalIC(1) + &
        Species(iSpec)%Init(iInit)%NormalIC(2)*Species(iSpec)%Init(iInit)%NormalIC(2) + &
        Species(iSpec)%Init(iInit)%NormalIC(3)*Species(iSpec)%Init(iInit)%NormalIC(3))
    END IF
    !--- read stuff for ExcludeRegions and normalize/calculate corresponding vectors
    IF (Species(iSpec)%Init(iInit)%NumberOfExcludeRegions.GT.0) THEN
      ALLOCATE(Species(iSpec)%Init(iInit)%ExcludeRegion(1:Species(iSpec)%Init(iInit)%NumberOfExcludeRegions))
      IF (((TRIM(Species(iSpec)%Init(iInit)%SpaceIC).EQ.'cuboid') &
      .OR.(TRIM(Species(iSpec)%Init(iInit)%SpaceIC).EQ.'cylinder') &
      .OR.(TRIM(Species(iSpec)%Init(iInit)%SpaceIC).EQ.'sphere'))) THEN
        DO iExclude=1,Species(iSpec)%Init(iInit)%NumberOfExcludeRegions
          WRITE(UNIT=hilf3,FMT='(I0)') iExclude
          hilf3=TRIM(hilf2)//'-ExcludeRegion'//TRIM(hilf3)
          Species(iSpec)%Init(iInit)%ExcludeRegion(iExclude)%SpaceIC             &
            = TRIM(GETSTR('Part-Species'//TRIM(hilf3)//'-SpaceIC','cuboid'))
          Species(iSpec)%Init(iInit)%ExcludeRegion(iExclude)%RadiusIC             &
            = GETREAL('Part-Species'//TRIM(hilf3)//'-RadiusIC','1.')
          Species(iSpec)%Init(iInit)%ExcludeRegion(iExclude)%Radius2IC            &
            = GETREAL('Part-Species'//TRIM(hilf3)//'-Radius2IC','0.')
          Species(iSpec)%Init(iInit)%ExcludeRegion(iExclude)%NormalIC             &
            = GETREALARRAY('Part-Species'//TRIM(hilf3)//'-NormalIC',3,'0. , 0. , 1.')
          Species(iSpec)%Init(iInit)%ExcludeRegion(iExclude)%BasePointIC          &
            = GETREALARRAY('Part-Species'//TRIM(hilf3)//'-BasePointIC',3,'0. , 0. , 0.')
          Species(iSpec)%Init(iInit)%ExcludeRegion(iExclude)%BaseVector1IC        &
            = GETREALARRAY('Part-Species'//TRIM(hilf3)//'-BaseVector1IC',3,'1. , 0. , 0.')
          Species(iSpec)%Init(iInit)%ExcludeRegion(iExclude)%BaseVector2IC        &
            = GETREALARRAY('Part-Species'//TRIM(hilf3)//'-BaseVector2IC',3,'0. , 1. , 0.')
          Species(iSpec)%Init(iInit)%ExcludeRegion(iExclude)%CuboidHeightIC       &
            = GETREAL('Part-Species'//TRIM(hilf3)//'-CuboidHeightIC','1.')
          Species(iSpec)%Init(iInit)%ExcludeRegion(iExclude)%CylinderHeightIC     &
            = GETREAL('Part-Species'//TRIM(hilf3)//'-CylinderHeightIC','1.')
          !--normalize and stuff
          IF((TRIM(Species(iSpec)%Init(iInit)%ExcludeRegion(iExclude)%SpaceIC).EQ.'cuboid') .OR. &
               ((((.NOT.ALMOSTEQUAL(Species(iSpec)%Init(iInit)%ExcludeRegion(iExclude)%BaseVector1IC(1),1.) &
              .OR. .NOT.ALMOSTEQUAL(Species(iSpec)%Init(iInit)%ExcludeRegion(iExclude)%BaseVector1IC(2),0.)) &
              .OR. .NOT.ALMOSTEQUAL(Species(iSpec)%Init(iInit)%ExcludeRegion(iExclude)%BaseVector1IC(3),0.)) &
            .OR. ((.NOT.ALMOSTEQUAL(Species(iSpec)%Init(iInit)%ExcludeRegion(iExclude)%BaseVector2IC(1),0.) &
              .OR. .NOT.ALMOSTEQUAL(Species(iSpec)%Init(iInit)%ExcludeRegion(iExclude)%BaseVector2IC(2),1.)) &
              .OR. .NOT.ALMOSTEQUAL(Species(iSpec)%Init(iInit)%ExcludeRegion(iExclude)%BaseVector2IC(3),0.))) &
            .AND. (((ALMOSTEQUAL(Species(iSpec)%Init(iInit)%ExcludeRegion(iExclude)%NormalIC(1),0.)) &
              .AND. (ALMOSTEQUAL(Species(iSpec)%Init(iInit)%ExcludeRegion(iExclude)%NormalIC(2),0.))) &
              .AND. (ALMOSTEQUAL(Species(iSpec)%Init(iInit)%ExcludeRegion(iExclude)%NormalIC(3),1.))))) THEN
            !-- cuboid; or BV are non-default and NormalIC is default: calc. NormalIC for ExcludeRegions from BV1/2
            !   (for def. BV and non-def. NormalIC; or all def. or non-def.: Use User-defined NormalIC when ExclRegion is cylinder)
            Species(iSpec)%Init(iInit)%ExcludeRegion(iExclude)%NormalIC(1) &
              = Species(iSpec)%Init(iInit)%ExcludeRegion(iExclude)%BaseVector1IC(2) &
              * Species(iSpec)%Init(iInit)%ExcludeRegion(iExclude)%BaseVector2IC(3) &
              - Species(iSpec)%Init(iInit)%ExcludeRegion(iExclude)%BaseVector1IC(3) &
              * Species(iSpec)%Init(iInit)%ExcludeRegion(iExclude)%BaseVector2IC(2)
            Species(iSpec)%Init(iInit)%ExcludeRegion(iExclude)%NormalIC(2) &
              = Species(iSpec)%Init(iInit)%ExcludeRegion(iExclude)%BaseVector1IC(3) &
              * Species(iSpec)%Init(iInit)%ExcludeRegion(iExclude)%BaseVector2IC(1) &
              - Species(iSpec)%Init(iInit)%ExcludeRegion(iExclude)%BaseVector1IC(1) &
              * Species(iSpec)%Init(iInit)%ExcludeRegion(iExclude)%BaseVector2IC(3)
            Species(iSpec)%Init(iInit)%ExcludeRegion(iExclude)%NormalIC(3) &
              = Species(iSpec)%Init(iInit)%ExcludeRegion(iExclude)%BaseVector1IC(1) &
              * Species(iSpec)%Init(iInit)%ExcludeRegion(iExclude)%BaseVector2IC(2) &
              - Species(iSpec)%Init(iInit)%ExcludeRegion(iExclude)%BaseVector1IC(2) &
              * Species(iSpec)%Init(iInit)%ExcludeRegion(iExclude)%BaseVector2IC(1)
          ELSE IF ( (TRIM(Species(iSpec)%Init(iInit)%ExcludeRegion(iExclude)%SpaceIC).NE.'cuboid')        .AND. &
                    (TRIM(Species(iSpec)%Init(iInit)%ExcludeRegion(iExclude)%SpaceIC).NE.'cylinder') )THEN
            CALL abort(&
__STAMP__&
,'Error in ParticleInit, ExcludeRegions must be cuboid or cylinder!')
          END IF
          IF (Species(iSpec)%Init(iInit)%ExcludeRegion(iExclude)%NormalIC(1)**2 + &
              Species(iSpec)%Init(iInit)%ExcludeRegion(iExclude)%NormalIC(2)**2 + &
              Species(iSpec)%Init(iInit)%ExcludeRegion(iExclude)%NormalIC(3)**2 .GT. 0.) THEN
            Species(iSpec)%Init(iInit)%ExcludeRegion(iExclude)%NormalIC &
              = Species(iSpec)%Init(iInit)%ExcludeRegion(iExclude)%NormalIC &
              / SQRT(Species(iSpec)%Init(iInit)%ExcludeRegion(iExclude)%NormalIC(1)**2 &
              + Species(iSpec)%Init(iInit)%ExcludeRegion(iExclude)%NormalIC(2)**2 &
              + Species(iSpec)%Init(iInit)%ExcludeRegion(iExclude)%NormalIC(3)**2)
            Species(iSpec)%Init(iInit)%ExcludeRegion(iExclude)%ExcludeBV_lenghts(1) &
              = SQRT(Species(iSpec)%Init(iInit)%ExcludeRegion(iExclude)%BaseVector1IC(1)**2 &
              + Species(iSpec)%Init(iInit)%ExcludeRegion(iExclude)%BaseVector1IC(2)**2 &
              + Species(iSpec)%Init(iInit)%ExcludeRegion(iExclude)%BaseVector1IC(3)**2)
            Species(iSpec)%Init(iInit)%ExcludeRegion(iExclude)%ExcludeBV_lenghts(2) &
              = SQRT(Species(iSpec)%Init(iInit)%ExcludeRegion(iExclude)%BaseVector2IC(1)**2 &
              + Species(iSpec)%Init(iInit)%ExcludeRegion(iExclude)%BaseVector2IC(2)**2 &
              + Species(iSpec)%Init(iInit)%ExcludeRegion(iExclude)%BaseVector2IC(3)**2)
          ELSE
            CALL abort(&
__STAMP__&
,'Error in ParticleInit, NormalIC Vector must not be zero!')
          END IF
        END DO !iExclude
      ELSE
        CALL abort(&
__STAMP__&
,'Error in ParticleInit, ExcludeRegions are currently only implemented for the SpaceIC cuboid, sphere or cylinder!')
      END IF
    END IF
    !--- stuff for calculating ParticleEmission/InitialParticleNumber from PartDensity
    PartDens_OnlyInit=.FALSE.
    IF ((Species(iSpec)%Init(iInit)%PartDensity.GT.0.)) THEN
      IF (Species(iSpec)%Init(iInit)%ParticleEmissionType.NE.1) THEN
        IF ( (Species(iSpec)%Init(iInit)%ParticleEmissionType.EQ.2 .OR. Species(iSpec)%Init(iInit)%ParticleEmissionType.EQ.0) &
            .AND. (Species(iSpec)%Init(iInit)%UseForInit) ) THEN
          PartDens_OnlyInit=.TRUE.
        ELSE
          CALL abort(&
            __STAMP__&
            , 'PartDensity is only supported for EmiType1 or initial ParticleInserting with EmiType1/2!')
        END IF
      END IF
      IF ((TRIM(Species(iSpec)%Init(iInit)%SpaceIC).EQ.'cuboid').OR.(TRIM(Species(iSpec)%Init(iInit)%SpaceIC).EQ.'cylinder') &
          .OR.(TRIM(Species(iSpec)%Init(iInit)%SpaceIC).EQ.'sphere')) THEN
        IF  ((((TRIM(Species(iSpec)%Init(iInit)%velocityDistribution).EQ.'constant') &
          .OR.(TRIM(Species(iSpec)%Init(iInit)%velocityDistribution).EQ.'maxwell') ) &
          .OR.(TRIM(Species(iSpec)%Init(iInit)%velocityDistribution).EQ.'maxwell_lpn') ) ) THEN
          IF (Species(iSpec)%Init(iInit)%ParticleEmission .GT. 0.) THEN
            CALL abort(&
              __STAMP__&
              ,'Either ParticleEmission or PartDensity can be defined for selected emission parameters, not both!')
          END IF
          !---calculation of Base-Area and corresponding component of VeloVecIC
          lineVector(1) = Species(iSpec)%Init(iInit)%BaseVector1IC(2) * Species(iSpec)%Init(iInit)%BaseVector2IC(3) - &
            Species(iSpec)%Init(iInit)%BaseVector1IC(3) * Species(iSpec)%Init(iInit)%BaseVector2IC(2)
          lineVector(2) = Species(iSpec)%Init(iInit)%BaseVector1IC(3) * Species(iSpec)%Init(iInit)%BaseVector2IC(1) - &
            Species(iSpec)%Init(iInit)%BaseVector1IC(1) * Species(iSpec)%Init(iInit)%BaseVector2IC(3)
          lineVector(3) = Species(iSpec)%Init(iInit)%BaseVector1IC(1) * Species(iSpec)%Init(iInit)%BaseVector2IC(2) - &
            Species(iSpec)%Init(iInit)%BaseVector1IC(2) * Species(iSpec)%Init(iInit)%BaseVector2IC(1)
          A_ins = lineVector(1)*lineVector(1) + lineVector(2)*lineVector(2) + lineVector(3)*lineVector(3)
          IF (A_ins .GT. 0.) THEN
            A_ins = SQRT(A_ins)
            lineVector = lineVector / A_ins
            IF (Species(iSpec)%Init(iInit)%CalcHeightFromDt) THEN
              v_drift_line = Species(iSpec)%Init(iInit)%VeloIC * &
                ( Species(iSpec)%Init(iInit)%VeloVecIC(1)*lineVector(1) + Species(iSpec)%Init(iInit)%VeloVecIC(2)*lineVector(2) &
                + Species(iSpec)%Init(iInit)%VeloVecIC(3)*lineVector(3) ) !lineVector component of drift-velocity
            ELSE
              v_drift_line = 0.
              IF (Species(iSpec)%Init(iInit)%UseForInit) THEN
                PartDens_OnlyInit=.TRUE.
              ELSE
                CALL abort(&
                  __STAMP__&
                  ,'PartDensity is only supported for CalcHeightFromDt, or initial ParticleInserting!')
              END IF
            END IF
            IF ( TRIM(Species(iSpec)%Init(iInit)%SpaceIC) .EQ. 'cylinder' ) THEN
              A_ins = Pi * (Species(iSpec)%Init(iInit)%RadiusIC**2-Species(iSpec)%Init(iInit)%Radius2IC**2)
            END IF
            !---calculation of particle flow (macroparticles/s) through boundary
            IF (.NOT.PartDens_OnlyInit) THEN
              Species(iSpec)%Init(iInit)%ParticleEmission &
                = Species(iSpec)%Init(iInit)%PartDensity / Species(iSpec)%MacroParticleFactor * v_drift_line * A_ins
            END IF
            !---calculation of initial (macro)particle number
            IF (Species(iSpec)%Init(iInit)%UseForInit) THEN
              IF (Species(iSpec)%Init(iInit)%initialParticleNumber .GT. 0) THEN
                CALL abort(&
                  __STAMP__&
                  ,'Either initialParticleNumber or PartDensity can be defined for selected parameters, not both!')
              END IF
              IF(TRIM(Species(iSpec)%Init(iInit)%SpaceIC).EQ.'cuboid') THEN
                Species(iSpec)%Init(iInit)%initialParticleNumber &
                  = INT(Species(iSpec)%Init(iInit)%PartDensity / Species(iSpec)%MacroParticleFactor &
                  * Species(iSpec)%Init(iInit)%CuboidHeightIC * A_ins)
              ELSE IF (TRIM(Species(iSpec)%Init(iInit)%SpaceIC).EQ.'cylinder') THEN
                Species(iSpec)%Init(iInit)%initialParticleNumber &
                  = INT(Species(iSpec)%Init(iInit)%PartDensity / Species(iSpec)%MacroParticleFactor &
                  * Species(iSpec)%Init(iInit)%CylinderHeightIC * A_ins)
              ELSE IF (TRIM(Species(iSpec)%Init(iInit)%SpaceIC).EQ.'sphere') THEN
                Species(iSpec)%Init(iInit)%initialParticleNumber &
                  = INT(Species(iSpec)%Init(iInit)%PartDensity / Species(iSpec)%MacroParticleFactor &
                  * (Species(iSpec)%Init(iInit)%RadiusIC**3 * 4./3. * PI))
              END IF
            END IF
          ELSE
            CALL abort(&
              __STAMP__&
              ,'BaseVectors are parallel or zero!')
          END IF
        ELSE
          CALL abort(&
            __STAMP__&
            ,'Only const. or maxwell(_lpn) is supported as velocityDistr. for PartDensity!')
        END IF
      ELSE IF ((TRIM(Species(iSpec)%Init(iInit)%SpaceIC).EQ.'cell_local')) THEN
        IF( (TRIM(Species(iSpec)%Init(iInit)%velocityDistribution).EQ.'constant') &
           .OR.(TRIM(Species(iSpec)%Init(iInit)%velocityDistribution).EQ.'maxwell') &
           .OR.(TRIM(Species(iSpec)%Init(iInit)%velocityDistribution).EQ.'maxwell_lpn') &
           .OR.(TRIM(Species(iSpec)%Init(iInit)%velocityDistribution).EQ.'taylorgreenvortex') )THEN
          IF (Species(iSpec)%Init(iInit)%ParticleEmission .GT. 0.) THEN
            CALL abort(&
              __STAMP__&
              ,'Either ParticleEmission or PartDensity can be defined for cell_local emission parameters, not both!')
          END IF
          IF (LocalVolume.GT.0.) THEN
            IF (Species(iSpec)%Init(iInit)%UseForInit) THEN
              IF (Species(iSpec)%Init(iInit)%initialParticleNumber .GT. 0) THEN
                CALL abort(&
                  __STAMP__&
                  ,'Either initialParticleNumber or PartDensity can be defined for selected parameters, not both!')
              END IF
              Species(iSpec)%Init(iInit)%initialParticleNumber &
                  = NINT(Species(iSpec)%Init(iInit)%PartDensity / Species(iSpec)%MacroParticleFactor * LocalVolume)
            END IF
          ELSE
            CALL abort(&
              __STAMP__&
              ,'Local mesh volume is zero!')
          END IF
        ELSE
          CALL abort(&
            __STAMP__&
            ,'Only const. or maxwell_lpn is supported as velocityDistr. using cell_local inserting with PartDensity!')
        END IF
      ELSE IF (TRIM(Species(iSpec)%Init(iInit)%SpaceIC).EQ.'background') THEN
        ! do nothing
      ELSE
        SWRITE(*,*) 'SpaceIC is: ', TRIM(Species(iSpec)%Init(iInit)%SpaceIC)
        CALL abort(&
          __STAMP__&
          ,'ERROR: Unknown SpaceIC for species: ', iSpec)
      END IF
    END IF
    IF(Species(iSpec)%Init(iInit)%InflowRiseTime.GT.0.)THEN
      IF(.NOT.DoPoissonRounding .AND. .NOT.DoTimeDepInflow)  CALL CollectiveStop(&
__STAMP__, &
' Linearly ramping of inflow-number-of-particles is only possible with PoissonRounding or DoTimeDepInflow!')
    END IF
  END DO ! iInit
END DO ! iSpec
IF(nSpecies.GT.0)THEN
  SWRITE (UNIT_stdOut,'(66(". "))')
END IF ! nSpecies.GT.0

!-- reading BG Gas stuff
!   (moved here from dsmc_init for switching off the initial emission)
IF (useDSMC) THEN
  IF (BGGas%NumberOfSpecies.GT.0) THEN
    CALL BGGas_Initialize()
  ELSE
    DEALLOCATE(BGGas%NumberDensity)
  END IF ! BGGas%NumberOfSpecies.GT.0
END IF !useDSMC


END SUBROUTINE InitializeVariablesSpeciesInits

#if defined(IMPA) || defined(ROS)
SUBROUTINE InitializeVariablesImplicit()
!===================================================================================================================================
! Initialize the variables first
!===================================================================================================================================
! MODULES
USE MOD_Globals
USE MOD_Particle_Vars
USE MOD_TimeDisc_Vars ,ONLY: nRKStages
! IMPLICIT VARIABLE HANDLING
 IMPLICIT NONE
!-----------------------------------------------------------------------------------------------------------------------------------
! INPUT VARIABLES
!-----------------------------------------------------------------------------------------------------------------------------------
! OUTPUT VARIABLES
!-----------------------------------------------------------------------------------------------------------------------------------
! LOCAL VARIABLES
INTEGER               :: ALLOCSTAT
!===================================================================================================================================
#ifdef IMPA
ALLOCATE(PartStage(1:6,1:nRKStages-1,1:PDM%maxParticleNumber), STAT=ALLOCSTAT)  ! save memory
IF (ALLOCSTAT.NE.0) THEN
  CALL abort(&
__STAMP__&
  ,' Cannot allocate PartStage arrays!')
END IF
ALLOCATE(PartStateN(1:6,1:PDM%maxParticleNumber), STAT=ALLOCSTAT)
IF (ALLOCSTAT.NE.0) THEN
  CALL abort(&
__STAMP__&
  ,' Cannot allocate PartStateN arrays!')
END IF
ALLOCATE(PartQ(1:6,1:PDM%maxParticleNumber), STAT=ALLOCSTAT)  ! save memory
IF (ALLOCSTAT.NE.0) THEN
  CALL abort(&
__STAMP__&
  ,'Cannot allocate PartQ arrays!')
END IF
! particle function values at X0
ALLOCATE(F_PartX0(1:6,1:PDM%maxParticleNumber), STAT=ALLOCSTAT)  ! save memory
IF (ALLOCSTAT.NE.0) THEN
  CALL abort(&
__STAMP__&
  ,'Cannot allocate F_PartX0 arrays!')
END IF
! particle function values at Xk
ALLOCATE(F_PartXk(1:6,1:PDM%maxParticleNumber), STAT=ALLOCSTAT)  ! save memory
IF (ALLOCSTAT.NE.0) THEN
  CALL abort(&
__STAMP__&
  ,'Cannot allocate F_PartXk arrays!')
END IF
! and the required norms
ALLOCATE(Norm_F_PartX0(1:PDM%maxParticleNumber), STAT=ALLOCSTAT)  ! save memory
IF (ALLOCSTAT.NE.0) THEN
  CALL abort(&
__STAMP__&
  ,'Cannot allocate Norm_F_PartX0 arrays!')
END IF
ALLOCATE(Norm_F_PartXk(1:PDM%maxParticleNumber), STAT=ALLOCSTAT)  ! save memory
IF (ALLOCSTAT.NE.0) THEN
  CALL abort(&
__STAMP__&
  ,'Cannot allocate Norm_F_PartXk arrays!')
END IF
ALLOCATE(Norm_F_PartXk_old(1:PDM%maxParticleNumber), STAT=ALLOCSTAT)  ! save memory
IF (ALLOCSTAT.NE.0) THEN
  CALL abort(&
__STAMP__&
  ,'Cannot allocate Norm_F_PartXk_old arrays!')
END IF
ALLOCATE(PartDeltaX(1:6,1:PDM%maxParticleNumber), STAT=ALLOCSTAT)  ! save memory
IF (ALLOCSTAT.NE.0) THEN
  CALL abort(&
__STAMP__&
  ,'Cannot allocate PartDeltaX arrays!')
END IF
ALLOCATE(PartLambdaAccept(1:PDM%maxParticleNumber), STAT=ALLOCSTAT)  ! save memory
IF (ALLOCSTAT.NE.0) THEN
  CALL abort(&
__STAMP__&
  ,'Cannot allocate PartLambdaAccept arrays!')
END IF
ALLOCATE(DoPartInNewton(1:PDM%maxParticleNumber), STAT=ALLOCSTAT)  ! save memory
IF (ALLOCSTAT.NE.0) THEN
  CALL abort(&
__STAMP__&
      ,'Cannot allocate DoPartInNewton arrays!')
END IF
#endif /* IMPA */
#ifdef ROS
ALLOCATE(PartStage(1:6,1:nRKStages-1,1:PDM%maxParticleNumber), STAT=ALLOCSTAT)  ! save memory
IF (ALLOCSTAT.NE.0) THEN
  CALL abort(&
__STAMP__&
  ,' Cannot allocate PartStage arrays!')
END IF
ALLOCATE(PartStateN(1:6,1:PDM%maxParticleNumber), STAT=ALLOCSTAT)
IF (ALLOCSTAT.NE.0) THEN
  CALL abort(&
__STAMP__&
  ,' Cannot allocate PartStateN arrays!')
END IF
ALLOCATE(PartQ(1:6,1:PDM%maxParticleNumber), STAT=ALLOCSTAT)  ! save memory
IF (ALLOCSTAT.NE.0) THEN
  CALL abort(&
__STAMP__&
  ,'Cannot allocate PartQ arrays!')
END IF
ALLOCATE(PartDtFrac(1:PDM%maxParticleNumber), STAT=ALLOCSTAT)  ! save memory
IF (ALLOCSTAT.NE.0) THEN
  CALL abort(&
__STAMP__&
  ,' Cannot allocate PartDtFrac arrays!')
END IF
PartDtFrac=1.
ALLOCATE(PEM%NormVec(1:3,1:PDM%maxParticleNumber),STAT=ALLOCSTAT)
IF (ALLOCSTAT.NE.0) THEN
   CALL abort(&
 __STAMP__&
   ,' Cannot allocate the normal vector for reflections!')
END IF
PEM%NormVec=0
ALLOCATE(PEM%PeriodicMoved(1:PDM%maxParticleNumber),STAT=ALLOCSTAT)
IF (ALLOCSTAT.NE.0) THEN
   CALL abort(&
 __STAMP__&
   ,' Cannot allocate the stage position and element arrays!')
END IF
PEM%PeriodicMoved=.FALSE.
#endif /* ROSENBROCK */

#if IMPA
ALLOCATE(PartIsImplicit(1:PDM%maxParticleNumber), STAT=ALLOCSTAT)  ! save memory
IF (ALLOCSTAT.NE.0) THEN
  CALL abort(&
__STAMP__&
  ,' Cannot allocate PartIsImplicit arrays!')
END IF
PartIsImplicit=.FALSE.
ALLOCATE(PartDtFrac(1:PDM%maxParticleNumber), STAT=ALLOCSTAT)  ! save memory
IF (ALLOCSTAT.NE.0) THEN
  CALL abort(&
__STAMP__&
  ,' Cannot allocate PartDtFrac arrays!')
END IF
PartDtFrac=1.
ALLOCATE(PEM%NormVec(1:3,1:PDM%maxParticleNumber),STAT=ALLOCSTAT)
IF (ALLOCSTAT.NE.0) THEN
   CALL abort(&
 __STAMP__&
   ,' Cannot allocate the normal vector for reflections!')
END IF
PEM%NormVec=0
ALLOCATE(PEM%PeriodicMoved(1:PDM%maxParticleNumber),STAT=ALLOCSTAT)
IF (ALLOCSTAT.NE.0) THEN
   CALL abort(&
 __STAMP__&
   ,' Cannot allocate the stage position and element arrays!')
END IF
PEM%PeriodicMoved=.FALSE.
#endif

END SUBROUTINE InitializeVariablesImplicit
#endif

SUBROUTINE InitialIonization()
!----------------------------------------------------------------------------------------------------------------------------------!
! 1.) assign charges to each atom/molecule using the charge supplied by the user
! 2.) reconstruct the electron phase space using the summed charges in each cell for which an electron is
!     created to achieve an ionization degree supplied by the user
!----------------------------------------------------------------------------------------------------------------------------------!
! MODULES                                                                                                                          !
!----------------------------------------------------------------------------------------------------------------------------------!
USE MOD_Globals
USE MOD_Globals_Vars        ,ONLY:  ElementaryCharge
USE MOD_PreProc
USE MOD_Particle_Vars       ,ONLY: PDM,PEM,PartState,nSpecies,Species,PartSpecies
USE MOD_Particle_Vars       ,ONLY: InitialIonizationChargeAverage,InitialIonizationSpeciesID,InitialIonizationSpecies
USE MOD_Mesh_Vars           ,ONLY: NGeo,XCL_NGeo,XiCL_NGeo,wBaryCL_NGeo,offsetElem
USE MOD_DSMC_Vars           ,ONLY: CollisMode,DSMC,PartStateIntEn
USE MOD_part_emission_tools ,ONLY: CalcVelocity_maxwell_lpn
USE MOD_DSMC_Vars           ,ONLY: useDSMC
USE MOD_Eval_xyz            ,ONLY: TensorProductInterpolation
USE MOD_Particle_Analyze    ,ONLY: PARTISELECTRON
!----------------------------------------------------------------------------------------------------------------------------------!
IMPLICIT NONE
! INPUT VARIABLES
!----------------------------------------------------------------------------------------------------------------------------------!
! OUTPUT VARIABLES
!-----------------------------------------------------------------------------------------------------------------------------------
! LOCAL VARIABLES
INTEGER       :: ChargeLower,ChargeUpper
INTEGER       :: ElemCharge(1:PP_nElems)
INTEGER       :: ElecSpecIndx,iSpec,location,iElem,iPart,ParticleIndexNbr
REAL          :: ChargeProbability
REAL          :: iRan
REAL          :: PartPosRef(1:3)
REAL          :: CellElectronTemperature=300
!INTEGER       :: SpeciesID(3)
!INTEGER       :: SpeciesCharge(3)
CHARACTER(32) :: hilf
INTEGER       :: SpeciesCharge(1:InitialIonizationSpecies)
INTEGER       :: I
!===================================================================================================================================
! Determine the charge number of each species
DO I = 1, InitialIonizationSpecies
  iSpec = InitialIonizationSpeciesID(I)
  SpeciesCharge(I) = NINT(Species(iSpec)%ChargeIC/(ElementaryCharge))
END DO ! I = 1, InitialIonizationSpecies

! ---------------------------------------------------------------------------------------------------------------------------------
! 1.) reconstruct ions and determine charge
! ---------------------------------------------------------------------------------------------------------------------------------
SWRITE(UNIT_stdOut,*)'InitialIonization:'
SWRITE(UNIT_stdOut,*)'  1.) Reconstructing ions and determining the charge of each particle'

! Initialize the element charge with zero
ElemCharge(1:PP_nElems)=0

! Loop over all particles in the vector list
DO iPart=1,PDM%ParticleVecLength
  IF(PDM%ParticleInside(iPart)) THEN

    ! If the current particle is part of the species list, then a charge can be assigned
    IF(ANY(PartSpecies(iPart).EQ.InitialIonizationSpeciesID(:)))THEN !

      IF(PARTISELECTRON(iPart))THEN
        CYCLE
      END IF
      ! Get the cell charge average value and select and upper and lower charge number
      ChargeLower       = INT(InitialIonizationChargeAverage)
      ChargeUpper       = ChargeLower+1
      ChargeProbability = REAL(ChargeUpper)-InitialIonizationChargeAverage !e.g. 2-1.4 = 0.6 -> 60% probability to get lower charge

      ! Compare the random number with the charge difference
      CALL RANDOM_NUMBER(iRan)
      IF(iRan.LT.ChargeProbability)THEN ! Select the lower charge number
        ! Determines the location of the element in the array with min value: get the index of the corresponding charged ion
        ! species
        location                            = MINLOC(ABS(SpeciesCharge-ChargeLower),1)
        ElemCharge(PEM%LocalElemID(iPart))      = ElemCharge(PEM%LocalElemID(iPart))+ChargeLower
      ELSE ! Select the upper charge number
        ! Determines the location of the element in the array with min value: get the index of the corresponding charged ion
        ! species
        location                            = MINLOC(ABS(SpeciesCharge-ChargeUpper),1)
        ElemCharge(PEM%LocalElemID(iPart))      = ElemCharge(PEM%LocalElemID(iPart))+ChargeUpper
      END IF

      ! Set the species ID to atom/singly charged ion/doubly charged ... and so on
      PartSpecies(iPart)=InitialIonizationSpeciesID(location)
    END IF
  END IF
END DO

! ---------------------------------------------------------------------------------------------------------------------------------
! 2.) reconstruct electrons
! ---------------------------------------------------------------------------------------------------------------------------------
SWRITE(UNIT_stdOut,*)'  2.) Reconstructing electrons'

! Initialize the species index for the electron species with -1
ElecSpecIndx = -1

! Loop over all species and find the index corresponding to the electron species: take the first electron species that is
! encountered
DO iSpec = 1, nSpecies
  IF (Species(iSpec)%ChargeIC.GE.0.0) CYCLE
    IF(NINT(Species(iSpec)%ChargeIC/(-ElementaryCharge)).EQ.1)THEN
      ElecSpecIndx = iSpec
    EXIT
  END IF
END DO
IF (ElecSpecIndx.EQ.-1) CALL abort(&
  __STAMP__&
  ,'Electron species not found. Cannot create electrons without the defined species!')

WRITE(UNIT=hilf,FMT='(I0)') iSpec
SWRITE(UNIT_stdOut,'(A)')'  Using iSpec='//TRIM(hilf)//' as electron species index.'
WRITE(UNIT=hilf,FMT=WRITEFORMAT) CellElectronTemperature
SWRITE(UNIT_stdOut,'(A)')'  Using T='//TRIM(hilf)//' K for the initial electron temperatture (maxwell_lpn) in each cell.'
! Loop over all elements and the sum of charges in each element (for each charge assigned in an element, an electron is created)
DO iElem=1,PP_nElems
  DO iPart=1,ElemCharge(iElem) ! 1 electron for each charge of each element

    ! Set the next free position in the particle vector list
    PDM%CurrentNextFreePosition = PDM%CurrentNextFreePosition + 1
    ParticleIndexNbr            = PDM%nextFreePosition(PDM%CurrentNextFreePosition)
    PDM%ParticleVecLength       = PDM%ParticleVecLength + 1

    !Set new SpeciesID of new particle (electron)
    PDM%ParticleInside(ParticleIndexNbr) = .true.
    PartSpecies(ParticleIndexNbr) = ElecSpecIndx

    ! Place the electron randomly in the reference cell
    CALL RANDOM_NUMBER(PartPosRef(1:3)) ! get random reference space
    PartPosRef(1:3)=PartPosRef(1:3)*2. - 1. ! map (0,1) -> (-1,1)

    ! Get the physical coordinates that correspond to the reference coordinates
    CALL TensorProductInterpolation(PartPosRef(1:3),3,NGeo,XiCL_NGeo,wBaryCL_NGeo,XCL_NGeo(1:3,0:NGeo,0:NGeo,0:NGeo,iElem) &
                      ,PartState(1:3,ParticleIndexNbr)) !Map into phys. space

    ! Set the internal energies (vb, rot and electronic) to zero if needed
    IF ((useDSMC).AND.(CollisMode.GT.1)) THEN
      PartStateIntEn(1,ParticleIndexNbr) = 0.
      PartStateIntEn(2,ParticleIndexNbr) = 0.
      IF (DSMC%ElectronicModel.GT.0)  PartStateIntEn(3,ParticleIndexNbr) = 0.
    END IF

    ! Set the element ID of the electron to the current element ID
    PEM%GlobalElemID(ParticleIndexNbr) = iElem + offsetElem

    ! Set the electron velocity using the Maxwellian distribution (use the function that is suitable for small numbers)
    CALL CalcVelocity_maxwell_lpn(ElecSpecIndx, PartState(4:6,ParticleIndexNbr),&
                                  Temperature=CellElectronTemperature)
  END DO
END DO


END SUBROUTINE InitialIonization


SUBROUTINE InitParticleBoundaryRotPeriodic()
!----------------------------------------------------------------------------------------------------------------------------------!
! Build Mapping for rotational periodicity: RotPeriodicSide -> SideID2 (Side on corresponding BC).
! In RotPeriodicBC (particle_boundary_condition.f90): SideID -> SurfSideID -> RotPeriodicSide
!                                                     RotPeriodicSide -> SideID2
! (1) counting rotational periodic sides and build mapping from SurfSideID -> RotPeriodicSide
! (2) find Side on corresponding BC and build mapping RotPeriodicSide -> SideID2 (and vice versa)
!     counting potentional rotational periodic sides (for not conform meshes)
! (3) reallocate array due to number of potentional rotational periodic sides
!----------------------------------------------------------------------------------------------------------------------------------!
! MODULES                                                                                                                          !
!----------------------------------------------------------------------------------------------------------------------------------!
USE MOD_Globals
USE MOD_Particle_Boundary_Vars  ,ONLY: RotPeriodicSide2GlobalSide,nComputeNodeSurfTotalSides,SurfSide2GlobalSide,PartBound
USE MOD_Particle_Boundary_Vars  ,ONLY: RotPeriodicSideMapping, NumRotPeriodicNeigh, SurfSide2RotPeriodicSide
USE MOD_Particle_Mesh_Vars      ,ONLY: SideInfo_Shared, NodeCoords_Shared, ElemSideNodeID_Shared, GEO
USE MOD_Mesh_Tools              ,ONLY: GetCNElemID
!----------------------------------------------------------------------------------------------------------------------------------!
IMPLICIT NONE
! INPUT VARIABLES
!----------------------------------------------------------------------------------------------------------------------------------!
! OUTPUT VARIABLES
!-----------------------------------------------------------------------------------------------------------------------------------
! LOCAL VARIABLES
INTEGER              :: iSide, jSide, nRotPeriodicSides, SideID,SideID2, MaxNumRotPeriodicNeigh, iNode, jNode, iNeigh
INTEGER              :: NodeID, CNElemID, CNElemID2, LocSideID, k, l, m, NodeID2, LocSideID2
INTEGER,ALLOCATABLE  :: Rot2Glob_temp(:)
INTEGER,ALLOCATABLE  :: RotPeriodicSideMapping_temp(:,:)
LOGICAL              :: isMapped,SideIsMapped
REAL                 :: iNodeVec(1:3), jNodeVec(1:3)
REAL                 :: iNodeR, iNodeH, jNodeR, jNodeH, Node2Rmin, Node2Rmax, Node2Hmin, Node2Hmax
!===================================================================================================================================

ALLOCATE(Rot2Glob_temp(nComputeNodeSurfTotalSides))
ALLOCATE(SurfSide2RotPeriodicSide(nComputeNodeSurfTotalSides))
SurfSide2RotPeriodicSide(:) = -1
nRotPeriodicSides=0

! (1) counting rotational periodic sides and build mapping from SurfSideID -> RotPeriodicSide
DO iSide=1, nComputeNodeSurfTotalSides
  SideID = SurfSide2GlobalSide(SURF_SIDEID,iSide)
  IF(PartBound%TargetBoundCond(SideInfo_Shared(SIDE_BCID,SideID)).EQ.6) THEN
    nRotPeriodicSides = nRotPeriodicSides + 1
    Rot2Glob_temp(nRotPeriodicSides) = SideID
    SurfSide2RotPeriodicSide(iSide) = nRotPeriodicSides
  END IF
END DO

ALLOCATE(RotPeriodicSide2GlobalSide(nRotPeriodicSides))
ALLOCATE(NumRotPeriodicNeigh(nRotPeriodicSides))
! number of potentional rotational periodic sides is unknown => allocate mapping array with fixed number of 1000
! and reallocate at the end of subroutin
ALLOCATE(RotPeriodicSideMapping_temp(nRotPeriodicSides,1000))

DO iSide=1, nRotPeriodicSides
  RotPeriodicSide2GlobalSide(iSide) = Rot2Glob_temp(iSide)
  NumRotPeriodicNeigh(iSide) = 0
  RotPeriodicSideMapping_temp(iSide,1:1000) = -1
END DO

MaxNumRotPeriodicNeigh = 0
! Defining rotation matrix
SELECT CASE(GEO%RotPeriodicAxi)
  CASE(1) ! x-rotation axis
    k = 1
    l = 2
    m = 3
  CASE(2) ! x-rotation axis
    k = 2
    l = 3
    m = 1
  CASE(3) ! x-rotation axis
    k = 3
    l = 1
    m = 2
END SELECT
! (2) find Side on corresponding BC and build mapping RotPeriodicSide -> SideID2 (and vice versa)
!     counting potentional rotational periodic sides (for not conform meshes)
DO iSide=1, nRotPeriodicSides
  SideID    = RotPeriodicSide2GlobalSide(iSide)
  CNElemID  = GetCNElemID(SideInfo_Shared(SIDE_ELEMID,SideID))
  LocSideID = SideInfo_Shared(SIDE_LOCALID,SideID)
  SideIsMapped = .FALSE.
  ! check if at least one node of iSide is inside bounding box of a Side on corresponding BC
  DO iNode=1, 4
    NodeID = ElemSideNodeID_Shared(iNode,LocSideID,CNElemID) + 1
    iNodeVec(1:3) = NodeCoords_Shared(1:3,NodeID)
    iNodeH = iNodeVec(k)
    iNodeR = SQRT(iNodeVec(l)*iNodeVec(l)+iNodeVec(m)*iNodeVec(m))
    DO jSide=1, nRotPeriodicSides
      SideID2 = RotPeriodicSide2GlobalSide(jSide)
      ! is on same RotPeriodicBC?
      IF(PartBound%RotPeriodicDir(SideInfo_Shared(SIDE_BCID,SideID)).EQ. &
        PartBound%RotPeriodicDir(SideInfo_Shared(SIDE_BCID,SideID2))) CYCLE
      isMapped = .FALSE.
      ! check wether RotPeriodicSides is already mapped
      IF(NumRotPeriodicNeigh(jSide).GT. 0) THEN
        DO iNeigh=1, NumRotPeriodicNeigh(jSide)
          IF(RotPeriodicSideMapping_temp(jSide,iNeigh).EQ.SideID) THEN
            isMapped = .TRUE.
            SideIsMapped = .TRUE.
            EXIT
          END IF
        END DO
      END IF
      IF(isMapped) CYCLE
      ! get ElemID for node mapping
      CNElemID2    = GetCNElemID(SideInfo_Shared(SIDE_ELEMID,SideID2))
      LocSideID2 = SideInfo_Shared(SIDE_LOCALID,SideID2)
      ! calc bounding box of jSide
      DO jNode=1, 4
        NodeID2       = ElemSideNodeID_Shared(jNode,LocSideID2,CNElemID2) + 1
        jNodeVec(1:3) = NodeCoords_Shared(1:3,NodeID2)
        jNodeH        = jNodeVec(k)
        jNodeR        = SQRT(jNodeVec(l)*jNodeVec(l)+jNodeVec(m)*jNodeVec(m))
        IF(jNode.EQ. 1) THEN
          Node2Hmin = jNodeH
          Node2Hmax = jNodeH
          Node2Rmin = jNodeR
          Node2Rmax = jNodeR
        ELSE
          Node2Hmin = MIN(Node2Hmin,jNodeH)
          Node2Hmax = MAX(Node2Hmax,jNodeH)
          Node2Rmin = MIN(Node2Rmin,jNodeR)
          Node2Rmax = MAX(Node2Rmax,jNodeR)
        END IF
      END DO
      IF( ( (Node2Hmin.LE.iNodeH).AND.(iNodeH.LE.Node2Hmax) ) .AND. &
          ( (Node2Rmin.LE.iNodeR).AND.(iNodeR.LE.Node2Rmax) )       ) THEN
      ! at least one node of iSide is inside bounding box of jSide =>
      !                                                     1. increase NumRotPeriodicNeigh
      !                                                     2. map:     iSide => SideID2 and
      !                                                     vise versa: jSide => SideID  s.o.
        NumRotPeriodicNeigh(iSide) = NumRotPeriodicNeigh(iSide) + 1
        IF(NumRotPeriodicNeigh(iSide).GT. 1000) THEN
          CALL abort(&
              __STAMP__&
              ,' ERROR: Number of rotational periodic side exceed fixed number of 1000!.')
        END IF
        RotPeriodicSideMapping_temp(iSide,NumRotPeriodicNeigh(iSide)) = SideID2
        NumRotPeriodicNeigh(jSide) = NumRotPeriodicNeigh(jSide) + 1
        IF(NumRotPeriodicNeigh(jSide).GT. 1000) THEN
          CALL abort(&
              __STAMP__&
              ,' ERROR: Number of rotational periodic side exceed fixed number of 1000!.')
        END IF
        RotPeriodicSideMapping_temp(jSide,NumRotPeriodicNeigh(jSide)) = SideID
        SideIsMapped = .TRUE.
      END IF
    END DO
  END DO
  IF(.NOT.SideIsMapped) THEN
    CALL abort(&
        __STAMP__&
        ,' ERROR: One rot periodic side did not find a corresponding side.')
  END IF
END DO
! (3) reallocate array due to number of potentional rotational periodic sides
MaxNumRotPeriodicNeigh = MAXVAL(NumRotPeriodicNeigh)
ALLOCATE(RotPeriodicSideMapping(nRotPeriodicSides,MaxNumRotPeriodicNeigh))
DO iSide=1, nRotPeriodicSides
  DO iNeigh=1, MaxNumRotPeriodicNeigh
    RotPeriodicSideMapping(iSide,iNeigh) = RotPeriodicSideMapping_temp(iSide,iNeigh)
  END DO
END DO

END SUBROUTINE InitParticleBoundaryRotPeriodic


SUBROUTINE FinalizeParticles()
!----------------------------------------------------------------------------------------------------------------------------------!
! finalize particle variables
!----------------------------------------------------------------------------------------------------------------------------------!
! MODULES                                                                                                                          !
!----------------------------------------------------------------------------------------------------------------------------------!
USE MOD_Globals
USE MOD_Particle_Vars
USE MOD_Particle_Mesh_Vars
USE MOD_Particle_Boundary_Vars
#if USE_MPI
USE MOD_Particle_MPI_Halo      ,ONLY: FinalizePartExchangeProcs
USE MOD_PICDepo_Vars           ,ONLY: SendShapeElemID,SendElemShapeID,ShapeMapping,CNShapeMapping
#endif /*USE_MPI*/
!#if USE_MPI
!USE MOD_Particle_MPI_Emission      ,ONLY: FinalizeEmissionParticlesToProcs
!#endif
!USE MOD_DSMC_Vars,                  ONLY: SampDSMC
!----------------------------------------------------------------------------------------------------------------------------------!
IMPLICIT NONE
! INPUT VARIABLES
!----------------------------------------------------------------------------------------------------------------------------------!
! OUTPUT VARIABLES
!-----------------------------------------------------------------------------------------------------------------------------------
! LOCAL VARIABLES
!===================================================================================================================================
!#if USE_MPI
!CALL FinalizeEmissionParticlesToProcs()
!#endif
#if defined(LSERK)
!#if (PP_TimeDiscMethod==1)||(PP_TimeDiscMethod==2)||(PP_TimeDiscMethod==6)||(PP_TimeDiscMethod>=501 && PP_TimeDiscMethod<=506)
SDEALLOCATE( Pt_temp)
#endif
#if (PP_TimeDiscMethod==508) || (PP_TimeDiscMethod==509)
IF (velocityOutputAtTime) THEN
  SDEALLOCATE(velocityAtTime)
END IF
#endif /*(PP_TimeDiscMethod==508) || (PP_TimeDiscMethod==509)*/
#if defined(ROS) || defined(IMPA)
SDEALLOCATE(PartStage)
SDEALLOCATE(PartStateN)
SDEALLOCATE(PartQ)
SDEALLOCATE(PartDtFrac)
SDEALLOCATE(PEM%GlobalElemID)
SDEALLOCATE(PEM%NormVec)
SDEALLOCATE(PEM%PeriodicMoved)
#endif /*defined(ROS) || defined(IMPA)*/
#if defined(IMPA)
SDEALLOCATE(F_PartXk)
SDEALLOCATE(F_PartX0)
SDEALLOCATE(Norm_F_PartXk_old)
SDEALLOCATE(Norm_F_PartXk)
SDEALLOCATE(Norm_F_PartX0)
SDEALLOCATE(PartDeltaX)
SDEALLOCATE(PartLambdaAccept)
SDEALLOCATE(DoPartInNewton)
SDEALLOCATE(PartIsImplicit)
#endif /*defined(IMPA)*/
!SDEALLOCATE(SampDSMC)
SDEALLOCATE(PartPosRef)
SDEALLOCATE(PartState)
SDEALLOCATE(LastPartPos)
SDEALLOCATE(PartSpecies)
SDEALLOCATE(Pt)
SDEALLOCATE(PDM%ParticleInside)
SDEALLOCATE(PDM%nextFreePosition)
SDEALLOCATE(PDM%nextFreePosition)
SDEALLOCATE(PDM%dtFracPush)
SDEALLOCATE(PDM%IsNewPart)
SDEALLOCATE(vMPF_SpecNumElem)
SDEALLOCATE(PartMPF)
!SDEALLOCATE(Species%Init)
SDEALLOCATE(Species)
SDEALLOCATE(SpecReset)
SDEALLOCATE(IMDSpeciesID)
SDEALLOCATE(IMDSpeciesCharge)
SDEALLOCATE(VarTimeStep%ParticleTimeStep)
SDEALLOCATE(VarTimeStep%ElemFac)
SDEALLOCATE(VarTimeStep%ElemWeight)
SDEALLOCATE(PartBound%SourceBoundName)
SDEALLOCATE(PartBound%TargetBoundCond)
SDEALLOCATE(PartBound%MomentumACC)
SDEALLOCATE(PartBound%WallTemp)
SDEALLOCATE(PartBound%WallTemp2)
SDEALLOCATE(PartBound%WallTempDelta)
SDEALLOCATE(PartBound%TempGradStart)
SDEALLOCATE(PartBound%TempGradEnd)
SDEALLOCATE(PartBound%TempGradVec)
SDEALLOCATE(PartBound%TransACC)
SDEALLOCATE(PartBound%VibACC)
SDEALLOCATE(PartBound%RotACC)
SDEALLOCATE(PartBound%ElecACC)
SDEALLOCATE(PartBound%Resample)
SDEALLOCATE(PartBound%WallVelo)
SDEALLOCATE(PartBound%RotVelo)
SDEALLOCATE(PartBound%RotFreq)
SDEALLOCATE(PartBound%RotOrg)
SDEALLOCATE(PartBound%RotAxi)
SDEALLOCATE(PartBound%RotPeriodicDir)
SDEALLOCATE(Adaptive_MacroVal)
SDEALLOCATE(PartBound%Voltage)
SDEALLOCATE(PartBound%UseForQCrit)
SDEALLOCATE(PartBound%NbrOfSpeciesSwaps)
SDEALLOCATE(PartBound%ProbOfSpeciesSwaps)
SDEALLOCATE(PartBound%SpeciesSwaps)
SDEALLOCATE(PartBound%MapToPartBC)
SDEALLOCATE(PartBound%SurfaceModel)
SDEALLOCATE(PartBound%Reactive)
SDEALLOCATE(PartBound%Dielectric)
SDEALLOCATE(PartBound%BoundaryParticleOutput)
SDEALLOCATE(PartStateBoundary)
SDEALLOCATE(PEM%GlobalElemID)
SDEALLOCATE(PEM%LastGlobalElemID)
SDEALLOCATE(PEM%pStart)
SDEALLOCATE(PEM%pNumber)
SDEALLOCATE(PEM%pEnd)
SDEALLOCATE(PEM%pNext)
SDEALLOCATE(seeds)
SDEALLOCATE(RegionBounds)
SDEALLOCATE(RegionElectronRef)
#if USE_MPI
SDEALLOCATE(SendShapeElemID)
SDEALLOCATE(SendElemShapeID)
SDEALLOCATE(ShapeMapping)
SDEALLOCATE(CNShapeMapping)
! particle MPI halo exchange
CALL FinalizePartExchangeProcs()
#endif
END SUBROUTINE FinalizeParticles

!-- matrices for coordtrafo:
!SUBROUTINE rotz(mat,a)
!IMPLICIT NONE
!REAL, INTENT(OUT), DIMENSION(3,3) :: mat
!REAL, INTENT(IN) :: a
!mat(:,1)=(/COS(a) ,-SIN(a) , 0./)
!mat(:,2)=(/SIN(a) , COS(a) , 0./)
!mat(:,3)=(/0.     , 0.     , 1./)
!END SUBROUTINE
SUBROUTINE rotx(mat,a)
IMPLICIT NONE
REAL, INTENT(OUT), DIMENSION(3,3) :: mat
REAL, INTENT(IN) :: a
mat(:,1)=(/1.0 , 0.     , 0.  /)
mat(:,2)=(/0.0 , COS(a) ,-SIN(a)/)
mat(:,3)=(/0.0 , SIN(a) , COS(a)/)
END SUBROUTINE
SUBROUTINE roty(mat,a)
IMPLICIT NONE
REAL, INTENT(OUT), DIMENSION(3,3) :: mat
REAL, INTENT(IN) :: a
mat(:,1)=(/ COS(a) , 0., SIN(a)/)
mat(:,2)=(/ 0.     , 1., 0.  /)
mat(:,3)=(/-SIN(a) , 0., COS(a)/)
END SUBROUTINE
SUBROUTINE ident(mat)
IMPLICIT NONE
REAL, INTENT(OUT), DIMENSION(3,3) :: mat
INTEGER :: j
mat = 0.
FORALL(j = 1:3) mat(j,j) = 1.
END SUBROUTINE


SUBROUTINE InitRandomSeed(nRandomSeeds,SeedSize,Seeds)
!===================================================================================================================================
!> Initialize pseudo random numbers: Create Random_seed array
!===================================================================================================================================
! MODULES
#if USE_MPI
USE MOD_Particle_MPI_Vars,     ONLY:PartMPI
#endif
! IMPLICIT VARIABLE HANDLING
!===================================================================================================================================
IMPLICIT NONE
! VARIABLES
INTEGER,INTENT(IN)             :: nRandomSeeds
INTEGER,INTENT(IN)             :: SeedSize
INTEGER,INTENT(INOUT)          :: Seeds(SeedSize)
!----------------------------------------------------------------------------------------------------------------------------------!
! LOCAL VARIABLES
INTEGER                        :: iSeed,DateTime(8),ProcessID,iStat,OpenFileID,GoodSeeds
INTEGER(KIND=8)                :: Clock,AuxilaryClock
LOGICAL                        :: uRandomExists
!==================================================================================================================================

uRandomExists=.FALSE.
IF (nRandomSeeds.NE.-1) THEN
  Clock     = 1536679165842_8
  ProcessID = 3671
ELSE
! First try if the OS provides a random number generator
  OPEN(NEWUNIT=OpenFileID, FILE="/dev/urandom", ACCESS="stream", &
       FORM="unformatted", ACTION="read", STATUS="old", IOSTAT=iStat)
  IF (iStat.EQ.0) THEN
    READ(OpenFileID) Seeds
    CLOSE(OpenFileID)
    uRandomExists=.TRUE.
  ELSE
    ! Fallback to XOR:ing the current time and pid. The PID is
    ! useful in case one launches multiple instances of the same
    ! program in parallel.
    CALL SYSTEM_CLOCK(COUNT=Clock)
    IF (Clock .EQ. 0) THEN
      CALL DATE_AND_TIME(values=DateTime)
      Clock =(DateTime(1) - 1970) * 365_8 * 24 * 60 * 60 * 1000 &
      + DateTime(2) * 31_8 * 24 * 60 * 60 * 1000 &
      + DateTime(3) * 24_8 * 60 * 60 * 1000 &
      + DateTime(5) * 60 * 60 * 1000 &
      + DateTime(6) * 60 * 1000 &
      + DateTime(7) * 1000 &
      + DateTime(8)
    END IF
    ProcessID = GetPID_C()
  END IF
END IF
IF(.NOT. uRandomExists) THEN
  Clock = IEOR(Clock, INT(ProcessID, KIND(Clock)))
  AuxilaryClock=Clock
  DO iSeed = 1, SeedSize
#if USE_MPI
    IF (nRandomSeeds.EQ.0) THEN
      AuxilaryClock=AuxilaryClock+PartMPI%MyRank
    ELSE IF(nRandomSeeds.GT.0) THEN
      AuxilaryClock=AuxilaryClock+(PartMPI%MyRank+1)*Seeds(iSeed)*37
    END IF
#else
    IF (nRandomSeeds.GT.0) THEN
      AuxilaryClock=AuxilaryClock+Seeds(iSeed)*37
    END IF
#endif
    IF (AuxilaryClock .EQ. 0) THEN
      AuxilaryClock = 104729
    ELSE
      AuxilaryClock = MOD(AuxilaryClock, 4294967296_8)
    END IF
    AuxilaryClock = MOD(AuxilaryClock * 279470273_8, 4294967291_8)
    GoodSeeds = INT(MOD(AuxilaryClock, INT(HUGE(0),KIND=8)), KIND(0))
    Seeds(iSeed) = GoodSeeds
  END DO
END IF
CALL RANDOM_SEED(PUT=Seeds)

END SUBROUTINE InitRandomSeed


END MODULE MOD_ParticleInit
