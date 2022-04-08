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

MODULE MOD_Particle_BGM
!===================================================================================================================================
!> Contains
!===================================================================================================================================
! MODULES
! IMPLICIT VARIABLE HANDLING
IMPLICIT NONE
PRIVATE

INTERFACE DefineParametersParticleBGM
    MODULE PROCEDURE DefineParametersParticleBGM
END INTERFACE

INTERFACE BuildBGMAndIdentifyHaloRegion
    MODULE PROCEDURE BuildBGMAndIdentifyHaloRegion
END INTERFACE

INTERFACE FinalizeBGM
    MODULE PROCEDURE FinalizeBGM
END INTERFACE

#if USE_MPI
INTERFACE WriteHaloInfo
  MODULE PROCEDURE WriteHaloInfo
END INTERFACE

INTERFACE FinalizeHaloInfo
  MODULE PROCEDURE FinalizeHaloInfo
END INTERFACE
#endif /*USE_MPI*/

PUBLIC::DefineParametersParticleBGM
PUBLIC::BuildBGMAndIdentifyHaloRegion
PUBLIC::FinalizeBGM
#if USE_MPI
PUBLIC::WriteHaloInfo
PUBLIC::FinalizeHaloInfo
#endif /*USE_MPI*/

CONTAINS

!==================================================================================================================================
!> Define parameters for particle backgroundmesh
!==================================================================================================================================
SUBROUTINE DefineParametersParticleBGM()
! MODULES
USE MOD_Globals
USE MOD_ReadInTools ,ONLY: prms
IMPLICIT NONE
!==================================================================================================================================
CALL prms%SetSection('BGM')

! Background mesh init variables
CALL prms%CreateRealArrayOption('Part-FIBGMdeltas'&
  , 'Define the deltas for the Cartesian Fast-Init-Background-Mesh.'//&
  ' They should be of the similar size as the smallest cells of the used mesh for simulation.'&
  , '1. , 1. , 1.')
CALL prms%CreateRealArrayOption('Part-FactorFIBGM'&
  , 'Factor with which the background mesh will be scaled.'&
  , '1. , 1. , 1.')
CALL prms%CreateRealOption(     'Part-SafetyFactor'           , 'Factor to scale the halo region with MPI', '1.0')
CALL prms%CreateRealOption(     'Particles-HaloEpsVelo'       , 'Halo region velocity [m/s]', '0.')


END SUBROUTINE DefineParametersParticleBGM


SUBROUTINE BuildBGMAndIdentifyHaloRegion()
!===================================================================================================================================
!> computes the BGM-indices of an element and maps the number of element and which element to each BGM cell
!> BGM is only saved for compute-node-mesh + halo-region on shared memory
!===================================================================================================================================
! MODULES                                                                                                                          !
!----------------------------------------------------------------------------------------------------------------------------------!
USE MOD_Globals
USE MOD_Globals_Vars           ,ONLY: c
USE MOD_Preproc
USE MOD_Basis                  ,ONLY: DeCasteljauInterpolation
USE MOD_Mesh_Vars              ,ONLY: NGeo,nElems,offsetElem!,nBCSides
USE MOD_Particle_Mesh_Tools    ,ONLY: GetGlobalNonUniqueSideID
USE MOD_Particle_Periodic_BC   ,ONLY: InitPeriodicBC
USE MOD_Particle_Surfaces_Vars ,ONLY: BezierControlPoints3D
USE MOD_Particle_Tracking_Vars ,ONLY: TrackingMethod,Distance,ListDistance
USE MOD_ReadInTools            ,ONLY: GETREAL,GetRealArray,PrintOption
USE MOD_Particle_Mesh_Vars     ,ONLY: NodeCoords_Shared
USE MOD_Particle_Mesh_Vars     ,ONLY: ElemInfo_Shared,FIBGM_nElems,ElemToBGM_Shared,FIBGM_offsetElem
USE MOD_Particle_Mesh_Vars     ,ONLY: BoundsOfElem_Shared,GEO,FIBGM_Element
#if (PP_TimeDiscMethod==501) || (PP_TimeDiscMethod==502) || (PP_TimeDiscMethod==506)
USE MOD_TimeDisc_Vars          ,ONLY: iStage,nRKStages,RK_c
#endif
#if ! (USE_HDG)
USE MOD_DG                     ,ONLY: DGTimeDerivative_weakForm
USE MOD_CalcTimeStep           ,ONLY: CalcTimeStep
#endif /*USE_HDG*/
#if USE_MPI
USE MOD_MPI_Shared_Vars
USE MOD_MPI_Shared
USE MOD_PICDepo_Vars           ,ONLY: DepositionType,r_sf
USE MOD_Particle_MPI_Vars      ,ONLY: SafetyFactor,halo_eps_velo,halo_eps,halo_eps2, halo_eps_woshape
USE MOD_TimeDisc_Vars          ,ONLY: ManualTimeStep
USE MOD_PICDepo_Vars           ,ONLY: DepositionType,SFAdaptiveSmoothing,dim_sf,dimFactorSF
USE MOD_Particle_Mesh_Vars     ,ONLY: ElemInfo_Shared_Win,FIBGM_nElems_Shared_Win,FIBGMToProcFlag_Shared_Win,FIBGMProcs_Shared_Win
USE MOD_Particle_Mesh_Vars     ,ONLY: SideInfo_Shared,nNonUniqueGlobalSides,nNonUniqueGlobalNodes
USE MOD_Mesh_Vars              ,ONLY: nGlobalElems
USE MOD_MPI_Vars               ,ONLY: offsetElemMPI
USE MOD_Particle_Mesh_Vars     ,ONLY: FIBGMToProc_Shared,FIBGMToProcFlag_Shared,nComputeNodeElems,FIBGMProcs_Shared
USE MOD_Particle_Mesh_Vars     ,ONLY: FIBGM_nElems_Shared,FIBGM_Element_Shared,FIBGMProcs
USE MOD_Particle_Mesh_Vars     ,ONLY: FIBGM_offsetElem_Shared,FIBGMToProc
USE MOD_Particle_Mesh_Vars     ,ONLY: offsetComputeNodeElem,nComputeNodeSides,FIBGMToProcFlag
USE MOD_Particle_Mesh_Vars     ,ONLY: FIBGM_offsetElem_Shared_Win,FIBGMToProc_Shared_Win,FIBGM_Element_Shared_Win
USE MOD_Particle_Mesh_Vars     ,ONLY: FIBGM_nTotalElems_Shared_Win,BoundsOfElem_Shared_Win,ElemToBGM_Shared_Win
USE MOD_Particle_Mesh_Vars     ,ONLY: FIBGM_nTotalElems,FIBGM_nTotalElems_Shared
USE MOD_Particle_Mesh_Vars     ,ONLY: MeshHasPeriodic,MeshHasRotPeriodic
#endif /*USE_MPI*/
!----------------------------------------------------------------------------------------------------------------------------------!
! IMPLICIT VARIABLE HANDLING
IMPLICIT NONE
! INPUT VARIABLES
!----------------------------------------------------------------------------------------------------------------------------------!
! OUTPUT VARIABLES
!-----------------------------------------------------------------------------------------------------------------------------------
! LOCAL VARIABLES
INTEGER                        :: iElem,iHaloElem,iLocSide,SideID
INTEGER                        :: FirstElem,LastElem
INTEGER                        :: firstNodeID,lastNodeID
INTEGER                        :: offsetNodeID,nNodeIDs,currentOffset
INTEGER,PARAMETER              :: moveBGMindex=1,increment=1,haloChange=4
REAL                           :: xmin,xmax,ymin,ymax,zmin,zmax
INTEGER                        :: iBGM,jBGM,kBGM
INTEGER                        :: BGMimax,BGMimin,BGMjmax,BGMjmin,BGMkmax,BGMkmin
INTEGER                        :: BGMCellXmax,BGMCellXmin,BGMCellYmax,BGMCellYmin,BGMCellZmax,BGMCellZmin
INTEGER                        :: BGMiminglob,BGMimaxglob,BGMjminglob,BGMjmaxglob,BGMkminglob,BGMkmaxglob
#if USE_MPI
INTEGER                        :: iSide
INTEGER                        :: ElemID
REAL                           :: deltaT
REAL                           :: globalDiag,maxCellRadius
INTEGER,ALLOCATABLE            :: sendbuf(:,:,:),recvbuf(:,:,:)
INTEGER,ALLOCATABLE            :: offsetElemsInBGMCell(:,:,:)
INTEGER                        :: nHaloElems
INTEGER,ALLOCATABLE            :: offsetCNHalo2GlobalElem(:)
REAL,ALLOCATABLE               :: MPISideBoundsOfElemCenter(:,:)
REAL                           :: BoundsOfElemCenter(1:4)
LOGICAL                        :: ElemInsideHalo
INTEGER                        :: firstHaloElem,lastHaloElem
! Halo calculation
INTEGER                        :: p,q
INTEGER,ALLOCATABLE            :: offsetMPIElemShared(:)
INTEGER,ALLOCATABLE            :: offsetMPISideShared(:)
REAL,ALLOCATABLE               :: metricMPISideShared(:,:)
INTEGER                        :: nBorderSidesShared,nBorderElemsShared
REAL                           :: origin(3),vec(3),radius,radiusMax
!INTEGER                        :: iNode,localSideID,nStart,SideCornerNodeIDs(1:4)
!INTEGER                        :: CornerNodeIDswitch(8),NodeMap(4,6)
! FIBGMToProc
LOGICAL                        :: dummyLog
INTEGER                        :: dummyInt
INTEGER                        :: iProc,ProcRank,nFIBGMToProc,nFIBGM,MessageSize
INTEGER                        :: BGMiDelta,BGMjDelta,BGMkDelta
INTEGER                        :: BGMiglobDelta,BGMjglobDelta,BGMkglobDelta
INTEGER,ALLOCATABLE            :: FIBGM_LocalProcs(:,:,:,:)
! Periodic FIBGM
LOGICAL                        :: PeriodicComponent(1:3)
INTEGER                        :: iPeriodicVector,iPeriodicComponent
REAL                           :: CharacteristicLength,CharacteristicLengthMax
INTEGER                        :: CNElemID
LOGICAL                        :: EnlargeBGM ! Flag used for enlarging the BGM if RefMapping and/or shape function is used
INTEGER                        :: offsetElemCNProc
REAL                           :: BoundingBoxVolume
! Mortar
INTEGER                        :: iMortar,NbElemID,NbSideID,nMortarElems!,nFoundSides,nlocSides,i
#else
REAL                           :: halo_eps
#endif /*USE_MPI*/
#ifdef CODE_ANALYZE
INTEGER,ALLOCATABLE            :: NumberOfElements(:)
#endif /*CODE_ANALYZE*/
REAL                           :: StartT,EndT ! Timer
!===================================================================================================================================

! Read parameter for FastInitBackgroundMesh (FIBGM)
GEO%FIBGMdeltas(1:3) = GETREALARRAY('Part-FIBGMdeltas',3)
GEO%FactorFIBGM(1:3) = GETREALARRAY('Part-FactorFIBGM',3)
GEO%FIBGMdeltas(1:3) = 1./GEO%FactorFIBGM(1:3) * GEO%FIBGMdeltas(1:3)

! Ensure BGM does not protrude beyond mesh when divisible by FIBGMdeltas
BGMiminglob = 0 + moveBGMindex
BGMimaxglob = FLOOR((GEO%xmaxglob-GEO%xminglob)/GEO%FIBGMdeltas(1)) + moveBGMindex
BGMimaxglob = MERGE(BGMimaxglob,BGMimaxglob-1,MODULO(GEO%xmaxglob-GEO%xminglob,GEO%FIBGMdeltas(1)).NE.0)
BGMjminglob = 0 + moveBGMindex
BGMjmaxglob = FLOOR((GEO%ymaxglob-GEO%yminglob)/GEO%FIBGMdeltas(2)) + moveBGMindex
BGMjmaxglob = MERGE(BGMjmaxglob,BGMjmaxglob-1,MODULO(GEO%ymaxglob-GEO%yminglob,GEO%FIBGMdeltas(2)).NE.0)
BGMkminglob = 0 + moveBGMindex
BGMkmaxglob = FLOOR((GEO%zmaxglob-GEO%zminglob)/GEO%FIBGMdeltas(3)) + moveBGMindex
BGMkmaxglob = MERGE(BGMkmaxglob,BGMkmaxglob-1,MODULO(GEO%zmaxglob-GEO%zminglob,GEO%FIBGMdeltas(3)).NE.0)

GEO%FIBGMiminglob = BGMiminglob
GEO%FIBGMimaxglob = BGMimaxglob
GEO%FIBGMjminglob = BGMjminglob
GEO%FIBGMjmaxglob = BGMjmaxglob
GEO%FIBGMkminglob = BGMkminglob
GEO%FIBGMkmaxglob = BGMkmaxglob

SWRITE(UNIT_stdOut,'(A,I18,A,I18,A,I18)') ' | Total FIBGM Cells(x,y,z): '                                     &
                                          , BGMimaxglob - BGMiminglob                                    ,', '&
                                          , BGMjmaxglob - BGMjminglob                                    ,', '&
                                          , BGMkmaxglob - BGMkminglob

! Read periodic vectors from parameter file
CALL InitPeriodicBC()

#if USE_MPI
CALL Allocate_Shared((/6  ,nGlobalElems/),ElemToBGM_Shared_Win,ElemToBGM_Shared)
CALL Allocate_Shared((/2,3,nGlobalElems/),BoundsOfElem_Shared_Win,BoundsOfElem_Shared)
CALL MPI_WIN_LOCK_ALL(0,ElemToBGM_Shared_Win  ,IERROR)
CALL MPI_WIN_LOCK_ALL(0,BoundsOfElem_Shared_Win,IERROR)
firstElem = INT(REAL( myComputeNodeRank   *nGlobalElems)/REAL(nComputeNodeProcessors))+1
lastElem  = INT(REAL((myComputeNodeRank+1)*nGlobalElems)/REAL(nComputeNodeProcessors))
! Periodic Sides
MeshHasPeriodic    = MERGE(.TRUE.,.FALSE.,GEO%nPeriodicVectors.GT.0)
MeshHasRotPeriodic = GEO%RotPeriodicBC
#else
! In order to use only one type of variables VarName_Shared in code structure such as tracking etc. for NON_MPI
! the same variables are allocated on the single proc and used from mesh_vars instead of mpi_shared_vars
ALLOCATE(ElemToBGM_Shared(   1:6,    1:nElems))
ALLOCATE(BoundsOfElem_Shared(1:2,1:3,1:nElems)) ! 1-2: Min, Max value; 1-3: x,y,z
firstElem = 1
lastElem  = nElems
#endif  /*USE_MPI*/

! Use NodeCoords only for TriaTracking since Tracing and RefMapping have potentially curved elements, only BezierControlPoints form
! convex hull
SELECT CASE(TrackingMethod)
  CASE(TRIATRACKING)
    DO iElem = firstElem, lastElem
      offsetNodeID = ElemInfo_Shared(ELEM_FIRSTNODEIND,iElem)
      nNodeIDs     = ElemInfo_Shared(ELEM_LASTNODEIND ,iElem)-ElemInfo_Shared(ELEM_FIRSTNODEIND,iElem)
      firstNodeID  = offsetNodeID+1
      lastNodeID   = offsetNodeID+nNodeIDs

      xmin=MINVAL(NodeCoords_Shared(1,firstNodeID:lastNodeID))
      xmax=MAXVAL(NodeCoords_Shared(1,firstNodeID:lastNodeID))
      ymin=MINVAL(NodeCoords_Shared(2,firstNodeID:lastNodeID))
      ymax=MAXVAL(NodeCoords_Shared(2,firstNodeID:lastNodeID))
      zmin=MINVAL(NodeCoords_Shared(3,firstNodeID:lastNodeID))
      zmax=MAXVAL(NodeCoords_Shared(3,firstNodeID:lastNodeID))

      BoundsOfElem_Shared(1,1,iElem) = xmin
      BoundsOfElem_Shared(2,1,iElem) = xmax
      BoundsOfElem_Shared(1,2,iElem) = ymin
      BoundsOfElem_Shared(2,2,iElem) = ymax
      BoundsOfElem_Shared(1,3,iElem) = zmin
      BoundsOfElem_Shared(2,3,iElem) = zmax

      ! BGM indices must be >0 --> move by 1
      ElemToBGM_Shared(1,iElem) = MAX(FLOOR((xmin-GEO%xminglob)/GEO%FIBGMdeltas(1)),0) + moveBGMindex
      ElemToBGM_Shared(2,iElem) = MIN(FLOOR((xmax-GEO%xminglob)/GEO%FIBGMdeltas(1))    + moveBGMindex,GEO%FIBGMimaxglob)
      ElemToBGM_Shared(3,iElem) = MAX(FLOOR((ymin-GEO%yminglob)/GEO%FIBGMdeltas(2)),0) + moveBGMindex
      ElemToBGM_Shared(4,iElem) = MIN(FLOOR((ymax-GEO%yminglob)/GEO%FIBGMdeltas(2))    + moveBGMindex,GEO%FIBGMjmaxglob)
      ElemToBGM_Shared(5,iElem) = MAX(FLOOR((zmin-GEO%zminglob)/GEO%FIBGMdeltas(3)),0) + moveBGMindex
      ElemToBGM_Shared(6,iElem) = MIN(FLOOR((zmax-GEO%zminglob)/GEO%FIBGMdeltas(3))    + moveBGMindex,GEO%FIBGMkmaxglob)
    END DO ! iElem = firstElem, lastElem

  CASE(TRACING,REFMAPPING)
    DO iElem = firstElem, lastElem
      xmin= HUGE(1.)
      xmax=-HUGE(1.)
      ymin= HUGE(1.)
      ymax=-HUGE(1.)
      zmin= HUGE(1.)
      zmax=-HUGE(1.)

      DO iLocSide = 1,6
        SideID = GetGlobalNonUniqueSideID(iElem,iLocSide)
        xmin = MIN(xmin,MINVAL(BezierControlPoints3D(1,:,:,SideID)))
        xmax = MAX(xmax,MAXVAL(BezierControlPoints3D(1,:,:,SideID)))
        ymin = MIN(ymin,MINVAL(BezierControlPoints3D(2,:,:,SideID)))
        ymax = MAX(ymax,MAXVAL(BezierControlPoints3D(2,:,:,SideID)))
        zmin = MIN(zmin,MINVAL(BezierControlPoints3D(3,:,:,SideID)))
        zmax = MAX(zmax,MAXVAL(BezierControlPoints3D(3,:,:,SideID)))
      END DO

      ! Restrict to domain extent
      xmin = MAX(xmin,GEO%xminglob)
      xmax = MIN(xmax,GEO%xmaxglob)
      ymin = MAX(ymin,GEO%yminglob)
      ymax = MIN(ymax,GEO%ymaxglob)
      zmin = MAX(zmin,GEO%zminglob)
      zmax = MIN(zmax,GEO%zmaxglob)

      BoundsOfElem_Shared(1,1,iElem) = xmin
      BoundsOfElem_Shared(2,1,iElem) = xmax
      BoundsOfElem_Shared(1,2,iElem) = ymin
      BoundsOfElem_Shared(2,2,iElem) = ymax
      BoundsOfElem_Shared(1,3,iElem) = zmin
      BoundsOfElem_Shared(2,3,iElem) = zmax

      ! BGM indices must be >0 --> move by 1
      ElemToBGM_Shared(1,iElem) = MAX(FLOOR((xmin-GEO%xminglob)/GEO%FIBGMdeltas(1)),0) + moveBGMindex
      ElemToBGM_Shared(2,iElem) = MIN(FLOOR((xmax-GEO%xminglob)/GEO%FIBGMdeltas(1))    + moveBGMindex,GEO%FIBGMimaxglob)
      ElemToBGM_Shared(3,iElem) = MAX(FLOOR((ymin-GEO%yminglob)/GEO%FIBGMdeltas(2)),0) + moveBGMindex
      ElemToBGM_Shared(4,iElem) = MIN(FLOOR((ymax-GEO%yminglob)/GEO%FIBGMdeltas(2))    + moveBGMindex,GEO%FIBGMjmaxglob)
      ElemToBGM_Shared(5,iElem) = MAX(FLOOR((zmin-GEO%zminglob)/GEO%FIBGMdeltas(3)),0) + moveBGMindex
      ElemToBGM_Shared(6,iElem) = MIN(FLOOR((zmax-GEO%zminglob)/GEO%FIBGMdeltas(3))    + moveBGMindex,GEO%FIBGMkmaxglob)
    END DO ! iElem = firstElem, lastElem
END SELECT

#if USE_MPI
CALL BARRIER_AND_SYNC(ElemToBGM_Shared_Win   ,MPI_COMM_SHARED)
CALL BARRIER_AND_SYNC(BoundsOfElem_Shared_Win,MPI_COMM_SHARED)
#endif  /*USE_MPI*/

! deallocate stuff // required for dynamic load balance
#if USE_LOADBALANCE
IF (ALLOCATED(GEO%FIBGM)) THEN
  DO iBGM=GEO%FIBGMimin,GEO%FIBGMimax
    DO jBGM=GEO%FIBGMjmin,GEO%FIBGMjmax
      DO kBGM=GEO%FIBGMkmin,GEO%FIBGMkmax
        SDEALLOCATE(GEO%FIBGM(iBGM,jBGM,kBGM)%Element)
      END DO ! kBGM
    END DO ! jBGM
  END DO ! iBGM
  DEALLOCATE(GEO%FIBGM)
END IF
#endif /*USE_LOADBALANCE*/

#if USE_MPI
SafetyFactor  = GETREAL('Part-SafetyFactor')
halo_eps_velo = GETREAL('Particles-HaloEpsVelo')

! Adaptive SF: Determine global shape function radius from maximum of characteristic length in each cell
IF((TRIM(DepositionType).EQ.'shape_function_adaptive').AND.SFAdaptiveSmoothing)THEN
  ! J_N is only built for local DG elements. Therefore, array is only filled for elements on the same compute node
  offsetElemCNProc = offsetElem - offsetComputeNodeElem
  CharacteristicLengthMax=0.
  DO iElem = 1, nElems
    CNElemID = iElem+offsetElemCNProc

    ! Because ElemVolume_Shared(CNElemID) is not available for halo elements, the bounding box volume is used as an approximate
    ! value for the element volume from which the characteristic length of the element is calculated
    ASSOCIATE( Bounds => BoundsOfElem_Shared(1:2,1:3,iElem + offsetElem) ) ! 1-2: Min, Max value; 1-3: x,y,z
      BoundingBoxVolume = (Bounds(2,1)-Bounds(1,1)) * (Bounds(2,2)-Bounds(1,2)) * (Bounds(2,3)-Bounds(1,3))
    END ASSOCIATE
    IF(BoundingBoxVolume.LE.0.0) CALL abort(__STAMP__,'Element bounding box volume cannot be zero!')

    ! Check which shape function dimension is used
    SELECT CASE(dim_sf)
    CASE(1)
      !CharacteristicLength = ElemVolume_Shared(CNElemID) / dimFactorSF
      CharacteristicLength = BoundingBoxVolume / dimFactorSF
    CASE(2)
      !CharacteristicLength = SQRT(ElemVolume_Shared(CNElemID) / dimFactorSF)
      CharacteristicLength = SQRT(BoundingBoxVolume / dimFactorSF)
    CASE(3)
      !CharacteristicLength = ElemCharLength_Shared(CNElemID)
      CharacteristicLength = BoundingBoxVolume**(1./3.)
    END SELECT
    CharacteristicLengthMax = MAX(CharacteristicLengthMax,CharacteristicLength)
  END DO ! iElem = 1, nElems
  CALL MPI_ALLREDUCE(MPI_IN_PLACE,CharacteristicLengthMax,1,MPI_DOUBLE_PRECISION,MPI_MAX,MPI_COMM_WORLD,iError)
  r_sf = 1.1 * CharacteristicLengthMax ! Increase by 10%
  IF(CharacteristicLength.LE.0.) CALL abort(__STAMP__,'CharacteristicLength.LE.0. is not allowed.')
  CALL PrintOption('Global shape function radius from elements: PIC-shapefunction-radius' , 'INFO.' , RealOpt=r_sf)
END IF ! (TRIM(DepositionType).EQ.'shape_function_adaptive').AND.SFAdaptiveSmoothing

! Check if multi-node
IF (nComputeNodeProcessors.EQ.nProcessors_Global) THEN
#endif /*USE_MPI*/
  halo_eps  = 0.
#if USE_MPI
  halo_eps2 = 0.
ELSE
  IF (ManualTimeStep.LE.0.0) THEN
#if !(USE_HDG)
    deltaT = CalcTimeStep()
#else
     CALL abort(__STAMP__&
  , 'ManualTimeStep.LLE0.0 -> ManualTimeStep is not defined correctly! ManualTimeStep = ',RealInfoOpt=ManualTimeStep)
#endif /*USE_HDG*/
  ELSE
    deltaT=ManualTimeStep
  END IF
  IF (halo_eps_velo.EQ.0) halo_eps_velo = c
#if (PP_TimeDiscMethod==4 || PP_TimeDiscMethod==200 || PP_TimeDiscMethod==42)
  IF (halo_eps_velo.EQ.c) CALL abort(__STAMP__, 'halo_eps_velo.EQ.c -> Halo Eps Velocity for MPI not defined')
#endif
#if (PP_TimeDiscMethod==501) || (PP_TimeDiscMethod==502) || (PP_TimeDiscMethod==506)
  halo_eps = RK_c(2)
  DO iStage=2,nRKStages-1
    halo_eps = MAX(halo_eps,RK_c(iStage+1)-RK_c(iStage))
  END DO
  halo_eps = MAX(halo_eps,1.-RK_c(nRKStages))
  CALL PrintOption('halo_eps from max. RKdtFrac','CALCUL.',RealOpt=halo_eps)
  halo_eps = halo_eps*halo_eps_velo*deltaT*SafetyFactor !dt multiplied with maximum RKdtFrac
#else
  halo_eps = halo_eps_velo*deltaT*SafetyFactor ! for RK too large
#endif
  halo_eps_woshape = halo_eps
  ! Check whether halo_eps is smaller than shape function radius e.g. 'shape_function'
  IF(StringBeginsWith(DepositionType,'shape_function'))THEN
    IF(r_sf.LT.0.) CALL abort(__STAMP__,'Shape function radius not read yet (less than zero)! r_sf=',RealInfoOpt=r_sf)
    halo_eps = halo_eps + r_sf
    CALL PrintOption('halo_eps from shape function radius','CALCUL.',RealOpt=halo_eps)
  END IF

  ! limit halo_eps to diagonal of bounding box
  globalDiag = SQRT( (GEO%xmaxglob-GEO%xminglob)**2 &
                   + (GEO%ymaxglob-GEO%yminglob)**2 &
                   + (GEO%zmaxglob-GEO%zminglob)**2 )
  IF(halo_eps.GT.globalDiag)THEN
    CALL PrintOption('unlimited halo distance','CALCUL.',RealOpt=halo_eps)
    SWRITE(UNIT_stdOut,'(A38)') ' |   limitation of halo distance  |    '
    halo_eps=globalDiag
  END IF

  halo_eps2=halo_eps*halo_eps
  CALL PrintOption('halo distance','CALCUL.',RealOpt=halo_eps)
  IF(halo_eps.LT.0.)CALL abort(__STAMP__,'halo_eps cannot be negative!')
END IF

! The initial cutoff is performed based on the FIBGM elements. However, we have to ensure that all possible halo elements, i.e.
! those in range (myRadius + otherRadius + halo_eps) will be tested. We make a worst case approximation by determining the
! global largest cell radius and use it to keep all cells that are in this range.
! >> Find radius of largest cell
maxCellRadius = 0
DO iElem = firstElem, lastElem
  maxCellRadius = MAX(maxCellRadius,VECNORM((/ BoundsOfElem_Shared(2,1,iElem)-BoundsOfElem_Shared(1,1,iElem), &
                                               BoundsOfElem_Shared(2,2,iElem)-BoundsOfElem_Shared(1,2,iElem), &
                                               BoundsOfElem_Shared(2,3,iElem)-BoundsOfElem_Shared(1,3,iElem)/)/2.))
END DO
! >> Communicate global maximum
CALL MPI_ALLREDUCE(MPI_IN_PLACE,maxCellRadius,1,MPI_DOUBLE_PRECISION,MPI_MAX,MPI_COMM_SHARED,iError)
SWRITE(UNIT_stdOut,'(A,E15.7,A)') ' | Found max. cell radius as', maxCellRadius, ', for building halo BGM ...'
#if USE_MPI
StartT=MPI_WTIME()
#else
CALL CPU_TIME(StartT)
#endif /*USE_MPI*/

! Check, whether the BGM must be enlarged. Periodic sides plus EITHER of the following
! 1. RefMapping
! 2. Shape function
IF((GEO%nPeriodicVectors.GT.0).AND.((TrackingMethod.EQ.REFMAPPING).OR.(StringBeginsWith(DepositionType,'shape_function'))))THEN
  EnlargeBGM = .TRUE.
ELSE
  EnlargeBGM = .FALSE.
END IF

! Enlarge BGM with halo region (all element outside of this region will be cut off)
IF (EnlargeBGM) THEN
  PeriodicComponent = .FALSE.
  Do iPeriodicVector = 1,GEO%nPeriodicVectors
    DO iPeriodicComponent = 1,3
      IF (ABS(GEO%PeriodicVectors(iPeriodicComponent,iPeriodicVector)).GT.0) PeriodicComponent(iPeriodicComponent) = .TRUE.
    END DO
  END DO

  ! >> Take global maxima of cell radius into account and increase the considered range accordingly
  BGMimin = MERGE(GEO%FIBGMiminglob,MAX(FLOOR((GEO%CNxmin-(halo_eps+maxCellRadius)-GEO%xminglob)/GEO%FIBGMdeltas(1)),0) + moveBGMindex                   ,PeriodicComponent(1))
  BGMimax = MERGE(GEO%FIBGMimaxglob,MIN(FLOOR((GEO%CNxmax+(halo_eps+maxCellRadius)-GEO%xminglob)/GEO%FIBGMdeltas(1))    + moveBGMindex,GEO%FIBGMimaxglob),PeriodicComponent(1))
  BGMjmin = MERGE(GEO%FIBGMjminglob,MAX(FLOOR((GEO%CNymin-(halo_eps+maxCellRadius)-GEO%yminglob)/GEO%FIBGMdeltas(2)),0) + moveBGMindex                   ,PeriodicComponent(2))
  BGMjmax = MERGE(GEO%FIBGMjmaxglob,MIN(FLOOR((GEO%CNymax+(halo_eps+maxCellRadius)-GEO%yminglob)/GEO%FIBGMdeltas(2))    + moveBGMindex,GEO%FIBGMjmaxglob),PeriodicComponent(2))
  BGMkmin = MERGE(GEO%FIBGMkminglob,MAX(FLOOR((GEO%CNzmin-(halo_eps+maxCellRadius)-GEO%zminglob)/GEO%FIBGMdeltas(3)),0) + moveBGMindex                   ,PeriodicComponent(3))
  BGMkmax = MERGE(GEO%FIBGMkmaxglob,MIN(FLOOR((GEO%CNzmax+(halo_eps+maxCellRadius)-GEO%zminglob)/GEO%FIBGMdeltas(3))    + moveBGMindex,GEO%FIBGMkmaxglob),PeriodicComponent(3))
ELSE
  ! >> Take global maxima of cell radius into account and increase the considered range accordingly
  BGMimin = MAX(FLOOR((GEO%CNxmin-(halo_eps+maxCellRadius)-GEO%xminglob)/GEO%FIBGMdeltas(1)),0) + moveBGMindex
  BGMimax = MIN(FLOOR((GEO%CNxmax+(halo_eps+maxCellRadius)-GEO%xminglob)/GEO%FIBGMdeltas(1))    + moveBGMindex,GEO%FIBGMimaxglob)
  BGMjmin = MAX(FLOOR((GEO%CNymin-(halo_eps+maxCellRadius)-GEO%yminglob)/GEO%FIBGMdeltas(2)),0) + moveBGMindex
  BGMjmax = MIN(FLOOR((GEO%CNymax+(halo_eps+maxCellRadius)-GEO%yminglob)/GEO%FIBGMdeltas(2))    + moveBGMindex,GEO%FIBGMjmaxglob)
  BGMkmin = MAX(FLOOR((GEO%CNzmin-(halo_eps+maxCellRadius)-GEO%zminglob)/GEO%FIBGMdeltas(3)),0) + moveBGMindex
  BGMkmax = MIN(FLOOR((GEO%CNzmax+(halo_eps+maxCellRadius)-GEO%zminglob)/GEO%FIBGMdeltas(3))    + moveBGMindex,GEO%FIBGMkmaxglob)
END IF

! write function-local BGM indices into global variables
GEO%FIBGMimin = BGMimin
GEO%FIBGMimax = BGMimax
GEO%FIBGMjmin = BGMjmin
GEO%FIBGMjmax = BGMjmax
GEO%FIBGMkmin = BGMkmin
GEO%FIBGMkmax = BGMkmax
#else
BGMimin = BGMiminglob
BGMimax = BGMimaxglob
BGMjmin = BGMjminglob
BGMjmax = BGMjmaxglob
BGMkmin = BGMkminglob
BGMkmax = BGMkmaxglob

GEO%FIBGMimin = BGMimin
GEO%FIBGMimax = BGMimax
GEO%FIBGMjmin = BGMjmin
GEO%FIBGMjmax = BGMjmax
GEO%FIBGMkmin = BGMkmin
GEO%FIBGMkmax = BGMkmax
#endif /*USE_MPI*/

ALLOCATE(GEO%FIBGM(BGMimin:BGMimax,BGMjmin:BGMjmax,BGMkmin:BGMkmax))

! null number of element per BGM cell
DO kBGM = BGMkmin,BGMkmax
  DO jBGM = BGMjmin,BGMjmax
    DO iBGM = BGMimin,BGMimax
      GEO%FIBGM(iBGM,jBGM,kBGM)%nElem = 0
    END DO ! kBGM
  END DO ! jBGM
END DO ! iBGM

#if USE_MPI
! check which element is inside of compute-node domain (1),
! check which element is inside of compute-node halo (2)
! and which element is outside of compute-node domain (0)
! first do coarse check with BGM
IF (nComputeNodeProcessors.EQ.nProcessors_Global) THEN
  ! Single-node
  ElemInfo_Shared(ELEM_HALOFLAG,firstElem:lastElem) = 1
  ! initial values to eliminate compiler warnings
  firstHaloElem = -1
  lastHaloElem  = -1
ELSE
  ! Multi-node
  ElemInfo_Shared(ELEM_HALOFLAG,firstElem:lastElem) = 0
  ! Loop global elems
  DO iElem = firstElem, lastElem
    BGMCellXmin = ElemToBGM_Shared(1,iElem)
    BGMCellXmax = ElemToBGM_Shared(2,iElem)
    BGMCellYmin = ElemToBGM_Shared(3,iElem)
    BGMCellYmax = ElemToBGM_Shared(4,iElem)
    BGMCellZmin = ElemToBGM_Shared(5,iElem)
    BGMCellZmax = ElemToBGM_Shared(6,iElem)
    ! add current element to number of BGM-elems
    ! ATTENTION: THIS ONLY ADDS THE ELEMENT TO THE BGM CELLS ON THE NODE WHILE
    ! SKIPPING BGM CELLS OUTSIDE. WE END UP WITH PARTIALLY ADDED ELEMENTS
    DO iBGM = BGMCellXmin,BGMCellXmax
      IF(iBGM.LT.BGMimin) CYCLE
      IF(iBGM.GT.BGMimax) CYCLE
      DO jBGM = BGMCellYmin,BGMCellYmax
        IF(jBGM.LT.BGMjmin) CYCLE
        IF(jBGM.GT.BGMjmax) CYCLE
        DO kBGM = BGMCellZmin,BGMCellZmax
          IF(kBGM.LT.BGMkmin) CYCLE
          IF(kBGM.GT.BGMkmax) CYCLE
          !GEO%FIBGM(iBGM,jBGM,kBGM)%nElem = GEO%FIBGM(iBGM,jBGM,kBGM)%nElem + 1
          IF(iElem.GE.offsetComputeNodeElem+1 .AND. iElem.LE.offsetComputeNodeElem+nComputeNodeElems) THEN
            ElemInfo_Shared(ELEM_HALOFLAG,iElem) = 1 ! compute-node element
          ELSE
            ElemInfo_Shared(ELEM_HALOFLAG,iElem) = 2 ! halo element
          END IF
        END DO ! kBGM
      END DO ! jBGM
    END DO ! iBGM
  END DO ! iElem
  CALL BARRIER_AND_SYNC(ElemInfo_Shared_Win,MPI_COMM_SHARED)

  ! sum up potential halo elements and create correct offset mapping via ElemInfo_Shared
  nHaloElems = COUNT(ElemInfo_Shared(ELEM_HALOFLAG,:).EQ.2)

  ALLOCATE(offsetCNHalo2GlobalElem(1:nHaloElems))
  offsetCNHalo2GlobalElem = -1
  nHaloElems = 0
  DO iElem = 1, nGlobalElems
    IF (ElemInfo_Shared(ELEM_HALOFLAG,iElem).EQ.2) THEN
      nHaloElems = nHaloElems + 1
      offsetCNHalo2GlobalElem(nHaloElems) = iElem
    END IF
  END DO
  ! The code below changes ElemInfo_Shared, identification of halo elements must complete before
  CALL MPI_BARRIER(MPI_COMM_SHARED,IERROR)

  ! sum all MPI-side of compute-node and create correct offset mapping in SideInfo_Shared
  !nBorderSidesShared = COUNT(SideInfo_Shared(SIDE_NBELEMTYPE,:).EQ.2) + nBCSides
  nBorderSidesShared = 0
  DO iSide = 1, nNonUniqueGlobalSides
    ! Check for MPI sides or BC sides
    ! Node-to-node MPI interface
    IF ((SideInfo_Shared(SIDE_NBELEMTYPE,iSide).EQ.2).OR.&
       ! BC side + element on local proc (do not count multiple times) + skip inner BCs (they would otherwise be counted twice)
       ((SideInfo_Shared(SIDE_BCID      ,iSide).GT.0).AND.(ElementOnProc(SideInfo_Shared(SIDE_ELEMID,iSide)).AND.(SideInfo_Shared(SIDE_NBELEMID,iSide).EQ.0)))) THEN
      nBorderSidesShared = nBorderSidesShared + 1
    END IF

    ! check if the side is a big mortar side. Find big mortar sides that point outwards (node-to-node interfaces)
    NbElemID = SideInfo_Shared(SIDE_NBELEMID,iSide)
    IF (NbElemID.LT.0) THEN ! Mortar side (from particle_tracing.f90)
    nMortarElems = MERGE(4,2,SideInfo_Shared(SIDE_NBELEMID,iSide).EQ.-1)

      DO iMortar = 1,nMortarElems
        NbSideID = SideInfo_Shared(SIDE_NBSIDEID,iSide + iMortar)

        ! If small mortar element not defined, abort. Every available information on the compute-node is kept in shared memory, so
        ! no way to recover it during runtime
        IF (NbSideID.LT.1) CALL ABORT(__STAMP__,'Small mortar side not defined! iSide + iMortar=',iSide + iMortar)

        NbElemID = SideInfo_Shared(SIDE_ELEMID,NbSideID)
        ! If small mortar element not defined, abort. Every available information on the compute-node is kept in shared memory, so
        ! no way to recover it during runtime
        IF (NbElemID.LT.1) CALL ABORT(__STAMP__,'Small mortar element not defined! ElemID=',ElemID)

        ! Check if the small mortar element is on my own node or on a different node. Only consider if on a different node
        IF(.NOT.ElementOnNode(NbElemID))THEN
          nBorderSidesShared = nBorderSidesShared + 1
        END IF ! .NOT.ElementOnNode(NbElemID)
      END DO ! iMortar = 1,nMortarElems
    END IF ! NbElemID.LT.0
  END DO ! iSide = 1, nNonUniqueGlobalSides

  ALLOCATE(offsetMPISideShared(  nBorderSidesShared))
  ALLOCATE(metricMPISideShared(4,nBorderSidesShared))

  nBorderSidesShared = 0
  DO iSide = 1, nNonUniqueGlobalSides
    ! Check for MPI sides or BC sides
    ! Node-to-node MPI interface
    IF ((SideInfo_Shared(SIDE_NBELEMTYPE,iSide).EQ.2).OR.&
       ! BC side + element on local proc (do not count multiple times) + skip inner BCs (they would otherwise be counted twice)
       ((SideInfo_Shared(SIDE_BCID      ,iSide).GT.0).AND.(ElementOnProc(SideInfo_Shared(SIDE_ELEMID,iSide)).AND.(SideInfo_Shared(SIDE_NBELEMID,iSide).EQ.0)))) THEN
      nBorderSidesShared = nBorderSidesShared + 1
      offsetMPISideShared(nBorderSidesShared) = iSide
    END IF

    ! check if the side is a big mortar side. Find big mortar sides that point outwards (node-to-node interfaces)
    NbElemID = SideInfo_Shared(SIDE_NBELEMID,iSide)
    IF (NbElemID.LT.0) THEN ! Mortar side (from particle_tracing.f90)
    nMortarElems = MERGE(4,2,SideInfo_Shared(SIDE_NBELEMID,iSide).EQ.-1)

      DO iMortar = 1,nMortarElems
        NbSideID = SideInfo_Shared(SIDE_NBSIDEID,iSide + iMortar)

        ! If small mortar element not defined, abort. Every available information on the compute-node is kept in shared memory, so
        ! no way to recover it during runtime
        IF (NbSideID.LT.1) CALL ABORT(__STAMP__,'Small mortar side not defined! iSide + iMortar=',iSide + iMortar)

        NbElemID = SideInfo_Shared(SIDE_ELEMID,NbSideID)
        ! If small mortar element not defined, abort. Every available information on the compute-node is kept in shared memory, so
        ! no way to recover it during runtime
        IF (NbElemID.LT.1) CALL ABORT(__STAMP__,'Small mortar element not defined! ElemID=',ElemID)

        ! Check if the small mortar element is on my own node or on a different node. Only consider if on a different node
        IF(.NOT.ElementOnNode(NbElemID))THEN
          nBorderSidesShared = nBorderSidesShared + 1
          offsetMPISideShared(nBorderSidesShared) = iSide
        END IF ! .NOT.ElementOnNode(NbElemID)
      END DO ! iMortar = 1,nMortarElems
    END IF ! NbElemID.LT.0
  END DO ! iSide = 1, nNonUniqueGlobalSides

  ! calculate center and radius of each outward facing MPI-side of the compute-node
  !SELECT CASE(TrackingMethod)
    !CASE(TRACING,REFMAPPING)
      DO iSide = 1, nBorderSidesShared
        SideID = offsetMPISideShared(iSide)

        CALL DeCasteljauInterpolation(NGeo,(/0.0,0.0/),SideID,origin)
        metricMPISideShared(1:3,iSide) = origin(1:3)

        !> build side radius
        radiusMax = 0.
        DO q = 0,NGeo
          DO p = 0,NGeo
            vec(1:3) = BezierControlPoints3D(:,p,q,SideID) - origin
            radius   = DOTPRODUCT(Vec)
            radiusMax= MAX(radiusMax,radius)
          END DO
        END DO
        metricMPISideShared(4,iSide) = SQRT(RadiusMax)
      END DO

    !CASE(TRIATRACKING)
      !! the cornernodes are not the first 8 entries (for Ngeo>1) of nodeinfo array so mapping is built
      !CornerNodeIDswitch(1)=1
      !CornerNodeIDswitch(2)=(Ngeo+1)
      !CornerNodeIDswitch(3)=(Ngeo+1)**2
      !CornerNodeIDswitch(4)=(Ngeo+1)*Ngeo+1
      !CornerNodeIDswitch(5)=(Ngeo+1)**2*Ngeo+1
      !CornerNodeIDswitch(6)=(Ngeo+1)**2*Ngeo+(Ngeo+1)
      !CornerNodeIDswitch(7)=(Ngeo+1)**2*Ngeo+(Ngeo+1)**2
      !CornerNodeIDswitch(8)=(Ngeo+1)**2*Ngeo+(Ngeo+1)*Ngeo+1

      !! New crazy corner node switch (philipesque)
      !ASSOCIATE(CNS => CornerNodeIDswitch )
        !! CGNS Mapping
        !NodeMap(:,1)=(/CNS(1),CNS(4),CNS(3),CNS(2)/)
        !NodeMap(:,2)=(/CNS(1),CNS(2),CNS(6),CNS(5)/)
        !NodeMap(:,3)=(/CNS(2),CNS(3),CNS(7),CNS(6)/)
        !NodeMap(:,4)=(/CNS(3),CNS(4),CNS(8),CNS(7)/)
        !NodeMap(:,5)=(/CNS(1),CNS(5),CNS(8),CNS(4)/)
        !NodeMap(:,6)=(/CNS(5),CNS(6),CNS(7),CNS(8)/)

        !nFoundSides = 1
        !nBorderSidesLoop: DO iSide = 1, nBorderSidesShared

          !! Stop if all sides are found (note that the same SideID can be in the list multiple times if there are Mortars added)
          !!IPWRITE(UNIT_StdOut,*) "iSide,nFoundSides.GT.nBorderSidesShared =", iSide,nFoundSides.GT.nBorderSidesShared
          !IF(nFoundSides.GT.nBorderSidesShared) EXIT nBorderSidesLoop

          !SideID   = offsetMPISideShared(nFoundSides)
          !ElemID   = SideInfo_Shared(SIDE_ELEMID,SideID)
          !NbElemID = SideInfo_Shared(SIDE_NBELEMID,SideID)
          !!IPWRITE(UNIT_StdOut,*) "NbElemID =", NbElemID

          !! Only mortar (MPI node interfaces) sides: large mortar side
          !IF(NbElemID.LT.0)THEN ! Mortar side (from particle_tracing.f90)
            !nMortarElems = MERGE(4,2,SideInfo_Shared(SIDE_NBELEMID,SideID).EQ.-1)
              !DO iMortar = 1,nMortarElems
                !NbSideID = SideInfo_Shared(SIDE_NBSIDEID,SideID + iMortar)

                !! If small mortar element not defined, abort. Every available information on the compute-node is kept in shared memory, so
                !! no way to recover it during runtime
                !IF (NbSideID.LT.1) CALL ABORT(__STAMP__,'Small mortar side not defined! SideID + iMortar=',SideID + iMortar)

                !NbElemID = SideInfo_Shared(SIDE_ELEMID,NbSideID)
                !! If small mortar element not defined, abort. Every available information on the compute-node is kept in shared memory, so
                !! no way to recover it during runtime
                !IF (NbElemID.LT.1) CALL ABORT(__STAMP__,'Small mortar element not defined! ElemID=',ElemID)

                !! Check if the small mortar element is on my own node or on a different node. Only consider if on a different node
                !IF(.NOT.ElementOnNode(NbElemID))THEN
                  !localSideID = SideInfo_Shared(SIDE_LOCALID,NbSideID)

                  !! Find start of CGNS mapping from flip
                  !IF (SideInfo_Shared(SIDE_ID,NbSideID).GT.0) THEN
                    !nStart = 0
                  !ELSE
                    !nStart = MAX(0,MOD(SideInfo_Shared(SIDE_FLIP,NbSideID),10)-1)
                  !END IF
                  !! Shared memory array starts at 1, but NodeID at 0
                  !SideCornerNodeIDs(1:4) = (/ElemInfo_Shared(ELEM_FIRSTNODEIND,NbElemID)+NodeMap(MOD(nStart  ,4)+1,localSideID)-1, &
                                             !ElemInfo_Shared(ELEM_FIRSTNODEIND,NbElemID)+NodeMap(MOD(nStart+1,4)+1,localSideID)-1, &
                                             !ElemInfo_Shared(ELEM_FIRSTNODEIND,NbElemID)+NodeMap(MOD(nStart+2,4)+1,localSideID)-1, &
                                             !ElemInfo_Shared(ELEM_FIRSTNODEIND,NbElemID)+NodeMap(MOD(nStart+3,4)+1,localSideID)-1/)
                  !origin = 0.
                  !DO iNode = 1,4
                    !origin(1:3) = origin(1:3) + NodeCoords_Shared(1:3,SideCornerNodeIDs(iNode)+1)
                  !END DO
                  !metricMPISideShared(1:3,nFoundSides)= origin/4.

                  !!> build side radius
                  !radiusMax = 0.
                  !DO iNode = 1,4
                    !vec(1:3) = metricMPISideShared(1:3,nFoundSides) - origin
                    !radius   = DOTPRODUCT(Vec)
                    !radiusMax= MAX(radiusMax,radius)
                  !END DO
                  !metricMPISideShared(4,nFoundSides) = SQRT(RadiusMax)

                  !!IPWRITE(UNIT_StdOut,*) "iSide,nFoundSides,nBorderSidesShared =", iSide,nFoundSides,nBorderSidesShared
                  !nFoundSides = nFoundSides + 1
                !END IF ! .NOT.ElementOnNode(NbElemID)
              !END DO ! iMortar = 1,nMortarElems

          !ELSE
            !!localSideID = SideInfo_Shared(SIDE_LOCALID,SideID)
            !!IF(localSideID.LE.0) CALL abort(__STAMP__,'Local side ID cannot be smaller than 1: localSideID=',IntInfoOpt=localSideID)
            !nlocSides = ElemInfo_Shared(ELEM_LASTSIDEIND,ElemID) -  ElemInfo_Shared(ELEM_FIRSTSIDEIND,ElemID)
            !locSideLoop: DO iLocSide = 1,nlocSides

              !localSideID = SideInfo_Shared(SIDE_LOCALID,SideID)
              !IF (localSideID.LE.0) CYCLE locSideLoop

              !! Find start of CGNS mapping from flip
              !IF (SideInfo_Shared(SIDE_ID,SideID).GT.0) THEN
                !nStart = 0
              !ELSE
                !nStart = MAX(0,MOD(SideInfo_Shared(SIDE_FLIP,SideID),10)-1)
              !END IF
              !! Shared memory array starts at 1, but NodeID at 0
              !SideCornerNodeIDs(1:4) = (/ElemInfo_Shared(ELEM_FIRSTNODEIND,ElemID)+NodeMap(MOD(nStart  ,4)+1,localSideID)-1, &
                                         !ElemInfo_Shared(ELEM_FIRSTNODEIND,ElemID)+NodeMap(MOD(nStart+1,4)+1,localSideID)-1, &
                                         !ElemInfo_Shared(ELEM_FIRSTNODEIND,ElemID)+NodeMap(MOD(nStart+2,4)+1,localSideID)-1, &
                                         !ElemInfo_Shared(ELEM_FIRSTNODEIND,ElemID)+NodeMap(MOD(nStart+3,4)+1,localSideID)-1/)
              !origin = 0.
              !DO iNode = 1,4
                !origin(1:3) = origin(1:3) + NodeCoords_Shared(1:3,SideCornerNodeIDs(iNode)+1)
              !END DO
              !metricMPISideShared(1:3,nFoundSides)= origin/4.

              !!> build side radius
              !radiusMax = 0.
              !DO iNode = 1,4
                !vec(1:3) = metricMPISideShared(1:3,nFoundSides) - origin
                !radius   = DOTPRODUCT(Vec)
                !radiusMax= MAX(radiusMax,radius)
              !END DO
              !metricMPISideShared(4,nFoundSides) = SQRT(RadiusMax)

              !!IPWRITE(UNIT_StdOut,*) "iSide,nFoundSides,nBorderSidesShared =", iSide,nFoundSides,nBorderSidesShared
              !nFoundSides = nFoundSides + 1
              !EXIT locSideLoop
            !END DO locSideLoop ! iLocSide = 1,nlocSides



          !END IF ! NbElemID.LT.1
        !END DO nBorderSidesLoop! iSide = 1, nBorderSidesShared
      !END ASSOCIATE

  !END SELECT

  !IF(myrank.eq.0) read*; CALL MPI_BARRIER(MPI_COMM_WORLD,iError)
  ! Find the radius of the largest cell on the compute-node
  DO iElem = offsetElemMPI(ComputeNodeRootRank)+1,offsetElemMPI(ComputeNodeRootRank+nComputeNodeProcessors)
    maxCellRadius = MAX(maxCellRadius,VECNORM((/ BoundsOfElem_Shared(2,1,iElem)-BoundsOfElem_Shared(1,1,iElem), &
                                                 BoundsOfElem_Shared(2,2,iElem)-BoundsOfElem_Shared(1,2,iElem), &
                                                 BoundsOfElem_Shared(2,3,iElem)-BoundsOfElem_Shared(1,3,iElem)/)/2.))
  END DO

  ! Sanity check
  !DO iSide = 1, nBorderSidesShared
  !  DO i = 1, 4
  !    IF(ISNAN(metricMPISideShared(i,iSide)))THEN
  !      IPWRITE(UNIT_StdOut,*) "iSide,i,metricMPISideShared(i,iSide) =", iSide,i,metricMPISideShared(i,iSide)
  !      CALL abort(__STAMP__,'found NAN')
  !    END IF
  !  END DO ! i = 1, 4
  !END DO ! iSide = 1, nBorderSidesShared
  ! Sum of all compute-node elements in range of the MPI-sides of the compute-node
  nBorderElemsShared = 0
  DO iElem = offsetElemMPI(ComputeNodeRootRank)+1,offsetElemMPI(ComputeNodeRootRank+nComputeNodeProcessors)
    BoundsOfElemCenter(1:3) = (/ SUM(   BoundsOfElem_Shared(1:2,1,iElem)), &
                                 SUM(   BoundsOfElem_Shared(1:2,2,iElem)), &
                                 SUM(   BoundsOfElem_Shared(1:2,3,iElem)) /) / 2.

    DO iSide = 1, nBorderSidesShared
      !IPWRITE(UNIT_StdOut,*) "VECNORM(BoundsOfElemCenter(1:3)-metricMPISideShared(1:3,iSide)) =", VECNORM(BoundsOfElemCenter(1:3)-metricMPISideShared(1:3,iSide))
      !IPWRITE(UNIT_StdOut,*) "halo_eps+maxCellRadius+metricMPISideShared(4,iSide) =", halo_eps+maxCellRadius+metricMPISideShared(4,iSide)
      IF (VECNORM(BoundsOfElemCenter(1:3)-metricMPISideShared(1:3,iSide)) &
          .LE. halo_eps+maxCellRadius+metricMPISideShared(4,iSide) ) THEN
        nBorderElemsShared = nBorderElemsShared + 1
      END IF
    END DO
  END DO

  ! Build an array containing all compute-node elements in range of the MPI-sides of the compute-node
  ALLOCATE(offsetMPIElemShared(nBorderElemsShared))
  nBorderElemsShared = 0
  DO iElem = offsetElemMPI(ComputeNodeRootRank)+1,offsetElemMPI(ComputeNodeRootRank+nComputeNodeProcessors)
    BoundsOfElemCenter(1:3) = (/ SUM(   BoundsOfElem_Shared(1:2,1,iElem)), &
                                 SUM(   BoundsOfElem_Shared(1:2,2,iElem)), &
                                 SUM(   BoundsOfElem_Shared(1:2,3,iElem)) /) / 2.

    DO iSide = 1, nBorderSidesShared
      IF (VECNORM(BoundsOfElemCenter(1:3)-metricMPISideShared(1:3,iSide)) &
          .LE. halo_eps+maxCellRadius+metricMPISideShared(4,iSide) ) THEN
        nBorderElemsShared = nBorderElemsShared + 1
        offsetMPIElemShared(nBorderElemsShared) = iElem
      END IF
    END DO
  END DO

  DEALLOCATE(offsetMPISideShared)
  DEALLOCATE(metricMPISideShared)

  ! Distribute nHaloElements evenly on compute-node procs
  IF (nHaloElems.GT.nComputeNodeProcessors) THEN
    firstHaloElem = INT(REAL( myComputeNodeRank   *nHaloElems)/REAL(nComputeNodeProcessors))+1
    lastHaloElem  = INT(REAL((myComputeNodeRank+1)*nHaloElems)/REAL(nComputeNodeProcessors))
  ELSE
    firstHaloElem = myComputeNodeRank + 1
    IF (myComputeNodeRank.LT.nHaloElems) THEN
      lastHaloElem = myComputeNodeRank + 1
    ELSE
      lastHaloElem = 0
    END IF
  END IF

  ! Get centers and radii of all CN elements connected to MPI sides for distance check with the halo elements assigned to the proc
  ALLOCATE(MPISideBoundsOfElemCenter(1:4,1:nBorderElemsShared))
  DO iElem = 1, nBorderElemsShared
    ElemID = offsetMPIElemShared(iElem)
    MPISideBoundsOfElemCenter(1:3,iElem) = (/ SUM(   BoundsOfElem_Shared(1:2,1,ElemID)), &
                                              SUM(   BoundsOfElem_Shared(1:2,2,ElemID)), &
                                              SUM(   BoundsOfElem_Shared(1:2,3,ElemID)) /) / 2.
    ! Calculate outer radius of the element on my compute node
    MPISideBoundsOfElemCenter(4,iElem) = VECNORM ((/ BoundsOfElem_Shared(2,1,ElemID)-BoundsOfElem_Shared(1,1,ElemID), &
                                                     BoundsOfElem_Shared(2,2,ElemID)-BoundsOfElem_Shared(1,2,ElemID), &
                                                     BoundsOfElem_Shared(2,3,ElemID)-BoundsOfElem_Shared(1,3,ElemID) /) / 2.)
  END DO

  ! do refined check: (refined halo region reduction)
  ! check the bounding box of each element in compute-nodes' halo domain
  ! against the bounding boxes of the elements of the MPI-surface (inter compute-node MPI sides)
  DO iHaloElem = firstHaloElem, lastHaloElem
    ElemID = offsetCNHalo2GlobalElem(iHaloElem)
    ElemInsideHalo = .FALSE.
    BoundsOfElemCenter(1:3) = (/ SUM(   BoundsOfElem_Shared(1:2,1,ElemID)), &
                                 SUM(   BoundsOfElem_Shared(1:2,2,ElemID)), &
                                 SUM(   BoundsOfElem_Shared(1:2,3,ElemID)) /) / 2.
    ! Calculate halo element outer radius
    BoundsOfElemCenter(4) = VECNORM ((/ BoundsOfElem_Shared(2  ,1,ElemID)-BoundsOfElem_Shared(1,1,ElemID), &
                                        BoundsOfElem_Shared(2  ,2,ElemID)-BoundsOfElem_Shared(1,2,ElemID), &
                                        BoundsOfElem_Shared(2  ,3,ElemID)-BoundsOfElem_Shared(1,3,ElemID) /) / 2.)
    DO iElem = 1, nBorderElemsShared
      ! compare distance of centers with sum of element outer radii+halo_eps
      IF (VECNORM(BoundsOfElemCenter(1:3)-MPISideBoundsOfElemCenter(1:3,iElem)) &
          .GT. halo_eps+BoundsOfElemCenter(4)+MPISideBoundsOfElemCenter(4,iElem) ) CYCLE
      ElemInsideHalo = .TRUE.
      EXIT
    END DO ! iElem = 1, nBorderElemsShared
    IF (.NOT.ElemInsideHalo) THEN
      ElemInfo_Shared(ELEM_HALOFLAG,ElemID) = 0
    ELSE
      ! Only add element to BGM if inside halo region on node.
      ! THIS IS WRONG. WE ARE WORKING ON THE CN HALO REGION. IF WE OMIT THE
      ! ELEMENT HERE, WE LOOSE IT. IF WE KEEP IT, WE BREAK AT 589. YOUR CALL.
      CALL AddElementToFIBGM(ElemID)
    END IF
  END DO ! iHaloElem = firstHaloElem, lastHaloElem
END IF ! nComputeNodeProcessors.EQ.nProcessors_Global
CALL BARRIER_AND_SYNC(ElemInfo_Shared_Win            ,MPI_COMM_SHARED)

IF (MeshHasPeriodic)    CALL CheckPeriodicSides   (EnlargeBGM)
IF (MeshHasRotPeriodic) CALL CheckRotPeriodicSides(EnlargeBGM)
CALL BARRIER_AND_SYNC(ElemInfo_Shared_Win,MPI_COMM_SHARED)

! Mortar sides: Only multi-node
IF (nComputeNodeProcessors.NE.nProcessors_Global) THEN
  DO iElem = firstElem, lastElem
    IF (ElemInfo_Shared(ELEM_HALOFLAG,iElem).LT.1) CYCLE

    ! Loop over all sides and check for mortar sides
    DO iSide = ElemInfo_Shared(ELEM_FIRSTSIDEIND,iElem)+1,ElemInfo_Shared(ELEM_LASTSIDEIND,iElem)
      NbElemID = SideInfo_Shared(SIDE_NBELEMID,iSide)
      ! Mortar side
      IF (NbElemID.LT.0) THEN
        nMortarElems = MERGE(4,2,SideInfo_Shared(SIDE_NBELEMID,iSide).EQ.-1)

        DO iMortar = 1,nMortarElems
          NbSideID   = SideInfo_Shared(SIDE_NBSIDEID,iSide + iMortar)
          ElemID     = SideInfo_Shared(SIDE_ELEMID  ,NbSideID)

          ! Element not previously flagged
          IF (ElemInfo_Shared(ELEM_HALOFLAG,ElemID).LT.1) THEN
            ASSOCIATE(posElem => (ElemID-1)*ELEMINFOSIZE + (ELEM_HALOFLAG-1))
              CALL MPI_FETCH_AND_OP(haloChange,dummyInt,MPI_INTEGER,0,INT(posElem*SIZE_INT,MPI_ADDRESS_KIND),MPI_REPLACE,ElemInfo_Shared_Win,IERROR)
            END ASSOCIATE
          END IF
        END DO
      END IF
    END DO
  END DO
END IF

CALL BARRIER_AND_SYNC(ElemInfo_Shared_Win,MPI_COMM_SHARED)
#else
!ElemInfo_Shared(ELEM_HALOFLAG,:) = 1
#endif  /*USE_MPI*/

!--- compute number of elements in each background cell
DO iElem = offsetElem+1, offsetElem+nElems
  BGMCellXmin = ElemToBGM_Shared(1,iElem)
  BGMCellXmax = ElemToBGM_Shared(2,iElem)
  BGMCellYmin = ElemToBGM_Shared(3,iElem)
  BGMCellYmax = ElemToBGM_Shared(4,iElem)
  BGMCellZmin = ElemToBGM_Shared(5,iElem)
  BGMCellZmax = ElemToBGM_Shared(6,iElem)
  ! add current element to number of BGM-elems
  DO iBGM = BGMCellXmin,BGMCellXmax
    DO jBGM = BGMCellYmin,BGMCellYmax
      DO kBGM = BGMCellZmin,BGMCellZmax
        GEO%FIBGM(iBGM,jBGM,kBGM)%nElem = GEO%FIBGM(iBGM,jBGM,kBGM)%nElem + 1
      END DO ! kBGM
    END DO ! jBGM
  END DO ! iBGM
END DO ! iElem

#if USE_MPI
ALLOCATE(sendbuf(BGMimin:BGMimax,BGMjmin:BGMjmax,BGMkmin:BGMkmax))
ALLOCATE(recvbuf(BGMimin:BGMimax,BGMjmin:BGMjmax,BGMkmin:BGMkmax))
! find max nelems and offset in each BGM cell
DO iBGM = BGMimin,BGMimax
  DO jBGM = BGMjmin,BGMjmax
    DO kBGM = BGMkmin,BGMkmax
      sendbuf(iBGM,jBGM,kBGM)=GEO%FIBGM(iBGM,jBGM,kBGM)%nElem
      recvbuf(iBGM,jBGM,kBGM)=0
    END DO ! kBGM
  END DO ! jBGM
END DO ! iBGM

BGMiDelta = BGMimax - BGMimin
BGMjDelta = BGMjmax - BGMjmin
BGMkDelta = BGMkmax - BGMkmin
! allocated shared memory for nElems per BGM cell
! MPI shared memory is continuous, beginning from 1. All shared arrays have to
! be shifted to BGM[i]min with pointers
ALLOCATE(offsetElemsInBGMCell(BGMimin:BGMimax,BGMjmin:BGMjmax,BGMkmin:BGMkmax))
CALL MPI_EXSCAN(sendbuf(:,:,:),recvbuf(:,:,:),(BGMiDelta+1)*(BGMjDelta+1)*(BGMkDelta+1),MPI_INTEGER,MPI_SUM,MPI_COMM_SHARED,iError)
offsetElemsInBGMCell=recvbuf
DEALLOCATE(recvbuf)

! last proc of compute-node calculates total number of elements in each BGM-cell
! after this loop sendbuf of last proc contains nElems per BGM cell
IF(myComputeNodeRank.EQ.nComputeNodeProcessors-1)THEN
  DO iBGM = BGMimin,BGMimax
    DO jBGM = BGMjmin,BGMjmax
      DO kBGM = BGMkmin,BGMkmax
        sendbuf(iBGM,jBGM,kBGM)=offsetElemsInBGMCell(iBGM,jBGM,kBGM)+GEO%FIBGM(iBGM,jBGM,kBGM)%nElem
      END DO ! kBGM
    END DO ! jBGM
  END DO ! iBGM
END IF

! allocated shared memory for nElems per BGM cell
! MPI shared memory is continuous, beginning from 1. All shared arrays have to
! be shifted to BGM[i]min with pointers
CALL Allocate_Shared((/(BGMiDelta+1)*(BGMjDelta+1)*(BGMkDelta+1)/),FIBGM_nElems_Shared_Win,FIBGM_nElems_Shared)
CALL MPI_WIN_LOCK_ALL(0,FIBGM_nElems_Shared_Win,IERROR)
! allocated shared memory for BGM cell offset in 1D array of BGM to element mapping
CALL Allocate_Shared((/(BGMiDelta+1)*(BGMjDelta+1)*(BGMkDelta+1)/),FIBGM_offsetElem_Shared_Win,FIBGM_offsetElem_Shared)
CALL MPI_WIN_LOCK_ALL(0,FIBGM_offsetElem_Shared_Win,IERROR)
FIBGM_nElems     (BGMimin:BGMimax, BGMjmin:BGMjmax, BGMkmin:BGMkmax) => FIBGM_nElems_Shared
FIBGM_offsetElem (BGMimin:BGMimax, BGMjmin:BGMjmax, BGMkmin:BGMkmax) => FIBGM_offsetElem_Shared

! last proc of compute-node writes into shared memory to make nElems per BGM accessible for every proc
IF(myComputeNodeRank.EQ.nComputeNodeProcessors-1)THEN
  currentOffset = 0
  DO iBGM = BGMimin,BGMimax
    DO jBGM = BGMjmin,BGMjmax
      DO kBGM = BGMkmin,BGMkmax
        ! senfbuf and recvbuf have to stay on original position. Shift 1 --> BGMimin
        FIBGM_nElems(iBGM,jBGM,kBGM)     = sendbuf(iBGM,jBGM,kBGM)
        FIBGM_offsetElem(iBGM,jBGM,kBGM) = currentOffset
        currentOffset = currentoffset    + sendbuf(iBGM,jBGM,kBGM)
      END DO ! kBGM
    END DO ! jBGM
  END DO ! iBGM
END IF
DEALLOCATE(sendbuf)
CALL BARRIER_AND_SYNC(FIBGM_nElems_Shared_Win    ,MPI_COMM_SHARED)
CALL BARRIER_AND_SYNC(FIBGM_offsetElem_Shared_Win,MPI_COMM_SHARED)
#else /*NOT USE_MPI*/
ALLOCATE(FIBGM_nElems    (BGMimin:BGMimax, BGMjmin:BGMjmax, BGMkmin:BGMkmax))
ALLOCATE(FIBGM_offsetElem(BGMimin:BGMimax, BGMjmin:BGMjmax, BGMkmin:BGMkmax))
currentOffset = 0
  DO iBGM = BGMimin,BGMimax
    DO jBGM = BGMjmin,BGMjmax
      DO kBGM = BGMkmin,BGMkmax
      FIBGM_nElems(iBGM,jBGM,kBGM)     = GEO%FIBGM(iBGM,jBGM,kBGM)%nElem
      FIBGM_offsetElem(iBGM,jBGM,kBGM) = currentOffset
      currentOffset = currentoffset    + GEO%FIBGM(iBGM,jBGM,kBGM)%nElem
    END DO ! kBGM
  END DO ! jBGM
END DO ! iBGM
#endif  /*USE_MPI*/

#if USE_MPI
! allocate 1D array for mapping of BGM cell to Element indeces
CALL Allocate_Shared((/FIBGM_offsetElem(BGMimax,BGMjmax,BGMkmax)+FIBGM_nElems(BGMimax,BGMjmax,BGMkmax)/),FIBGM_Element_Shared_Win,FIBGM_Element_Shared)
CALL MPI_WIN_LOCK_ALL(0,FIBGM_Element_Shared_Win,IERROR)
FIBGM_Element => FIBGM_Element_Shared
#else
ALLOCATE( FIBGM_Element(1:FIBGM_offsetElem(BGMimax,BGMjmax,BGMkmax) + &
                          FIBGM_nElems    (BGMimax,BGMjmax,BGMkmax)))
#endif  /*USE_MPI*/

#if USE_MPI
IF (myComputeNodeRank.EQ.0) THEN
#endif /*USE_MPI*/
  FIBGM_Element = -1
#if USE_MPI
END IF
CALL BARRIER_AND_SYNC(FIBGM_Element_Shared_Win,MPI_COMM_SHARED)
#endif /*USE_MPI*/

DO iBGM = BGMimin,BGMimax
  DO jBGM = BGMjmin,BGMjmax
    DO kBGM = BGMkmin,BGMkmax
      GEO%FIBGM(iBGM,jBGM,kBGM)%nElem = 0
    END DO ! kBGM
  END DO ! jBGM
END DO ! iBGM

#if USE_MPI
! We might need to expand the halo BGM region
IF (nComputeNodeProcessors.NE.nProcessors_Global) THEN
  DO iElem = firstHaloElem, lastHaloElem
    ElemID = offsetCNHalo2GlobalElem(iElem)

    ! Only add non-peri halo elems
    IF (ElemInfo_Shared(ELEM_HALOFLAG,ElemID).NE.2) CYCLE

    BGMCellXmin = MAX(ElemToBGM_Shared(1,ElemID),BGMimin)
    BGMCellXmax = MIN(ElemToBGM_Shared(2,ElemID),BGMimax)
    BGMCellYmin = MAX(ElemToBGM_Shared(3,ElemID),BGMjmin)
    BGMCellYmax = MIN(ElemToBGM_Shared(4,ElemID),BGMjmax)
    BGMCellZmin = MAX(ElemToBGM_Shared(5,ElemID),BGMkmin)
    BGMCellZmax = MIN(ElemToBGM_Shared(6,ElemID),BGMkmax)

    ! add current Element to BGM-Elem
    DO kBGM = BGMCellZmin,BGMCellZmax
      DO jBGM = BGMCellYmin,BGMCellYmax
        DO iBGM = BGMCellXmin,BGMCellXmax
          GEO%FIBGM(iBGM,jBGM,kBGM)%nElem = GEO%FIBGM(iBGM,jBGM,kBGM)%nElem + 1
          FIBGM_Element( FIBGM_offsetElem(iBGM,jBGM,kBGM)            & ! offset of BGM cell in 1D array
                              + offsetElemsInBGMCell(iBGM,jBGM,kBGM) & ! offset of BGM nElems in local proc
                              + GEO%FIBGM(iBGM,jBGM,kBGM)%nElem) = ElemID
        END DO ! kBGM
      END DO ! jBGM
    END DO ! iBGM
  END DO ! iElem = firstHaloElem, lastHaloElem

  IF (EnlargeBGM) THEN
    firstElem = INT(REAL( myComputeNodeRank   *nGlobalElems)/REAL(nComputeNodeProcessors))+1
    lastElem  = INT(REAL((myComputeNodeRank+1)*nGlobalElems)/REAL(nComputeNodeProcessors))
    DO ElemID = firstElem, lastElem
      ! Only add peri halo elems
      IF (ElemInfo_Shared(ELEM_HALOFLAG,ElemID).NE.3) CYCLE

      BGMCellXmin = MAX(ElemToBGM_Shared(1,ElemID),BGMimin)
      BGMCellXmax = MIN(ElemToBGM_Shared(2,ElemID),BGMimax)
      BGMCellYmin = MAX(ElemToBGM_Shared(3,ElemID),BGMjmin)
      BGMCellYmax = MIN(ElemToBGM_Shared(4,ElemID),BGMjmax)
      BGMCellZmin = MAX(ElemToBGM_Shared(5,ElemID),BGMkmin)
      BGMCellZmax = MIN(ElemToBGM_Shared(6,ElemID),BGMkmax)

      ! add current Element to BGM-Elem
      DO kBGM = BGMCellZmin,BGMCellZmax
        DO jBGM = BGMCellYmin,BGMCellYmax
          DO iBGM = BGMCellXmin,BGMCellXmax
            GEO%FIBGM(iBGM,jBGM,kBGM)%nElem = GEO%FIBGM(iBGM,jBGM,kBGM)%nElem + 1
            IF (FIBGM_Element( FIBGM_offsetElem    (iBGM,jBGM,kBGM)        & ! offset of BGM cell in 1D array
                         + offsetElemsInBGMCell(iBGM,jBGM,kBGM)        & ! offset of BGM nElems in local proc
                         + GEO%FIBGM           (iBGM,jBGM,kBGM)%nElem).NE.-1) CALL ABORT(__STAMP__,'Double access')
            FIBGM_Element( FIBGM_offsetElem    (iBGM,jBGM,kBGM)        & ! offset of BGM cell in 1D array
                         + offsetElemsInBGMCell(iBGM,jBGM,kBGM)        & ! offset of BGM nElems in local proc
                         + GEO%FIBGM           (iBGM,jBGM,kBGM)%nElem) = ElemID
          END DO ! kBGM
        END DO ! jBGM
      END DO ! iBGM
    END DO ! iElem = firstHaloElem, lastHaloElem
  END IF ! (TrackingMethod.EQ.REFMAPPING .AND. GEO%nPeriodicVectors.GT.0)
END IF
#endif  /*USE_MPI*/

! Add local elements
DO iElem = offsetElem+1, offsetElem+nElems
  ! find element extent on BGM
  BGMCellXmin = MAX(ElemToBGM_Shared(1,iElem),BGMimin)
  BGMCellXmax = MIN(ElemToBGM_Shared(2,iElem),BGMimax)
  BGMCellYmin = MAX(ElemToBGM_Shared(3,iElem),BGMjmin)
  BGMCellYmax = MIN(ElemToBGM_Shared(4,iElem),BGMjmax)
  BGMCellZmin = MAX(ElemToBGM_Shared(5,iElem),BGMkmin)
  BGMCellZmax = MIN(ElemToBGM_Shared(6,iElem),BGMkmax)

  ! add current element to BGM-Elem
  DO kBGM = BGMCellZmin,BGMCellZmax
    DO jBGM = BGMCellYmin,BGMCellYmax
      DO iBGM = BGMCellXmin,BGMCellXmax
        GEO%FIBGM(iBGM,jBGM,kBGM)%nElem = GEO%FIBGM(iBGM,jBGM,kBGM)%nElem + 1
        FIBGM_Element( FIBGM_offsetElem(iBGM,jBGM,kBGM) & ! offset of BGM cell in 1D array
#if USE_MPI
                            + offsetElemsInBGMCell(iBGM,jBGM,kBGM)    & ! offset of BGM nElems in local proc
#endif  /*USE_MPI*/
                            + GEO%FIBGM(iBGM,jBGM,kBGM)%nElem         ) = iElem
      END DO ! kBGM
    END DO ! jBGM
  END DO ! iBGM
END DO ! iElem

#if USE_MPI
DEALLOCATE(offsetElemsInBGMCell)

CALL BARRIER_AND_SYNC(FIBGM_Element_Shared_Win,MPI_COMM_SHARED)

! Abort if FIBGM_Element still contains unfilled entries
IF (ANY(FIBGM_Element.EQ.-1)) CALL ABORT(__STAMP__,'Error while filling FIBGM element array: ANY(FIBGM_Element.EQ.-1)')

! Locally sum up Number of all elements on current compute-node (including halo region)
IF (nComputeNodeProcessors.EQ.nProcessors_Global) THEN
  nComputeNodeTotalElems = nGlobalElems
  nComputeNodeTotalSides = nNonUniqueGlobalSides
  nComputeNodeTotalNodes = nNonUniqueGlobalNodes
ELSE
  nComputeNodeTotalElems = 0
  nComputeNodeTotalSides = 0
  nComputeNodeTotalNodes = 0
  DO iElem = 1, nGlobalElems
    IF (ElemInfo_Shared(ELEM_HALOFLAG,iElem).NE.0) THEN
      nComputeNodeTotalElems = nComputeNodeTotalElems + 1
    END IF
  END DO
  ALLOCATE(CNTotalElem2GlobalElem(1:nComputeNodeTotalElems))
  ALLOCATE(GlobalElem2CNTotalElem(1:nGlobalElems))
  nComputeNodeTotalElems = 0
  GlobalElem2CNTotalElem(1:nGlobalElems) = -1
  ! CN-local elements
  DO iElem = 1,nGlobalElems
    IF (ElemInfo_Shared(ELEM_HALOFLAG,iElem).EQ.1) THEN
      nComputeNodeTotalElems = nComputeNodeTotalElems + 1
      CNTotalElem2GlobalElem(nComputeNodeTotalElems) = iElem
      GlobalElem2CNTotalElem(iElem) = nComputeNodeTotalElems
      nComputeNodeTotalSides = nComputeNodeTotalSides &
                             + (ElemInfo_Shared(ELEM_LASTSIDEIND,iElem) - ElemInfo_Shared(ELEM_FIRSTSIDEIND,iElem))
      nComputeNodeTotalNodes = nComputeNodeTotalNodes &
                             + (ElemInfo_Shared(ELEM_LASTNODEIND,iElem) - ElemInfo_Shared(ELEM_FIRSTNODEIND,iElem))
    END IF
  END DO
  ! CN-halo elements (non-periodic)
  DO iElem = 1,nGlobalElems
    IF (ElemInfo_Shared(ELEM_HALOFLAG,iElem).EQ.2) THEN
      nComputeNodeTotalElems = nComputeNodeTotalElems + 1
      CNTotalElem2GlobalElem(nComputeNodeTotalElems) = iElem
      GlobalElem2CNTotalElem(iElem) = nComputeNodeTotalElems
      nComputeNodeTotalSides = nComputeNodeTotalSides &
                             + (ElemInfo_Shared(ELEM_LASTSIDEIND,iElem) - ElemInfo_Shared(ELEM_FIRSTSIDEIND,iElem))
      nComputeNodeTotalNodes = nComputeNodeTotalNodes &
                             + (ElemInfo_Shared(ELEM_LASTNODEIND,iElem) - ElemInfo_Shared(ELEM_FIRSTNODEIND,iElem))
    END IF
  END DO
  ! CN-halo elements (periodic)
  DO iElem = 1,nGlobalElems
    IF ((ElemInfo_Shared(ELEM_HALOFLAG,iElem).EQ.3).OR.(ElemInfo_Shared(ELEM_HALOFLAG,iElem).EQ.4)) THEN
      nComputeNodeTotalElems = nComputeNodeTotalElems + 1
      CNTotalElem2GlobalElem(nComputeNodeTotalElems) = iElem
      GlobalElem2CNTotalElem(iElem) = nComputeNodeTotalElems
      nComputeNodeTotalSides = nComputeNodeTotalSides &
                             + (ElemInfo_Shared(ELEM_LASTSIDEIND,iElem) - ElemInfo_Shared(ELEM_FIRSTSIDEIND,iElem))
      nComputeNodeTotalNodes = nComputeNodeTotalNodes &
                             + (ElemInfo_Shared(ELEM_LASTNODEIND,iElem) - ElemInfo_Shared(ELEM_FIRSTNODEIND,iElem))
    END IF
  END DO
END IF

#ifdef CODE_ANALYZE
! Sanity checks
IF (  SUM(ElemInfo_Shared(ELEM_HALOFLAG,:)  ,MASK=ElemInfo_Shared(ELEM_HALOFLAG,:).EQ.1).NE.nComputeNodeElems) &
  CALL ABORT(__STAMP__,'Error with number of local elements on compute node')

IF ((SUM(ElemInfo_Shared(ELEM_HALOFLAG,:)  ,MASK=ElemInfo_Shared(ELEM_HALOFLAG,:).EQ.1) &
    +SUM(ElemInfo_Shared(ELEM_HALOFLAG,:)/2,MASK=ElemInfo_Shared(ELEM_HALOFLAG,:).EQ.2) &
    +SUM(ElemInfo_Shared(ELEM_HALOFLAG,:)/3,MASK=ElemInfo_Shared(ELEM_HALOFLAG,:).EQ.3)).NE.nComputeNodeTotalElems) &
  CALL ABORT(__STAMP__,'Error with number of halo elements on compute node')

! Debug output
IF (myRank.EQ.0) THEN
  SWRITE(Unit_StdOut,'(A)') ' DETERMINED compute-node (CN) halo region ...'
  SWRITE(Unit_StdOut,'(A)') ' | CN Rank | Local Elements | Halo Elements (non-peri) | Halo Elements (peri) |'
  CALL FLUSH(UNIT_stdOut)
  ALLOCATE(NumberOfElements(3*nLeaderGroupProcs))
END IF

IF (myComputeNodeRank.EQ.0) THEN
  ASSOCIATE( sendBuf => (/ &
        SUM(ElemInfo_Shared(ELEM_HALOFLAG,:)  ,MASK=ElemInfo_Shared(ELEM_HALOFLAG,:).EQ.1),  &
        SUM(ElemInfo_Shared(ELEM_HALOFLAG,:)/2,MASK=ElemInfo_Shared(ELEM_HALOFLAG,:).EQ.2),  &
        SUM(ElemInfo_Shared(ELEM_HALOFLAG,:)/3,MASK=ElemInfo_Shared(ELEM_HALOFLAG,:).EQ.3)/) )
    IF (myRank.EQ.0) THEN
      CALL MPI_GATHER(sendBuf , 3 , MPI_INTEGER , NumberOfElements , 3 , MPI_INTEGER , 0 , MPI_COMM_LEADERS_SHARED , iError)
    ELSE
      CALL MPI_GATHER(sendBuf , 3 , MPI_INTEGER , MPI_IN_PLACE     , 3 , MPI_INTEGER , 0 , MPI_COMM_LEADERS_SHARED , iError)
    END IF
  END ASSOCIATE
END IF

IF (myRank.EQ.0) THEN
  DO iProc = 0,nLeaderGroupProcs-1
    WRITE(Unit_StdOut,'(A,I7,A,I15,A,I25,A,I21,A)')  &
                                      ' |>',iProc, &
                                      ' |'  ,NumberOfElements(iProc*3+1), &
                                      ' |'  ,NumberOfElements(iProc*3+2), &
                                      ' |'  ,NumberOfElements(iProc*3+3), ' |'
  END DO
END IF
CALL MPI_BARRIER(MPI_COMM_WORLD,iError)
#endif /*CODE_ANALYZE*/

EndT = PICLASTIME()
SWRITE(UNIT_stdOut,'(A,E15.7,A,F0.3,A)') ' | Found max. cell radius as',maxCellRadius,', for building halo BGM ... DONE! ['&
,EndT-StartT,'s]'
SWRITE(UNIT_StdOut,'(132("-"))')

! ONLY IF HALO_EPS .LT. GLOBAL_DIAG
! ONLY IF EMISSION .EQ. 1 .OR. 2

!===================================================================================================================================
! Loop over all elements and build a global FIBGM to processor mapping. This is required to identify potential emission procs.
! However, this step must be performed in a distributed manner to avoid scaling issues during building of FIBGMToProcFlag.
!===================================================================================================================================
! This procedure outputs three arrays:
! - FIBGM_nTotalElems(FIBGMi,FIBGMj,FIBGMk) contains the total number of elements connected to each FIBGM cell
! - FIBGMProcs(nFIGBMTotalElems)            contains an 1D array of the MPI ranks connected to each FIBGM cell
! - FIBGMToProc(FIBGMi,FIBGMj,FIBGMk)       contains the offset and the number of MPI ranks connected to each FIGBM cell
!===================================================================================================================================
! The procedure consists of the following steps:
! 1.1) Each MPI rank runs over all local elements, adds them to the compute-node shared FIBGM_nTotalElems array and flags the
!      FIBGM cells it encounters in FIBGMToProcFlag
! 1.2) Compute node root adds up FIBGM_nTotalElems
! 2.1) Compute node root sums up the procs for each FIBGM cell on the current node
! 2.2) Compute node root communicates with other compute node roots to determine the total number and offset. At the end, the total
!      size required for the FIBGMProcs is known as well as the positions of each compute node root
! 2.3) Compute node root broadcasts the information on the compute node to allocate the shared array
! 2.4) Compute-node root fills the FIBGMToProc as well as the FIBGMProcs with the compute-node local information since it knows the
!      local FIBGMToProcFlag and its offset
! 2.5) Compute node root communicates the partially filled arrays between the other compute node roots to obtain the full array
!===================================================================================================================================
#endif /*USE_MPI*/

SWRITE(UNIT_stdOut,'(A)')' BUILDING FIBGM ELEMENT MAPPING ...'
#if USE_MPI
StartT=MPI_WTIME()
#else
CALL CPU_TIME(StartT)
#endif /*USE_MPI*/

#if USE_MPI
firstElem = INT(REAL( myComputeNodeRank   *nGlobalElems)/REAL(nComputeNodeProcessors))+1
lastElem  = INT(REAL((myComputeNodeRank+1)*nGlobalElems)/REAL(nComputeNodeProcessors))

! Flag each FIBGM element proc positive
BGMiglobDelta = BGMimaxglob - BGMiminglob
BGMjglobDelta = BGMjmaxglob - BGMjminglob
BGMkglobDelta = BGMkmaxglob - BGMkminglob

! Allocate array to hold the number of elements on each FIBGM cell
CALL Allocate_Shared((/(BGMiglobDelta+1)*(BGMjglobDelta+1)*(BGMkglobDelta+1)/),FIBGM_nTotalElems_Shared_Win,FIBGM_nTotalElems_Shared)
CALL MPI_WIN_LOCK_ALL(0,FIBGM_nTotalElems_Shared_Win,IERROR)

! Allocate flags which procs belong to which FIGBM cell
CALL Allocate_Shared((/(BGMiglobDelta+1)*(BGMjglobDelta+1)*(BGMkglobDelta+1)*nComputeNodeProcessors/),FIBGMToProcFlag_Shared_Win,FIBGMToProcFlag_Shared)
CALL MPI_WIN_LOCK_ALL(0,FIBGMToProcFlag_Shared_Win,IERROR)
FIBGM_nTotalElems(BGMiminglob:BGMimaxglob,BGMjminglob:BGMjmaxglob,BGMkminglob:BGMkmaxglob)                            => FIBGM_nTotalElems_Shared
FIBGMToProcFlag  (BGMiminglob:BGMimaxglob,BGMjminglob:BGMjmaxglob,BGMkminglob:BGMkmaxglob,0:nComputeNodeProcessors-1) => FIBGMToProcFlag_Shared

IF (myComputeNodeRank.EQ.0) THEN
  FIBGMToProcFlag   = .FALSE.
  FIBGM_nTotalElems = 0
END IF

CALL BARRIER_AND_SYNC(FIBGM_nTotalElems_Shared_Win,MPI_COMM_SHARED)
CALL BARRIER_AND_SYNC(FIBGMToProcFlag_Shared_Win  ,MPI_COMM_SHARED)

! 1.1) Count number of elements on compute node
DO iElem = offsetElem+1,offsetElem+nElems
  ProcRank = myRank - ComputeNodeRootRank

  DO kBGM = ElemToBGM_Shared(5,iElem),ElemToBGM_Shared(6,iElem)
    DO jBGM = ElemToBGM_Shared(3,iElem),ElemToBGM_Shared(4,iElem)
      DO iBGM = ElemToBGM_Shared(1,iElem),ElemToBGM_Shared(2,iElem)
        ASSOCIATE(posElem =>     (kBGM-1)*(BGMiglobDelta+1)*(BGMjglobDelta+1)                   + (jBGM-1)*(BGMiglobDelta+1)                   + (iBGM-1), &
                  posRank => INT(ProcRank*(BGMiglobDelta+1)*(BGMjglobDelta+1)*(BGMkglobDelta+1) + (kBGM-1)*(BGMiglobDelta+1)*(BGMjglobDelta+1) + (jBGM-1)*(BGMiglobDelta+1) + (iBGM-1),KIND=MPI_ADDRESS_KIND))

          ! Increment number of elements on FIBGM cell
          CALL MPI_FETCH_AND_OP(increment,dummyInt,MPI_INTEGER,0,INT(posElem*SIZE_INT,MPI_ADDRESS_KIND),MPI_SUM,FIBGM_nTotalElems_Shared_Win,IERROR)
          ! Perform logical OR and place data on CN root
          CALL MPI_FETCH_AND_OP(.TRUE.   ,dummyLog,MPI_LOGICAL,0,INT(posRank*SIZE_INT,MPI_ADDRESS_KIND),MPI_LOR,FIBGMToProcFlag_Shared_Win  ,IERROR)
        END ASSOCIATE
      END DO
    END DO
  END DO
END DO

CALL BARRIER_AND_SYNC(FIBGMToProcFlag_Shared_Win  ,MPI_COMM_SHARED)
CALL BARRIER_AND_SYNC(FIBGM_nTotalElems_Shared_Win,MPI_COMM_SHARED)

! 1.2) FIBGM_nTotalElems can just be added up
IF (myComputeNodeRank.EQ.0) THEN
  ! All-reduce between node leaders
  CALL MPI_ALLREDUCE(MPI_IN_PLACE,FIBGM_nTotalElems_Shared,(BGMiglobDelta+1)*(BGMjglobDelta+1)*(BGMkglobDelta+1),MPI_INTEGER,MPI_SUM,MPI_COMM_LEADERS_SHARED,iError)
END IF
CALL BARRIER_AND_SYNC(FIBGM_nTotalElems_Shared_Win,MPI_COMM_SHARED)

! Allocate shared array to hold the mapping
CALL Allocate_Shared((/2,BGMiglobDelta+1,BGMjglobDelta+1,BGMkglobDelta+1/),FIBGMToProc_Shared_Win,FIBGMToProc_Shared)
CALL MPI_WIN_LOCK_ALL(0,FIBGMToProc_Shared_Win,IERROR)
FIBGMToProc => FIBGMToProc_Shared

IF (myComputeNodeRank.EQ.0) FIBGMToProc = 0
CALL BARRIER_AND_SYNC(FIBGMToProc_Shared_Win,MPI_COMM_SHARED)

IF (myComputeNodeRank.EQ.0) THEN

  ! Compute-node local array to hold local number of elements
  ALLOCATE(FIBGM_LocalProcs(3,BGMiglobDelta+1,BGMjglobDelta+1,BGMkglobDelta+1))
  FIBGM_LocalProcs = 0

  ! 2.1) Count the number of procs on the current root
  DO kBGM = BGMkminglob,BGMkmaxglob
    DO jBGM = BGMjminglob,BGMjmaxglob
      DO iBGM = BGMiminglob,BGMimaxglob
        ! Save number of procs per FIBGM element
        DO iProc = 0,nComputeNodeProcessors-1
          ! Proc belongs to current FIBGM cell
          IF (FIBGMToProcFlag(iBGM,jBGM,kBGM,iProc)) THEN
            FIBGM_LocalProcs(FIBGM_NLOCALPROCS,iBGM,jBGM,kBGM) = FIBGM_LocalProcs(FIBGM_NLOCALPROCS,iBGM,jBGM,kBGM) + 1
          END IF
        END DO
      END DO
    END DO
  END DO

  ALLOCATE(sendbuf(BGMiglobDelta+1,BGMjglobDelta+1,BGMkglobDelta+1)&
          ,recvbuf(BGMiglobDelta+1,BGMjglobDelta+1,BGMkglobDelta+1))

  ! 2.2) Communicate with other compute node roots to determine the total number and offset
  sendbuf = FIBGM_LocalProcs(FIBGM_NLOCALPROCS,:,:,:)
  recvbuf = 0

  CALL MPI_EXSCAN(sendbuf,recvbuf,(BGMiglobDelta+1)*(BGMjglobDelta+1)*(BGMkglobDelta+1) &
                 ,MPI_INTEGER,MPI_SUM            ,MPI_COMM_LEADERS_SHARED,iError)

  ! Save the global proc offset for each FIBGM cell
  FIBGM_LocalProcs(FIBGM_FIRSTPROCIND,:,:,:) = recvbuf

  ! Last proc knows global number of procs per FIBGM cell
  sendbuf = recvbuf + FIBGM_LocalProcs(FIBGM_NLOCALPROCS,:,:,:)

  CALL MPI_BCAST (sendbuf        ,(BGMiglobDelta+1)*(BGMjglobDelta+1)*(BGMkglobDelta+1) &
                 ,MPI_INTEGER,nLeaderGroupProcs-1,MPI_COMM_LEADERS_SHARED,iError)
  FIBGM_LocalProcs(FIBGM_NPROCS,:,:,:) = sendbuf

  DEALLOCATE(sendbuf)
  DEALLOCATE(recvbuf)

  ! Determine global size of mapping array
  nFIBGMToProc = SUM(FIBGM_LocalProcs(FIBGM_NPROCS,:,:,:))
END IF

! 2.3) Broadcast the information on the compute node to allocate the shared array
CALL MPI_BCAST(nFIBGMToProc,1,MPI_INTEGER,0,MPI_COMM_SHARED,iError)

! Allocate shared array to hold the proc information
CALL Allocate_Shared((/nFIBGMToProc/),FIBGMProcs_Shared_Win,FIBGMProcs_Shared)
CALL MPI_WIN_LOCK_ALL(0,FIBGMProcs_Shared_Win,IERROR)
FIBGMProcs => FIBGMProcs_Shared

IF (myComputeNodeRank.EQ.0) FIBGMProcs= -1
CALL BARRIER_AND_SYNC(FIBGMProcs_Shared_Win,MPI_COMM_SHARED)

! 2.4) Compute-node root fills the information
IF (myComputeNodeRank.EQ.0) THEN
  FIBGMToProc(FIBGM_NPROCS,:,:,:) = FIBGM_LocalProcs(FIBGM_NPROCS      ,:,:,:)
  nFIBGM = 0

  DO kBGM = BGMkminglob,BGMkmaxglob
    DO jBGM = BGMjminglob,BGMjmaxglob
      DO iBGM = BGMiminglob,BGMimaxglob
        ! Save offset of procs per FIBGM element
        FIBGMToProc(FIBGM_FIRSTPROCIND,iBGM,jBGM,kBGM) = nFIBGM

        ! Save number of procs per FIBGM element
        nFIBGMToProc = 0
        DO iProc = 0,nComputeNodeProcessors-1
          ! Proc belongs to current FIBGM cell
          IF (FIBGMToProcFlag(iBGM,jBGM,kBGM,iProc)) THEN
            nFIBGMToProc = nFIBGMToProc + 1
            FIBGMProcs(nFIBGM + FIBGM_LocalProcs(FIBGM_FIRSTPROCIND,iBGM,jBGM,kBGM) + nFIBGMToProc) = iProc + ComputeNodeRootRank
          END IF
        END DO

        ! Increment the offset
        nFIBGM = nFIBGM + FIBGMToProc(FIBGM_NPROCS,iBGM,jBGM,kBGM)
      END DO
    END DO
  END DO

  ! Restore global size of mapping array
  nFIBGMToProc = SUM(FIBGM_LocalProcs(FIBGM_NPROCS,:,:,:))
  DEALLOCATE(FIBGM_LocalProcs)

  ! 2.5) Communicate the partially filled arrays between the procs
  ! > Technically, this could be an MPI_ALLGATHERV but good luck figuring out the linearized displacements
  CALL MPI_ALLREDUCE(MPI_IN_PLACE,FIBGMProcs,nFIBGMToProc,MPI_INTEGER,MPI_MAX,MPI_COMM_LEADERS_SHARED,iError)
END IF

! De-allocate FLAG array
CALL MPI_BARRIER(MPI_COMM_SHARED,iERROR)
CALL UNLOCK_AND_FREE(FIBGMToProcFlag_Shared_Win)
CALL MPI_BARRIER(MPI_COMM_SHARED,iERROR)

! Then, free the pointers or arrays
ADEALLOCATE(FIBGMToProcFlag_Shared)
ADEALLOCATE(FIBGMToProcFlag)

CALL BARRIER_AND_SYNC(FIBGMProcs_Shared_Win ,MPI_COMM_SHARED)
CALL BARRIER_AND_SYNC(FIBGMToProc_Shared_Win,MPI_COMM_SHARED)
#endif /*USE_MPI*/

EndT = PICLASTIME()
SWRITE(UNIT_stdOut,'(A,F0.3,A)')' BUILDING FIBGM ELEMENT MAPPING DONE! [',EndT-StartT,'s]'
SWRITE(UNIT_StdOut,'(132("-"))')

! and get max number of bgm-elems
ALLOCATE(Distance    (1:MAXVAL(FIBGM_nElems)) &
        ,ListDistance(1:MAXVAL(FIBGM_nElems)) )

#if USE_MPI
! Build a local nNonUniqueSides to nComputeNodeSides/nComputeNodeTotalSides mapping
ALLOCATE(CNTotalSide2GlobalSide(1:nComputeNodeTotalSides))
ALLOCATE(GlobalSide2CNTotalSide(1:nNonUniqueGlobalSides))

! Use MessageSize to temporally store the previous value
MessageSize = nComputeNodeTotalSides
nComputeNodeSides      = 0
nComputeNodeTotalSides = 0
GlobalSide2CNTotalSide(:) = -1
CNTotalSide2GlobalSide(:) = -1

! CN-local elements
DO iElem = 1,nComputeNodeElems
  ElemID = iElem + offsetComputeNodeElem

  ! Loop over all sides
  DO iSide = ElemInfo_Shared(ELEM_FIRSTSIDEIND,ElemID)+1,ElemInfo_Shared(ELEM_LASTSIDEIND,ElemID)
    ! Check if side was already added
    ! IF (GlobalSide2CNTotalSide(iSide).NE.-1) CYCLE

    nComputeNodeSides             = nComputeNodeSides      + 1
    nComputeNodeTotalSides        = nComputeNodeTotalSides + 1
    CNTotalSide2GlobalSide(nComputeNodeTotalSides) = iSide
    GlobalSide2CNTotalSide(iSide) = nComputeNodeTotalSides
  END DO
END DO

! CN-halo elements
Do iElem = nComputeNodeElems + 1,nComputeNodeTotalElems
  ElemID = CNTotalElem2GlobalElem(iElem)

  ! Loop over all sides
  DO iSide = ElemInfo_Shared(ELEM_FIRSTSIDEIND,ElemID)+1,ElemInfo_Shared(ELEM_LASTSIDEIND,ElemID)
    ! Check if side was already added
    ! IF (GlobalSide2CNTotalSide(iSide).NE.-1) CYCLE

    nComputeNodeTotalSides        = nComputeNodeTotalSides + 1
    CNTotalSide2GlobalSide(nComputeNodeTotalSides) = iSide
    GlobalSide2CNTotalSide(iSide) = nComputeNodeTotalSides
  END DO
END DO

! Sanity check
IF (nComputeNodeSides.NE.ElemInfo_Shared(ELEM_LASTSIDEIND,offsetComputeNodeElem+nComputeNodeElems)-ElemInfo_Shared(ELEM_FIRSTSIDEIND,offsetComputeNodeElem+1)) &
  CALL ABORT(__STAMP__,'Error with number of local sides on compute node')

IF (nComputeNodeTotalSides.NE.MessageSize) &
  CALL ABORT(__STAMP__,'Error with number of halo sides on compute node')

! ElemToBGM is only used during init. First, free every shared memory window. This requires MPI_BARRIER as per MPI3.1 specification
CALL MPI_BARRIER(MPI_COMM_SHARED,iERROR)

CALL UNLOCK_AND_FREE(ElemToBGM_Shared_Win)

CALL MPI_BARRIER(MPI_COMM_SHARED,iERROR)

#endif /*USE_MPI*/
! Then, free the pointers or arrays
ADEALLOCATE(ElemToBGM_Shared)

END SUBROUTINE BuildBGMAndIdentifyHaloRegion


SUBROUTINE FinalizeBGM()
!===================================================================================================================================
! Deallocates variables for the particle background mesh
!===================================================================================================================================
! MODULES
USE MOD_Globals
USE MOD_MPI_Shared_Vars
USE MOD_MPI_Shared
USE MOD_Particle_Mesh_Vars
!-----------------------------------------------------------------------------------------------------------------------------------
! INPUT VARIABLES
!-----------------------------------------------------------------------------------------------------------------------------------
! OUTPUT VARIABLES
!-----------------------------------------------------------------------------------------------------------------------------------
! LOCAL VARIABLES
!===================================================================================================================================

! First, free every shared memory window. This requires MPI_BARRIER as per MPI3.1 specification
#if USE_MPI
CALL MPI_BARRIER(MPI_COMM_SHARED,iERROR)

!CALL UNLOCK_AND_FREE(ElemToBGM_Shared_Win)
CALL UNLOCK_AND_FREE(BoundsOfElem_Shared_Win)
CALL UNLOCK_AND_FREE(FIBGM_nTotalElems_Shared_Win)
CALL UNLOCK_AND_FREE(FIBGM_nElems_Shared_Win)
CALL UNLOCK_AND_FREE(FIBGM_offsetElem_Shared_Win)
CALL UNLOCK_AND_FREE(FIBGM_Element_Shared_Win)
CALL UNLOCK_AND_FREE(FIBGMToProc_Shared_Win)
CALL UNLOCK_AND_FREE(FIBGMProcs_Shared_Win)

CALL MPI_BARRIER(MPI_COMM_SHARED,iERROR)

! Then, free the pointers or arrays
SDEALLOCATE(CNTotalElem2GlobalElem)
SDEALLOCATE(GlobalElem2CNTotalElem)
SDEALLOCATE(CNTotalSide2GlobalSide)
SDEALLOCATE(GlobalSide2CNTotalSide)
#endif /*USE_MPI*/

!ADEALLOCATE(ElemToBGM_Shared)
ADEALLOCATE(BoundsOfElem_Shared)
ADEALLOCATE(FIBGM_nTotalElems)
ADEALLOCATE(FIBGM_nTotalElems_Shared)
ADEALLOCATE(FIBGM_nElems)
ADEALLOCATE(FIBGM_nElems_Shared)
ADEALLOCATE(FIBGM_offsetElem)
ADEALLOCATE(FIBGM_offsetElem_Shared)
ADEALLOCATE(FIBGM_Element)
ADEALLOCATE(FIBGM_Element_Shared)
ADEALLOCATE(FIBGMToProc)
ADEALLOCATE(FIBGMToProc_Shared)
ADEALLOCATE(FIBGMProcs)
ADEALLOCATE(FIBGMProcs_Shared)

#if USE_MPI
CALL FinalizeHaloInfo()
#endif /*USE_MPI*/

END SUBROUTINE FinalizeBGM


#if USE_MPI
!===================================================================================================================================
! Writes the HaloFlag of each compute-node into an ElemData array 'CNRankX_ElemHaloInfo'
!===================================================================================================================================
SUBROUTINE WriteHaloInfo()
! MODULES                                                                                                                          !
USE MOD_Globals
USE MOD_Preproc
USE MOD_IO_HDF5                ,ONLY: AddToElemData,ElementOut
USE MOD_Mesh_Vars              ,ONLY: nGlobalElems,offsetElem
USE MOD_MPI_Shared
USE MOD_MPI_Shared_Vars        ,ONLY: myComputeNodeRank,myLeaderGroupRank,nLeaderGroupProcs
USE MOD_MPI_Shared_Vars        ,ONLY: MPI_COMM_SHARED,MPI_COMM_LEADERS_SHARED
USE MOD_Particle_Mesh_Vars     ,ONLY: ElemHaloID
USE MOD_Particle_Mesh_Vars     ,ONLY: ElemHaloInfo_Array,ElemHaloInfo_Shared,ElemHaloInfo_Shared_Win,ElemInfo_Shared
! IMPLICIT VARIABLE HANDLING
IMPLICIT NONE
!----------------------------------------------------------------------------------------------------------------------------------
! INPUT / OUTPUT VARIABLES

!-----------------------------------------------------------------------------------------------------------------------------------
! LOCAL VARIABLES
INTEGER                        :: iRank,iElem
CHARACTER(LEN=255)             :: tmpStr
!===================================================================================================================================

SWRITE(UNIT_stdOut,'(A)',ADVANCE='YES') " ADDING halo debug information to State file..."

! Allocate array in shared memory for each compute-node rank
CALL Allocate_Shared((/nGlobalElems*nLeaderGroupProcs/),ElemHaloInfo_Shared_Win,ElemHaloInfo_Array)
CALL MPI_WIN_LOCK_ALL(0,ElemHaloInfo_Shared_Win,iERROR)
ElemHaloInfo_Shared(1:nGlobalElems,0:nLeaderGroupProcs-1) => ElemHaloInfo_Array

ElemHaloInfo_Shared(:,myLeaderGroupRank) = ElemInfo_Shared(ELEM_HALOFLAG,:)

! Communicate halo information between compute-nodes
IF (myComputeNodeRank.EQ.0) THEN
  DO iRank = 0,nLeaderGroupProcs-1
    CALL MPI_BCAST(ElemHaloInfo_Shared(:,iRank),nGlobalElems,MPI_INTEGER,iRank,MPI_COMM_LEADERS_SHARED,iERROR)
  END DO
END IF

! Synchronize information on each compute-node
CALL BARRIER_AND_SYNC(ElemHaloInfo_Shared_Win,MPI_COMM_SHARED)

! Add ElemInfo halo information to ElemData
DO iRank = 0,nLeaderGroupProcs-1
  WRITE(UNIT=tmpStr,FMT='(I0)') iRank
  CALL AddToElemData(ElementOut,'CNRank'//TRIM(tmpStr)//'_ElemHaloInfo',IntArray=ElemHaloInfo_Shared(offsetElem+1:offsetElem+PP_nElems,iRank))
END DO

! Add ElemHaloID information to ElemData to ease debugging
ALLOCATE(ElemHaloID(1:PP_nElems))
DO iElem = 1,PP_nElems
  ElemHaloID(iElem) = offsetElem+iElem
END DO
CALL AddToElemData(ElementOut,'ElemID_ElemHaloInfo',IntArray=ElemHaloID)

END SUBROUTINE WriteHaloInfo


!===================================================================================================================================
! Deallocates variables for the particle halo debug information
!===================================================================================================================================
SUBROUTINE FinalizeHaloInfo()
! MODULES                                                                                                                          !
USE MOD_Globals
USE MOD_Preproc
USE MOD_Analyze_Vars           ,ONLY: CalcHaloInfo
USE MOD_MPI_Shared
USE MOD_MPI_Shared_Vars        ,ONLY: MPI_COMM_SHARED
USE MOD_Particle_Mesh_Vars     ,ONLY: ElemHaloID
USE MOD_Particle_Mesh_Vars     ,ONLY: ElemHaloInfo_Array,ElemHaloInfo_Shared,ElemHaloInfo_Shared_Win
! IMPLICIT VARIABLE HANDLING
IMPLICIT NONE
!----------------------------------------------------------------------------------------------------------------------------------
! INPUT / OUTPUT VARIABLES

!-----------------------------------------------------------------------------------------------------------------------------------
! LOCAL VARIABLES
!===================================================================================================================================

IF (.NOT.CalcHaloInfo) RETURN

! First, free every shared memory window. This requires MPI_BARRIER as per MPI3.1 specification
CALL MPI_BARRIER(MPI_COMM_SHARED,iERROR)
CALL UNLOCK_AND_FREE(ElemHaloInfo_Shared_Win)

! Then, free the pointers or arrays
ADEALLOCATE(ElemHaloInfo_Shared)
ADEALLOCATE(ElemHaloInfo_Array)

SDEALLOCATE(ElemHaloID)

END SUBROUTINE FinalizeHaloInfo
#endif /*USE_MPI*/


#if USE_MPI
SUBROUTINE CheckPeriodicSides(EnlargeBGM)
!===================================================================================================================================
!> checks the elements against periodic distance
!===================================================================================================================================
! MODULES                                                                                                                          !
!----------------------------------------------------------------------------------------------------------------------------------!
USE MOD_Globals
USE MOD_Preproc
USE MOD_Mesh_Vars              ,ONLY: nGlobalElems
USE MOD_MPI_Shared_Vars
USE MOD_Particle_Mesh_Vars     ,ONLY: GEO
USE MOD_Particle_Mesh_Vars     ,ONLY: ElemInfo_Shared,BoundsOfElem_Shared,nComputeNodeElems
USE MOD_Particle_MPI_Vars      ,ONLY: halo_eps
USE MOD_MPI_Vars               ,ONLY: offsetElemMPI
! IMPLICIT VARIABLE HANDLING
IMPLICIT NONE
!----------------------------------------------------------------------------------------------------------------------------------!
! INPUT VARIABLES
LOGICAL,INTENT(IN)             :: EnlargeBGM ! Flag used for enlarging the BGM if RefMapping and/or shape function is used
!----------------------------------------------------------------------------------------------------------------------------------!
! OUTPUT VARIABLES
!-----------------------------------------------------------------------------------------------------------------------------------
! LOCAL VARIABLES
INTEGER                        :: iElem,firstElem,lastElem,iDir,jDir,kDir
INTEGER                        :: iLocElem
INTEGER                        :: iPeriodicVector,jPeriodicVector
REAL                           :: BoundsOfElemCenter(1:4),LocalBoundsOfElemCenter(1:4)
!===================================================================================================================================

firstElem = INT(REAL( myComputeNodeRank   *nGlobalElems)/REAL(nComputeNodeProcessors))+1
lastElem  = INT(REAL((myComputeNodeRank+1)*nGlobalElems)/REAL(nComputeNodeProcessors))

! The code below changes ElemInfo_Shared, identification of periodic elements must complete before
CALL MPI_BARRIER(MPI_COMM_SHARED,IERROR)

! This is a distributed loop. Nonetheless, the load will be unbalanced due to the location of the space-filling curve. Still,
! this approach is again preferred compared to the communication overhead.
DO iElem = firstElem,lastElem
  ! only consider elements that are not already flagged
  IF (ElemInfo_Shared(ELEM_HALOFLAG,iElem).GT.0) CYCLE

  BoundsOfElemCenter(1:3) = (/ SUM(   BoundsOfElem_Shared(1:2,1,iElem)),                                                   &
                               SUM(   BoundsOfElem_Shared(1:2,2,iElem)),                                                   &
                               SUM(   BoundsOfElem_Shared(1:2,3,iElem)) /) / 2.
  BoundsOfElemCenter(4) = VECNORM ((/ BoundsOfElem_Shared(2  ,1,iElem)-BoundsOfElem_Shared(1,1,iElem),                     &
                                      BoundsOfElem_Shared(2  ,2,iElem)-BoundsOfElem_Shared(1,2,iElem),                     &
                                      BoundsOfElem_Shared(2  ,3,iElem)-BoundsOfElem_Shared(1,3,iElem) /) / 2.)

! Use a named loop so the entire element can be cycled
ElemLoop: DO iLocElem = offsetElemMPI(ComputeNodeRootRank)+1, offsetElemMPI(ComputeNodeRootRank)+nComputeNodeElems
    ! element might be already added back
    IF (ElemInfo_Shared(ELEM_HALOFLAG,iElem).GT.0) EXIT ElemLoop

    LocalBoundsOfElemCenter(1:3) = (/ SUM(   BoundsOfElem_Shared(1:2,1,iLocElem)),                                         &
                                      SUM(   BoundsOfElem_Shared(1:2,2,iLocElem)),                                         &
                                      SUM(   BoundsOfElem_Shared(1:2,3,iLocElem)) /) / 2.
    LocalBoundsOfElemCenter(4) = VECNORM ((/ BoundsOfElem_Shared(2  ,1,iLocElem)-BoundsOfElem_Shared(1,1,iLocElem),        &
                                             BoundsOfElem_Shared(2  ,2,iLocElem)-BoundsOfElem_Shared(1,2,iLocElem),        &
                                             BoundsOfElem_Shared(2  ,3,iLocElem)-BoundsOfElem_Shared(1,3,iLocElem) /) / 2.)

    SELECT CASE(GEO%nPeriodicVectors)

      CASE(1)
        ! check two directions
        DO iDir = -1, 1, 2
          ! check if element is within halo_eps of periodically displaced element
          IF (VECNORM( BoundsOfElemCenter(1:3) + GEO%PeriodicVectors(1:3,1)*REAL(iDir) - LocalBoundsOfElemCenter(1:3))&
                  .LE. halo_eps+BoundsOfElemCenter(4)+LocalBoundsOfElemCenter(4))THEN
            ! add element back to halo region
            ElemInfo_Shared(ELEM_HALOFLAG,iElem) = 3
            IF (EnlargeBGM) CALL AddElementToFIBGM(iElem)
            EXIT ElemLoop
          END IF
        END DO

      CASE(2)
        ! check the two possible periodic vectors. Begin with checking the single periodic vector, followed by the combination of
        ! the first periodic vector with the other, 1,2,1+2
        DO iPeriodicVector = 1,2
          ! element might be already added back
          IF (ElemInfo_Shared(ELEM_HALOFLAG,iElem).GT.0) EXIT ElemLoop

          DO iDir = -1, 1, 2
            ! check if element is within halo_eps of periodically displaced element
            IF (VECNORM( BoundsOfElemCenter(1:3)                                                           &
                      + GEO%PeriodicVectors(1:3,iPeriodicVector)*REAL(iDir) - LocalBoundsOfElemCenter(1:3))&
                      .LE. halo_eps+BoundsOfElemCenter(4)+LocalBoundsOfElemCenter(4))THEN
              ! add element back to halo region
              ElemInfo_Shared(ELEM_HALOFLAG,iElem) = 3
              IF (EnlargeBGM) CALL AddElementToFIBGM(iElem)
              EXIT ElemLoop
            END IF
          END DO ! iDir = -1, 1, 2

          ! Check linear combination of two periodic vectors
          DO jPeriodicVector = 1,2
            IF (iPeriodicVector.GE.jPeriodicVector) CYCLE

            DO iDir = -1, 1, 2
              DO jDir = -1, 1, 2
                ! check if element is within halo_eps of periodically displaced element
                IF (VECNORM( BoundsOfElemCenter(1:3)                                                             &
                          + GEO%PeriodicVectors(1:3,iPeriodicVector)*REAL(iDir)                                  &
                          + GEO%PeriodicVectors(1:3,jPeriodicVector)*REAL(jDir) - LocalBoundsOfElemCenter(1:3) ) &
                          .LE. halo_eps+BoundsOfElemCenter(4)+LocalBoundsOfElemCenter(4))THEN
                  ! add element back to halo region
                  ElemInfo_Shared(ELEM_HALOFLAG,iElem) = 3
                  IF (EnlargeBGM) CALL AddElementToFIBGM(iElem)
                  EXIT ElemLoop
                END IF
              END DO ! jDir = -1, 1, 2
            END DO ! iDir = -1, 1, 2

          END DO ! jPeriodicVector = 1,2
        END DO ! iPeriodicVector = 1,2

      CASE(3)
        ! check the three periodic vectors. Begin with checking the first periodic vector, followed by the combination of
        ! the first periodic vector with the others. Then check the other combinations, i.e. 1, 1+2, 1+3, 2, 2+3, 3, 1+2+3
        DO iPeriodicVector = 1,3
          ! element might be already added back
          IF (ElemInfo_Shared(ELEM_HALOFLAG,iElem).GT.0) EXIT ElemLoop

          ! check if element is within halo_eps of periodically displaced element
          DO iDir = -1, 1, 2
            ! check if element is within halo_eps of periodically displaced element
            IF (VECNORM( BoundsOfElemCenter(1:3)                                                           &
                      + GEO%PeriodicVectors(1:3,iPeriodicVector)*REAL(iDir) - LocalBoundsOfElemCenter(1:3))&
                      .LE. halo_eps+BoundsOfElemCenter(4)+LocalBoundsOfElemCenter(4))THEN
              ! add element back to halo region
              ElemInfo_Shared(ELEM_HALOFLAG,iElem) = 3
              IF (EnlargeBGM) CALL AddElementToFIBGM(iElem)
              EXIT ElemLoop
            END IF
          END DO ! iDir = -1, 1, 2

          ! Combination of two periodic vectors
          DO jPeriodicVector = 1,3
            IF (iPeriodicVector.GE.jPeriodicVector) CYCLE

            DO iDir = -1, 1, 2
              DO jDir = -1, 1, 2
                ! check if element is within halo_eps of periodically displaced element
                IF (VECNORM( BoundsOfElemCenter(1:3)                                                             &
                          + GEO%PeriodicVectors(1:3,iPeriodicVector)*REAL(iDir)                                  &
                          + GEO%PeriodicVectors(1:3,jPeriodicVector)*REAL(jDir) - LocalBoundsOfElemCenter(1:3) ) &
                          .LE. halo_eps+BoundsOfElemCenter(4)+LocalBoundsOfElemCenter(4))THEN
                  ! add element back to halo region
                  ElemInfo_Shared(ELEM_HALOFLAG,iElem) = 3
                  IF (EnlargeBGM) CALL AddElementToFIBGM(iElem)
                  EXIT ElemLoop
                END IF
              END DO ! jDir = -1, 1, 2
            END DO ! iDir = -1, 1, 2

          END DO ! jPeriodicVector = 1,3
        END DO ! iPeriodicVector = 1,3

        ! Combination of three periodic vectors
        DO iDir = -1, 1, 2
          DO jDir = -1, 1, 2
            DO kDir = -1, 1, 2
            ! check if element is within halo_eps of periodically displaced element
              IF (VECNORM( BoundsOfElemCenter(1:3)                                                             &
                        + GEO%PeriodicVectors(1:3,1)*REAL(iDir)                                  &
                        + GEO%PeriodicVectors(1:3,2)*REAL(jDir)                                  &
                        + GEO%PeriodicVectors(1:3,3)*REAL(kDir) - LocalBoundsOfElemCenter(1:3) ) &
                        .LE. halo_eps+BoundsOfElemCenter(4)+LocalBoundsOfElemCenter(4))THEN
                ! add element back to halo region
                ElemInfo_Shared(ELEM_HALOFLAG,iElem) = 3
                IF (EnlargeBGM) CALL AddElementToFIBGM(iElem)
                EXIT ElemLoop
              END IF
            END DO ! kDir = -1, 1, 2
          END DO ! jDir = -1, 1, 2
        END DO ! iDir = -1, 1, 2

      END SELECT
  END DO ElemLoop
END DO

END SUBROUTINE CheckPeriodicSides


!===================================================================================================================================
!> checks the elements against periodic rotation
!> In addition to halo flat elements (normal halo region), find rotationally periodic elements (halo flag 3), which can be reached
!> by rotationally periodic transformation (normally 90 degree rotation that is checked in both directions, i.e., +90 and -90
!> degrees)
!>   1. Loop over all global elements (split work on node) and skip all elements that do not have halo flag 0
!>   2. Loop over all compute-node elements (every processors loops over all of these elements)
!>   3. Rotate the global element and check the distance of all compute-node elements to this element and flag it with halo flag 3
!>      if the element can be reached by a particle
!===================================================================================================================================
SUBROUTINE CheckRotPeriodicSides(EnlargeBGM)
! MODULES                                                                                                                          !
!----------------------------------------------------------------------------------------------------------------------------------!
USE MOD_Globals
USE MOD_Preproc
USE MOD_MPI_Shared_Vars
USE MOD_Mesh_Vars              ,ONLY: nGlobalElems
USE MOD_Particle_Mesh_Vars     ,ONLY: ElemInfo_Shared,BoundsOfElem_Shared,nComputeNodeElems,GEO
USE MOD_Particle_MPI_Vars      ,ONLY: halo_eps
USE MOD_MPI_Vars               ,ONLY: offsetElemMPI
! IMPLICIT VARIABLE HANDLING
IMPLICIT NONE
!----------------------------------------------------------------------------------------------------------------------------------!
! INPUT VARIABLES
LOGICAL,INTENT(IN)             :: EnlargeBGM ! Flag used for enlarging the BGM if RefMapping and/or shape function is used
!----------------------------------------------------------------------------------------------------------------------------------!
! OUTPUT VARIABLES
!-----------------------------------------------------------------------------------------------------------------------------------
! LOCAL VARIABLES
INTEGER                        :: iElem,firstElem,lastElem
REAL                           :: RotBoundsOfElemCenter(3)
REAL                           :: BoundsOfElemCenter(1:4),LocalBoundsOfElemCenter(1:4)
INTEGER,DIMENSION(2)           :: DirPeriodicVector = [-1,1]
INTEGER                        :: iPeriodicDir,iLocElem
!===================================================================================================================================

firstElem = INT(REAL( myComputeNodeRank   *nGlobalElems)/REAL(nComputeNodeProcessors))+1
lastElem  = INT(REAL((myComputeNodeRank+1)*nGlobalElems)/REAL(nComputeNodeProcessors))

! The code below changes ElemInfo_Shared, identification of periodic elements must complete before
CALL MPI_BARRIER(MPI_COMM_SHARED,IERROR)

!   1. Loop over all global elements (split work on node) and skip all elements that do not have halo flag 0
! This is a distributed loop. Nonetheless, the load will be unbalanced due to the location of the space-filling curve. Still,
! this approach is again preferred compared to the communication overhead.
DO iElem = firstElem ,lastElem
  ! only consider elements that are not already flagged
  ! 1: my elements, 2: halo elements (not considering linear or rot periodic)
  IF (ElemInfo_Shared(ELEM_HALOFLAG,iElem).NE.0) CYCLE

  BoundsOfElemCenter(1:3) = (/ SUM(   BoundsOfElem_Shared(1:2,1,iElem)),                                                   &
                               SUM(   BoundsOfElem_Shared(1:2,2,iElem)),                                                   &
                               SUM(   BoundsOfElem_Shared(1:2,3,iElem)) /) / 2.
  BoundsOfElemCenter(4) = VECNORM ((/ BoundsOfElem_Shared(2  ,1,iElem)-BoundsOfElem_Shared(1,1,iElem),                     &
                                      BoundsOfElem_Shared(2  ,2,iElem)-BoundsOfElem_Shared(1,2,iElem),                     &
                                      BoundsOfElem_Shared(2  ,3,iElem)-BoundsOfElem_Shared(1,3,iElem) /) / 2.)

  !   2. Loop over all compute-node elements (every processors loops over all of these elements)
  ! Loop ALL compute-node elements (use global element index)
  DO iLocElem = offsetElemMPI(ComputeNodeRootRank)+1, offsetElemMPI(ComputeNodeRootRank)+nComputeNodeElems
    ! element might be already added back
    IF (ElemInfo_Shared(ELEM_HALOFLAG,iElem).GT.0) EXIT

    LocalBoundsOfElemCenter(1:3) = (/ SUM(   BoundsOfElem_Shared(1:2,1,iLocElem)),                                         &
                                      SUM(   BoundsOfElem_Shared(1:2,2,iLocElem)),                                         &
                                      SUM(   BoundsOfElem_Shared(1:2,3,iLocElem)) /) / 2.
    LocalBoundsOfElemCenter(4) = VECNORM ((/ BoundsOfElem_Shared(2  ,1,iLocElem)-BoundsOfElem_Shared(1,1,iLocElem),        &
                                             BoundsOfElem_Shared(2  ,2,iLocElem)-BoundsOfElem_Shared(1,2,iLocElem),        &
                                             BoundsOfElem_Shared(2  ,3,iLocElem)-BoundsOfElem_Shared(1,3,iLocElem) /) / 2.)
    !   3. Rotate the global element and check the distance of all compute-node elements to
    !      this element and flag it with halo flag 3 if the element can be reached by a particle
    DO iPeriodicDir = 1,2
      ASSOCIATE( alpha => GEO%RotPeriodicAngle * DirPeriodicVector(iPeriodicDir) )
        SELECT CASE(GEO%RotPeriodicAxi)
          CASE(1) ! x-rotation axis
            RotBoundsOfElemCenter(1) = BoundsOfElemCenter(1)
            RotBoundsOfElemCenter(2) = COS(alpha)*BoundsOfElemCenter(2) - SIN(alpha)*BoundsOfElemCenter(3)
            RotBoundsOfElemCenter(3) = SIN(alpha)*BoundsOfElemCenter(2) + COS(alpha)*BoundsOfElemCenter(3)
          CASE(2) ! y-rotation axis
            RotBoundsOfElemCenter(1) = COS(alpha)*BoundsOfElemCenter(1) + SIN(alpha)*BoundsOfElemCenter(3)
            RotBoundsOfElemCenter(2) = BoundsOfElemCenter(2)
            RotBoundsOfElemCenter(3) =-SIN(alpha)*BoundsOfElemCenter(1) + COS(alpha)*BoundsOfElemCenter(3)
          CASE(3) ! z-rotation axis
            RotBoundsOfElemCenter(1) = COS(alpha)*BoundsOfElemCenter(1) - SIN(alpha)*BoundsOfElemCenter(2)
            RotBoundsOfElemCenter(2) = SIN(alpha)*BoundsOfElemCenter(1) + COS(alpha)*BoundsOfElemCenter(2)
            RotBoundsOfElemCenter(3) = BoundsOfElemCenter(3)
        END SELECT
      END ASSOCIATE
      ! check if element is within halo_eps of rotationally displaced element
      IF (VECNORM( RotBoundsOfElemCenter(1:3)                               &
                 - LocalBoundsOfElemCenter(1:3))                            &
              .LE. halo_eps+BoundsOfElemCenter(4)+LocalBoundsOfElemCenter(4))THEN
        ! add element back to halo region
        ElemInfo_Shared(ELEM_HALOFLAG,iElem) = 3
        IF (EnlargeBGM) CALL AddElementToFIBGM(iElem)
      END IF ! VECNORM( ...
    END DO ! iPeriodicDir = 1,2
  END DO ! iLocElem = offsetElemMPI(ComputeNodeRootRank)+1, offsetElemMPI(ComputeNodeRootRank)+nComputeNodeElems
END DO ! firstElem,lastElem

END SUBROUTINE CheckRotPeriodicSides


SUBROUTINE AddElementToFIBGM(ElemID)
!===================================================================================================================================
!> adds an element to all corresponding FIBGM cells and ensures correct bounds
!===================================================================================================================================
! MODULES                                                                                                                          !
!----------------------------------------------------------------------------------------------------------------------------------!
USE MOD_Particle_Mesh_Vars     ,ONLY: GEO
USE MOD_Particle_Mesh_Vars     ,ONLY: ElemToBGM_Shared
! IMPLICIT VARIABLE HANDLING
IMPLICIT NONE
!----------------------------------------------------------------------------------------------------------------------------------!
! INPUT VARIABLES
INTEGER,INTENT(IN)             :: ElemID
!----------------------------------------------------------------------------------------------------------------------------------!
! OUTPUT VARIABLES
!-----------------------------------------------------------------------------------------------------------------------------------
! LOCAL VARIABLES
INTEGER                        :: iBGM,jBGM,kBGM
INTEGER                        :: BGMCellXmax,BGMCellXmin,BGMCellYmax,BGMCellYmin,BGMCellZmax,BGMCellZmin
!===================================================================================================================================

BGMCellXmin = MAX(ElemToBGM_Shared(1,ElemID),GEO%FIBGMimin)
BGMCellXmax = MIN(ElemToBGM_Shared(2,ElemID),GEO%FIBGMimax)
BGMCellYmin = MAX(ElemToBGM_Shared(3,ElemID),GEO%FIBGMjmin)
BGMCellYmax = MIN(ElemToBGM_Shared(4,ElemID),GEO%FIBGMjmax)
BGMCellZmin = MAX(ElemToBGM_Shared(5,ElemID),GEO%FIBGMkmin)
BGMCellZmax = MIN(ElemToBGM_Shared(6,ElemID),GEO%FIBGMkmax)

! add current element to number of BGM-elems
DO iBGM = BGMCellXmin,BGMCellXmax
  DO jBGM = BGMCellYmin,BGMCellYmax
    DO kBGM = BGMCellZmin,BGMCellZmax
      GEO%FIBGM(iBGM,jBGM,kBGM)%nElem = GEO%FIBGM(iBGM,jBGM,kBGM)%nElem + 1
    END DO ! kBGM
  END DO ! jBGM
END DO ! iBGM

END SUBROUTINE


#if GCC_VERSION < 90000
PPURE FUNCTION FINDLOC(Array,Value,Dim)
!===================================================================================================================================
!> Implements a subset of the intrinsic FINDLOC function for Fortran < 2008
!===================================================================================================================================
! MODULES                                                                                                                          !
!----------------------------------------------------------------------------------------------------------------------------------!
! IMPLICIT VARIABLE HANDLING
IMPLICIT NONE
!----------------------------------------------------------------------------------------------------------------------------------!
! INPUT VARIABLES
INTEGER,INTENT(IN)             :: Array(:)
INTEGER,INTENT(IN)             :: Value
INTEGER,INTENT(IN)             :: Dim
!----------------------------------------------------------------------------------------------------------------------------------!
! OUTPUT VARIABLES
INTEGER                        :: FINDLOC
!-----------------------------------------------------------------------------------------------------------------------------------
! LOCAL VARIABLES
INTEGER                        :: iVar
!===================================================================================================================================
DO iVar = 1,SIZE(ARRAY,1)
  IF (Array(iVar).EQ.Value) THEN
    FINDLOC = iVar
    RETURN
  END IF
END DO

! Return error code -1 if the value was not found
FINDLOC = -1

END FUNCTION FINDLOC
#endif /*GCC_VERSION < 90000*/
#endif /*USE_MPI*/


END MODULE MOD_Particle_BGM
