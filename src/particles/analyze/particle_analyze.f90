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

MODULE MOD_Particle_Analyze
! IMPLICIT VARIABLE HANDLING
IMPLICIT NONE
#ifdef PARTICLES
PRIVATE
!-----------------------------------------------------------------------------------------------------------------------------------
! GLOBAL VARIABLES
!-----------------------------------------------------------------------------------------------------------------------------------
! Private Part ---------------------------------------------------------------------------------------------------------------------
! Public Part ----------------------------------------------------------------------------------------------------------------------
INTERFACE AnalyzeParticles
  MODULE PROCEDURE AnalyzeParticles
END INTERFACE

PUBLIC :: InitParticleAnalyze, FinalizeParticleAnalyze
PUBLIC :: AnalyzeParticles
!===================================================================================================================================
PUBLIC::DefineParametersParticleAnalyze

CONTAINS

!==================================================================================================================================
!> Define parameters for particle analysis
!==================================================================================================================================
SUBROUTINE DefineParametersParticleAnalyze()
! MODULES
USE MOD_ReadInTools ,ONLY: prms
!USE MOD_AnalyzeEquation ,ONLY: DefineParametersAnalyzeEquation
IMPLICIT NONE
!==================================================================================================================================
CALL prms%SetSection("Particle Analyze")

CALL prms%CreateIntOption(      'Part-AnalyzeStep'        , 'Analyze is performed each Nth time step','1')
CALL prms%CreateLogicalOption(  'CalcTotalEnergy'         , 'Calculate Total Energy. Output file is Database.csv','.FALSE.')
CALL prms%CreateLogicalOption(  'PIC-VerifyCharge'        , 'Validate the charge after each deposition'//&
                                                            'and write an output in std.out','.FALSE.')
CALL prms%CreateLogicalOption(  'CalcIonizationDegree'    , 'Compute the ionization degree in each cell','.FALSE.')
CALL prms%CreateLogicalOption(  'CalcPointsPerShapeFunction','Compute the average number of interpolation points that are used for the shape function in each cell','.FALSE.')
CALL prms%CreateLogicalOption(  'CalcPlasmaParameter'     ,'Compute the plasma parameter N_D in each cell','.FALSE.')
CALL prms%CreateLogicalOption(  'CalcPointsPerDebyeLength', 'Compute the points per Debye length in each cell','.FALSE.')
CALL prms%CreateLogicalOption(  'CalcPICCFLCondition'     , 'Compute a PIC CFL condition for each cell','.FALSE.')
CALL prms%CreateLogicalOption(  'CalcMaxPartDisplacement' , 'Compute the maximum displacement of the fastest particle in terms of'//&
                                                            ' cell lengths in X, Y and Z for each cell','.FALSE.')
CALL prms%CreateLogicalOption(  'CalcDebyeLength'         , 'Compute the Debye length in each cell','.FALSE.')
CALL prms%CreateLogicalOption(  'CalcPICTimeStep'         , 'Compute the HDG time step in each cell depending on the plasma frequency','.FALSE.')
CALL prms%CreateLogicalOption(  'CalcPICTimeStepCyclotron', 'Compute the HDG time step in each cell depending on the cyclotron frequency','.FALSE.')
CALL prms%CreateLogicalOption(  'CalcElectronTemperature' , 'Compute the electron temperature in each cell','.FALSE.')
!CALL prms%CreateLogicalOption(  'ElectronTemperatureIsMaxwell', 'Flag if  electron temperature is assumed to be Maxwellian in each cell','.TRUE.')
CALL prms%CreateLogicalOption(  'CalcElectronIonDensity'     , 'Compute the electron density in each cell','.FALSE.')
CALL prms%CreateLogicalOption(  'CalcPlasmaFrequency'     , 'Compute the electron plasma frequency in each cell','.FALSE.')
CALL prms%CreateLogicalOption(  'CalcCyclotronFrequency'  , 'Compute the electron cylcotron frequency in each cell','.FALSE.')
CALL prms%CreateLogicalOption(  'CalcCharge'              , 'TODO-DEFINE-PARAMETER\n'//&
                                                            'Compute the whole deposited charge,'//&
                                                            ' absolute and relative charge error','.FALSE.')
CALL prms%CreateLogicalOption(  'CalcKineticEnergy'       , 'TODO-DEFINE-PARAMETER\n'//&
                                                            'Calculate Kinetic Energy. ','.FALSE.')
CALL prms%CreateLogicalOption(  'CalcInternalEnergy'      , 'TODO-DEFINE-PARAMETER\n'//&
                                                            'Calculate Internal Energy. ','.FALSE.')
CALL prms%CreateLogicalOption(  'CalcTemp'                , 'TODO-DEFINE-PARAMETER\n'//&
                                                            'Calculate Translational temperature.'&
                                                          ,'.FALSE.')
CALL prms%CreateLogicalOption(  'CalcPartBalance'         , 'TODO-DEFINE-PARAMETER\n'//&
                                                            'Calculate the Particle Power Balance'//&
                                                            '- input and outflow energy of all particles','.FALSE.')
CALL prms%CreateLogicalOption(  'CalcVelos'               , 'TODO-DEFINE-PARAMETER\n'//&
                                                            'Calculate thermal and flow velocities.'//&
                                                            'if CalcVelos = T VelocityDirections = (/[int],[int],[int],[int]/)  '//&
                                                            'Switching dimensions for CalcVelos on (1) or off (0)\n'//&
                                                            '(/v_x,v_y,v_z,|v|/) ','.FALSE.')
CALL prms%CreateLogicalOption(  'CalcLaserInteraction'     , 'Compute laser-plasma interaction properties such as maximum '//&
                                                             'particle energy per species.','.FALSE.')
CALL prms%CreateLogicalOption(  'CalcRelaxProb'           , 'Calculate variable rotational and vibrational relaxation probability'&
                                                            ' for PartAnalyse.csv\n'//&
                                                            'Particles-DSMC-CalcQualityFactors has to be true.'&
                                                          ,'.FALSE.')
CALL prms%CreateRealOption(     'LaserInteractionEkinMaxRadius','maximum radius (x- and y-dir) of particle to be considered for '//&
                                                                'Ekin maximum calculation (default is HUGE) '//&
                                                                'OR if LaserInteractionEkinMaxZPosMin condition is true')
CALL prms%CreateRealOption(     'LaserInteractionEkinMaxZPosMin','minimum z-position of particle to be considered for Ekin '//&
                                                                 'maximum calculation (default is -1.*HUGE) '//&
                                                                 'OR if LaserInteractionEkinMaxRadius condition is true')
CALL prms%CreateIntArrayOption( 'VelocityDirections'      , 'TODO-DEFINE-PARAMETER\n'//&
                                                            'x,y,z,abs -> 0/1 = T/F. (please note: CalcVelos)'&
                                                          ,'1 , 1 , 1 , 1')
CALL prms%CreateLogicalOption(  'Part-TrackPosition'      , 'TODO-DEFINE-PARAMETER\n'//&
                                                            'Track particle position','.FALSE.')
CALL prms%CreateLogicalOption(  'printDiff'               , 'TODO-DEFINE-PARAMETER','.FALSE.')
CALL prms%CreateRealOption(     'printDiffTime'           , 'TODO-DEFINE-PARAMETER','12.')
CALL prms%CreateRealArrayOption('printDiffVec'            , 'TODO-DEFINE-PARAMETER','0. , 0. , 0. , 0. , 0. , 0.')
CALL prms%CreateLogicalOption(  'CalcNumSpec'             , 'Calculate the number of simulation particles per species for the '//&
                                                            'complete domain','.FALSE.')
CALL prms%CreateLogicalOption(  'CalcNumDens'             , 'Calculate the number density [1/m3] per species for the complete '//&
                                                            'domain','.FALSE.')
CALL prms%CreateLogicalOption(  'CalcAdaptiveBCInfo'      , 'Calculate the massflow rate [kg/s] per species and surface flux' &
                                                          ,'.FALSE.')
CALL prms%CreateLogicalOption(  'CalcCollRates'           , 'TODO-DEFINE-PARAMETER\n'//&
                                                            'Calculate the collision rates per '//&
                                                            'collision pair','.FALSE.')
CALL prms%CreateLogicalOption(  'CalcReacRates'           , 'TODO-DEFINE-PARAMETER\n'//&
                                                            'Calculate the reaction rate per reaction'&
                                                          ,'.FALSE.')
CALL prms%CreateLogicalOption(  'CalcShapeEfficiency'     , 'TODO-DEFINE-PARAMETER\n'//&
                                                            'Use efficiency methods for shape functions.'&
                                                          , '.FALSE.')
CALL prms%CreateStringOption(   'CalcShapeEfficiencyMethod', 'TODO-DEFINE-PARAMETER\n'//&
                                                             'Choose between "AllParts" and '//&
                                                             '"SomeParts", to either use all particles or a certain percentage'//&
                                                             ' (ShapeEfficiencyNumber) of the currently used particles','AllParts')
CALL prms%CreateIntOption(      'ShapeEfficiencyNumber'    , 'TODO-DEFINE-PARAMETER\n'//&
                                                             'Percentage of currently used particles is used.'&
                                                           , '100')
CALL prms%CreateLogicalOption(  'IsRestart'                , 'TODO-DEFINE-PARAMETER\n'//&
                                                             'Flag, if the current calculation is a restart. '&
                                                           , '.FALSE.')
CALL prms%CreateLogicalOption(  'CalcCoupledPower'         , 'Calculate output of Power that is coupled into plasma' , '.FALSE.')
CALL prms%CreateLogicalOption(  'DisplayCoupledPower'      , 'Display coupled power in UNIT_stdOut' , '.FALSE.')

END SUBROUTINE DefineParametersParticleAnalyze

SUBROUTINE InitParticleAnalyze()
!===================================================================================================================================
! Initializes variables necessary for analyse subroutines
!===================================================================================================================================
! MODULES
USE MOD_Globals
USE MOD_Globals_Vars          ,ONLY: PI
USE MOD_Preproc
USE MOD_DSMC_Vars             ,ONLY: RadialWeighting, Collismode
USE MOD_IO_HDF5               ,ONLY: AddToElemData,ElementOut
USE MOD_Mesh_Vars             ,ONLY: nElems,offsetElem
USE MOD_Particle_Analyze_Vars
USE MOD_Particle_Mesh_Vars    ,ONLY: BoundsOfElem_Shared,ElemVolume_Shared
USE MOD_Particle_Mesh_Vars    ,ONLY: ElemCharLengthX_Shared,ElemCharLengthY_Shared,ElemCharLengthZ_Shared
USE MOD_Mesh_Tools            ,ONLY: GetCNElemID
USE MOD_Particle_Vars         ,ONLY: Species, nSpecies, VarTimeStep, PDM, usevMPF
USE MOD_PICDepo_Vars          ,ONLY: DoDeposition,SFAdaptiveDOF,r_sf,DepositionType,SFElemr2_Shared,dim_sf,dimFactorSF,dim_sf_dir
USE MOD_PICDepo_Vars          ,ONLY: SFAdaptiveSmoothing
USE MOD_ReadInTools           ,ONLY: GETLOGICAL, GETINT, GETSTR, GETINTARRAY, GETREALARRAY, GETREAL
USE MOD_ReadInTools           ,ONLY: PrintOption
#if (PP_TimeDiscMethod == 42)
USE MOD_TimeDisc_Vars         ,ONLY: TEnd
USE MOD_TimeDisc_Vars         ,ONLY: ManualTimeStep
USE MOD_Restart_Vars          ,ONLY: RestartTime
#endif
#if USE_MPI
USE MOD_MPI_Shared
USE MOD_MPI_Shared_Vars       ,ONLY: MPI_COMM_SHARED
USE MOD_Particle_Mesh_Vars    ,ONLY: nComputeNodeElems,offsetComputeNodeElem
USE MOD_Particle_Mesh_Vars    ,ONLY: ElemCharLengthX_Shared_Win
USE MOD_Particle_Mesh_Vars    ,ONLY: ElemCharLengthY_Shared_Win
USE MOD_Particle_Mesh_Vars    ,ONLY: ElemCharLengthZ_Shared_Win
#endif /*USE_MPI*/
USE MOD_Mesh_Vars             ,ONLY: ElemBaryNGeo
USE MOD_Particle_Analyze_Tools,ONLY: AllocateElectronIonDensityCell,AllocateElectronTemperatureCell
#if USE_HDG
USE MOD_HDG_Vars              ,ONLY: CalcBRVariableElectronTemp
#endif /*USE_HDG*/
! IMPLICIT VARIABLE HANDLING
IMPLICIT NONE
!-----------------------------------------------------------------------------------------------------------------------------------
! OUTPUT VARIABLES
!-----------------------------------------------------------------------------------------------------------------------------------
! LOCAL VARIABLES
INTEGER       :: dir, VeloDirs_hilf(4),iElem
REAL          :: DOF,DOFMax,VolumeShapeFunction,ShapeFunctionFractionLoc
CHARACTER(32) :: hilf,hilf2
INTEGER       :: iSpec
INTEGER       :: offsetElemCNProc,CNElemID
#if USE_MPI
INTEGER(KIND=MPI_ADDRESS_KIND) :: MPISharedSize
#else
INTEGER       :: ALLOCSTAT
#endif
!===================================================================================================================================
IF (ParticleAnalyzeInitIsDone) THEN
CALL abort(__STAMP__,&
'InitParticleAnalyse already called.',999,999.)
  RETURN
END IF
SWRITE(UNIT_StdOut,'(132("-"))')
SWRITE(UNIT_stdOut,'(A)') ' INIT PARTICLE ANALYZE...'

! Average number of points per shape function: max. number allowed is (PP_N+1)^3
IF(StringBeginsWith(DepositionType,'shape_function'))THEN
  CalcPointsPerShapeFunction = GETLOGICAL('CalcPointsPerShapeFunction')
ELSE
  CalcPointsPerShapeFunction = .FALSE.
END IF

! Allocate arrays and calculate the average number of points in each shape function sphere
IF(CalcPointsPerShapeFunction)THEN

  ! PPSCell:
  ! Points per shape function sphere (cell mean value): Calculate cell local number excluding neighbor DOFs
  ALLOCATE( PPSCell(1:PP_nElems) )
  PPSCell=0.0
  CALL AddToElemData(ElementOut,'PPSCell',RealArray=PPSCell(1:PP_nElems))

  ! PPSCellCartesian:
  ! Points per shape function sphere (cell mean value): Assume Cartesian grid and calculate to total number including neighbor DOFs
  ALLOCATE( PPSCellCartesian(1:PP_nElems) )
  PPSCellCartesian=0.0
  CALL AddToElemData(ElementOut,'PPSCellCartesian',RealArray=PPSCellCartesian(1:PP_nElems))

  ! Depending on type of shape function, calculate global shape function volume or separate for each cell
  IF(TRIM(DepositionType).EQ.'shape_function_adaptive')THEN
    ! ShapeFunctionRadius: Create additional array (radius is already stored in the shared array) for output to .h5 (debugging)
    ALLOCATE( ShapeFunctionRadius(1:PP_nElems) )
    ShapeFunctionRadius=0.0
    CALL AddToElemData(ElementOut,'ShapeFunctionRadius',RealArray=ShapeFunctionRadius(1:PP_nElems))

    ! ShapeFunctioFraction: Element to shape function volume ratio
    ALLOCATE( ShapeFunctionFraction(1:PP_nElems) )
    ShapeFunctionFraction=0.0
    CALL AddToElemData(ElementOut,'ShapeFunctionFraction',RealArray=ShapeFunctionFraction(1:PP_nElems))

    ! Loop over all elems and calculate shape function volume for each element separately
    DO iElem = 1, nElems
      CNElemID                     = GetCNElemID(iElem+offSetElem) ! iElem + offSetElem = globElemID
      ShapeFunctionRadius(iElem)   = SFElemr2_Shared(1,CNElemID)

      ! Check which shape function dimension is used
      SELECT CASE(dim_sf)
      CASE(1) ! 1D
        DOF    = REAL((PP_N+1)) ! DOF per element in 1D
        DOFMax = 2.0*DOF        ! Max. DOF per element in 1D
        hilf2 = '2*(N+1)'       ! Max. DOF per element in 1D for abort message
        VolumeShapeFunction          = 2.0*ShapeFunctionRadius(iElem)
        ShapeFunctionFraction(iElem) = (VolumeShapeFunction/ElemVolume_Shared(CNElemID))*dimFactorSF

      CASE(2) ! 2D
        DOF    = REAL((PP_N+1)**2) ! DOF per element in 2D
        DOFMax = PI*DOF            ! Max. DOF per element in 2D
        hilf2 = 'PI*(N+1)**2'      ! Max. DOF per element in 1D for abort message
        VolumeShapeFunction          = PI*(ShapeFunctionRadius(iElem)**2)
        ShapeFunctionFraction(iElem) = (VolumeShapeFunction/ElemVolume_Shared(CNElemID))*dimFactorSF

      CASE(3) ! 3D
        DOF = REAL((PP_N+1)**3)     ! DOF per element in 3D
        DOFMax = (4./3.)*PI*DOF     ! Max. DOF per element in 2D
        hilf2 = '(4/3)*PI*(N+1)**3' ! Max. DOF per element in 1D for abort message
        VolumeShapeFunction          = PI*(ShapeFunctionRadius(iElem)**2)
        VolumeShapeFunction          = 4./3.*PI*(ShapeFunctionRadius(iElem)**3)
        ShapeFunctionFraction(iElem) = VolumeShapeFunction/ElemVolume_Shared(CNElemID)
      END SELECT

      ! Calculate the corresponding number of DOF per shape function per cell/element (considering 1D, 2D or 3D distribution)
      PPSCell(iElem)     = MIN(1.,ShapeFunctionFraction(iElem)) * DOF
      PPSCellCartesian(iElem) =        ShapeFunctionFraction(iElem)  * DOF

      ! Sanity check (only when smoothing is not activated because then the radius is allowed to be larger)
      IF(.NOT.SFAdaptiveSmoothing)THEN
        ! Check if more DOF/SF are present in a cell than allowed (but allow the maximum value as it is used as default)
        IF(PPSCellCartesian(iElem).GT.DOFMax.AND.(.NOT.ALMOSTEQUALRELATIVE(PPSCellCartesian(iElem),DOFMax,1e-5)))THEN
          IPWRITE(UNIT_StdOut,'(I0,A57,F10.2)') " PPSCellCartesian(iElem) :", PPSCellCartesian(iElem)
          IPWRITE(UNIT_StdOut,'(I0,A,I3,A,A19,A,F10.2)') " For N =",PP_N,", the maximum allowed is ",TRIM(hilf2)," :", DOFMax
          IPWRITE(UNIT_StdOut,'(I0,A,29X,A,3(ES23.14))') " ElemBaryNGeo(1:3,iElem)   ",":", ElemBaryNGeo(1:3,iElem)
          IPWRITE(UNIT_StdOut,'(I0,A,29X,A,ES23.14)')    " ShapeFunctionRadius(iElem)",":", ShapeFunctionRadius(iElem)
          IPWRITE(UNIT_StdOut,'(I0,A,F10.2)') " Reduce the number of DOF/SF in order to have no DOF outside of the deposition "//&
              "range (neighbour elems) by changing\n  PIC-shapefunction-adaptive-DOF, which is currently set to =", SFAdaptiveDOF
          ! Check 1D/2D shape function distribution (assume that only 1 element is used in the constant direction)
          SELECT CASE(dim_sf)
          CASE(1) ! 1D
            IPWRITE(UNIT_StdOut,'(I0,A,I3,A)') &
                " WARNING: IF THIS CHECK FAILS YOU MIGHT BE USING MORE THAN 1 element in the other directions of "&
                ,dim_sf_dir," (1: x, 2: y and 3: zdir)"
          CASE(2) ! 2D
            IPWRITE(UNIT_StdOut,'(I0,A,I3,A)') &
                " WARNING: IF THIS CHECK FAILS YOU MIGHT BE USING MORE THAN 1 element in the direction of "&
                ,dim_sf_dir," (1: x, 2: y and 3: zdir)"
          END SELECT
          CALL abort(__STAMP__,'PPSCellCartesian(iElem) > '//TRIM(hilf2)//' is not allowed')
        END IF ! PPSCellCartesian(iElem).GT.4./3.*PI*(PP_N+1)**3
      END IF ! .NOT.SFAdaptiveSmoothing

    END DO ! iElem = 1, nElems

  ELSE ! normal/cc shape function with global radius

    DO iElem = 1, nElems
      CNElemID           = GetCNElemID(iElem+offSetElem) ! iElem + offSetElem = globElemID
      ! Check which shape function dimension is used
      SELECT CASE(dim_sf)
      CASE(1) ! 1D
        DOF                 = REAL((PP_N+1)) ! DOF per element in 1D
        VolumeShapeFunction = 2.0*r_sf
        IF(MPIRoot.AND.(iElem.EQ.1))THEN
          CALL PrintOption('VolumeShapeFunction (1D, line)','OUTPUT',RealOpt=VolumeShapeFunction)
          CALL PrintOption('Max DOFs in Shape-Function per cell (1D, line)','OUTPUT',RealOpt=DOF)
        END IF ! MPIRoot.AND.(iElem.EQ.1)
        ShapeFunctionFractionLoc = (VolumeShapeFunction/ElemVolume_Shared(CNElemID))*dimFactorSF
      CASE(2) ! 2D
        DOF                 = REAL((PP_N+1)**2) ! DOF per element in 2D
        VolumeShapeFunction = PI*(r_sf**2)
        IF(MPIRoot.AND.(iElem.EQ.1))THEN
          CALL PrintOption('VolumeShapeFunction (2D, circle area)','OUTPUT',RealOpt=VolumeShapeFunction)
          CALL PrintOption('Max DOFs in Shape-Function per cell (2D, area)','OUTPUT',RealOpt=DOF)
        END IF ! MPIRoot.AND.(iElem.EQ.1)
        ShapeFunctionFractionLoc = (VolumeShapeFunction/ElemVolume_Shared(CNElemID))*dimFactorSF
      CASE(3) ! 3D
        DOF                 = REAL((PP_N+1)**3) ! DOF per element in 3D
        VolumeShapeFunction = 4./3.*PI*(r_sf**3)
        IF(MPIRoot.AND.(iElem.EQ.1))THEN
          CALL PrintOption('VolumeShapeFunction (3D, sphere)','OUTPUT',RealOpt=VolumeShapeFunction)
          CALL PrintOption('Max DOFs in Shape-Function per cell (3D, cuboid)','OUTPUT',RealOpt=DOF)
        END IF ! MPIRoot.AND.(iElem.EQ.1)
        ShapeFunctionFractionLoc = VolumeShapeFunction/ElemVolume_Shared(CNElemID)
      END SELECT
      PPSCell(iElem)          = MIN(1.,ShapeFunctionFractionLoc) * DOF
      PPSCellCartesian(iElem) = ShapeFunctionFractionLoc  * DOF
    END DO ! iElem = 1, nElems

  END IF ! TRIM(DepositionType).EQ.'shape_function_adaptive'

END IF

!--------------------------------------------------------------------------------------------------------------------
! get derived particle properties
!--------------------------------------------------------------------------------------------------------------------
! Compute a PIC CFL condition for each cell
CalcPICCFLCondition       = GETLOGICAL('CalcPICCFLCondition','.FALSE.')
IF(CalcPICCFLCondition)THEN
  ! value in 3D estimated with the characteristic length of the cell
  ALLOCATE( PICCFLCell(1:PP_nElems) )
  PICCFLCell=0.0
  CALL AddToElemData(ElementOut,'PICCFL3D',RealArray=PICCFLCell(1:PP_nElems))
  ! x
  ALLOCATE( PICCFLCellX(1:PP_nElems) )
  PICCFLCellX=0.0
  CALL AddToElemData(ElementOut,'PICCFLDirX',RealArray=PICCFLCellX(1:PP_nElems))
  ! y
  ALLOCATE( PICCFLCellY(1:PP_nElems) )
  PICCFLCellY=0.0
  CALL AddToElemData(ElementOut,'PICCFLDirY',RealArray=PICCFLCellY(1:PP_nElems))
  ! z
  ALLOCATE( PICCFLCellZ(1:PP_nElems) )
  PICCFLCellZ=0.0
  CALL AddToElemData(ElementOut,'PICCFLDirZ',RealArray=PICCFLCellZ(1:PP_nElems))
END IF ! CalcPICCFLCondition

! Compute the maximum displacement of the fastest particle
CalcMaxPartDisplacement = GETLOGICAL('CalcMaxPartDisplacement','.FALSE.')
IF(CalcMaxPartDisplacement)THEN
  ! value in 3D estimated with the characteristic length of the cell
  ALLOCATE( MaxPartDisplacementCell(1:PP_nElems) )
  MaxPartDisplacementCell=0.0
  CALL AddToElemData(ElementOut,'MaxPartDisplacement3D',RealArray=MaxPartDisplacementCell(1:PP_nElems))
  ! x
  ALLOCATE( MaxPartDisplacementCellX(1:PP_nElems) )
  MaxPartDisplacementCellX=0.0
  CALL AddToElemData(ElementOut,'MaxPartDisplacementDirX',RealArray=MaxPartDisplacementCellX(1:PP_nElems))
  ! y
  ALLOCATE( MaxPartDisplacementCellY(1:PP_nElems) )
  MaxPartDisplacementCellY=0.0
  CALL AddToElemData(ElementOut,'MaxPartDisplacementDirY',RealArray=MaxPartDisplacementCellY(1:PP_nElems))
  ! z
  ALLOCATE( MaxPartDisplacementCellZ(1:PP_nElems) )
  MaxPartDisplacementCellZ=0.0
  CALL AddToElemData(ElementOut,'MaxPartDisplacementDirZ',RealArray=MaxPartDisplacementCellZ(1:PP_nElems))
END IF ! MaxPartDisplacement


!--------------------------------------------------------------------------------------------------------------------
! get more derived particle properties
! (Note that for IMD/TTM initialization these values are calculated from the TTM grid values)
!--------------------------------------------------------------------------------------------------------------------
! PointsPerDebyeLength: PPD = (p+1)*lambda_D/L_cell
! p:        Polynomial degree
! lambda_D: Debye length
! L_cell:   Characteristic ceill length -> V_cell^(1/3)
CalcPointsPerDebyeLength       = GETLOGICAL('CalcPointsPerDebyeLength','.FALSE.')
IF(CalcPointsPerDebyeLength)THEN
  ! value in 3D estimated with the characteristic length of the cell
  ALLOCATE( PPDCell(1:PP_nElems) )
  PPDCell=0.0
  CALL AddToElemData(ElementOut,'PPDCell3D',RealArray=PPDCell(1:PP_nElems))
  ! x
  ALLOCATE( PPDCellX(1:PP_nElems) )
  PPDCellX=0.0
  CALL AddToElemData(ElementOut,'PPDCellDirX',RealArray=PPDCellX(1:PP_nElems))
  ! y
  ALLOCATE( PPDCellY(1:PP_nElems) )
  PPDCellY=0.0
  CALL AddToElemData(ElementOut,'PPDCellDirY',RealArray=PPDCellY(1:PP_nElems))
  ! z
  ALLOCATE( PPDCellZ(1:PP_nElems) )
  PPDCellZ=0.0
  CALL AddToElemData(ElementOut,'PPDCellDirZ',RealArray=PPDCellZ(1:PP_nElems))
END IF


IF(CalcPointsPerDebyeLength.OR.CalcPICCFLCondition.OR.CalcMaxPartDisplacement)THEN
  ! Determine the average distances in x, y and z
  ! Move the determination of these variables as soon as they are required for other functions!
#if USE_MPI
  MPISharedSize = INT(nComputeNodeElems,MPI_ADDRESS_KIND)*MPI_ADDRESS_KIND
  CALL Allocate_Shared(MPISharedSize,(/nComputeNodeElems/),ElemCharLengthX_Shared_Win,ElemCharLengthX_Shared)
  CALL Allocate_Shared(MPISharedSize,(/nComputeNodeElems/),ElemCharLengthY_Shared_Win,ElemCharLengthY_Shared)
  CALL Allocate_Shared(MPISharedSize,(/nComputeNodeElems/),ElemCharLengthZ_Shared_Win,ElemCharLengthZ_Shared)
  CALL MPI_WIN_LOCK_ALL(0,ElemCharLengthX_Shared_Win,IERROR)
  CALL MPI_WIN_LOCK_ALL(0,ElemCharLengthY_Shared_Win,IERROR)
  CALL MPI_WIN_LOCK_ALL(0,ElemCharLengthZ_Shared_Win,IERROR)
  ! CharLength is only build for local DG elements. Therefore, array is only filled for elements on the same compute node
  offsetElemCNProc = offsetElem - offsetComputeNodeElem
#else
  ALLOCATE(ElemCharLengthX_Shared(nElems), &
           ElemCharLengthY_Shared(nElems), &
           ElemCharLengthZ_Shared(nElems), &
           STAT=ALLOCSTAT)
  IF (ALLOCSTAT.NE.0) &
    CALL abort(__STAMP__,'ERROR in Particle Analyze: Cannot allocate ElemCharLength in X, Y or Z!')
  offsetElemCNProc = 0
#endif  /*USE_MPI*/
  DO iElem = 1, nElems
    ASSOCIATE( Bounds => BoundsOfElem_Shared(1:2,1:3,iElem + offsetElem) ) ! 1-2: Min, Max value; 1-3: x,y,z
      ElemCharLengthX_Shared(iElem + offsetElemCNProc) = ABS(Bounds(2,1)-Bounds(1,1)) ! ABS(max - min)
      ElemCharLengthY_Shared(iElem + offsetElemCNProc) = ABS(Bounds(2,2)-Bounds(1,2)) ! ABS(max - min)
      ElemCharLengthZ_Shared(iElem + offsetElemCNProc) = ABS(Bounds(2,3)-Bounds(1,3)) ! ABS(max - min)
    END ASSOCIATE
  END DO ! iElem = 1, nElems

#if USE_MPI
  CALL BARRIER_AND_SYNC(ElemCharLengthX_Shared_Win,MPI_COMM_SHARED)
  CALL BARRIER_AND_SYNC(ElemCharLengthY_Shared_Win,MPI_COMM_SHARED)
  CALL BARRIER_AND_SYNC(ElemCharLengthZ_Shared_Win,MPI_COMM_SHARED)
#endif
END IF

! Plasma parameter
CalcPlasmaParameter   = GETLOGICAL('CalcPlasmaParameter','.FALSE.')
IF(CalcPlasmaParameter)THEN
  ALLOCATE( PlasmaParameterCell(1:PP_nElems) )
  PlasmaParameterCell=0.0
  CALL AddToElemData(ElementOut,'PlasmaParameterCell',RealArray=PlasmaParameterCell(1:PP_nElems))
END IF

! Debye Length
CalcDebyeLength       = GETLOGICAL('CalcDebyeLength','.FALSE.')
IF(CalcPointsPerDebyeLength.OR.CalcPlasmaParameter) CalcDebyeLength=.TRUE.
IF(CalcDebyeLength)THEN
  ALLOCATE( DebyeLengthCell(1:PP_nElems) )
  DebyeLengthCell=0.0
  CALL AddToElemData(ElementOut,'DebyeLengthCell',RealArray=DebyeLengthCell(1:PP_nElems))
END IF

! Ionization degree and quasi-neutrality
CalcIonizationDegree = GETLOGICAL('CalcIonizationDegree','.FALSE.')
IF(CalcDebyeLength) CalcIonizationDegree=.TRUE.
IF(CalcIonizationDegree)THEN
  ! degree of ionization
  ALLOCATE( IonizationCell(1:PP_nElems) )
  IonizationCell=0.0
  CALL AddToElemData(ElementOut,'IonizationCell',RealArray=IonizationCell(1:PP_nElems))
  ! quasi neutrality
  ALLOCATE( QuasiNeutralityCell(1:PP_nElems) )
  QuasiNeutralityCell=0.0
  CALL AddToElemData(ElementOut,'QuasiNeutralityCell',RealArray=QuasiNeutralityCell(1:PP_nElems))
END IF

! PIC time step Approximation
CalcPICTimeStep       = GETLOGICAL('CalcPICTimeStep','.FALSE.')
IF(CalcPICTimeStep)THEN
  ALLOCATE( PICTimeStepCell(1:PP_nElems) )
  PICTimeStepCell=0.0
  CALL AddToElemData(ElementOut,'PICTimeStepCell',RealArray=PICTimeStepCell(1:PP_nElems))
END IF

! Plasma frequency
CalcPlasmaFrequency   = GETLOGICAL('CalcPlasmaFrequency','.FALSE.')
IF(CalcPICTimeStep) CalcPlasmaFrequency=.TRUE.
IF(CalcPlasmaFrequency)THEN
  ALLOCATE( PlasmaFrequencyCell(1:PP_nElems) )
  PlasmaFrequencyCell=0.0
  CALL AddToElemData(ElementOut,'PlasmaFrequencyCell',RealArray=PlasmaFrequencyCell(1:PP_nElems))
END IF

! PIC time step approximation for gyro motion
CalcPICTimeStepCyclotron       = GETLOGICAL('CalcPICTimeStepCyclotron','.FALSE.')
IF(CalcPICTimeStepCyclotron)THEN
  ALLOCATE( PICTimeStepCyclotronCell(1:PP_nElems) )
  PICTimeStepCyclotronCell=0.0
  CALL AddToElemData(ElementOut,'PICTimeStepCyclotronCell',RealArray=PICTimeStepCyclotronCell(1:PP_nElems))
END IF

! Electron cyclotron frequency and gyroradius
CalcCyclotronFrequency   = GETLOGICAL('CalcCyclotronFrequency','.FALSE.')
IF(CalcPICTimeStepCyclotron) CalcCyclotronFrequency=.TRUE.
IF(CalcCyclotronFrequency)THEN
  ALLOCATE( CyclotronFrequencyMaxCell(1:PP_nElems) )
  CyclotronFrequencyMaxCell=0.0
  CALL AddToElemData(ElementOut,'CyclotronFrequencyMaxCell',RealArray=CyclotronFrequencyMaxCell(1:PP_nElems))
  ALLOCATE( CyclotronFrequencyMinCell(1:PP_nElems) )
  CyclotronFrequencyMinCell=0.0
  CALL AddToElemData(ElementOut,'CyclotronFrequencyMinCell',RealArray=CyclotronFrequencyMinCell(1:PP_nElems))
  ALLOCATE( GyroradiusMinCell(1:PP_nElems) )
  GyroradiusMinCell=0.0
  CALL AddToElemData(ElementOut,'GyroradiusMinCell',RealArray=GyroradiusMinCell(1:PP_nElems))
  ALLOCATE( GyroradiusMaxCell(1:PP_nElems) )
  GyroradiusMaxCell=0.0
  CALL AddToElemData(ElementOut,'GyroradiusMaxCell',RealArray=GyroradiusMaxCell(1:PP_nElems))
END IF

! Electron Density
CalcElectronIonDensity   = GETLOGICAL('CalcElectronIonDensity','.FALSE.')
IF(CalcDebyeLength.OR.CalcPlasmaFrequency.OR.CalcIonizationDegree) CalcElectronIonDensity=.TRUE.
IF(CalcElectronIonDensity) CALL AllocateElectronIonDensityCell()

! Electron Temperature
CalcElectronTemperature   = GETLOGICAL('CalcElectronTemperature','.FALSE.')
IF(CalcDebyeLength.OR.CalcPlasmaFrequency.OR.CalcPICCFLCondition) CalcElectronTemperature=.TRUE.
IF(CalcElectronTemperature) CALL AllocateElectronTemperatureCell()
!--------------------------------------------------------------------------------------------------------------------
! PartAnalyzeStep: The interval for the particle analyze output routines (write-out into PartAnalyze.csv)
!             = 1: Analyze and output every time step
!             = 0: Single output at the end, averaged over number of iterations (HUGE: MOD function can still be used to determine
!                  whether an output has to be performed)
!             = N: Analyze and output every Nth time step, average over N number of iterations
PartAnalyzeStep = GETINT('Part-AnalyzeStep','1')
IF (PartAnalyzeStep.EQ.0) PartAnalyzeStep = HUGE(PartAnalyzeStep)

#if (PP_TimeDiscMethod == 42)
  IF(PartAnalyzeStep.NE.HUGE(PartAnalyzeStep)) THEN
    IF(MOD(NINT((TEnd-RestartTime)/ManualTimeStep,8),PartAnalyzeStep).NE.0) THEN
      SWRITE(UNIT_stdOut,'(A,I0)') 'NINT((TEnd-RestartTime)/ManualTimeStep) = ',NINT((TEnd-RestartTime)/ManualTimeStep,8)
      SWRITE(UNIT_stdOut,'(A,I0)') '                        PartAnalyzeStep = ',PartAnalyzeStep
      CALL abort(&
        __STAMP__&
        ,'Please specify a PartAnalyzeStep, which is a factor of the total number of iterations!')
    END IF
  END IF
#endif

DoPartAnalyze = .FALSE.
! only verifycharge and CalcCharge if particles are deposited onto the grid
DoVerifyCharge= .FALSE.
CalcCharge = .FALSE.
IF(DoDeposition) THEN
  DoVerifyCharge = GETLOGICAL('PIC-VerifyCharge','.FALSE.')
  CalcCharge = GETLOGICAL('CalcCharge','.FALSE.')
  IF(CalcCharge) DoPartAnalyze = .TRUE.
ELSE
  SWRITE(UNIT_stdOut,'(A)') ' Deposition is switched of. VerifyCharge and CalcCharge are deactivated!'
END IF

CalcEkin = GETLOGICAL('CalcKineticEnergy','.FALSE.')
! Laser-plasma interaction analysis
CalcLaserInteraction = GETLOGICAL('CalcLaserInteraction')
IF(CalcLaserInteraction)THEN
  ! set boundaries in order to exclude particles near the boundary (nonphysical velocities)
  WRITE(UNIT=hilf,FMT=WRITEFORMAT) 1.0E200!HUGE(1.0) -> HUGE produces IEEE overflow
  LaserInteractionEkinMaxRadius  = GETREAL('LaserInteractionEkinMaxRadius',TRIM(hilf))
  WRITE(UNIT=hilf,FMT=WRITEFORMAT) -1.0E200!-1.*HUGE(1.0) -> HUGE produces IEEE overflow
  LaserInteractionEkinMaxZPosMin = GETREAL('LaserInteractionEkinMaxZPosMin',TRIM(hilf))
  CalcEkin=.TRUE.
END IF

CalcEint = GETLOGICAL('CalcInternalEnergy','.FALSE.')
CalcTemp = GETLOGICAL('CalcTemp','.FALSE.')
IF(CalcTemp.OR.CalcEint) DoPartAnalyze = .TRUE.
IF(CalcEkin) DoPartAnalyze = .TRUE.
IF(nSpecies.GT.1) THEN
  nSpecAnalyze = nSpecies + 1
ELSE
  nSpecAnalyze = 1
END IF

!-- Coupled Power
CalcCoupledPower = GETLOGICAL('CalcCoupledPower')

IF(CalcCoupledPower) THEN
  DisplayCoupledPower = GETLOGICAL('DisplayCoupledPower')
  DoPartAnalyze = .TRUE.
  PCouplAverage = 0.0
#if !((PP_TimeDiscMethod==500) || (PP_TimeDiscMethod==501) || (PP_TimeDiscMethod==502) || (PP_TimeDiscMethod==506) || (PP_TimeDiscMethod==508) || (PP_TimeDiscMethod==509))
  CALL abort(__STAMP__,&
      'ERROR: CalcCoupledPower is not implemented yet with the chosen time discretization method!')
#endif
  ! Allocate type array for all ranks
  ALLOCATE(PCouplSpec(1:nSpecies))
  DO iSpec = 1, nSpecies
    IF(ABS(Species(iSpec)%ChargeIC).GT.0.0)THEN
      ALLOCATE(PCouplSpec(iSpec)%DensityAvgElem(1:PP_nElems))
      PCouplSpec(iSpec)%DensityAvgElem = 0.
      WRITE(UNIT=hilf,FMT='(I0.3)') iSpec
      CALL AddToElemData(ElementOut,'Spec'//TRIM(hilf)//'_PCouplDensityAvgElem',RealArray=PCouplSpec(iSpec)%DensityAvgElem)
    END IF ! ABS(Species(iSpec)%ChargeIC).GT.0.0
  END DO ! iSpec = 1, nSpecies
END IF

!-- PartBalance
! compute number of entering and leaving particles and their energy
CalcPartBalance = GETLOGICAL('CalcPartBalance','.FALSE.')
IF (CalcPartBalance) THEN
  DoPartAnalyze = .TRUE.
  ALLOCATE( nPartIn(1:nSpecAnalyze)     &
          , nPartOut(1:nSpecAnalyze)    &
          , PartEkinOut(1:nSpecAnalyze) &
          , PartEkinIn(1:nSpecAnalyze)  )
  nPartIn=0
  nPartOut=0
  PartEkinOut=0.
  PartEkinIn=0.
END IF
TrackParticlePosition = GETLOGICAL('Part-TrackPosition','.FALSE.')
IF(TrackParticlePosition)THEN
  IF(PDM%ParticleVecLength.GT.1)THEN
  CALL abort(&
      __STAMP__&
      ,'Part-TrackPosition=T is currently not supported in combination with more than 1 particle!')
  END IF
  printDiff=GETLOGICAL('printDiff','.FALSE.')
  IF(printDiff)THEN
    printDiffTime=GETREAL('printDiffTime','12.')
    printDiffVec=GETREALARRAY('printDiffVec',6,'0.,0.,0.,0.,0.,0.')
  END IF
END IF
CalcSimNumSpec = GETLOGICAL('CalcNumSpec','.FALSE.')
CalcNumDens    = GETLOGICAL('CalcNumDens','.FALSE.')
CalcAdaptiveBCInfo = GETLOGICAL('CalcAdaptiveBCInfo')
IF(CalcAdaptiveBCInfo) THEN
  ALLOCATE(MassflowRate(1:nSpecAnalyze,1:MAXVAL(Species(:)%nSurfacefluxBCs)))
  MassflowRate = 0.
  ALLOCATE(PressureAdaptiveBC(1:nSpecAnalyze,1:MAXVAL(Species(:)%nSurfacefluxBCs)))
  PressureAdaptiveBC = 0.
END IF
CalcCollRates = GETLOGICAL('CalcCollRates','.FALSE.')
CalcReacRates = GETLOGICAL('CalcReacRates','.FALSE.')
CalcRelaxProb = GETLOGICAL('CalcRelaxProb','.FALSE.')
IF(CalcRelaxProb.AND.(Collismode.LE.1)) THEN
  CALL abort(&
    __STAMP__&
    ,'CollisMode has to be greater than 1 to calculate variable relaxation probabilities in PartAnalyze.csv')
END IF


IF(CalcReacRates) THEN
  IF(usevMPF.OR.RadialWeighting%DoRadialWeighting.OR.VarTimeStep%UseVariableTimeStep) THEN
    CALL abort(&
      __STAMP__&
      ,'ERROR: CalcReacRates is not supported with radial weighting or variable time step yet!')
  END IF
END IF

IF(CalcSimNumSpec.OR.CalcNumDens.OR.CalcCollRates.OR.CalcReacRates.OR.CalcAdaptiveBCInfo.OR.CalcRelaxProb) DoPartAnalyze = .TRUE.

!-- Compute transversal or thermal velocity of whole computational domain
CalcVelos = GETLOGICAL('CalcVelos','.FALSE')
IF (CalcVelos) THEN
  IF(RadialWeighting%DoRadialWeighting.OR.VarTimeStep%UseVariableTimeStep) THEN
    CALL abort(&
      __STAMP__&
      ,'ERROR: CalcVelos is not supported with radial weighting or variable time step yet!')
  END IF
  DoPartAnalyze=.TRUE.
  VeloDirs_hilf = GetIntArray('VelocityDirections',4,'1,1,1,1') ! x,y,z,abs -> 0/1 = T/F
  VeloDirs(:) = .FALSE.
  IF(.NOT.CalcSimNumSpec)THEN
    SWRITE(UNIT_stdOut,'(A)') ' Velocity computation requires NumSpec and SimNumSpec. Setting CalcSimNumSpec=.TRUE.'
    CalcSimNumSpec = .TRUE.
  END IF
  DO dir = 1,4
    IF (VeloDirs_hilf(dir) .EQ. 1) THEN
      VeloDirs(dir) = .TRUE.
    END IF
  END DO
  IF ((.NOT. VeloDirs(1)) .AND. (.NOT. VeloDirs(2)) .AND. &
      (.NOT. VeloDirs(3)) .AND. (.NOT. VeloDirs(4))) THEN
    CALL abort(&
      __STAMP__&
      ,'No VelocityDirections set in CalcVelos!')
  END IF
END IF

!-- Shape function efficiency
CalcShapeEfficiency = GETLOGICAL('CalcShapeEfficiency','.FALSE.')
IF (CalcShapeEfficiency) THEN
  DoPartAnalyze = .TRUE.
  CalcShapeEfficiencyMethod = GETSTR('CalcShapeEfficiencyMethod','AllParts')
  SELECT CASE(CalcShapeEfficiencyMethod)
  CASE('AllParts')  ! All currently available Particles are used
  CASE('SomeParts') ! A certain percentage of currently available Particles is used
    ShapeEfficiencyNumber = GETINT('ShapeEfficiencyNumber','100')  ! in percent
  CASE DEFAULT
    CALL abort(&
        __STAMP__&
        , ' CalcShapeEfficiencyMethod not implemented: ')
  END SELECT
END IF

!-- check if total energy should be computed
IF(DoPartAnalyze)THEN
  CalcEtot = GETLOGICAL('CalcTotalEnergy','.FALSE.')
END IF
IsRestart = GETLOGICAL('IsRestart','.FALSE.')

#if USE_HDG
!-- Check variable ref. electron temperature for BR electron model
IF(CalcBRVariableElectronTemp) DoPartAnalyze=.TRUE.
CALL PrintOption('CalcBRVariableElectronTemp','INFO',LogOpt=CalcBRVariableElectronTemp)
#endif /*USE_HDG*/

ParticleAnalyzeInitIsDone=.TRUE.

SWRITE(UNIT_stdOut,'(A)')' INIT PARTCILE ANALYZE DONE!'
SWRITE(UNIT_StdOut,'(132("-"))')

END SUBROUTINE InitParticleAnalyze


SUBROUTINE AnalyzeParticles(Time)
!===================================================================================================================================
! Initializes variables necessary for analyse subroutines
! MPI-INFO:
! important change: all MPI-communication is done directly in the corresponding subroutines
! a) its easier and cleaner
! b) reduces the probability of errors (routines are again fixed for MPI...)
! The decision if an analysis is performed is done in PerformAnalysis.
! Furthermore:
! Each separate outputfile handler is called from within PerformAnalysis
!===================================================================================================================================
! MODULES
USE MOD_Globals
USE MOD_Preproc
USE MOD_Analyze_Vars            ,ONLY: CalcEpot,Wel,Wmag,Wphi,Wpsi
USE MOD_BGK_Vars                ,ONLY: BGK_MaxRelaxFactor,BGK_MaxRotRelaxFactor,BGK_MeanRelaxFactor,BGK_MeanRelaxFactorCounter
USE MOD_BGK_Vars                ,ONLY: BGKInitDone
USE MOD_DSMC_Vars               ,ONLY: CollInf, useDSMC, CollisMode, ChemReac
USE MOD_DSMC_Vars               ,ONLY: DSMC
USE MOD_FPFlow_Vars             ,ONLY: FP_MaxRelaxFactor,FP_MaxRotRelaxFactor,FP_MeanRelaxFactor,FP_MeanRelaxFactorCounter
USE MOD_FPFlow_Vars             ,ONLY: FP_PrandtlNumber,FPInitDone
USE MOD_Particle_Analyze_Vars
USE MOD_Particle_MPI_Vars       ,ONLY: PartMPI
USE MOD_Particle_Vars           ,ONLY: Species,nSpecies
USE MOD_PIC_Analyze             ,ONLY: CalcDepositedCharge
USE MOD_Restart_Vars            ,ONLY: RestartTime,DoRestart
USE MOD_TimeDisc_Vars           ,ONLY: iter, dt, IterDisplayStep
USE MOD_Particle_Analyze_Tools  ,ONLY: CalcNumPartsOfSpec,CalcShapeEfficiencyR,CalcKineticEnergy,CalcKineticEnergyAndMaximum
USE MOD_Particle_Analyze_Tools  ,ONLY: CalcNumberDensity,CalcAdaptBCInfo,CalcTemperature,CalcVelocities
USE MOD_Particle_Analyze_Output ,ONLY: DisplayCoupledPowerPart
#if (PP_TimeDiscMethod==2 || PP_TimeDiscMethod==4 || PP_TimeDiscMethod==42 || PP_TimeDiscMethod==300 || PP_TimeDiscMethod==400 || (PP_TimeDiscMethod>=501 && PP_TimeDiscMethod<=509))
USE MOD_Particle_Mesh_Vars      ,ONLY: MeshVolume
USE MOD_DSMC_Analyze            ,ONLY: CalcMeanFreePath
USE MOD_DSMC_Vars               ,ONLY: BGGas
USE MOD_Particle_Analyze_Tools  ,ONLY: CalcRelaxProbRotVib
#endif
#if (PP_TimeDiscMethod==42)
USE MOD_DSMC_Vars               ,ONLY: SpecDSMC, XSec_Relaxation, SpecXSec
USE MOD_Particle_Analyze_Tools  ,ONLY: CollRates,CalcRelaxRates,ReacRates
#endif
#if USE_HDG
USE MOD_HDG_Vars               ,ONLY: BRNbrOfRegions,CalcBRVariableElectronTemp,RegionElectronRef
USE MOD_Globals_Vars           ,ONLY: BoltzmannConst,ElementaryCharge
#endif /*USE_HDG*/
! IMPLICIT VARIABLE HANDLING
IMPLICIT NONE
!-----------------------------------------------------------------------------------------------------------------------------------
! INPUT VARIABLES
REAL,INTENT(IN)                 :: Time
!-----------------------------------------------------------------------------------------------------------------------------------
! OUTPUT VARIABLES
!-----------------------------------------------------------------------------------------------------------------------------------
! LOCAL VARIABLES
LOGICAL             :: isOpen
CHARACTER(LEN=350)  :: outfile
INTEGER             :: unit_index, iSpec, OutputCounter, iSF
INTEGER(KIND=IK)    :: SimNumSpec(nSpecAnalyze)
REAL                :: NumSpec(nSpecAnalyze), NumDens(nSpecAnalyze)
REAL                :: Ekin(nSpecAnalyze), Temp(nSpecAnalyze)
REAL                :: EkinMax(nSpecies)
REAL                :: IntEn(nSpecAnalyze,3),IntTemp(nSpecies,3),TempTotal(nSpecAnalyze), Xi_Vib(nSpecies), Xi_Elec(nSpecies)
REAL                :: ETotal
#if (PP_TimeDiscMethod==2 || PP_TimeDiscMethod==4 || PP_TimeDiscMethod==42 || PP_TimeDiscMethod==300 || PP_TimeDiscMethod==400 || (PP_TimeDiscMethod>=501 && PP_TimeDiscMethod<=509))
REAL                :: MaxCollProb, MeanCollProb, MeanFreePath
REAL                :: NumSpecTmp(nSpecAnalyze), RotRelaxProb(2), VibRelaxProb(2)
#endif
#if (PP_TimeDiscMethod==42)
INTEGER             :: jSpec, iCase
#endif
#if USE_MPI
#if (PP_TimeDiscMethod==2 || PP_TimeDiscMethod==4 || PP_TimeDiscMethod==42 || PP_TimeDiscMethod==300||(PP_TimeDiscMethod>=501 && PP_TimeDiscMethod<=509))
REAL                :: sumMeanCollProb
#endif
#endif /*USE_MPI*/
REAL, ALLOCATABLE   :: CRate(:), RRate(:), VibRelaxRate(:)
#if (PP_TimeDiscMethod ==42)
#ifdef CODE_ANALYZE
CHARACTER(LEN=64)   :: DebugElectronicStateFilename
INTEGER             :: ii, iunit
#endif
#endif
REAL                :: PartVtrans(nSpecies,4) ! macroscopic velocity (drift velocity) A. Frohn: kinetische Gastheorie
REAL                :: PartVtherm(nSpecies,4) ! microscopic velocity (eigen velocity) PartVtrans + PartVtherm = PartVtotal
INTEGER             :: dir
#if USE_HDG
INTEGER             :: iRegions
#endif /*USE_HDG*/
!===================================================================================================================================
  IF ( DoRestart ) THEN
    isRestart = .true.
  END IF
  IF (.NOT.DoPartAnalyze) RETURN
  IF (useDSMC) THEN
    IF (CollisMode.NE.0) THEN
      SDEALLOCATE(CRate)
      ALLOCATE(CRate(CollInf%NumCase + 1))
      CRate = 0.0
      IF(CalcRelaxProb) THEN
        ALLOCATE(VibRelaxRate(CollInf%NumCase))
        VibRelaxRate = 0.0
      END IF
      IF (CollisMode.EQ.3) THEN
        SDEALLOCATE(RRate)
        ALLOCATE(RRate(ChemReac%NumOfReact))
        RRate = 0.0
      END IF
    END IF
  END IF
  OutputCounter = 2
  unit_index = 535
  IF (PartMPI%MPIRoot) THEN
    INQUIRE(UNIT   = unit_index , OPENED = isOpen)
    IF (.NOT.isOpen) THEN
      outfile = 'PartAnalyze.csv'
      IF (isRestart .and. FILEEXISTS(outfile)) THEN
        OPEN(unit_index,file=TRIM(outfile),position="APPEND",status="OLD")
        !CALL FLUSH (unit_index)
      ELSE
        OPEN(unit_index,file=TRIM(outfile))
        !CALL FLUSH (unit_index)
        !--- insert header
        WRITE(unit_index,'(A8)',ADVANCE='NO') '001-TIME'
        IF (CalcSimNumSpec) THEN
          DO iSpec = 1, nSpecAnalyze
            WRITE(unit_index,'(A1)',ADVANCE='NO') ','
            WRITE(unit_index,'(I3.3,A12,I3.3)',ADVANCE='NO') OutputCounter,'-nPart-Spec-', iSpec
            OutputCounter = OutputCounter + 1
          END DO
        END IF
        IF (CalcNumDens) THEN
          DO iSpec = 1, nSpecAnalyze
            WRITE(unit_index,'(A1)',ADVANCE='NO') ','
            WRITE(unit_index,'(I3.3,A14,I3.3)',ADVANCE='NO') OutputCounter,'-NumDens-Spec-', iSpec
            OutputCounter = OutputCounter + 1
          END DO
        END IF
        IF(CalcAdaptiveBCInfo) THEN
          DO iSpec = 1, nSpecAnalyze
            DO iSF = 1, Species(iSpec)%nSurfacefluxBCs
              WRITE(unit_index,'(A1)',ADVANCE='NO') ','
              WRITE(unit_index,'(I3.3,A15,I3.3,A4,I3.3)',ADVANCE='NO') OutputCounter,'-Massflow-Spec-',iSpec,'-SF-',iSF
              OutputCounter = OutputCounter + 1
              WRITE(unit_index,'(A1)',ADVANCE='NO') ','
              WRITE(unit_index,'(I3.3,A15,I3.3,A4,I3.3)',ADVANCE='NO') OutputCounter,'-Pressure-Spec-',iSpec,'-SF-',iSF
              OutputCounter = OutputCounter + 1
            END DO
          END DO
        END IF
        IF (CalcCharge) THEN
          WRITE(unit_index,'(A1)',ADVANCE='NO') ','
          WRITE(unit_index,'(I3.3,A7)',ADVANCE='NO') OutputCounter,'-Charge'
          OutputCounter = OutputCounter + 1
          WRITE(unit_index,'(A1)',ADVANCE='NO') ','
          WRITE(unit_index,'(I3.3,A16)',ADVANCE='NO') OutputCounter,'-Charge-absError'
          OutputCounter = OutputCounter + 1
          WRITE(unit_index,'(A1)',ADVANCE='NO') ','
          WRITE(unit_index,'(I3.3,A16)',ADVANCE='NO') OutputCounter,'-Charge-relError'
          OutputCounter = OutputCounter + 1
        END IF
        IF (CalcPartBalance) THEN ! calculate particle power balance with input and outflow energy of species
          DO iSpec=1, nSpecAnalyze
            WRITE(unit_index,'(A1)',ADVANCE='NO') ','
            WRITE(unit_index,'(I3.3,A14,I3.3)',ADVANCE='NO') OutputCounter,'-nPartIn-Spec-',iSpec
            OutputCounter = OutputCounter + 1
          END DO
          DO iSpec=1, nSpecAnalyze
            WRITE(unit_index,'(A1)',ADVANCE='NO') ','
            WRITE(unit_index,'(I3.3,A15,I3.3)',ADVANCE='NO') OutputCounter,'-nPartOut-Spec-',iSpec
            OutputCounter = OutputCounter + 1
          END DO
        END IF
        IF (CalcEkin) THEN ! calculate kinetic energy
          DO iSpec=1, nSpecAnalyze
            WRITE(unit_index,'(A1)',ADVANCE='NO') ','
            WRITE(unit_index,'(I3.3,A,I3.3)',ADVANCE='NO') OutputCounter,'-Ekin-',iSpec
            OutputCounter = OutputCounter + 1
          END DO
        END IF
        IF (CalcCoupledPower) THEN
          WRITE(unit_index,'(A1)',ADVANCE='NO') ','
          WRITE(unit_index,'(I3.3,A)',ADVANCE='NO') OutputCounter,'-PCoupled'
          OutputCounter = OutputCounter + 1
          WRITE(unit_index,'(A1)',ADVANCE='NO') ','
          WRITE(unit_index,'(I3.3,A)',ADVANCE='NO') OutputCounter,'-PCoupledMoAv'
          OutputCounter = OutputCounter + 1
        END IF
        IF (CalcLaserInteraction) THEN ! computer laser-plasma interaction
          DO iSpec=1, nSpecies
            WRITE(unit_index,'(A1)',ADVANCE='NO') ','
            WRITE(unit_index,'(I3.3,A,I3.3)',ADVANCE='NO') OutputCounter,'-EkinMax-eV-',iSpec
            OutputCounter = OutputCounter + 1
          END DO
        END IF
        IF(CalcEkin .AND. CalcEpot .AND. CalcEtot) THEN ! calculate kinetic, potential and total energy
          WRITE(unit_index,'(A1)',ADVANCE='NO') ','
          WRITE(unit_index,'(I3.3,A)',ADVANCE='NO') OutputCounter,'-E-kin+pot'
          OutputCounter = OutputCounter + 1
        END IF
        IF (CalcTemp) THEN ! calculate translational temperature
          DO iSpec=1, nSpecAnalyze
            WRITE(unit_index,'(A1)',ADVANCE='NO') ','
            WRITE(unit_index,'(I3.3,A,I3.3)',ADVANCE='NO') OutputCounter,'-TempTra-',iSpec
            OutputCounter = OutputCounter + 1
          END DO
        END IF
        IF (CalcVelos) THEN ! calculate flow and thermal velocities
          DO iSpec=1, nSpecies
            IF (VeloDirs(1)) THEN
              WRITE(unit_index,'(A1)',ADVANCE='NO') ','
              WRITE(unit_index,'(I3.3,A,I3.3)',ADVANCE='NO') OutputCounter,'-Velo_Xtrans',iSpec
              OutputCounter = OutputCounter + 1
              WRITE(unit_index,'(A1)',ADVANCE='NO') ','
              WRITE(unit_index,'(I3.3,A,I3.3)',ADVANCE='NO') OutputCounter,'-Velo_Xtherm',iSpec
              OutputCounter = OutputCounter + 1
            END IF
            IF (VeloDirs(2)) THEN
              WRITE(unit_index,'(A1)',ADVANCE='NO') ','
              WRITE(unit_index,'(I3.3,A,I3.3)',ADVANCE='NO') OutputCounter,'-Velo_Ytrans',iSpec
              OutputCounter = OutputCounter + 1
              WRITE(unit_index,'(A1)',ADVANCE='NO') ','
              WRITE(unit_index,'(I3.3,A,I3.3)',ADVANCE='NO') OutputCounter,'-Velo_Ytherm',iSpec
              OutputCounter = OutputCounter + 1
            END IF
            IF (VeloDirs(3)) THEN
              WRITE(unit_index,'(A1)',ADVANCE='NO') ','
              WRITE(unit_index,'(I3.3,A,I3.3)',ADVANCE='NO') OutputCounter,'-Velo_Ztrans',iSpec
              OutputCounter = OutputCounter + 1
              WRITE(unit_index,'(A1)',ADVANCE='NO') ','
              WRITE(unit_index,'(I3.3,A,I3.3)',ADVANCE='NO') OutputCounter,'-Velo_Ztherm',iSpec
              OutputCounter = OutputCounter + 1
            END IF
            IF (VeloDirs(4)) THEN
              WRITE(unit_index,'(A1)',ADVANCE='NO') ','
              WRITE(unit_index,'(I3.3,A,I3.3)',ADVANCE='NO') OutputCounter,'-AbsVelo_trans',iSpec
              OutputCounter = OutputCounter + 1
              WRITE(unit_index,'(A1)',ADVANCE='NO') ','
              WRITE(unit_index,'(I3.3,A,I3.3)',ADVANCE='NO') OutputCounter,'-AbsVelo_therm',iSpec
              OutputCounter = OutputCounter + 1
            END IF
          END DO
        END IF
        IF (CalcPartBalance) THEN ! calculate particle power balance with input and outflow energy of all particles
          DO iSpec=1, nSpecAnalyze
            WRITE(unit_index,'(A1)',ADVANCE='NO') ','
            WRITE(unit_index,'(I3.3,A8,I3.3)',ADVANCE='NO') OutputCounter,'-EkinIn-',iSpec
            OutputCounter = OutputCounter + 1
          END DO
          DO iSpec=1, nSpecAnalyze
            WRITE(unit_index,'(A1)',ADVANCE='NO') ','
            WRITE(unit_index,'(I3.3,A9,I3.3)',ADVANCE='NO') OutputCounter,'-EkinOut-',iSpec
            OutputCounter = OutputCounter + 1
          END DO
        END IF
#if (PP_TimeDiscMethod==2 || PP_TimeDiscMethod==4 || PP_TimeDiscMethod==42 || PP_TimeDiscMethod==300 || PP_TimeDiscMethod==400 || (PP_TimeDiscMethod>=501 && PP_TimeDiscMethod<=509))
        IF (CollisMode.GT.1) THEN
          IF(CalcEint) THEN
            DO iSpec=1, nSpecAnalyze
              WRITE(unit_index,'(A1)',ADVANCE='NO') ','
              WRITE(unit_index,'(I3.3,A,I3.3)',ADVANCE='NO') OutputCounter,'-E-Vib',iSpec
              OutputCounter = OutputCounter + 1
            END DO
            DO iSpec=1, nSpecAnalyze
              WRITE(unit_index,'(A1)',ADVANCE='NO') ','
              WRITE(unit_index,'(I3.3,A,I3.3)',ADVANCE='NO') OutputCounter,'-E-Rot',iSpec
              OutputCounter = OutputCounter + 1
            END DO
            IF (DSMC%ElectronicModel.GT.0) THEN
              DO iSpec = 1, nSpecAnalyze
                WRITE(unit_index,'(A1)',ADVANCE='NO') ','
                WRITE(unit_index,'(I3.3,A,I3.3)',ADVANCE='NO') OutputCounter,'-E-Elec',iSpec
                OutputCounter = OutputCounter + 1
              END DO
            END IF
            WRITE(unit_index,'(A1)',ADVANCE='NO') ','
            WRITE(unit_index,'(I3.3,A)',ADVANCE='NO') OutputCounter,'-E-TotalPart'
            OutputCounter = OutputCounter + 1
          END IF
          IF(CalcEpot .AND. CalcEtot .AND. CalcEint)THEN
            WRITE(unit_index,'(A1)',ADVANCE='NO') ','
            WRITE(unit_index,'(I3.3,A)',ADVANCE='NO') OutputCounter,'-E-Tot'
            OutputCounter = OutputCounter + 1
          END IF
          IF(CalcTemp) THEN
            DO iSpec=1, nSpecies
              WRITE(unit_index,'(A1)',ADVANCE='NO') ','
              WRITE(unit_index,'(I3.3,A,I3.3)',ADVANCE='NO') OutputCounter,'-TempVib',iSpec
              OutputCounter = OutputCounter + 1
            END DO
            DO iSpec=1, nSpecies
              WRITE(unit_index,'(A1)',ADVANCE='NO') ','
              WRITE(unit_index,'(I3.3,A,I3.3)',ADVANCE='NO') OutputCounter,'-XiVibMean',iSpec
              OutputCounter = OutputCounter + 1
            END DO
            DO iSpec=1, nSpecies
              WRITE(unit_index,'(A1)',ADVANCE='NO') ','
              WRITE(unit_index,'(I3.3,A,I3.3)',ADVANCE='NO') OutputCounter,'-TempRot',iSpec
              OutputCounter = OutputCounter + 1
            END DO
            IF (DSMC%ElectronicModel.GT.0) THEN
              DO iSpec=1, nSpecies
                WRITE(unit_index,'(A1)',ADVANCE='NO') ','
                WRITE(unit_index,'(I3.3,A,I3.3)',ADVANCE='NO') OutputCounter,'-TempElec',iSpec
                OutputCounter = OutputCounter + 1
              END DO
              DO iSpec=1, nSpecies
                WRITE(unit_index,'(A1)',ADVANCE='NO') ','
                WRITE(unit_index,'(I3.3,A,I3.3)',ADVANCE='NO') OutputCounter,'-XiElecMean',iSpec
                OutputCounter = OutputCounter + 1
              END DO
            END IF
            DO iSpec=1, nSpecAnalyze
              WRITE(unit_index,'(A1)',ADVANCE='NO') ','
              WRITE(unit_index,'(I3.3,A,I3.3)',ADVANCE='NO') OutputCounter,'-TempTotal',iSpec
              OutputCounter = OutputCounter + 1
            END DO
          END IF
        END IF
        IF(DSMC%CalcQualityFactors) THEN ! calculates flow-field variable maximum collision probability, time-averaged mean
                                         ! collision probability, mean collision separation distance over mean free path
          WRITE(unit_index,'(A1)',ADVANCE='NO') ','
          WRITE(unit_index,'(I3.3,A)',ADVANCE='NO') OutputCounter,'-Pmean'
          OutputCounter = OutputCounter + 1
          WRITE(unit_index,'(A1)',ADVANCE='NO') ','
          WRITE(unit_index,'(I3.3,A)',ADVANCE='NO') OutputCounter,'-Pmax'
          OutputCounter = OutputCounter + 1
          WRITE(unit_index,'(A1)',ADVANCE='NO') ','
          WRITE(unit_index,'(I3.3,A)',ADVANCE='NO') OutputCounter,'-MeanFreePath'
          OutputCounter = OutputCounter + 1
          IF(CalcRelaxProb) THEN
            WRITE(unit_index,'(A1)',ADVANCE='NO') ','
            WRITE(unit_index,'(I3.3,A)',ADVANCE='NO') OutputCounter,'-RotRelaxPmean'
            OutputCounter = OutputCounter + 1
            WRITE(unit_index,'(A1)',ADVANCE='NO') ','
            WRITE(unit_index,'(I3.3,A)',ADVANCE='NO') OutputCounter,'-RotRelaxPmax'
            OutputCounter = OutputCounter + 1
            WRITE(unit_index,'(A1)',ADVANCE='NO') ','
            WRITE(unit_index,'(I3.3,A)',ADVANCE='NO') OutputCounter,'-VibRelaxPmean'
            OutputCounter = OutputCounter + 1
            WRITE(unit_index,'(A1)',ADVANCE='NO') ','
            WRITE(unit_index,'(I3.3,A)',ADVANCE='NO') OutputCounter,'-VibRelaxPmax'
            OutputCounter = OutputCounter + 1
          END IF
        END IF
#endif
        IF(FPInitDone) THEN ! Fokker Planck
          IF(DSMC%CalcQualityFactors) THEN
            WRITE(unit_index,'(A1)',ADVANCE='NO') ','
            WRITE(unit_index,'(I3.3,A)',ADVANCE='NO') OutputCounter,'-FP-MeanRelaxFactor'
            OutputCounter = OutputCounter + 1
            WRITE(unit_index,'(A1)',ADVANCE='NO') ','
            WRITE(unit_index,'(I3.3,A)',ADVANCE='NO') OutputCounter,'-FP-MaxRelaxFactor'
            OutputCounter = OutputCounter + 1
            WRITE(unit_index,'(A1)',ADVANCE='NO') ','
            WRITE(unit_index,'(I3.3,A)',ADVANCE='NO') OutputCounter,'-FP-MaxRotRelaxFactor'
            OutputCounter = OutputCounter + 1
            WRITE(unit_index,'(A1)',ADVANCE='NO') ','
            WRITE(unit_index,'(I3.3,A)',ADVANCE='NO') OutputCounter,'-FP-MeanPrandtlNumber'
            OutputCounter = OutputCounter + 1
          END IF
        END IF
        IF(BGKInitDone) THEN ! Bhatnagar Gross Krook
          IF(DSMC%CalcQualityFactors) THEN
            WRITE(unit_index,'(A1)',ADVANCE='NO') ','
            WRITE(unit_index,'(I3.3,A)',ADVANCE='NO') OutputCounter,'-BGK-MeanRelaxFactor'
            OutputCounter = OutputCounter + 1
            WRITE(unit_index,'(A1)',ADVANCE='NO') ','
            WRITE(unit_index,'(I3.3,A)',ADVANCE='NO') OutputCounter,'-BGK-MaxRelaxFactor'
            OutputCounter = OutputCounter + 1
            WRITE(unit_index,'(A1)',ADVANCE='NO') ','
            WRITE(unit_index,'(I3.3,A)',ADVANCE='NO') OutputCounter,'-BGK-MaxRotRelaxFactor'
            OutputCounter = OutputCounter + 1
          END IF
        END IF
#if (PP_TimeDiscMethod==42)
        IF(CalcCollRates) THEN ! calculates collision rates per collision pair
          DO iSpec = 1, nSpecies
            DO jSpec = iSpec, nSpecies
              WRITE(unit_index,'(A1)',ADVANCE='NO') ','
              WRITE(unit_index,'(I3.3,A,I3.3,A,I3.3)',ADVANCE='NO') OutputCounter,'-CollRate', iSpec, '+', jSpec
              OutputCounter = OutputCounter + 1
            END DO
          END DO
          WRITE(unit_index,'(A1)',ADVANCE='NO') ','
          WRITE(unit_index,'(I3.3,A)',ADVANCE='NO') OutputCounter,'-TotalCollRate'
          OutputCounter = OutputCounter + 1
        END IF
        IF(CalcRelaxProb) THEN
          IF(XSec_Relaxation) THEN
            DO iSpec = 1, nSpecies
              DO jSpec = iSpec, nSpecies
                IF(SpecXSec(CollInf%Coll_Case(iSpec,jSpec))%UseVibXSec) THEN
                  ! Skip entry if both species are NOT molecules
                  IF(((SpecDSMC(iSpec)%InterID.NE.2).AND.(SpecDSMC(iSpec)%InterID.NE.20)).AND. &
                    ((SpecDSMC(jSpec)%InterID.NE.2).AND.(SpecDSMC(jSpec)%InterID.NE.20))) CYCLE
                  WRITE(unit_index,'(A1)',ADVANCE='NO') ','
                  WRITE(unit_index,'(I3.3,A,I3.3,A,I3.3)',ADVANCE='NO') OutputCounter,'-VibRelaxRate', iSpec, '+', jSpec
                  OutputCounter = OutputCounter + 1
                END IF
              END DO
            END DO
          END IF
        END IF
        IF(CalcReacRates) THEN ! calculates reaction rate per reaction
          IF(CollisMode.EQ.3) THEN
            DO iCase=1, ChemReac%NumOfReact
              WRITE(unit_index,'(A1)',ADVANCE='NO') ','
              WRITE(unit_index,'(I3.3,A,I3.3)',ADVANCE='NO') OutputCounter,'-Reaction', iCase
              OutputCounter = OutputCounter + 1
            END DO
          END IF
        END IF
#endif
#if USE_HDG
        IF(CalcBRVariableElectronTemp)THEN ! variable reference electron temperature
          DO iRegions=1,BRNbrOfRegions
            WRITE(unit_index,'(A1)',ADVANCE='NO') ','
            WRITE(unit_index,'(I3.3,A,I3.3)',ADVANCE='NO') OutputCounter,'-RegionElectronRef', iRegions
            OutputCounter = OutputCounter + 1
          END DO
        END IF ! CalcBRVariableElectronTemp
#endif /*USE_HDG*/
        WRITE(unit_index,'(A)') ''
      END IF
    END IF
  END IF

!===================================================================================================================================
! Analyze Routines
!===================================================================================================================================
  ! computes the real and simulated number of particles
  CALL CalcNumPartsOfSpec(NumSpec,SimNumSpec,.TRUE.,CalcSimNumSpec)
  IF(CalcNumDens) CALL CalcNumberDensity(NumSpec,NumDens)
  ! Determine the mass flux [kg/s] and pressure [Pa] per species and surface flux (includes MPI communication)
  IF(CalcAdaptiveBCInfo) CALL CalcAdaptBCInfo()
!-----------------------------------------------------------------------------------------------------------------------------------
! Calculate total temperature of each molecular species (Laux, p. 109)
  IF(CalcEkin.OR.CalcEint)THEN
    IF(CalcLaserInteraction)THEN
      CALL CalcKineticEnergyAndMaximum(Ekin,EkinMax)
#if USE_MPI
      IF(PartMPI%MPIRoot)THEN
        CALL MPI_REDUCE(MPI_IN_PLACE , EkinMax , nSpecies     , MPI_DOUBLE_PRECISION , MPI_MAX , 0 , PartMPI%COMM , iError)
      ELSE
        CALL MPI_REDUCE(EkinMax      , 0.      , nSpecies     , MPI_DOUBLE_PRECISION , MPI_MAX , 0 , PartMPI%COMM , iError)
      END IF
#endif /*USE_MPI*/
    ELSE
      CALL CalcKineticEnergy(Ekin)
    END IF
#if USE_MPI
      IF(PartMPI%MPIRoot)THEN
        CALL MPI_REDUCE(MPI_IN_PLACE , Ekin    , nSpecAnalyze , MPI_DOUBLE_PRECISION , MPI_SUM , 0 , PartMPI%COMM , IERROR)
      ELSE
        CALL MPI_REDUCE(Ekin         , 0.      , nSpecAnalyze , MPI_DOUBLE_PRECISION , MPI_SUM , 0 , PartMPI%COMM , IERROR)
      END IF
#endif /*USE_MPI*/
  END IF
  IF(CalcTemp.OR.CalcEint.OR.DSMC%CalcQualityFactors) THEN
    CALL CalcTemperature(NumSpec,Temp,IntTemp,IntEn,TempTotal,Xi_Vib,Xi_Elec) ! contains MPI Communication
    IF(CalcEint.AND.(CollisMode.GT.1)) THEN
      ETotal = Ekin(nSpecAnalyze) + IntEn(nSpecAnalyze,1) + IntEn(nSpecAnalyze,2) + IntEn(nSpecAnalyze,3)
    END IF
  END IF
!-----------------------------------------------------------------------------------------------------------------------------------
! Determine the maximal collision probability for whole reservoir and mean collision probability (only for one cell)
#if (PP_TimeDiscMethod==2 || PP_TimeDiscMethod==4 || PP_TimeDiscMethod==42 || PP_TimeDiscMethod==300 || PP_TimeDiscMethod==400 || (PP_TimeDiscMethod>=501 && PP_TimeDiscMethod<=509))
  MaxCollProb = 0.0
  MeanCollProb = 0.0
  MeanFreePath = 0.0
  IF(DSMC%CalcQualityFactors.OR.CalcReacRates) THEN
    NumSpecTmp = NumSpec
    IF(BGGas%NumberOfSpecies.GT.0) THEN
      ! Calculation of mean free path and reactions rates requires the number of particles the background species would have if
      ! actually inserted at the chosen weighting factor, determined here and used later also for the ReacRates subroutine
      DO iSpec = 1, nSpecies
        IF(BGGas%BackgroundSpecies(iSpec)) THEN
          NumSpecTmp(iSpec) = BGGas%NumberDensity(BGGas%MapSpecToBGSpec(iSpec))*MeshVolume/Species(iSpec)%MacroParticleFactor
          IF(nSpecAnalyze.GT.1) THEN
            NumSpecTmp(nSpecAnalyze) = NumSpecTmp(nSpecAnalyze) + NumSpecTmp(iSpec)
          END IF
        END IF
      END DO
    END IF
  END IF
  IF(DSMC%CalcQualityFactors) THEN
    IF(iter.GT.0) THEN
      MaxCollProb = DSMC%CollProbMax
      IF(DSMC%CollProbMeanCount.GT.0) MeanCollProb = DSMC%CollProbMean / DSMC%CollProbMeanCount
      IF (PartMPI%MPIRoot) THEN
        IF(TempTotal(nSpecAnalyze).GT.0.0) MeanFreePath = CalcMeanFreePath(NumSpecTmp(1:nSpecies), NumSpecTmp(nSpecAnalyze), &
                                                              MeshVolume, TempTotal(nSpecAnalyze))
      END IF
    END IF
    IF(CalcRelaxProb) CALL CalcRelaxProbRotVib(RotRelaxProb,VibRelaxProb)
  END IF
#endif
!-----------------------------------------------------------------------------------------------------------------------------------
! Other Analyze Routines
  IF(CalcCharge) CALL CalcDepositedCharge() ! mpi communication done in calcdepositedcharge
  ! get velocities
  IF(CalcVelos) CALL CalcVelocities(PartVtrans, PartVtherm,NumSpec,SimNumSpec)
!===================================================================================================================================
! MPI Communication for values which are not YET communicated
! All routines ABOVE contain the required MPI-Communication
!===================================================================================================================================
#if USE_MPI
  IF (PartMPI%MPIRoot) THEN
    IF (CalcPartBalance)THEN
      CALL MPI_REDUCE(MPI_IN_PLACE,nPartIn(1:nSpecAnalyze)    ,nSpecAnalyze,MPI_INTEGER         ,MPI_SUM,0,PartMPI%COMM,IERROR)
      CALL MPI_REDUCE(MPI_IN_PLACE,nPartOut(1:nSpecAnalyze)   ,nSpecAnalyze,MPI_INTEGER         ,MPI_SUM,0,PartMPI%COMM,IERROR)
      CALL MPI_REDUCE(MPI_IN_PLACE,PartEkinIn(1:nSpecAnalyze) ,nSpecAnalyze,MPI_DOUBLE_PRECISION,MPI_SUM,0,PartMPI%COMM,IERROR)
      CALL MPI_REDUCE(MPI_IN_PLACE,PartEkinOut(1:nSpecAnalyze),nSpecAnalyze,MPI_DOUBLE_PRECISION,MPI_SUM,0,PartMPI%COMM,IERROR)
    END IF
    IF(CalcCoupledPower) THEN
      CALL MPI_REDUCE(MPI_IN_PLACE,PCoupl       ,1,MPI_DOUBLE_PRECISION,MPI_SUM,0,PartMPI%COMM,IERROR)
      CALL MPI_REDUCE(MPI_IN_PLACE,PCouplAverage,1,MPI_DOUBLE_PRECISION,MPI_SUM,0,PartMPI%COMM,IERROR)
    END IF
#if (PP_TimeDiscMethod==2 || PP_TimeDiscMethod==4 || PP_TimeDiscMethod==42 || PP_TimeDiscMethod==300||(PP_TimeDiscMethod>=501 && PP_TimeDiscMethod<=509))
    IF((iter.GT.0).AND.(DSMC%CalcQualityFactors)) THEN
      ! Determining the maximal (MPI_MAX) and mean (MPI_SUM) collision probabilities
      CALL MPI_REDUCE(MPI_IN_PLACE,MaxCollProb    ,1, MPI_DOUBLE_PRECISION, MPI_MAX,0, PartMPI%COMM, IERROR)
      CALL MPI_REDUCE(MeanCollProb,sumMeanCollProb,1, MPI_DOUBLE_PRECISION, MPI_SUM,0, PartMPI%COMM, IERROR)
      MeanCollProb = sumMeanCollProb / REAL(PartMPI%nProcs)
    END IF
#endif
    IF(FPInitDone) THEN
      IF((iter.GT.0).AND.(DSMC%CalcQualityFactors)) THEN
        CALL MPI_REDUCE(MPI_IN_PLACE,FP_MeanRelaxFactor       ,1, MPI_DOUBLE_PRECISION, MPI_SUM,0, PartMPI%COMM, IERROR)
        CALL MPI_REDUCE(MPI_IN_PLACE,FP_MeanRelaxFactorCounter,1, MPI_INTEGER         , MPI_SUM,0, PartMPI%COMM, IERROR)
        CALL MPI_REDUCE(MPI_IN_PLACE,FP_PrandtlNumber         ,1, MPI_DOUBLE_PRECISION, MPI_SUM,0, PartMPI%COMM, IERROR)
        ! Determining the maximal (MPI_MAX) relaxation factors
        CALL MPI_REDUCE(MPI_IN_PLACE,FP_MaxRelaxFactor   ,1, MPI_DOUBLE_PRECISION, MPI_MAX,0, PartMPI%COMM, IERROR)
        CALL MPI_REDUCE(MPI_IN_PLACE,FP_MaxRotRelaxFactor,1, MPI_DOUBLE_PRECISION, MPI_MAX,0, PartMPI%COMM, IERROR)
      END IF
    END IF
    IF(BGKInitDone) THEN
      IF((iter.GT.0).AND.(DSMC%CalcQualityFactors)) THEN
        CALL MPI_REDUCE(MPI_IN_PLACE,BGK_MeanRelaxFactor       ,1, MPI_DOUBLE_PRECISION, MPI_SUM,0, PartMPI%COMM, IERROR)
        CALL MPI_REDUCE(MPI_IN_PLACE,BGK_MeanRelaxFactorCounter,1, MPI_INTEGER         , MPI_SUM,0, PartMPI%COMM, IERROR)
        ! Determining the maximal (MPI_MAX) relaxation factors
        CALL MPI_REDUCE(MPI_IN_PLACE,BGK_MaxRelaxFactor   ,1, MPI_DOUBLE_PRECISION, MPI_MAX,0, PartMPI%COMM, IERROR)
        CALL MPI_REDUCE(MPI_IN_PLACE,BGK_MaxRotRelaxFactor,1, MPI_DOUBLE_PRECISION, MPI_MAX,0, PartMPI%COMM, IERROR)
      END IF
    END IF
  ELSE ! no Root
    IF (CalcPartBalance)THEN
      CALL MPI_REDUCE(nPartIn    ,0,nSpecAnalyze,MPI_INTEGER         ,MPI_SUM,0,PartMPI%COMM,IERROR)
      CALL MPI_REDUCE(nPartOut   ,0,nSpecAnalyze,MPI_INTEGER         ,MPI_SUM,0,PartMPI%COMM,IERROR)
      CALL MPI_REDUCE(PartEkinIn ,0,nSpecAnalyze,MPI_DOUBLE_PRECISION,MPI_SUM,0,PartMPI%COMM,IERROR)
      CALL MPI_REDUCE(PartEkinOut,0,nSpecAnalyze,MPI_DOUBLE_PRECISION,MPI_SUM,0,PartMPI%COMM,IERROR)
    END IF
    IF(CalcCoupledPower) THEN
      CALL MPI_REDUCE(PCoupl       ,0,1,MPI_DOUBLE_PRECISION,MPI_SUM,0,PartMPI%COMM,IERROR)
      CALL MPI_REDUCE(PCouplAverage,0,1,MPI_DOUBLE_PRECISION,MPI_SUM,0,PartMPI%COMM,IERROR)
    END IF
#if (PP_TimeDiscMethod==2 || PP_TimeDiscMethod==4 || PP_TimeDiscMethod==42 || PP_TimeDiscMethod==300||(PP_TimeDiscMethod>=501 && PP_TimeDiscMethod<=509))
    IF((iter.GT.0).AND.(DSMC%CalcQualityFactors)) THEN
      CALL MPI_REDUCE(MaxCollProb ,0,1,MPI_DOUBLE_PRECISION,MPI_MAX,0, PartMPI%COMM, IERROR)
      CALL MPI_REDUCE(MeanCollProb,0,1,MPI_DOUBLE_PRECISION,MPI_SUM,0, PartMPI%COMM, IERROR)
    END IF
#endif
    IF(FPInitDone) THEN
      IF((iter.GT.0).AND.(DSMC%CalcQualityFactors)) THEN
        CALL MPI_REDUCE(FP_MeanRelaxFactor       ,0,1, MPI_DOUBLE_PRECISION, MPI_SUM,0, PartMPI%COMM, IERROR)
        CALL MPI_REDUCE(FP_MeanRelaxFactorCounter,0,1, MPI_INTEGER         , MPI_SUM,0, PartMPI%COMM, IERROR)
        CALL MPI_REDUCE(FP_PrandtlNumber         ,0,1, MPI_DOUBLE_PRECISION, MPI_SUM,0, PartMPI%COMM, IERROR)
        CALL MPI_REDUCE(FP_MaxRelaxFactor        ,0,1, MPI_DOUBLE_PRECISION, MPI_MAX,0, PartMPI%COMM, IERROR)
        CALL MPI_REDUCE(FP_MaxRotRelaxFactor     ,0,1, MPI_DOUBLE_PRECISION, MPI_MAX,0, PartMPI%COMM, IERROR)
      END IF
    END IF
    IF(BGKInitDone) THEN
      IF((iter.GT.0).AND.(DSMC%CalcQualityFactors)) THEN
        CALL MPI_REDUCE(BGK_MeanRelaxFactor       ,0,1, MPI_DOUBLE_PRECISION, MPI_SUM,0, PartMPI%COMM, IERROR)
        CALL MPI_REDUCE(BGK_MeanRelaxFactorCounter,0,1, MPI_INTEGER         , MPI_SUM,0, PartMPI%COMM, IERROR)
        CALL MPI_REDUCE(BGK_MaxRelaxFactor        ,0,1, MPI_DOUBLE_PRECISION, MPI_MAX,0, PartMPI%COMM, IERROR)
        CALL MPI_REDUCE(BGK_MaxRotRelaxFactor     ,0,1, MPI_DOUBLE_PRECISION, MPI_MAX,0, PartMPI%COMM, IERROR)
      END IF
    END IF
  END IF
#endif /*USE_MPI*/
!-----------------------------------------------------------------------------------------------------------------------------------
! Perform averaging/summation of the MPI communicated variables on the root only (and for the non-MPI case, MPIRoot is set to true)
IF(PartMPI%MPIRoot) THEN
  IF (CalcPartBalance)THEN
    IF(nSpecies.GT.1) THEN
      nPartIn(nSpecies+1)     = SUM(nPartIn(1:nSpecies))
      nPartOut(nSpecies+1)    = SUM(nPartOut(1:nSpecies))
      PartEkinIn(nSpecies+1)  = SUM(PartEkinIn(1:nSpecies))
      PartEkinOut(nSpecies+1) = SUM(PartEkinOut(1:nSpecies))
    END IF
  END IF
  IF(FPInitDone) THEN
    IF((iter.GT.0).AND.(DSMC%CalcQualityFactors)) THEN
      IF(FP_MeanRelaxFactorCounter.GT.0) THEN
        FP_MeanRelaxFactor = FP_MeanRelaxFactor / REAL(FP_MeanRelaxFactorCounter)
        FP_PrandtlNumber = FP_PrandtlNumber / REAL(FP_MeanRelaxFactorCounter)
      END IF
    END IF
  END IF
  IF(BGKInitDone) THEN
    IF((iter.GT.0).AND.(DSMC%CalcQualityFactors)) THEN
      IF(BGK_MeanRelaxFactorCounter.GT.0) BGK_MeanRelaxFactor = BGK_MeanRelaxFactor / REAL(BGK_MeanRelaxFactorCounter)
    END IF
  END IF
    ! Moving Average of PCoupl:
  IF(CalcCoupledPower) THEN
    ! Moving Average of PCoupl:
    IF(ABS(Time-RestartTime).GT.0.0) PCouplAverage = PCouplAverage / (Time-RestartTime)
    ! current PCoupl (Delta_E / Timestep)
    PCoupl = PCoupl / dt
  END IF
END IF

IF(CalcCoupledPower) THEN
  ! Moving Average of PCoupl for each species
  IF((DisplayCoupledPower).AND.(MOD(iter,IterDisplayStep).EQ.0)) CALL DisplayCoupledPowerPart()
END IF
!-----------------------------------------------------------------------------------------------------------------------------------
!-----------------------------------------------------------------------------------------------------------------------------------
! Calculate the collision rates and reaction rate coefficients (Arrhenius-type chemistry)
#if (PP_TimeDiscMethod==42)
  IF(iter.GT.0) THEN
    IF(CalcCollRates) CALL CollRates(CRate)
    IF(CalcRelaxProb) CALL CalcRelaxRates(NumSpecTmp,VibRelaxRate)
    IF(CalcReacRates) THEN
      IF (CollisMode.EQ.3) CALL ReacRates(NumSpecTmp,RRate)
    END IF
  END IF
#endif
!-----------------------------------------------------------------------------------------------------------------------------------
  IF (CalcShapeEfficiency) CALL CalcShapeEfficiencyR()   ! This will NOT be placed in the file but directly in "out"
!===================================================================================================================================
! Output Routines
!===================================================================================================================================
#if USE_MPI
IF (PartMPI%MPIROOT) THEN
#endif /*USE_MPI*/
  WRITE(unit_index,'(E23.16E3)',ADVANCE='NO') Time
    IF (CalcSimNumSpec) THEN
      DO iSpec=1, nSpecAnalyze
        WRITE(unit_index,CSVFORMAT,ADVANCE='NO') ',', REAL(SimNumSpec(iSpec))
      END DO
    END IF
    IF (CalcNumDens) THEN
      DO iSpec=1, nSpecAnalyze
        WRITE(unit_index,CSVFORMAT,ADVANCE='NO') ',', REAL(NumDens(iSpec))
      END DO
    END IF
    IF(CalcAdaptiveBCInfo) THEN
      DO iSpec = 1, nSpecAnalyze
        DO iSF = 1, Species(iSpec)%nSurfacefluxBCs
          WRITE(unit_index,CSVFORMAT,ADVANCE='NO') ',', MassflowRate(iSpec,iSF)
          WRITE(unit_index,CSVFORMAT,ADVANCE='NO') ',', PressureAdaptiveBC(iSpec,iSF)
        END DO
      END DO
    END IF
    IF (CalcCharge) THEN
      WRITE(unit_index,CSVFORMAT,ADVANCE='NO') ',', PartCharge(1)
      WRITE(unit_index,CSVFORMAT,ADVANCE='NO') ',', PartCharge(2)
      WRITE(unit_index,CSVFORMAT,ADVANCE='NO') ',', PartCharge(3)
    END IF
    IF (CalcPartBalance) THEN
      DO iSpec=1, nSpecAnalyze
        WRITE(unit_index,CSVFORMAT,ADVANCE='NO') ',', REAL(nPartIn(iSpec))
      END DO
      DO iSpec=1, nSpecAnalyze
        WRITE(unit_index,CSVFORMAT,ADVANCE='NO') ',', REAL(nPartOut(iSpec))
      END DO
    END IF
    IF (CalcEkin) THEN
      DO iSpec=1, nSpecAnalyze
        WRITE(unit_index,CSVFORMAT,ADVANCE='NO') ',', Ekin(iSpec)
      END DO
    END IF
    IF (CalcCoupledPower) THEN
      WRITE(unit_index,CSVFORMAT,ADVANCE='NO') ',', PCoupl
      WRITE(unit_index,CSVFORMAT,ADVANCE='NO') ',', PCouplAverage
    END IF
    IF (CalcLaserInteraction) THEN
      DO iSpec=1, nSpecies
        WRITE(unit_index,CSVFORMAT,ADVANCE='NO') ',', EkinMax(iSpec)
      END DO
    END IF
    IF (CalcEpot .AND. CalcEkin .AND. CalcEtot) THEN
      WRITE(unit_index,CSVFORMAT,ADVANCE='NO') ',', Ekin(nSpecAnalyze) + WEl + WMag + Wphi+Wpsi
    END IF
    IF (CalcTemp) THEN
      DO iSpec=1, nSpecAnalyze
        WRITE(unit_index,CSVFORMAT,ADVANCE='NO') ',', Temp(iSpec)
      END DO
    END IF
    IF (CalcVelos) THEN
      DO iSpec=1, nSpecies
        DO dir = 1,4
          IF (VeloDirs(dir)) THEN
            WRITE(unit_index,CSVFORMAT,ADVANCE='NO') ',', PartVtrans(iSpec,dir)
            WRITE(unit_index,CSVFORMAT,ADVANCE='NO') ',', PartVtherm(iSpec,dir)
          END IF
        END DO
      END DO
    END IF
    IF (CalcPartBalance) THEN
      DO iSpec=1, nSpecAnalyze
        WRITE(unit_index,CSVFORMAT,ADVANCE='NO') ',', PartEkinIn(iSpec)
      END DO
      DO iSpec=1, nSpecAnalyze
        WRITE(unit_index,CSVFORMAT,ADVANCE='NO') ',', PartEkinOut(iSpec)
      END DO
    END IF

#if (PP_TimeDiscMethod==2 || PP_TimeDiscMethod==4 || PP_TimeDiscMethod==42 || PP_TimeDiscMethod==300 || PP_TimeDiscMethod==400 || (PP_TimeDiscMethod>=501 && PP_TimeDiscMethod<=509))
    IF (CollisMode.GT.1) THEN
      IF(CalcEint) THEN
        DO iSpec=1, nSpecAnalyze
          WRITE(unit_index,CSVFORMAT,ADVANCE='NO') ',', IntEn(iSpec,1)
        END DO
        DO iSpec=1, nSpecAnalyze
          WRITE(unit_index,CSVFORMAT,ADVANCE='NO') ',', IntEn(iSpec,2)
        END DO
        IF (DSMC%ElectronicModel.GT.0) THEN
          DO iSpec=1, nSpecAnalyze
            WRITE(unit_index,CSVFORMAT,ADVANCE='NO') ',', IntEn(iSpec,3)
          END DO
        END IF
        WRITE(unit_index,CSVFORMAT,ADVANCE='NO') ',', ETotal
      END IF
      IF(CalcEpot .AND. CalcEtot .AND. CalcEint)THEN
        WRITE(unit_index,CSVFORMAT,ADVANCE='NO') ',', ETotal+WEl+WMag + Wphi+Wpsi
      END IF
      IF(CalcTemp) THEN
        DO iSpec=1, nSpecies
          WRITE(unit_index,CSVFORMAT,ADVANCE='NO') ',', IntTemp(iSpec,1)
        END DO
        DO iSpec=1, nSpecies
          WRITE(unit_index,CSVFORMAT,ADVANCE='NO') ',', Xi_Vib(iSpec)
        END DO
        DO iSpec=1, nSpecies
          WRITE(unit_index,CSVFORMAT,ADVANCE='NO') ',', IntTemp(iSpec,2)
        END DO
        IF (DSMC%ElectronicModel.GT.0) THEN
          DO iSpec=1, nSpecies
            WRITE(unit_index,CSVFORMAT,ADVANCE='NO') ',', IntTemp(iSpec,3)
          END DO
          DO iSpec=1, nSpecies
            WRITE(unit_index,CSVFORMAT,ADVANCE='NO') ',', Xi_Elec(iSpec)
          END DO
        END IF
        DO iSpec=1, nSpecAnalyze
          WRITE(unit_index,CSVFORMAT,ADVANCE='NO') ',', TempTotal(iSpec)
        END DO
      END IF
    END IF
    IF(DSMC%CalcQualityFactors) THEN
      WRITE(unit_index,CSVFORMAT,ADVANCE='NO') ',', MeanCollProb
      WRITE(unit_index,CSVFORMAT,ADVANCE='NO') ',', MaxCollProb
      WRITE(unit_index,CSVFORMAT,ADVANCE='NO') ',', MeanFreePath
      IF(CalcRelaxProb) THEN
        WRITE(unit_index,CSVFORMAT,ADVANCE='NO') ',', RotRelaxProb(2)
        WRITE(unit_index,CSVFORMAT,ADVANCE='NO') ',', RotRelaxProb(1)
        WRITE(unit_index,CSVFORMAT,ADVANCE='NO') ',', VibRelaxProb(2)
        WRITE(unit_index,CSVFORMAT,ADVANCE='NO') ',', VibRelaxProb(1)
      END IF
    END IF
#endif
    IF(FPInitDone) THEN
      IF(DSMC%CalcQualityFactors) THEN
        WRITE(unit_index,CSVFORMAT,ADVANCE='NO') ',', FP_MeanRelaxFactor
        WRITE(unit_index,CSVFORMAT,ADVANCE='NO') ',', FP_MaxRelaxFactor
        WRITE(unit_index,CSVFORMAT,ADVANCE='NO') ',', FP_MaxRotRelaxFactor
        WRITE(unit_index,CSVFORMAT,ADVANCE='NO') ',', FP_PrandtlNumber
      END IF
    END IF
    IF(BGKInitDone) THEN
      IF(DSMC%CalcQualityFactors) THEN
        WRITE(unit_index,CSVFORMAT,ADVANCE='NO') ',', BGK_MeanRelaxFactor
        WRITE(unit_index,CSVFORMAT,ADVANCE='NO') ',', BGK_MaxRelaxFactor
        WRITE(unit_index,CSVFORMAT,ADVANCE='NO') ',', BGK_MaxRotRelaxFactor
      END IF
    END IF
#if (PP_TimeDiscMethod==42)
    IF(CalcCollRates) THEN
      DO iCase=1, CollInf%NumCase +1
        WRITE(unit_index,CSVFORMAT,ADVANCE='NO') ',', CRate(iCase)
      END DO
    END IF
    IF(CalcRelaxProb) THEN
      IF(XSec_Relaxation) THEN
        DO iSpec = 1, nSpecies
          DO jSpec = iSpec, nSpecies
            iCase = CollInf%Coll_Case(iSpec,jSpec)
            IF(SpecXSec(iCase)%UseVibXSec) THEN
              ! Skip entry if both species are NOT molecules
              IF(((SpecDSMC(iSpec)%InterID.NE.2).AND.(SpecDSMC(iSpec)%InterID.NE.20)).AND. &
                  ((SpecDSMC(jSpec)%InterID.NE.2).AND.(SpecDSMC(jSpec)%InterID.NE.20))) CYCLE
              WRITE(unit_index,CSVFORMAT,ADVANCE='NO') ',', VibRelaxRate(iCase)
            END IF
          END DO
        END DO
      END IF
    END IF
    IF(CalcReacRates) THEN
      DO iCase=1, ChemReac%NumOfReact
        WRITE(unit_index,CSVFORMAT,ADVANCE='NO') ',', RRate(iCase)
      END DO
    END IF
#endif /*(PP_TimeDiscMethod==42)*/
#if USE_HDG
        IF(CalcBRVariableElectronTemp)THEN ! variable reference electron temperature
          DO iRegions=1,BRNbrOfRegions
            WRITE(unit_index,CSVFORMAT,ADVANCE='NO') ',', RegionElectronRef(3,iRegions)*ElementaryCharge/BoltzmannConst ! convert eV to K
          END DO
        END IF ! CalcBRVariableElectronTemp
#endif /*USE_HDG*/
    WRITE(unit_index,'(A)') ''
#if USE_MPI
  END IF
#endif /*USE_MPI*/
!-----------------------------------------------------------------------------------------------------------------------------------
! Reset coupled power to particles if output of coupled power is active
IF (CalcCoupledPower) THEN
  PCouplAverage = PCouplAverage * (Time-RestartTime) ! PCouplAverage is reseted
END IF
!-----------------------------------------------------------------------------------------------------------------------------------
! Reset the particle counter
IF(CalcPartBalance) THEN
  nPartIn=0; nPartOut=0; PartEkinIn=0.; PartEkinOut=0.
END IF
!-----------------------------------------------------------------------------------------------------------------------------------

END SUBROUTINE AnalyzeParticles


SUBROUTINE FinalizeParticleAnalyze()
!===================================================================================================================================
! Finalizes variables necessary for analyse subroutines
!===================================================================================================================================
! MODULES
USE MOD_Particle_Analyze_Vars
USE MOD_Particle_Vars         ,ONLY: nSpecies
USE MOD_Particle_Mesh_Vars    ,ONLY: ElemCharLengthX_Shared,ElemCharLengthY_Shared,ElemCharLengthZ_Shared
#if USE_MPI
USE MOD_Particle_Mesh_Vars    ,ONLY: ElemCharLengthX_Shared_Win,ElemCharLengthY_Shared_Win,ElemCharLengthZ_Shared_Win
USE MOD_MPI_Shared_Vars       ,ONLY: MPI_COMM_SHARED
USE MOD_MPI_Shared
#endif /*USE_MPI*/
IMPLICIT NONE
!-----------------------------------------------------------------------------------------------------------------------------------
! OUTPUT VARIABLES
!-----------------------------------------------------------------------------------------------------------------------------------
! LOCAL VARIABLES
INTEGER           :: iSpec,iError
!===================================================================================================================================
ParticleAnalyzeInitIsDone = .FALSE.
SDEALLOCATE(DebyeLengthCell)
SDEALLOCATE(PICTimeStepCell)
SDEALLOCATE(ElectronDensityCell)
SDEALLOCATE(ElectronTemperatureCell)
SDEALLOCATE(PlasmaFrequencyCell)
SDEALLOCATE(PPSCell)
SDEALLOCATE(PPSCellCartesian)
SDEALLOCATE(ShapeFunctionRadius)
SDEALLOCATE(ShapeFunctionFraction)
IF(CalcCoupledPower) THEN
  DO iSpec = 1, nSpecies
    SDEALLOCATE(PCouplSpec(iSpec)%DensityAvgElem)
  END DO ! iSpec = 1, nSpecies
END IF
SDEALLOCATE(PCouplSpec)
SDEALLOCATE(PPDCell)
SDEALLOCATE(PPDCellX)
SDEALLOCATE(PPDCellY)
SDEALLOCATE(PPDCellZ)
SDEALLOCATE(IonizationCell)
SDEALLOCATE(PICCFLCell)
SDEALLOCATE(PICCFLCellX)
SDEALLOCATE(PICCFLCellY)
SDEALLOCATE(PICCFLCellZ)
SDEALLOCATE(MaxPartDisplacementCell)
SDEALLOCATE(MaxPartDisplacementCellX)
SDEALLOCATE(MaxPartDisplacementCellY)
SDEALLOCATE(MaxPartDisplacementCellZ)
SDEALLOCATE(PlasmaParameterCell)
SDEALLOCATE(QuasiNeutralityCell)
SDEALLOCATE(IonDensityCell)
SDEALLOCATE(NeutralDensityCell)
SDEALLOCATE(ChargeNumberCell)
SDEALLOCATE(nPartIn)
SDEALLOCATE(nPartOut)
SDEALLOCATE(PartEkinIn)
SDEALLOCATE(PartEkinOut)
SDEALLOCATE(MassflowRate)
SDEALLOCATE(PressureAdaptiveBC)

IF(CalcPointsPerDebyeLength.OR.CalcPICCFLCondition.OR.CalcMaxPartDisplacement)THEN
#if USE_MPI
  CALL MPI_BARRIER(MPI_COMM_SHARED,iError)
  CALL UNLOCK_AND_FREE(ElemCharLengthX_Shared_Win)
  CALL UNLOCK_AND_FREE(ElemCharLengthY_Shared_Win)
  CALL UNLOCK_AND_FREE(ElemCharLengthZ_Shared_Win)
  CALL MPI_BARRIER(MPI_COMM_SHARED,iError)
#endif /*USE_MPI*/
  ADEALLOCATE(ElemCharLengthX_Shared)
  ADEALLOCATE(ElemCharLengthY_Shared)
  ADEALLOCATE(ElemCharLengthZ_Shared)
END IF

SDEALLOCATE(CyclotronFrequencyMaxCell)
SDEALLOCATE(CyclotronFrequencyMinCell)
SDEALLOCATE(GyroradiusMaxCell)
SDEALLOCATE(GyroradiusMinCell)
SDEALLOCATE(PICTimeStepCyclotronCell)

END SUBROUTINE FinalizeParticleAnalyze
#endif /*PARTICLES*/


END MODULE MOD_Particle_Analyze
