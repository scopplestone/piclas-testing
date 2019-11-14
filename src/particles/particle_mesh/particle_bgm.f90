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

PUBLIC::DefineParametersParticleBGM
PUBLIC::BuildBGMAndIdentifyHaloRegion

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
  , 'Define the deltas for the cartesian Fast-Init-Background-Mesh.'//&
  ' They should be of the similar size as the smallest cells of the used mesh for simulation.'&
  , '1. , 1. , 1.')
CALL prms%CreateRealArrayOption('Part-FactorFIBGM'&
  , 'Factor with which the background mesh will be scaled.'&
  , '1. , 1. , 1.')

END SUBROUTINE DefineParametersParticleBGM


SUBROUTINE BuildBGMAndIdentifyHaloRegion()
!===================================================================================================================================
!> computes the BGM-indices of an element and maps the number of element and which element to each BGM cell
!> BGM is only saved for compute-node-mesh + halo-region on shared memory
!===================================================================================================================================
! MODULES                                                                                                                          !
!----------------------------------------------------------------------------------------------------------------------------------!
USE MOD_Globals
USE MOD_Preproc
USE MOD_Mesh_Vars            ,ONLY: nElems, offsetElem
USE MOD_Partilce_Periodic_BC ,ONLY: InitPeriodicBC
USE MOD_Particle_Mesh_Vars   ,ONLY: GEO, OffsetTotalElems, OffsetSharedElems
USE MOD_Equation_Vars        ,ONLY: c
USE MOD_ReadInTools          ,ONLY: GETREAL, GetRealArray, PrintOption
#if !(USE_HDG)
USE MOD_CalcTimeStep         ,ONLY: CalcTimeStep
#endif /*USE_HDG*/
#if USE_MPI
USE MOD_MPI_Shared_Vars
USE MOD_MPI_Shared           ,ONLY: Allocate_Shared
USE MOD_PICDepo_Vars         ,ONLY: DepositionType, r_sf
USE MOD_Particle_MPI_Vars    ,ONLY: SafetyFactor,halo_eps_velo,halo_eps,halo_eps2
USE MOD_Particle_Vars        ,ONLY: manualtimestep, useManualTimeStep
#else
USE MOD_Mesh_Vars            ,ONLY: NodeCoords
#endif /*USE_MPI*/
!----------------------------------------------------------------------------------------------------------------------------------!
! IMPLICIT VARIABLE HANDLING
IMPLICIT NONE
! INPUT VARIABLES
!----------------------------------------------------------------------------------------------------------------------------------!
! OUTPUT VARIABLES
!-----------------------------------------------------------------------------------------------------------------------------------
! LOCAL VARIABLES
INTEGER                        :: iElem
REAL                           :: xmin, xmax, ymin, ymax, zmin, zmax
INTEGER                        :: iBGM, jBGM, kBGM
INTEGER                        :: BGMimax, BGMimin, BGMjmax, BGMjmin, BGMkmax, BGMkmin
INTEGER                        :: BGMCellXmax, BGMCellXmin, BGMCellYmax, BGMCellYmin, BGMCellZmax, BGMCellZmin
#if USE_MPI
INTEGER                        :: iSide, SideID
INTEGER                        :: ElemID
REAL                           :: deltaT
REAL                           :: globalDiag
INTEGER,ALLOCATABLE            :: sendbuf(:,:,:), recvbuf(:,:,:)
INTEGER,ALLOCATABLE            :: offsetElemsInBGMCell(:,:,:)
INTEGER(KIND=MPI_ADDRESS_KIND) :: MPISharedSize
INTEGER                        :: nHaloElems, nMPISidesShared
INTEGER,ALLOCATABLE            :: offsetHaloElem(:), offsetMPISideShared(:)
REAL,ALLOCATABLE               :: BoundsOfElemCenter(:), MPISideBoundsOfElemCenter(:,:)
LOGICAL                        :: ElemInsideHalo
INTEGER                        :: FirstElem, LastElem, firstHaloElem, lastHaloElem
INTEGER                        :: offsetNodeID, nNodeIDs, firstNodeID, lastNodeID
#else
INTEGER,ALLOCATABLE            :: ElemToBGM(:,:)
REAL,POINTER                   :: NodeCoordsPointer(:,:,:,:,:)
#endif
!===================================================================================================================================

! Read parameter for FastInitBackgroundMesh (FIBGM)
GEO%FIBGMdeltas(1:3) = GETREALARRAY('Part-FIBGMdeltas',3,'1. , 1. , 1.')
GEO%FactorFIBGM(1:3) = GETREALARRAY('Part-FactorFIBGM',3,'1. , 1. , 1.')
GEO%FIBGMdeltas(1:3) = 1./GEO%FactorFIBGM(1:3) * GEO%FIBGMdeltas(1:3)

#if USE_MPI
MPISharedSize = INT(6*nTotalElems,MPI_ADDRESS_KIND)*MPI_ADDRESS_KIND
CALL Allocate_Shared(MPISharedSize,(/6,nTotalElems/),ElemToBGM_Shared_Win,ElemToBGM_Shared)
CALL Allocate_Shared(MPISharedSize,(/6,nTotalElems/),BoundsOfElem_Shared_Win,BoundsOfElem_Shared)
CALL MPI_WIN_LOCK_ALL(0,ElemToBGM_Shared_Win,IERROR)
CALL MPI_WIN_LOCK_ALL(0,BoundsOfElem_Shared_Win,IERROR)

firstElem=INT(REAL(myRank_Shared*nTotalElems)/REAL(nProcessors_Shared))+1
lastElem=INT(REAL((myRank_Shared+1)*nTotalElems)/REAL(nProcessors_Shared))
moveBGMindex = 1 ! BGM indeces must be >1 --> move by 1
DO iElem = firstElem, lastElem
  offSetNodeID=ElemInfo_Shared(ELEM_FIRSTNODEIND,iElem)
  nNodeIDs=ElemInfo_Shared(ELEM_LASTNODEIND,iElem)-ElemInfo_Shared(ELEM_FIRSTNODEIND,iElem)
  firstNodeID = offsetNodeID+1
  lastNodeID = offsetNodeID+nNodeIDs

  xmin=MINVAL(NodeCoords_Shared(1,firstNodeID:lastNodeID))
  xmax=MAXVAL(NodeCoords_Shared(1,firstNodeID:lastNodeID))
  ymin=MINVAL(NodeCoords_Shared(2,firstNodeID:lastNodeID))
  ymax=MAXVAL(NodeCoords_Shared(2,firstNodeID:lastNodeID))
  zmin=MINVAL(NodeCoords_Shared(3,firstNodeID:lastNodeID))
  zmax=MAXVAL(NodeCoords_Shared(3,firstNodeID:lastNodeID))

  BoundsOfElem_Shared(1,iElem) = xmin
  BoundsOfElem_Shared(2,iElem) = xmax
  BoundsOfElem_Shared(3,iElem) = ymin
  BoundsOfElem_Shared(4,iElem) = ymax
  BoundsOfElem_Shared(5,iElem) = zmin
  BoundsOfElem_Shared(6,iElem) = zmax

  ! BGM indeces must be >1 --> move by 1
  ElemToBGM_Shared(1,iElem) = CEILING((xmin-GEO%xminglob)/GEO%FIBGMdeltas(1)) +moveBGMindex
  ElemToBGM_Shared(2,iElem) = CEILING((xmax-GEO%xminglob)/GEO%FIBGMdeltas(1)) +moveBGMindex
  ElemToBGM_Shared(3,iElem) = CEILING((ymin-GEO%yminglob)/GEO%FIBGMdeltas(2)) +moveBGMindex
  ElemToBGM_Shared(4,iElem) = CEILING((ymax-GEO%yminglob)/GEO%FIBGMdeltas(2)) +moveBGMindex
  ElemToBGM_Shared(5,iElem) = CEILING((zmin-GEO%zminglob)/GEO%FIBGMdeltas(3)) +moveBGMindex
  ElemToBGM_Shared(6,iElem) = CEILING((zmax-GEO%zminglob)/GEO%FIBGMdeltas(3)) +moveBGMindex
END DO ! iElem = 1, nElems
CALL MPI_WIN_SYNC(ElemToBGM_Shared_Win,IERROR)
CALL MPI_WIN_SYNC(BoundsOfElem_Shared_Win,IERROR)
CALL MPI_BARRIER(MPI_COMM_SHARED,IERROR)

!CALL InitPeriodicBC()

! deallocate stuff // required for dynamic load balance
#if USE_MPI
IF (ALLOCATED(GEO%FIBGM)) THEN
  DO iBGM=GEO%FIBGMimin,GEO%FIBGMimax
    DO jBGM=GEO%FIBGMjmin,GEO%FIBGMjmax
      DO kBGM=GEO%FIBGMkmin,GEO%FIBGMkmax
        SDEALLOCATE(GEO%FIBGM(iBGM,jBGM,kBGM)%Element)
        !SDEALLOCATE(GEO%FIBGM(iBGM,jBGM,kBGM)%ShapeProcs)
        !SDEALLOCATE(GEO%FIBGM(iBGM,jBGM,kBGM)%PaddingProcs)
        !SDEALLOCATE(GEO%FIBGM(i,k,l)%SharedProcs)
      END DO ! kBGM
    END DO ! jBGM
  END DO ! iBGM
  DEALLOCATE(GEO%FIBGM)
END IF
#endif /*USE_MPI*/

!--- Read Manual Time Step
useManualTimeStep = .FALSE.
ManualTimeStep = GETREAL('Particles-ManualTimeStep', '0.0')
IF (ManualTimeStep.GT.0.0) THEN
  useManualTimeStep=.True.
END IF
SafetyFactor  =GETREAL('Part-SafetyFactor','1.0')
halo_eps_velo =GETREAL('Particles-HaloEpsVelo','0')

IF (ManualTimeStep.EQ.0.0) THEN
#if !(USE_HDG)
  deltaT=CALCTIMESTEP()
#else
   CALL abort(&
__STAMP__&
, 'ManualTimeStep.EQ.0.0 -> ManualTimeStep is not defined correctly! Particles-ManualTimeStep = ',RealInfoOpt=ManualTimeStep)
#endif /*USE_HDG*/
ELSE
  deltaT=ManualTimeStep
END IF
IF (halo_eps_velo.EQ.0) halo_eps_velo = c
#if (PP_TimeDiscMethod==4 || PP_TimeDiscMethod==200 || PP_TimeDiscMethod==42 || PP_TimeDiscMethod==43)
IF (halo_eps_velo.EQ.c) THEN
   CALL abort(&
__STAMP__&
, 'halo_eps_velo.EQ.c -> Halo Eps Velocity for MPI not defined')
END IF
#endif
#if (PP_TimeDiscMethod==501) || (PP_TimeDiscMethod==502) || (PP_TimeDiscMethod==506)
halo_eps = RK_c(2)
DO iStage=2,nRKStages-1
  halo_eps = MAX(halo_eps,RK_c(iStage+1)-RK_c(iStage))
END DO
halo_eps = MAX(halo_eps,1.-RK_c(nRKStages))
CALL PrintOption('max. RKdtFrac','CALCUL.',RealOpt=halo_eps)
halo_eps = halo_eps*halo_eps_velo*deltaT*SafetyFactor !dt multiplied with maximum RKdtFrac
#else
halo_eps = halo_eps_velo*deltaT*SafetyFactor ! for RK too large
#endif

! Check whether halo_eps is smaller than shape function radius
! e.g. 'shape_function', 'shape_function_1d', 'shape_function_cylindrical', 'shape_function_spherical', 'shape_function_simple'
IF(TRIM(DepositionType(1:MIN(14,LEN(TRIM(ADJUSTL(DepositionType)))))).EQ.'shape_function')THEN
  IF(halo_eps.LT.r_sf)THEN
    SWRITE(UNIT_stdOut,'(A)') ' halo_eps is smaller than shape function radius. Setting halo_eps=r_sf'
    halo_eps = halo_eps + r_sf
    CALL PrintOption('max. RKdtFrac','CALCUL.',RealOpt=halo_eps)
  END IF
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

moveBGMindex = 2 ! BGM indeces must be >1 --> move by 2
! enlarge BGM with halo region (all element outside of this region will be cut off)
BGMimax = INT((MIN(GEO%xmax_Shared+halo_eps,GEO%xmaxglob)-GEO%xminglob)/GEO%FIBGMdeltas(1))+1  + moveBGMindex
BGMimin = INT((MAX(GEO%xmin_Shared-halo_eps,GEO%xminglob)-GEO%xminglob)/GEO%FIBGMdeltas(1))-1  + moveBGMindex
BGMjmax = INT((MIN(GEO%ymax_Shared+halo_eps,GEO%ymaxglob)-GEO%yminglob)/GEO%FIBGMdeltas(2))+1  + moveBGMindex
BGMjmin = INT((MAX(GEO%ymin_Shared-halo_eps,GEO%yminglob)-GEO%yminglob)/GEO%FIBGMdeltas(2))-1  + moveBGMindex
BGMkmax = INT((MIN(GEO%zmax_Shared+halo_eps,GEO%zmaxglob)-GEO%zminglob)/GEO%FIBGMdeltas(3))+1  + moveBGMindex
BGMkmin = INT((MAX(GEO%zmin_Shared-halo_eps,GEO%zminglob)-GEO%zminglob)/GEO%FIBGMdeltas(3))-1  + moveBGMindex
! write function-local BGM indeces into global variables
GEO%FIBGMimax_Shared=BGMimax
GEO%FIBGMimin_Shared=BGMimin
GEO%FIBGMjmax_Shared=BGMjmax
GEO%FIBGMjmin_Shared=BGMjmin
GEO%FIBGMkmax_Shared=BGMkmax
GEO%FIBGMkmin_Shared=BGMkmin
! initialize BGM min/max indeces using GEO min/max distances
GEO%FIBGMimax = INT((GEO%xmax-GEO%xminglob)/GEO%FIBGMdeltas(1))+1  + moveBGMindex
GEO%FIBGMimin = INT((GEO%xmin-GEO%xminglob)/GEO%FIBGMdeltas(1))-1  + moveBGMindex
GEO%FIBGMjmax = INT((GEO%ymax-GEO%yminglob)/GEO%FIBGMdeltas(2))+1  + moveBGMindex
GEO%FIBGMjmin = INT((GEO%ymin-GEO%yminglob)/GEO%FIBGMdeltas(2))-1  + moveBGMindex
GEO%FIBGMkmax = INT((GEO%zmax-GEO%zminglob)/GEO%FIBGMdeltas(3))+1  + moveBGMindex
GEO%FIBGMkmin = INT((GEO%zmin-GEO%zminglob)/GEO%FIBGMdeltas(3))-1  + moveBGMindex

ALLOCATE(GEO%FIBGM(BGMimin:BGMimax,BGMjmin:BGMjmax,BGMkmin:BGMkmax))

! null number of element per BGM cell
DO kBGM = BGMkmin,BGMkmax
  DO jBGM = BGMjmin,BGMjmax
    DO iBGM = BGMimin,BGMimax
      GEO%FIBGM(iBGM,jBGM,kBGM)%nElem = 0
    END DO ! kBGM
  END DO ! jBGM
END DO ! iBGM

!--- compute number of elements in each background cell
! allocated shared memory for nElems per BGM cell

! check which element is inside of compute-node domain (1),
! check which element is inside of compute-node halo (2)
! and which element is outside of compute-node domain (0)
! first do coarse check with BGM
ElemInfo_Shared(ELEM_HALOFLAG,firstElem:lastElem)=0
DO iElem = firstElem, lastElem
  BGMCellXmin = ElemToBGM_Shared(1,iElem)
  BGMCellXmax = ElemToBGM_Shared(2,iElem)
  BGMCellYmin = ElemToBGM_Shared(3,iElem)
  BGMCellYmax = ElemToBGM_Shared(4,iElem)
  BGMCellZmin = ElemToBGM_Shared(5,iElem)
  BGMCellZmax = ElemToBGM_Shared(6,iElem)
  ! add current element to number of BGM-elems
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
        IF(iElem.GE.offsetElem_Shared+1 .AND. iElem.LE.offsetElem_Shared+nElems_Shared) THEN
          ElemInfo_Shared(ELEM_HALOFLAG,iElem)=1 ! compute-node element
        ELSE
          ElemInfo_Shared(ELEM_HALOFLAG,iElem)=2 ! halo element
        END IF
      END DO ! kBGM
    END DO ! jBGM
  END DO ! iBGM
END DO ! iElem
CALL MPI_WIN_SYNC(ElemInfo_Shared_Win,IERROR)
CALL MPI_BARRIER(MPI_COMM_SHARED,iError)

! sum up potential halo elements and create correct offset mapping in ElemInfo_Shared
nHaloElems = 0
ALLOCATE(offsetHaloElem(nTotalElems))
DO iElem = 1, nTotalElems
  IF (ElemInfo_Shared(ELEM_HALOFLAG,iElem).EQ.2) THEN
    nHaloElems = nHaloElems + 1
    offsetHaloElem(nHaloElems) = iElem
  END IF
END DO

! sum all MPI-side of compute-node and create correct offset mapping in SideInfo_Shared
nMPISidesShared = 0
ALLOCATE(offsetMPISideShared(nTotalSides))
DO iSide = 1, nTotalSides
  IF (SideInfo_Shared(SIDEINFOSIZE+1,iSide).EQ.2) THEN
    nMPISidesShared = nMPISidesShared + 1
    offsetMPISideShared(nMPISidesShared) = iSide
  END IF
END DO

! Distribute nHaloElements evenly on compute-node procs
IF (nHaloElems.GT.nProcessors_Shared) THEN
  firstHaloElem=INT(REAL(myRank_Shared*nHaloElems)/REAL(nProcessors_Shared))+1
  lastHaloElem=INT(REAL((myRank_Shared+1)*nHaloElems)/REAL(nProcessors_Shared))
ELSE
  firstHaloElem = myRank_Shared + 1
  IF (myRank_Shared.LT.nHaloElems) THEN
    lastHaloElem = myRank_Shared + 1
  ELSE
    lastHaloElem = 0
  END IF
END IF

ALLOCATE(MPISideBoundsOfElemCenter(1:4,1:nMPISidesShared))
DO iSide = 1, nMPISidesShared
  SideID = offsetMPISideShared(iSide)
  ElemID = SideInfo_Shared(SIDE_ELEMID,SideID)
  MPISideBoundsOfElemCenter(1:3,SideID) = (/ SUM(BoundsOfElem_Shared(1:2,ElemID)), &
                                             SUM(BoundsOfElem_Shared(3:4,ElemID)), &
                                             SUM(BoundsOfElem_Shared(5:6,ElemID)) /) / 2.
  MPISideBoundsOfElemCenter(4,SideID) = VECNORM ((/ BoundsOfElem_Shared(2,ElemID)-BoundsOfElem_Shared(1,ElemID), &
                                                    BoundsOfElem_Shared(4,ElemID)-BoundsOfElem_Shared(3,ElemID), &
                                                    BoundsOfElem_Shared(6,ElemID)-BoundsOfElem_Shared(5,ElemID) /) / 2.)
END DO

! do refined check: (refined halo region reduction)
! check the bounding box of each element in compute-nodes' halo domain 
! against the bounding boxes of the elements of the MPI-surface (inter compute-node MPI sides) 
ALLOCATE(BoundsOfElemCenter(1:4))
DO iElem = firstHaloElem, lastHaloElem
  ElemID = offsetHaloElem(iElem)
  ElemInsideHalo = .FALSE.
  BoundsOfElemCenter(1:3) = (/ SUM(BoundsOfElem_Shared(1:2,ElemID)), &
                               SUM(BoundsOfElem_Shared(3:4,ElemID)), &
                               SUM(BoundsOfElem_Shared(5:6,ElemID)) /) / 2.
  BoundsOfElemCenter(4) = VECNORM ((/ BoundsOfElem_Shared(2,ElemID)-BoundsOfElem_Shared(1,ElemID), &
                                             BoundsOfElem_Shared(4,ElemID)-BoundsOfElem_Shared(3,ElemID), &
                                             BoundsOfElem_Shared(6,ElemID)-BoundsOfElem_Shared(5,ElemID) /) / 2.)
  DO iSide = 1, nMPISidesShared
    SideID = offsetMPISideShared(iSide)
    ! compare distance of centers with sum of element outer radii+halo_eps
    IF (VECNORM(BoundsOfElemCenter(1:3)-MPISideBoundsOfElemCenter(1:3,SideID)) &
        .GT. halo_eps+BoundsOfElemCenter(4)+MPISideBoundsOfElemCenter(4,SideID) ) CYCLE
    ElemInsideHalo = .TRUE.
    EXIT
  END DO ! iSide = 1, nMPISidesShared
  IF (.NOT.ElemInsideHalo) THEN
    ElemInfo_Shared(ELEM_HALOFLAG,ElemID)=0
  ELSE
    BGMCellXmin = ElemToBGM_Shared(1,ElemID)
    BGMCellXmax = ElemToBGM_Shared(2,ElemID)
    BGMCellYmin = ElemToBGM_Shared(3,ElemID)
    BGMCellYmax = ElemToBGM_Shared(4,ElemID)
    BGMCellZmin = ElemToBGM_Shared(5,ElemID)
    BGMCellZmax = ElemToBGM_Shared(6,ElemID)
    ! add current element to number of BGM-elems
    DO iBGM = BGMCellXmin,BGMCellXmax
      DO jBGM = BGMCellYmin,BGMCellYmax
        DO kBGM = BGMCellZmin,BGMCellZmax
          GEO%FIBGM(iBGM,jBGM,kBGM)%nElem = GEO%FIBGM(iBGM,jBGM,kBGM)%nElem + 1
        END DO ! kBGM
      END DO ! jBGM
    END DO ! iBGM
  END IF
END DO ! iElem = firstHaloElem, lastHaloElem
CALL MPI_WIN_SYNC(ElemInfo_Shared_Win,IERROR)
CALL MPI_BARRIER(MPI_COMM_SHARED,iError)

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

! alternative nElem count with cycles
!DO iElem = firstElem, lastElem
!  IF (ElemInfo_Shared(ELEM_HALOFLAG,iElem).EQ.0) CYCLE
!  BGMCellXmin = ElemToBGM_Shared(1,iElem)
!  BGMCellXmax = ElemToBGM_Shared(2,iElem)
!  BGMCellYmin = ElemToBGM_Shared(3,iElem)
!  BGMCellYmax = ElemToBGM_Shared(4,iElem)
!  BGMCellZmin = ElemToBGM_Shared(5,iElem)
!  BGMCellZmax = ElemToBGM_Shared(6,iElem)
!  ! add current element to number of BGM-elems
!  DO iBGM = BGMCellXmin,BGMCellXmax
!    DO jBGM = BGMCellYmin,BGMCellYmax
!      DO kBGM = BGMCellZmin,BGMCellZmax
!        GEO%FIBGM(iBGM,jBGM,kBGM)%nElem = GEO%FIBGM(iBGM,jBGM,kBGM)%nElem + 1
!      END DO ! kBGM
!    END DO ! jBGM
!  END DO ! iBGM
!END DO ! iElem

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

ALLOCATE(offsetElemsInBGMCell(BGMimin:BGMimax,BGMjmin:BGMjmax,BGMkmin:BGMkmax))
CALL MPI_EXSCAN(sendbuf(:,:,:),recvbuf(:,:,:),((BGMimax-BGMimin)+1)*((BGMjmax-BGMjmin)+1)*((BGMkmax-BGMkmin)+1) &
                ,MPI_INTEGER,MPI_SUM,MPI_COMM_SHARED,iError)
offsetElemsInBGMCell=recvbuf
DEALLOCATE(recvbuf)

! last proc of compute-node calculates total number of elements in each BGM-cell 
! after this loop sendbuf of last proc contains nElems per BGM cell
IF(myRank_Shared.EQ.nProcessors_Shared-1)THEN
  DO iBGM = BGMimin,BGMimax
    DO jBGM = BGMjmin,BGMjmax
      DO kBGM = BGMkmin,BGMkmax
        sendbuf(iBGM,jBGM,kBGM)=offsetElemsInBGMCell(iBGM,jBGM,kBGM)+GEO%FIBGM(iBGM,jBGM,kBGM)%nElem
      END DO ! kBGM
    END DO ! jBGM
  END DO ! iBGM
END IF

! allocated shared memory for nElems per BGM cell
MPISharedSize = INT(((BGMimax-BGMimin)+1)*((BGMjmax-BGMjmin)+1)*((BGMkmax-BGMkmin)+1),MPI_ADDRESS_KIND)*MPI_ADDRESS_KIND
CALL Allocate_Shared(MPISharedSize,(/BGMimax-BGMimin+1,BGMjmax-BGMjmin+1,BGMkmax-BGMkmin+1/) &
                    ,FIBGM_nElem_Shared_Win,FIBGM_nElem_Shared)
CALL MPI_WIN_LOCK_ALL(0,FIBGM_nElem_Shared_Win,IERROR)

! last proc of compute-node writes into shared memory to make nElems per BGM accessible for every proc
IF(myRank_Shared.EQ.nProcessors_Shared-1)THEN
  DO iBGM = BGMimin,BGMimax
    DO jBGM = BGMjmin,BGMjmax
      DO kBGM = BGMkmin,BGMkmax
        FIBGM_nElem_Shared(iBGM,jBGM,kBGM) = sendbuf(iBGM,jBGM,kBGM)
      END DO ! kBGM
    END DO ! jBGM
  END DO ! iBGM
END IF
DEALLOCATE(sendbuf)
CALL MPI_WIN_SYNC(FIBGM_nElem_Shared_Win,IERROR)
CALL MPI_BARRIER(MPI_COMM_SHARED,iError)

! allocate 1D array for mapping of BGM cell to Element indeces
MPISharedSize = INT((FIBGM_offsetElem_Shared(BGMimax,BGMjmax,BGMkmax)+FIBGM_nElem_Shared(BGMimax,BGMjmax,BGMkmax)) &
                     ,MPI_ADDRESS_KIND)*MPI_ADDRESS_KIND
CALL Allocate_Shared(MPISharedSize,(/FIBGM_offsetElem_Shared(BGMimax,BGMjmax,BGMkmax)+FIBGM_nElem_Shared(BGMimax,BGMjmax,BGMkmax)/)&
                     ,FIBGM_Element_Shared_Win,FIBGM_Element_Shared)
CALL MPI_WIN_LOCK_ALL(0,FIBGM_Element_Shared_Win,IERROR)

DO kBGM = BGMkmin,BGMkmax
  DO jBGM = BGMjmin,BGMjmax
    DO iBGM = BGMimin,BGMimax
      GEO%FIBGM(iBGM,jBGM,kBGM)%nElem = 0
    END DO ! kBGM
  END DO ! jBGM
END DO ! iBGM

DO iElem = firstHaloElem, lastHaloElem
  ElemID = offsetHaloElem(iElem)
  IF (ElemInfo_Shared(ELEM_HALOFLAG,ElemID).EQ.0) CYCLE
  BGMCellXmin = ElemToBGM_Shared(1,ElemID)
  BGMCellXmax = ElemToBGM_Shared(2,ElemID)
  BGMCellYmin = ElemToBGM_Shared(3,ElemID)
  BGMCellYmax = ElemToBGM_Shared(4,ElemID)
  BGMCellZmin = ElemToBGM_Shared(5,ElemID)
  BGMCellZmax = ElemToBGM_Shared(6,ElemID)
  ! add current Element to BGM-Elem
  DO kBGM = BGMCellZmin,BGMCellZmax
    DO jBGM = BGMCellYmin,BGMCellYmax
      DO iBGM = BGMCellXmin,BGMCellXmax
        GEO%FIBGM(iBGM,jBGM,kBGM)%nElem = GEO%FIBGM(iBGM,jBGM,kBGM)%nElem + 1
        FIBGM_Element_Shared( FIBGM_offsetElem_Shared(iBGM,jBGM,kBGM) & ! offset of BGM cell in 1D array
                            + offsetElemsInBGMCell(iBGM,jBGM,kBGM)    & ! offset of BGM nElems in local proc
                            + GEO%FIBGM(iBGM,jBGM,kBGM)%nElem         ) = ElemID
      END DO ! kBGM
    END DO ! jBGM
  END DO ! iBGM
END DO ! iElem = firstHaloElem, lastHaloElem
DO iElem = offsetElem+1, offsetElem+nElems
  BGMCellXmin = ElemToBGM_Shared(1,iElem)
  BGMCellXmax = ElemToBGM_Shared(2,iElem)
  BGMCellYmin = ElemToBGM_Shared(3,iElem)
  BGMCellYmax = ElemToBGM_Shared(4,iElem)
  BGMCellZmin = ElemToBGM_Shared(5,iElem)
  BGMCellZmax = ElemToBGM_Shared(6,iElem)
  ! add current Element to BGM-Elem
  DO kBGM = BGMCellZmin,BGMCellZmax
    DO jBGM = BGMCellYmin,BGMCellYmax
      DO iBGM = BGMCellXmin,BGMCellXmax
        GEO%FIBGM(iBGM,jBGM,kBGM)%nElem = GEO%FIBGM(iBGM,jBGM,kBGM)%nElem + 1
        FIBGM_Element_Shared( FIBGM_offsetElem_Shared(iBGM,jBGM,kBGM) & ! offset of BGM cell in 1D array
                            + offsetElemsInBGMCell(iBGM,jBGM,kBGM)    & ! offset of BGM nElems in local proc
                            + GEO%FIBGM(iBGM,jBGM,kBGM)%nElem         ) = iElem
      END DO ! kBGM
    END DO ! jBGM
  END DO ! iBGM
END DO ! iElem

!--- map elements to background cells
! alternative if nElem is counted with cycles
!DO iElem = firstElem, lastElem
!  IF (ElemInfo_Shared(ELEM_HALOFLAG,iElem).EQ.0) CYCLE
!  BGMCellXmin = ElemToBGM_Shared(1,iElem)
!  BGMCellXmax = ElemToBGM_Shared(2,iElem)
!  BGMCellYmin = ElemToBGM_Shared(3,iElem)
!  BGMCellYmax = ElemToBGM_Shared(4,iElem)
!  BGMCellZmin = ElemToBGM_Shared(5,iElem)
!  BGMCellZmax = ElemToBGM_Shared(6,iElem)
!  ! add current Element to BGM-Elem
!  DO kBGM = BGMCellZmin,BGMCellZmax
!    DO jBGM = BGMCellYmin,BGMCellYmax
!      DO iBGM = BGMCellXmin,BGMCellXmax
!        GEO%FIBGM(iBGM,jBGM,kBGM)%nElem = GEO%FIBGM(iBGM,jBGM,kBGM)%nElem + 1
!        FIBGM_Element_Shared( FIBGM_offsetElem_Shared(iBGM,jBGM,kBGM) & ! offset of BGM cell in 1D array
!                            + offsetElemsInBGMCell(iBGM,jBGM,kBGM)    & ! offset of BGM nElems in local proc
!                            + GEO%FIBGM(iBGM,jBGM,kBGM)%nElem         ) = iElem
!      END DO ! kBGM
!    END DO ! jBGM
!  END DO ! iBGM
!END DO ! iElem
DEALLOCATE(offsetElemsInBGMCell)

CALL MPI_WIN_SYNC(FIBGM_Element_Shared_Win,IERROR)
CALL MPI_BARRIER(MPI_COMM_SHARED,iError)

! sum up Number of all elements on current compute-node (including halo region)
nTotalElems_Shared = 0
DO iElem = 1, nTotalElems
  IF (ElemInfo_Shared(ELEM_HALOFLAG,iElem).EQ.2 .OR. ElemInfo_Shared(ELEM_HALOFLAG,iElem).EQ.1) THEN
    nTotalElems_Shared = nTotalElems_Shared + 1
  END IF
END DO
ALLOCATE(offSetTotalElems(1:nTotalElems_Shared))
ALLOCATE(offSetSharedElems(1:nTotalElems))
nTotalElems_Shared = 0
offSetSharedElems(1:nTotalElems) = -1
DO iElem = 1,nTotalElems
  IF (ElemInfo_Shared(ELEM_HALOFLAG,iElem).EQ.1) THEN
    nTotalElems_Shared = nTotalElems_Shared + 1
    offSetTotalElems(nTotalElems_Shared) = iElem
    offsetSharedElems(iElem) = nTotalElems_Shared
  END IF
END DO
DO iElem = 1,nTotalElems
  IF (ElemInfo_Shared(ELEM_HALOFLAG,iElem).EQ.2) THEN
    nTotalElems_Shared = nTotalElems_Shared + 1
    offSetTotalElems(nTotalElems_Shared) = iElem
    offsetSharedElems(iElem) = nTotalElems_Shared
  END IF
END DO

!MPISharedSize = INT(nTotalElems_Shared,MPI_ADDRESS_KIND)*MPI_ADDRESS_KIND
!CALL Allocate_Shared(MPISharedSize,(/nTotalElems_Shared/),offSetTotalElems_Shared_Win,offsetTotalElems_Shared)
!CALL MPI_WIN_LOCK_ALL(0,offSetTotalElems_Shared_Win,IERROR)
!firstOffsetElem=INT(REAL(myRank_Shared*nTotalElems_Shared)/REAL(nProcessors_Shared))+1
!lastOffsetElem=INT(REAL((myRank_Shared+1)*nTotalElems_Shared)/REAL(nProcessors_Shared))
!offSetTotalElems_Shared(firstOffsetElem:lastOffsetElem) = offSetTotalElems(firstOfffsetElem:lastOffsetElem)
!CALL MPI_WIN_SYNC(offSetTotalElems_Shared_Win,IERROR)
!CALL MPI_BARRIER(MPI_COMM_SHARED,iError)
!DEALLOCATE(offSetTotalElems)

nTotalSides_Shared = nTotalElems_Shared * 6

#else
!/*NOT USE_MPI*/
ALLOCATE(ElemToBGM(1:6,1:nElems))

DO iElem = 1, nElems
  NodeCoordsPointer => NodeCoords(:,:,:,:,iElem)
  xmin=MINVAL(NodeCoordsPointer(1,:,:,:))
  xmax=MAXVAL(NodeCoordsPointer(1,:,:,:))
  ymin=MINVAL(NodeCoordsPointer(2,:,:,:))
  ymax=MAXVAL(NodeCoordsPointer(2,:,:,:))
  zmin=MINVAL(NodeCoordsPointer(3,:,:,:))
  zmax=MAXVAL(NodeCoordsPointer(3,:,:,:))
  ElemToBGM(1,iElem) = CEILING((xmin-GEO%xminglob)/GEO%FIBGMdeltas(1))
  ElemToBGM(2,iElem) = CEILING((xmax-GEO%xminglob)/GEO%FIBGMdeltas(1))
  ElemToBGM(3,iElem) = CEILING((ymin-GEO%yminglob)/GEO%FIBGMdeltas(2))
  ElemToBGM(4,iElem) = CEILING((ymax-GEO%yminglob)/GEO%FIBGMdeltas(2))
  ElemToBGM(5,iElem) = CEILING((zmin-GEO%zminglob)/GEO%FIBGMdeltas(3))
  ElemToBGM(6,iElem) = CEILING((zmax-GEO%zminglob)/GEO%FIBGMdeltas(3))
END DO ! iElem = 1, nElems

DO kBGM = BGMkmin,BGMkmax
  DO jBGM = BGMjmin,BGMjmax
    DO iBGM = BGMimin,BGMimax
      IF(GEO%FIBGM(iBGM,jBGM,kBGM)%nElem.EQ.0) CYCLE
      ALLOCATE(GEO%FIBGM(iBGM,jBGM,kBGM)%Element(1:GEO%FIBGM(iBGM,jBGM,kBGM)%nElem))
      GEO%FIBGM(iBGM,jBGM,kBGM)%nElem = 0
    END DO ! kBGM
  END DO ! jBGM
END DO ! iBGM
! initialize BGM min/max indeces using GEO min/max distances
GEO%FIBGMimax = INT((GEO%xmax-GEO%xminglob)/GEO%FIBGMdeltas(1))+1
GEO%FIBGMimin = INT((GEO%xmin-GEO%xminglob)/GEO%FIBGMdeltas(1))-1
GEO%FIBGMjmax = INT((GEO%ymax-GEO%yminglob)/GEO%FIBGMdeltas(2))+1
GEO%FIBGMjmin = INT((GEO%ymin-GEO%yminglob)/GEO%FIBGMdeltas(2))-1
GEO%FIBGMkmax = INT((GEO%zmax-GEO%zminglob)/GEO%FIBGMdeltas(3))+1
GEO%FIBGMkmin = INT((GEO%zmin-GEO%zminglob)/GEO%FIBGMdeltas(3))-1
! write global variables into function-local BGM indeces 
BGMimax = GEO%FIBGMimax
BGMimin = GEO%FIBGMimin
BGMjmax = GEO%FIBGMjmax
BGMjmin = GEO%FIBGMjmin
BGMkmax = GEO%FIBGMkmax
BGMkmin = GEO%FIBGMkmin

!--- map elements to background cells
DO iElem=1,PP_nElems
  BGMCellXmin = ElemToBGM(1,iElem)
  BGMCellXmax = ElemToBGM(2,iElem)
  BGMCellYmin = ElemToBGM(3,iElem)
  BGMCellYmax = ElemToBGM(4,iElem)
  BGMCellZmin = ElemToBGM(5,iElem)
  BGMCellZmax = ElemToBGM(6,iElem)
  ! add current Element to BGM-Elem
  DO kBGM = BGMCellZmin,BGMCellZmax
    DO jBGM = BGMCellYmin,BGMCellYmax
      DO iBGM = BGMCellXmin,BGMCellXmax
        GEO%FIBGM(iBGM,jBGM,kBGM)%nElem = GEO%FIBGM(iBGM,jBGM,kBGM)%nElem + 1
        GEO%FIBGM(iBGM,jBGM,kBGM)%Element(GEO%FIBGM(iBGM,jBGM,kBGM)%nElem) = iElem
      END DO ! kBGM
    END DO ! jBGM
  END DO ! iBGM
END DO ! iElem
#endif  /*USE_MPI*/

END SUBROUTINE BuildBGMAndIdentifyHaloRegion


END MODULE MOD_Particle_BGM
