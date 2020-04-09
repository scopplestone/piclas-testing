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

MODULE MOD_Particle_Boundary_Sampling
!===================================================================================================================================
!! Determines how particles interact with a given boundary condition
!===================================================================================================================================
! MODULES
! IMPLICIT VARIABLE HANDLING
IMPLICIT NONE
PRIVATE

!-----------------------------------------------------------------------------------------------------------------------------------
INTERFACE DefineParametersParticleBoundarySampling
  MODULE PROCEDURE DefineParametersParticleBoundarySampling
END INTERFACE

INTERFACE InitParticleBoundarySampling
  MODULE PROCEDURE InitParticleBoundarySampling
END INTERFACE

INTERFACE FinalizeParticleBoundarySampling
  MODULE PROCEDURE FinalizeParticleBoundarySampling
END INTERFACE

INTERFACE WriteSurfSampleToHDF5
  MODULE PROCEDURE WriteSurfSampleToHDF5
END INTERFACE

!#if USE_MPI
!INTERFACE ExchangeSurfData
!  MODULE PROCEDURE ExchangeSurfData
!END INTERFACE
!
!INTERFACE MapInnerSurfData
!  MODULE PROCEDURE MapInnerSurfData
!END INTERFACE
!#endif /*USE_MPI*/

PUBLIC::DefineParametersParticleBoundarySampling
PUBLIC::InitParticleBoundarySampling
PUBLIC::WriteSurfSampleToHDF5
PUBLIC::FinalizeParticleBoundarySampling
!#if USE_MPI
!PUBLIC::ExchangeSurfData
!PUBLIC::MapInnerSurfData
!#endif /*USE_MPI*/
!===================================================================================================================================

CONTAINS

!==================================================================================================================================
!> Define parameters for particles
!==================================================================================================================================
SUBROUTINE DefineParametersParticleBoundarySampling()
! MODULES
USE MOD_ReadInTools ,ONLY: prms,addStrListEntry
IMPLICIT NONE
!==================================================================================================================================
CALL prms%SetSection("Particle Boundary Sampling")
CALL prms%CreateIntOption(      'DSMC-nSurfSample'  , 'Define polynomial degree of particle BC sampling. Default: NGeo', '1')
CALL prms%CreateLogicalOption(  'CalcSurfaceImpact' , 'Sample average impact energy of particles for each species (trans, rot, '//&
                                                      'vib), impact vector and angle.','.FALSE.')

CALL prms%SetSection("Particle SurfCollis")
CALL prms%CreateLogicalOption(  'Particles-CalcSurfCollis_OnlySwaps'    , 'Count only wall collisions being SpeciesSwaps','.FALSE.')
CALL prms%CreateLogicalOption(  'Particles-CalcSurfCollis_Only0Swaps'   , 'Count only wall collisions being delete-SpeciesSwaps'&
                                                                          , '.FALSE.')
CALL prms%CreateLogicalOption(  'Particles-CalcSurfCollis_Output'       , 'Print sums of all counted wall collisions','.FALSE.')
CALL prms%CreateLogicalOption(  'Particles-AnalyzeSurfCollis'           , 'Output of collided/swaped particles during Sampling'//&
                                                                          ' period? ', '.FALSE.')
CALL prms%CreateIntOption(      'Particles-DSMC-maxSurfCollisNumber'    , 'Max. number of collided/swaped particles during'//&
                                                                          ' Sampling', '0')
CALL prms%CreateIntOption(      'Particles-DSMC-NumberOfBCs'            , 'Count of BC to be analyzed', '1')
CALL prms%CreateIntArrayOption( 'Particles-DSMC-SurfCollisBC'           , 'BCs to be analyzed (def.: 0 = all)')
CALL prms%CreateIntOption(      'Particles-CalcSurfCollis_NbrOfSpecies' , 'Count of Species for wall  collisions (0: all)' , '0')
CALL prms%CreateIntArrayOption( 'Particles-CalcSurfCollis_Species'      , 'Help array for reading surface stuff')

END SUBROUTINE DefineParametersParticleBoundarySampling


SUBROUTINE InitParticleBoundarySampling()
!===================================================================================================================================
! Initialization of particle boundary sampling
! default: use for sampling same polynomial degree as NGeo
! 1) all procs identify surfaces for sampling on the node (plus halo region)
! 2) the compute-node leaders communicate the number of sampling surfaces
! 3) every proc holds a copy of the complete sampling region on the node
!===================================================================================================================================
! MODULES                                                                                                                          !
!----------------------------------------------------------------------------------------------------------------------------------!
USE MOD_Globals
USE MOD_Basis                   ,ONLY: LegendreGaussNodesAndWeights
USE MOD_DSMC_Symmetry2D         ,ONLY:DSMC_2D_CalcSymmetryArea
USE MOD_Mesh_Vars               ,ONLY: NGeo,nBCs,BoundaryName
USE MOD_Particle_Boundary_Vars  ,ONLY: SurfOnNode
USE MOD_Particle_Boundary_Vars  ,ONLY: nSurfSample,dXiEQ_SurfSample,PartBound,XiEQ_SurfSample
USE MOD_Particle_Boundary_Vars  ,ONLY: nComputeNodeSurfSides,nComputeNodeSurfTotalSides
USE MOD_Particle_Boundary_Vars  ,ONLY: nSurfBC,SurfBCName
USE MOD_Particle_Boundary_Vars  ,ONLY: nSurfProcSides,nSurfTotalSides
USE MOD_Particle_Boundary_Vars  ,ONLY: GlobalSide2SurfSide,SurfSide2GlobalSide
USE MOD_Particle_Boundary_Vars  ,ONLY: CalcSurfCollis,AnalyzeSurfCollis,nPorousBC,CalcSurfaceImpact
USE MOD_Particle_Boundary_Vars  ,ONLY: SurfSideArea,SurfSampSize
USE MOD_Particle_Boundary_Vars  ,ONLY: SampWallState
USE MOD_Particle_Boundary_Vars  ,ONLY: SampWallPumpCapacity
USE MOD_Particle_Boundary_Vars  ,ONLY: SampWallImpactEnergy
USE MOD_Particle_Boundary_Vars  ,ONLY: SampWallImpactVector
USE MOD_Particle_Boundary_Vars  ,ONLY: SampWallImpactAngle
USE MOD_Particle_Boundary_Vars  ,ONLY: SampWallImpactNumber
USE MOD_Particle_Mesh_Vars      ,ONLY: ElemInfo_Shared,SideInfo_Shared,NodeCoords_Shared
USE MOD_Particle_Mesh_Vars      ,ONLY: ElemSideNodeID_Shared
USE MOD_Particle_Surfaces       ,ONLY: EvaluateBezierPolynomialAndGradient
USE MOD_Particle_Surfaces_Vars  ,ONLY: BezierControlPoints3D,BezierSampleN
USE MOD_Particle_Tracking_Vars  ,ONLY: TriaTracking
USE MOD_Particle_Vars           ,ONLY: nSpecies,VarTimeStep
USE MOD_Particle_Vars           ,ONLY: Symmetry2D
USE MOD_PICDepo_Vars            ,ONLY: LastAnalyzeSurfCollis
USE MOD_PICDepo_Vars            ,ONLY: SFResampleAnalyzeSurfCollis
USE MOD_ReadInTools             ,ONLY: GETINT,GETLOGICAL,GETINTARRAY
#if USE_MPI
USE MOD_MPI_Shared              ,ONLY: Allocate_Shared
USE MOD_MPI_Shared_Vars         ,ONLY: MPI_COMM_SHARED,MPIRankLeader
USE MOD_MPI_Shared_Vars         ,ONLY: MPI_COMM_LEADERS_SURF
USE MOD_MPI_Shared_Vars         ,ONLY: myComputeNodeRank,nComputeNodeProcessors
USE MOD_MPI_Shared_Vars         ,ONLY: nComputeNodeTotalSides,nNonUniqueGlobalSides
USE MOD_MPI_Shared_Vars         ,ONLY: offsetComputeNodeElem,nComputeNodeElems
USE MOD_MPI_Shared_Vars         ,ONLY: myLeaderGroupRank,nLeaderGroupProcs
USE MOD_Particle_Boundary_Vars  ,ONLY: GlobalSide2SurfSide_Shared,GlobalSide2SurfSide_Shared_Win
USE MOD_Particle_Boundary_Vars  ,ONLY: SurfSide2GlobalSide_Shared,SurfSide2GlobalSide_Shared_Win
USE MOD_Particle_Boundary_Vars  ,ONLY: SurfSideArea_Shared,SurfSideArea_Shared_Win
USE MOD_Particle_Boundary_Vars  ,ONLY: SampWallState_Shared,SampWallState_Shared_Win
USE MOD_Particle_Boundary_Vars  ,ONLY: SampWallPumpCapacity_Shared,SampWallPumpCapacity_Shared_Win
USE MOD_Particle_Boundary_Vars  ,ONLY: SampWallImpactEnergy_Shared,SampWallImpactEnergy_Shared_Win
USE MOD_Particle_Boundary_Vars  ,ONLY: SampWallImpactVector_Shared,SampWallImpactVector_Shared_Win
USE MOD_Particle_Boundary_Vars  ,ONLY: SampWallImpactAngle_Shared,SampWallImpactAngle_Shared_Win
USE MOD_Particle_Boundary_Vars  ,ONLY: SampWallImpactNumber_Shared,SampWallImpactNumber_Shared_Win
USE MOD_Particle_MPI_Boundary_Sampling,ONLY: InitSurfCommunication
#else
!
#endif /*USE_MPI*/
! IMPLICIT VARIABLE HANDLING
IMPLICIT NONE
!----------------------------------------------------------------------------------------------------------------------------------!
! INPUT VARIABLES
!----------------------------------------------------------------------------------------------------------------------------------!
! OUTPUT VARIABLES
!-----------------------------------------------------------------------------------------------------------------------------------
! LOCAL VARIABLES
INTEGER                                :: iBC,iSpec
INTEGER                                :: iSide,firstSide,lastSide
INTEGER,ALLOCATABLE                    :: GlobalSide2SurfSideProc(:,:)
INTEGER,ALLOCATABLE                    :: CalcSurfCollis_SpeciesRead(:)                       ! help array for reading surface stuff
CHARACTER(20)                          :: hilf,hilf2
CHARACTER(LEN=255),ALLOCATABLE         :: BCName(:)
! surface area
INTEGER                                :: SideID,ElemID,LocSideID
INTEGER                                :: p,q,iSample,jSample
INTEGER                                :: TriNum, Node1, Node2
REAL                                   :: area,nVal
REAL,DIMENSION(2,3)                    :: gradXiEta3D
REAL,DIMENSION(:),ALLOCATABLE          :: Xi_NGeo,wGP_NGeo
REAL                                   :: XiOut(1:2),E,F,G,D,tmp1,tmpI2,tmpJ2
REAL                                   :: xNod, zNod, yNod, Vector1(3), Vector2(3), nx, ny, nz
#if USE_MPI
INTEGER                                :: iLeader
INTEGER                                :: offsetSurfTotalSidesProc
INTEGER                                :: GlobalElemID,GlobalElemRank
INTEGER(KIND=MPI_ADDRESS_KIND)         :: MPISharedSize
INTEGER                                :: sendbuf,recvbuf
#endif /*USE_MPI*/
!===================================================================================================================================

! Get input parameters
SWRITE(UNIT_stdOut,'(A)') ' INIT SURFACE SAMPLING ...'

WRITE(UNIT=hilf,FMT='(I0)') NGeo
nSurfSample = GETINT('DSMC-nSurfSample',TRIM(hilf))

IF((nSurfSample.GT.1).AND.(TriaTracking)) &
  CALL abort(__STAMP__,'nSurfSample cannot be >1 if TriaTracking=T')

IF (ANY(PartBound%Reactive)) THEN
  IF (nSurfSample.NE.BezierSampleN) THEN
    SWRITE (*,*) "nSurfSample   =", nSurfSample
    SWRITE (*,*) "BezierSampleN =", BezierSampleN
    CALL abort(__STAMP__,'Error: nSurfSample not equal to BezierSampleN. Problem for Desorption + Surfflux')
  END IF
END IF

! Sampling of impact energy for each species (trans, rot, vib), impact vector (x,y,z) and angle
CalcSurfaceImpact = GETLOGICAL('CalcSurfaceImpact')

! Calculate equidistant surface points
ALLOCATE(XiEQ_SurfSample(0:nSurfSample))

dXiEQ_SurfSample =2./REAL(nSurfSample)
DO q=0,nSurfSample
  XiEQ_SurfSample(q) = dXiEQ_SurfSample * REAL(q) - 1.
END DO

! Allocate shared array for surf sides
#if USE_MPI
MPISharedSize = INT((3*nComputeNodeTotalSides),MPI_ADDRESS_KIND)*MPI_ADDRESS_KIND
CALL Allocate_Shared(MPISharedSize,(/3,nComputeNodeTotalSides/),GlobalSide2SurfSide_Shared_Win,GlobalSide2SurfSide_Shared)
CALL MPI_WIN_LOCK_ALL(0,GlobalSide2SurfSide_Shared_Win,IERROR)
GlobalSide2SurfSide => GlobalSide2SurfSide_Shared
#else
ALLOCATE(GlobalSide2SurfSide(1:3,1:nComputeNodeTotalSides))
#endif /*USE_MPI*/

! only CN root nullifies
#if USE_MPI
IF (myComputeNodeRank.EQ.0) THEN
#endif /* USE_MPI*/
  nComputeNodeTotalSides = -1.
#if USE_MPI
END IF

CALL MPI_WIN_SYNC(GlobalSide2SurfSide_Shared_Win,IERROR)
CALL MPI_BARRIER(MPI_COMM_SHARED,iError)
#endif /* USE_MPI*/

! create boundary name mapping for surfaces SurfaceBC number mapping
nSurfBC = 0
ALLOCATE(BCName(1:nBCs))
DO iBC=1,nBCs
  BCName=''
END DO
DO iBC=1,nBCs
  ! inner side (can be just in the name list from preproc although already sorted out)
  IF (PartBound%MapToPartBC(iBC).EQ.-1) CYCLE

  ! count number of reflective BCs
  IF (PartBound%TargetBoundCond(PartBound%MapToPartBC(iBC)).EQ.PartBound%ReflectiveBC) THEN
    nSurfBC         = nSurfBC + 1
    BCName(nSurfBC) = BoundaryName(iBC)
  END IF
END DO

IF (nSurfBC.GE.1) THEN
ALLOCATE(SurfBCName(1:nSurfBC))
  DO iBC=1,nSurfBC
    SurfBCName(iBC) = BCName(iBC)
  END DO
END IF
DEALLOCATE(BCName)

! get number of BC-Sides
#if USE_MPI
! NO HALO REGION REDUCTION
firstSide = INT(REAL( myComputeNodeRank   *nNonUniqueGlobalSides)/REAL(nComputeNodeProcessors))+1
lastSide  = INT(REAL((myComputeNodeRank+1)*nNonUniqueGlobalSides)/REAL(nComputeNodeProcessors))
ALLOCATE(GlobalSide2SurfSideProc(1:3,firstSide:lastSide))
#else
firstSide = 1
lastSide  = nComputeNodeTotalSides
ALLOCATE(GlobalSide2SurfSideProc(1:3,1:nComputeNodeTotalSides))
#endif /*USE_MPI*/

GlobalSide2SurfSideProc    = -1
nComputeNodeSurfSides      = 0
nComputeNodeSurfTotalSides = 0

! check every BC side
DO iSide = firstSide,lastSide
  ! ignore non-BC sides
  IF (SideInfo_Shared(SIDE_BCID,iSide).LE.0) CYCLE

  ! ignore sides outside of halo region
  IF (ElemInfo_Shared(ELEM_HALOFLAG,SideInfo_Shared(SIDE_ELEMID,iSide)).EQ.0) CYCLE

  ! count number of reflective and inner BC sides
  IF ((PartBound%TargetBoundCond(PartBound%MapToPartBC(SideInfo_Shared(SIDE_BCID,iSide))).EQ.PartBound%ReflectiveBC) .OR. &
      (SideInfo_Shared(SIDE_TYPE,iSide).EQ.100)) THEN
    nComputeNodeSurfTotalSides = nComputeNodeSurfTotalSides + 1
#if USE_MPI
    ! check if element for this side is on the current compute-node
    IF ((SideInfo_Shared(SIDE_ID,iSide).GT.ElemInfo_Shared(ELEM_FIRSTSIDEIND,offsetComputeNodeElem+1))                  .AND. &
        (SideInfo_Shared(SIDE_ID,iSide).LE.ElemInfo_Shared(ELEM_LASTSIDEIND ,offsetComputeNodeElem+nComputeNodeElems))) THEN
      nComputeNodeSurfSides  = nComputeNodeSurfSides + 1
    END IF

    ! TODO: Add another check to determine the surface side in halo_eps from current proc. Node-wide halo can become quite large with
    !       with 128 procs!

#endif /*USE_MPI*/
    ! Write local mapping from Side to Surf side. The rank is already correct, the offset must be corrected by the proc offset later
    GlobalSide2SurfSideProc(SURF_SIDEID,iSide) = nComputeNodeSurfTotalSides
    GlobalSide2SurfSideProc(SURF_RANK  ,iSide) = ElemInfo_Shared(ELEM_RANK,SideInfo_Shared(SIDE_ELEMID,iSide))
    ! get global Elem ID
    GlobalElemID   = SideInfo_Shared(SIDE_ELEMID,iSide)
    GlobalElemRank = ElemInfo_Shared(ELEM_RANK,GlobalElemID)
    ! running on one node, everything belongs to us
    IF (nLeaderGroupProcs.EQ.1) THEN
      GlobalSide2SurfSideProc(SURF_LEADER,iSide) = myLeaderGroupRank
    ELSE
      ! find the compute node
      DO iLeader = 0,nLeaderProcs-1
        IF ((GlobalElemRank.GE.MPIRankLeader(iLeader)).AND.(GlobalElemRank.LT.MPIRankLeader(iLeader+1))) THEN
          GlobalSide2SurfSideProc(SURF_LEADER,iSide) = iLeader
          EXIT
        END IF
      END DO
    END IF
  END IF
END DO

! Find CN global number of surf sides and write Side to Surf Side mapping into shared array
#if USE_MPI
sendbuf = nComputeNodeSurfTotalSides
recvbuf = 0
CALL MPI_EXSCAN(sendbuf,recvbuf,1,MPI_INTEGER,MPI_SUM,MPI_COMM_SHARED,iError)
offsetSurfTotalSidesProc   = recvbuf
! last proc knows CN total number of BC elems
sendbuf = offsetSurfTotalSidesProc + nComputeNodeSurfTotalSides
CALL MPI_BCAST(sendbuf,1,MPI_INTEGER,nComputeNodeProcessors-1,MPI_COMM_SHARED,iError)
nComputeNodeSurfTotalSides = sendbuf

! nComputeNodeSurfSides can use ALLREDUCE as we are not interested in the offset
CALL MPI_ALLREDUCE(MPI_IN_PLACE,nComputeNodeSurfSides,1,MPI_INTEGER,MPI_SUM,MPI_COMM_SHARED,iError)

! increment SURF_SIDEID by offset
DO iSide = firstSide,lastSide
  IF (GlobalSide2SurfSideProc(SURF_SIDEID,iSide).EQ.-1) CYCLE
  GlobalSide2SurfSideProc(SURF_SIDEID,iSide) = GlobalSide2SurfSideProc(SURF_SIDEID,iSide) + offsetSurfTotalSidesProc
END DO

GlobalSide2SurfSide(SURF_SIDEID,firstSide:lastSide) = GlobalSide2SurfSideProc(SURF_SIDEID,firstSide:lastSide)
GlobalSide2SurfSide(SURF_RANK  ,firstSide:lastSide) = GlobalSide2SurfSideProc(SURF_RANK  ,firstSide:lastSide)
GlobalSide2SurfSide(SURF_LEADER,firstSide:lastSide) = GlobalSide2SurfSideProc(SURF_LEADER,firstSide:lastSide)

#else
offsetSurfTotalSidesProc  = 0

GlobalSide2SurfSide(:          ,firstSide:lastSide) = GlobalSide2SurfSide(:,firstSide:lastSide)
#endif /*USE_MPI*/
DEALLOCATE(GlobalSide2SurfSideProc)

! Build inverse mapping
#if USE_MPI
MPISharedSize = INT((3*nComputeNodeSurfTotalSides),MPI_ADDRESS_KIND)*MPI_ADDRESS_KIND
CALL Allocate_Shared(MPISharedSize,(/3,nComputeNodeSurfTotalSides/),SurfSide2GlobalSide_Shared_Win,SurfSide2GlobalSide_Shared)
CALL MPI_WIN_LOCK_ALL(0,SurfSide2GlobalSide_Shared_Win,IERROR)
SurfSide2GlobalSide => SurfSide2GlobalSide_Shared
#else
ALLOCATE(SurfSide2GlobalSide(1:3,1:nComputeNodeSurfTotalSides))
#endif /*USE_MPI*/

! only CN root nullifies
#if USE_MPI
IF (myComputeNodeRank.EQ.0) THEN
#endif /* USE_MPI*/
  SurfSide2GlobalSide = -1.
#if USE_MPI
END IF

CALL MPI_WIN_SYNC(GlobalSide2SurfSide_Shared_Win,IERROR)
CALL MPI_WIN_SYNC(SurfSide2GlobalSide_Shared_Win,IERROR)
CALL MPI_BARRIER(MPI_COMM_SHARED,iError)
#endif /* USE_MPI*/

#if USE_MPI
IF (myComputeNodeRank.EQ.0) THEN
#endif /* USE_MPI*/
  nSurfProcSides = 0
  DO iSide = 1,nNonUniqueGlobalSides
    IF (GlobalSide2SurfSide(SURF_SIDEID,iSide).EQ.-1) CYCLE

    nSurfProcSides = nSurfProcSides + 1
    SurfSide2GlobalSide(:,nSurfProcSides) = GlobalSide2SurfSide(:,iSide)
  END DO
#if USE_MPI
END IF
CALL MPI_WIN_SYNC(SurfSide2GlobalSide_Shared_Win,IERROR)
CALL MPI_BARRIER(MPI_COMM_SHARED,iError)
#endif /* USE_MPI */

! flag if there is at least one surf side on the node (sides in halo region do also count)
SurfOnNode = .FALSE.
IF (nComputeNodeSurfTotalSides.GT.0) SurfOnNode = .TRUE.

!> Leader communication
#if USE_MPI
IF (myComputeNodeRank.EQ.0) THEN
  CALL InitSurfCommunication()
END IF
CALL MPI_BCAST(nSurfTotalSides,1,MPI_INTEGER,0,MPI_COMM_SHARED,iError)
#else
nSurfTotalSides = nComputeNodeTotalSides
#endif /* USE_MPI */

!> User sanity check
SWRITE(UNIT_stdOut,'(A,I8)') ' nGlobalSurfSides ', nSurfTotalSides

!> Energy + Force + nSpecies
SurfSampSize = 9+3+nSpecies
IF(VarTimeStep%UseVariableTimeStep) SurfSampSize = SurfSampSize + 1

! Initialize surface collision sampling and analyze
CalcSurfCollis%OnlySwaps         = GETLOGICAL('Particles-CalcSurfCollis_OnlySwaps' ,'.FALSE.')
CalcSurfCollis%Only0Swaps        = GETLOGICAL('Particles-CalcSurfCollis_Only0Swaps','.FALSE.')
CalcSurfCollis%Output            = GETLOGICAL('Particles-CalcSurfCollis_Output'    ,'.FALSE.')
IF (CalcSurfCollis%Only0Swaps) CalcSurfCollis%OnlySwaps=.TRUE.
CalcSurfCollis%AnalyzeSurfCollis = GETLOGICAL('Particles-AnalyzeSurfCollis'        ,'.FALSE.')
AnalyzeSurfCollis%NumberOfBCs = 1 !initialize for ifs (BCs=0 means all)

ALLOCATE(AnalyzeSurfCollis%BCs(1))
AnalyzeSurfCollis%BCs = 0
IF (.NOT.CalcSurfCollis%AnalyzeSurfCollis .AND. SFResampleAnalyzeSurfCollis) &
  CALL abort(__STAMP__,'ERROR: SFResampleAnalyzeSurfCollis was set without CalcSurfCollis%AnalyzeSurfCollis!')

IF (CalcSurfCollis%AnalyzeSurfCollis) THEN
  AnalyzeSurfCollis%maxPartNumber = GETINT('Particles-DSMC-maxSurfCollisNumber','0')
  AnalyzeSurfCollis%NumberOfBCs   = GETINT('Particles-DSMC-NumberOfBCs'        ,'1')
  IF (AnalyzeSurfCollis%NumberOfBCs.EQ.1) THEN !already allocated
    AnalyzeSurfCollis%BCs    = GETINTARRAY('Particles-DSMC-SurfCollisBC'     ,1,'0') ! 0 means all...
  ELSE
    DEALLOCATE(AnalyzeSurfCollis%BCs)
    ALLOCATE(AnalyzeSurfCollis%BCs(1:AnalyzeSurfCollis%NumberOfBCs)) !dummy
    hilf2=''
    ! build default string: 0,0,0,...
    DO iBC=1,AnalyzeSurfCollis%NumberOfBCs
      WRITE(UNIT=hilf,FMT='(I0)') 0
      hilf2=TRIM(hilf2)//TRIM(hilf)
      IF (iBC.NE.AnalyzeSurfCollis%NumberOfBCs) hilf2=TRIM(hilf2)//','
    END DO
    AnalyzeSurfCollis%BCs    = GETINTARRAY('Particles-DSMC-SurfCollisBC',AnalyzeSurfCollis%NumberOfBCs,TRIM(hilf2))
  END IF
  ALLOCATE(AnalyzeSurfCollis%Data(1:AnalyzeSurfCollis%maxPartNumber,1:9))
  ALLOCATE(AnalyzeSurfCollis%Spec(1:AnalyzeSurfCollis%maxPartNumber))
  ALLOCATE(AnalyzeSurfCollis%BCid(1:AnalyzeSurfCollis%maxPartNumber))
  ALLOCATE(AnalyzeSurfCollis%Number(1:nSpecies+1))
  IF (LastAnalyzeSurfCollis%Restart) THEN
    CALL ReadAnalyzeSurfCollisToHDF5()
  END IF
  AnalyzeSurfCollis%Data   = 0.
  AnalyzeSurfCollis%Spec   = 0
  AnalyzeSurfCollis%BCid   = 0
  AnalyzeSurfCollis%Number = 0
END IF

! Species-dependent calculations
ALLOCATE(CalcSurfCollis%SpeciesFlags(1:nSpecies))
CalcSurfCollis%NbrOfSpecies = GETINT('Particles-CalcSurfCollis_NbrOfSpecies','0')

IF ( (CalcSurfCollis%NbrOfSpecies.GT.0) .AND. (CalcSurfCollis%NbrOfSpecies.LE.nSpecies) ) THEN
  ALLOCATE(CalcSurfCollis_SpeciesRead(1:CalcSurfCollis%NbrOfSpecies))
  hilf2=''
  ! build default string: 1 - CSC_NoS
  DO iSpec=1,CalcSurfCollis%NbrOfSpecies
    WRITE(UNIT=hilf,FMT='(I0)') iSpec
    hilf2=TRIM(hilf2)//TRIM(hilf)
    IF (ispec.NE.CalcSurfCollis%NbrOfSpecies) hilf2=TRIM(hilf2)//','
  END DO
  CalcSurfCollis_SpeciesRead  = GETINTARRAY('Particles-CalcSurfCollis_Species',CalcSurfCollis%NbrOfSpecies,TRIM(hilf2))
  CalcSurfCollis%SpeciesFlags(:) = .FALSE.
  DO iSpec=1,CalcSurfCollis%NbrOfSpecies
    CalcSurfCollis%SpeciesFlags(CalcSurfCollis_SpeciesRead(ispec)) = .TRUE.
  END DO
  DEALLOCATE(CalcSurfCollis_SpeciesRead)
ELSE IF (CalcSurfCollis%NbrOfSpecies.EQ.0) THEN !default
  CalcSurfCollis%SpeciesFlags(:) = .TRUE.
ELSE
  CALL ABORT(__STAMP__,'Error in Particles-CalcSurfCollis_NbrOfSpecies!')
END IF

! surface sampling array do not need to be allocated if there are no sides within halo_eps range
IF(.NOT.SurfOnNode) RETURN

! allocate everything. Caution: SideID is surfSideID, not global ID
!> First local arrays for boundary sampling
!>>> Pointer structure type ruins possibility of ALLREDUCE, need separate arrays for everything
ALLOCATE(SampWallState(1:SurfSampSize,1:nSurfSample,1:nSurfSample,1:nComputeNodeSurfTotalSides))
SampWallState = 0.
!
IF(nPorousBC.GT.0) THEN
  ALLOCATE(SampWallPumpCapacity(1:nComputeNodeSurfTotalSides))
  SampWallPumpCapacity = 0.
END IF
! Sampling of impact energy for each species (trans, rot, vib), impact vector (x,y,z) and angle
IF (CalcSurfaceImpact) THEN
  ALLOCATE( SampWallImpactEnergy(1:nSpecies,1:3,1:nSurfSample,1:nSurfSample,1:nComputeNodeSurfTotalSides) &
          , SampWallImpactVector(1:nSpecies,1:3,1:nSurfSample,1:nSurfSample,1:nComputeNodeSurfTotalSides) &
          , SampWallImpactAngle (1:nSpecies,    1:nSurfSample,1:nSurfSample,1:nComputeNodeSurfTotalSides) &
          , SampWallImpactNumber(1:nSpecies,    1:nSurfSample,1:nSurfSample,1:nComputeNodeSurfTotalSides))
  SampWallImpactEnergy = 0.
  SampWallImpactVector = 0.
  SampWallImpactAngle  = 0.
  SampWallImpactNumber = 0.
END IF

#if USE_MPI
!> Then shared arrays for boundary sampling
MPISharedSize = INT((SurfSampSize*nSurfSample*nSurfSample*nComputeNodeSurfTotalSides),MPI_ADDRESS_KIND)*MPI_ADDRESS_KIND
CALL Allocate_Shared(MPISharedSize,(/SurfSampSize,nSurfSample,nSurfSample,nComputeNodeSurfTotalSides/),SampWallState_Shared_Win,SampWallState_Shared)
CALL MPI_WIN_LOCK_ALL(0,SampWallState_Shared_Win,IERROR)
IF (myComputeNodeRank.EQ.0) THEN
  SampWallState_Shared = 0.
END IF
CALL MPI_WIN_SYNC(SampWallState_Shared_Win,IERROR)
!
IF(nPorousBC.GT.0) THEN
  MPISharedSize = INT((nComputeNodeSurfTotalSides),MPI_ADDRESS_KIND)*MPI_ADDRESS_KIND
  CALL Allocate_Shared(MPISharedSize,(/nComputeNodeSurfTotalSides/),SampWallPumpCapacity_Shared_Win,SampWallPumpCapacity_Shared)
  CALL MPI_WIN_LOCK_ALL(0,SampWallPumpCapacity_Shared_Win,IERROR)
  IF (myComputeNodeRank.EQ.0) THEN
    SampWallPumpCapacity_Shared = 0.
  END IF
  CALL MPI_WIN_SYNC(SampWallPumpCapacity_Shared_Win,IERROR)
END IF
! Sampling of impact energy for each species (trans, rot, vib), impact vector (x,y,z) and angle
IF (CalcSurfaceImpact) THEN
  MPISharedSize = INT((nSpecies*3*nSurfSample*nSurfSample*nComputeNodeSurfTotalSides),MPI_ADDRESS_KIND)*MPI_ADDRESS_KIND
  CALL Allocate_Shared(MPISharedSize,(/nSpecies,3,nSurfSample,nSurfSample,nComputeNodeSurfTotalSides/),SampWallImpactEnergy_Shared_Win &
                                                                                                      ,SampWallImpactEnergy_Shared)
  CALL Allocate_Shared(MPISharedSize,(/nSpecies,3,nSurfSample,nSurfSample,nComputeNodeSurfTotalSides/),SampWallImpactVector_Shared_Win &
                                                                                                      ,SampWallImpactVector_Shared)
  MPISharedSize = INT((nSpecies*nSurfSample*nSurfSample*nComputeNodeSurfTotalSides),MPI_ADDRESS_KIND)*MPI_ADDRESS_KIND
  CALL Allocate_Shared(MPISharedSize,(/nSpecies,  nSurfSample,nSurfSample,nComputeNodeSurfTotalSides/),SampWallImpactAngle_Shared_Win  &
                                                                                                      ,SampWallImpactAngle_Shared)
  CALL Allocate_Shared(MPISharedSize,(/nSpecies,  nSurfSample,nSurfSample,nComputeNodeSurfTotalSides/),SampWallImpactNumber_Shared_Win &
                                                                                                      ,SampWallImpactNumber_Shared)
  IF (myComputeNodeRank.EQ.0) THEN
    SampWallImpactEnergy_Shared = 0.
    SampWallImpactVector_Shared = 0.
    SampWallImpactAngle_Shared  = 0.
    SampWallImpactNumber_Shared = 0.
  END IF
  CALL MPI_WIN_SYNC(SampWallImpactEnergy_Shared_Win,IERROR)
  CALL MPI_WIN_SYNC(SampWallImpactVector_Shared_Win,IERROR)
  CALL MPI_WIN_SYNC(SampWallImpactAngle_Shared_Win ,IERROR)
  CALL MPI_WIN_SYNC(SampWallImpactNumber_Shared_Win,IERROR)
END IF
#endif /*USE_MPI*/

! Surf sides are shared, array calculation can be distributed
#if USE_MPI
MPISharedSize = INT((nSurfSample*nSurfSample*nComputeNodeSurfTotalSides),MPI_ADDRESS_KIND)*MPI_ADDRESS_KIND
CALL Allocate_Shared(MPISharedSize,(/nSurfSample,nSurfSample,nComputeNodeSurfTotalSides/),SurfSideArea_Shared_Win,SurfSideArea_Shared)
CALL MPI_WIN_LOCK_ALL(0,SurfSideArea_Shared_Win,IERROR)
SurfSideArea => SurfSideArea_Shared

firstSide = INT(REAL( myComputeNodeRank   *nComputeNodeSurfTotalSides)/REAL(nComputeNodeProcessors))+1
lastSide  = INT(REAL((myComputeNodeRank+1)*nComputeNodeSurfTotalSides)/REAL(nComputeNodeProcessors))
#else
ALLOCATE(SurfSideArea(1:nSurfSample,1:nSurfSample,1:nSurfTotalSides))

firstSide = 1
lastSide  = nSurfTotalSides
#endif /*USE_MPI*/

#if USE_MPI
IF (myComputeNodeRank.EQ.0) THEN
#endif /*USE_MPI*/
  SurfSideArea=0.
#if USE_MPI
END IF
CALL MPI_WIN_SYNC(SurfSideArea_Shared_Win,IERROR)
CALL MPI_BARRIER(MPI_COMM_SHARED,IERROR)
#endif /*USE_MPI*/

! get interpolation points and weights
ALLOCATE( Xi_NGeo( 0:NGeo)  &
        , wGP_NGeo(0:NGeo) )
CALL LegendreGaussNodesAndWeights(NGeo,Xi_NGeo,wGP_NGeo)

! compute area of sub-faces
tmp1=dXiEQ_SurfSample/2.0 !(b-a)/2

DO iSide = firstSide,LastSide
  ! get global SideID. This contains only nonUniqueSide, no special mortar treatment required
  SideID = SurfSide2GlobalSide(SURF_SIDEID,iSide)

  IF (TriaTracking) THEN
    ElemID    = SideInfo_Shared(SIDE_ELEMID ,SideID)
    LocSideID = SideInfo_Shared(SIDE_LOCALID,SideID)
    area = 0.
    xNod = NodeCoords_Shared(1,ElemSideNodeID_Shared(1,LocSideID,ElemID))
    yNod = NodeCoords_Shared(2,ElemSideNodeID_Shared(1,LocSideID,ElemID))
    zNod = NodeCoords_Shared(3,ElemSideNodeID_Shared(1,LocSideID,ElemID))
    IF(Symmetry2D) THEN
      SurfSideArea(1,1,iSide) = DSMC_2D_CalcSymmetryArea(LocSideID,ElemID)
    ELSE
      DO TriNum = 1,2
        Node1 = TriNum+1     ! normal = cross product of 1-2 and 1-3 for first triangle
        Node2 = TriNum+2     !          and 1-3 and 1-4 for second triangle
        Vector1(1) = NodeCoords_Shared(1,ElemSideNodeID_Shared(Node1,LocSideID,ElemID)) - xNod
        Vector1(2) = NodeCoords_Shared(2,ElemSideNodeID_Shared(Node1,LocSideID,ElemID)) - yNod
        Vector1(3) = NodeCoords_Shared(3,ElemSideNodeID_Shared(Node1,LocSideID,ElemID)) - zNod
        Vector2(1) = NodeCoords_Shared(1,ElemSideNodeID_Shared(Node2,LocSideID,ElemID)) - xNod
        Vector2(2) = NodeCoords_Shared(2,ElemSideNodeID_Shared(Node2,LocSideID,ElemID)) - yNod
        Vector2(3) = NodeCoords_Shared(3,ElemSideNodeID_Shared(Node2,LocSideID,ElemID)) - zNod
        nx = - Vector1(2) * Vector2(3) + Vector1(3) * Vector2(2) !NV (inwards)
        ny = - Vector1(3) * Vector2(1) + Vector1(1) * Vector2(3)
        nz = - Vector1(1) * Vector2(2) + Vector1(2) * Vector2(1)
        nVal = SQRT(nx*nx + ny*ny + nz*nz)
        area = area + nVal/2.
      END DO
      SurfSideArea(1,1,iSide) = area
    END IF
  ! .NOT. TriaTracking
  ELSE
    ! call here stephens algorithm to compute area
    DO jSample=1,nSurfSample
      DO iSample=1,nSurfSample
        area=0.
        tmpI2=(XiEQ_SurfSample(iSample-1)+XiEQ_SurfSample(iSample))/2. ! (a+b)/2
        tmpJ2=(XiEQ_SurfSample(jSample-1)+XiEQ_SurfSample(jSample))/2. ! (a+b)/2
        DO q=0,NGeo
          DO p=0,NGeo
            XiOut(1)=tmp1*Xi_NGeo(p)+tmpI2
            XiOut(2)=tmp1*Xi_NGeo(q)+tmpJ2
            CALL EvaluateBezierPolynomialAndGradient(XiOut,NGeo,3,BezierControlPoints3D(1:3,0:NGeo,0:NGeo,SideID) &
                                                    ,Gradient=gradXiEta3D)
            ! calculate first fundamental form
            E=DOT_PRODUCT(gradXiEta3D(1,1:3),gradXiEta3D(1,1:3))
            F=DOT_PRODUCT(gradXiEta3D(1,1:3),gradXiEta3D(2,1:3))
            G=DOT_PRODUCT(gradXiEta3D(2,1:3),gradXiEta3D(2,1:3))
            D=SQRT(E*G-F*F)
            area = area+tmp1*tmp1*D*wGP_NGeo(p)*wGP_NGeo(q)
          END DO
        END DO
        SurfSideArea(iSample,jSample,iSide) = area
      END DO ! iSample=1,nSurfSample
    END DO ! jSample=1,nSurfSample
  END IF
END DO ! iSide = firstSide,lastSide

#if USE_MPI
CALL MPI_WIN_SYNC(SurfSideArea_Shared_Win,IERROR)
CALL MPI_BARRIER(MPI_COMM_SHARED,IERROR)
#endif /*USE_MPI*/

! get the full area of all surface sides
area=0.

#if USE_MPI
IF (myComputeNodeRank.EQ.0) THEN
#endif /*USE_MPI*/
  DO iSide = 1,nComputeNodeSurfTotalSides
    ! ignore sides in halo region
    IF (SurfSide2GlobalSide(SURF_LEADER,iSide).NE.myLeaderGroupRank) CYCLE

    area = area + SUM(SurfSideArea(:,:,iSide))
  END DO ! iSide = 1,nComputeNodeSurfTotalSides
#if USE_MPI
  ! surf leaders communicate total surface area
  CALL MPI_ALLREDUCE(MPI_IN_PLACE,area,1,MPI_DOUBLE_PRECISION,MPI_SUM,MPI_COMM_LEADERS_SURF,IERROR)
END IF

! surf leaders inform the other procs on their node
CALL MPI_BCAST(area,1,MPI_DOUBLE_PRECISION,0,MPI_COMM_SHARED,iError)
#endif /*USE_MPI*/

SWRITE(UNIT_stdOut,'(A,ES25.14E3)') ' Surface-Area: ', Area

! de-allocate temporary interpolation points and weights
DEALLOCATE(Xi_NGeo,wGP_NGeo)

SWRITE(UNIT_stdOut,'(A)') ' ... DONE.'

END SUBROUTINE InitParticleBoundarySampling

#if USE_MPI


!SUBROUTINE GetHaloSurfMapping()
!!===================================================================================================================================
!! build all missing stuff for surface-sampling communicator, like
!! offSetMPI
!! MPI-neighbor list
!! PartHaloSideToProc
!! only receiving process knows to which local side the sending information is going, the sending process does not know the final
!! sideid
!! if only a processes has to send his data to another, the whole structure is build, but not filled. only if the nsidesrecv,send>0
!! communication is performed
!!===================================================================================================================================
!! MODULES                                                                                                                          !
!!----------------------------------------------------------------------------------------------------------------------------------!
!USE MOD_Globals
!USE MOD_Preproc
!USE MOD_Mesh_Vars              ,ONLY: nSides,nBCSides
!USE MOD_Particle_Mesh_Vars     ,ONLY: ElemInfo_Shared
!USE MOD_Particle_Boundary_Vars ,ONLY: SurfMesh,SurfComm,nSurfSample, nPorousBC, nPorousBCVars,CalcSurfaceImpact
!USE MOD_Particle_MPI_Vars      ,ONLY: PartHaloSideToProc,SurfSendBuf,SurfRecvBuf,SurfExchange!,PartHaloElemToProc
!USE MOD_Particle_Mesh_Vars     ,ONLY: nTotalSides,PartSideToElem,PartElemToSide
!USE MOD_Particle_MPI_Vars      ,ONLY: PorousBCSendBuf,PorousBCRecvBuf
!USE MOD_Particle_Vars          ,ONLY: nSpecies
!!----------------------------------------------------------------------------------------------------------------------------------!
!! IMPLICIT VARIABLE HANDLING
!IMPLICIT NONE
!! INPUT VARIABLES
!!----------------------------------------------------------------------------------------------------------------------------------!
!! OUTPUT VARIABLES
!!-----------------------------------------------------------------------------------------------------------------------------------
!! LOCAL VARIABLES
!LOGICAL                           :: isMPINeighbor(0:SurfCOMM%nProcs-1)
!LOGICAL                           :: RecvMPINeighbor(0:SurfCOMM%nProcs-1)
!INTEGER                           :: nDOF,ALLOCSTAT,SideID, TargetProc, TargetElem
!INTEGER                           :: iProc, GlobalProcID,iSide,ElemID,SurfSideID,LocalProcID,iSendSide,iRecvSide,iPos
!INTEGER,ALLOCATABLE               :: recv_status_list(:,:)
!INTEGER                           :: RecvRequest(0:SurfCOMM%nProcs-1),SendRequest(0:SurfCOMM%nProcs-1)
!INTEGER                           :: SurfToGlobal(0:SurfCOMM%nProcs-1)
!INTEGER                           :: NativeElemID, NativeLocSideID, LocSideID, SampSizeAllocate
!!===================================================================================================================================
!
!nDOF=nSurfSample**2
!
!! get mapping from local rank to global rank...
!CALL MPI_ALLGATHER(MyRank,1, MPI_INTEGER, SurfToGlobal(0:SurfCOMM%nProcs-1), 1, MPI_INTEGER, SurfCOMM%COMM, IERROR)
!
!! get list of mpi surf-comm neighbors in halo-region
!isMPINeighbor=.FALSE.
!IF(SurfMesh%nTotalSides.GT.SurfMesh%nSides)THEN
!  ! PartHaloSideToProc has the mapping from the local sideid to the corresponding
!  ! element-id, localsideid, native-proc-id and local-proc-id
!  ! caution:
!  ! native-proc-id is id in global list || PartMPI%COMM
!  ! local-proc-id is the nth neighbor in SurfCOMM%COMM
!  ! caution2:
!  !  this mapping is done only for reflective bcs, thus, each open side or non-reflective side
!  !  points to -1
!  ! get all MPI-neighbors to communicate with
!  DO iProc=0,SurfCOMM%nProcs-1
!    IF(iProc.EQ.SurfCOMM%MyRank) CYCLE
!    GlobalProcID=SurfToGlobal(iProc)
!    DO iSide=nSides+1,nTotalSides
!      SurfSideID=SurfMesh%SideIDToSurfID(iSide)
!      IF(SurfSideID.EQ.-1) CYCLE
!      ! get elemid
!      ElemID=PartSideToElem(S2E_ELEM_ID,iSide)
!      IF (ElemID.EQ.-1) THEN
!        ElemID=PartSideToElem(S2E_NB_ELEM_ID,iSide)
!      END IF
!      TargetProc=ElemInfo_Shared(ELEM_RANK,ElemID)
!      IF(ElemID.LE.PP_nElems)THEN
!        CALL abort(&
!__STAMP__&
!,' Error in PartSideToElem. Halo-Side cannot be connected to local element', ElemID  )
!      END IF
!      IF(GlobalProcID.EQ.TargetProc)THEN
!        IF(.NOT.isMPINeighbor(iProc))THEN
!          isMPINeighbor(iProc)=.TRUE.
!        END IF
!      END IF
!    END DO ! iSide=nSides+1,nTotalSides
!  END DO ! iProc = 0, SurfCOMM%nProcs-1
!END IF
!
!! Make sure SurfCOMM%MPINeighbor is consistent
!! 1) communication of found is neighbor
!ALLOCATE(RECV_STATUS_LIST(1:MPI_STATUS_SIZE,0:SurfCOMM%nProcs-1))
!! receive and send connection information
!DO iProc=0,SurfCOMM%nProcs-1
!  IF(iProc.EQ.SurfCOMM%MyRank) CYCLE
!  CALL MPI_IRECV( RecvMPINeighbor(iProc)                    &
!                , 1                                         &
!                , MPI_LOGICAL                               &
!                , iProc                                     &
!                , 1001                                      &
!                , SurfCOMM%COMM                             &
!                , RecvRequest(iProc)                        &
!                , IERROR )
!END DO ! iProc
!DO iProc=0,SurfCOMM%nProcs-1
!  IF(iProc.EQ.SurfCOMM%MyRank) CYCLE
!  CALL MPI_ISEND( isMPINeighbor(iProc)                      &
!                , 1                                         &
!                , MPI_LOGICAL                               &
!                , iProc                                     &
!                , 1001                                      &
!                , SurfCOMM%COMM                             &
!                , SendRequest(iProc)                        &
!                , IERROR )
!  IF(IERROR.NE.MPI_SUCCESS) CALL abort(&
!    __STAMP__&
!    ,' MPI Communication error', IERROR)
!END DO ! iProc
!
!! finish communication
!DO iProc=0,SurfCOMM%nProcs-1
!  IF(iProc.EQ.SurfCOMM%MyRank) CYCLE
!  CALL MPI_WAIT(SendRequest(iProc),MPIStatus,IERROR)
!  IF(IERROR.NE.MPI_SUCCESS) CALL abort(&
!    __STAMP__&
!    ,' MPI Communication error', IERROR)
!  CALL MPI_WAIT(RecvRequest(iProc),recv_status_list(:,iProc),IERROR)
!  IF(IERROR.NE.MPI_SUCCESS) CALL abort(&
!    __STAMP__&
!    ,' MPI Communication error', IERROR)
!END DO ! iProc
!DEALLOCATE(RECV_STATUS_LIST)
!
!! 2) finalize MPI consistency check.
!DO iProc=0,SurfCOMM%nProcs-1
!  IF(iProc.EQ.SurfCOMM%MyRank) CYCLE
!  IF (RecvMPINeighbor(iProc).NEQV.isMPINeighbor(iProc)) THEN
!    IF(.NOT.isMPINeighbor(iProc))THEN
!      isMPINeighbor(iProc)=.TRUE.
!      ! it is a debug output
!      !IPWRITE(UNIT_stdOut,*) ' Found missing mpi-neighbor'
!    END IF
!  END IF
!END DO ! iProc
!
!! build the mapping
!SurfCOMM%nMPINeighbors=0
!IF(ANY(IsMPINeighbor))THEN
!  ! PartHaloSideToProc has the mapping from the local sideid to the corresponding
!  ! element-id, localsideid, native-proc-id and local-proc-id
!  ! caution:
!  ! native-proc-id is id in global list || PartMPI%COMM
!  ! local-proc-id is the nth neighbor in SurfCOMM%COMM
!  ! caution2:
!  !  this mapping is done only for reflective bcs, thus, each open side or non-reflective side
!  !  points to -1
!  IF(SurfMesh%nTotalSides.GT.SurfMesh%nSides)THEN
!    ALLOCATE(PartHaloSideToProc(1:4,nSides+1:nTotalSides))
!    PartHaloSideToProc=-1
!    ! get all MPI-neighbors to communicate with
!    DO iProc=0,SurfCOMM%nProcs-1
!      IF(iProc.EQ.SurfCOMM%MyRank) CYCLE
!      IF(isMPINeighbor(iProc))THEN
!        SurfCOMM%nMPINeighbors=SurfCOMM%nMPINeighbors+1
!      ELSE
!        CYCLE
!      END IF
!      GlobalProcID=SurfToGlobal(iProc)
!      DO iSide=nSides+1,nTotalSides
!        SurfSideID=SurfMesh%SideIDToSurfID(iSide)
!        IF(SurfSideID.EQ.-1) CYCLE
!        ! get elemid
!        ElemID=PartSideToElem(S2E_ELEM_ID,iSide)
!        IF (ElemID.EQ.-1) THEN
!          ElemID=PartSideToElem(S2E_NB_ELEM_ID,iSide)
!        END IF
!        TargetProc=ElemInfo_Shared(ELEM_RANK,ElemID)
!        IF(ElemID.LE.PP_nElems)THEN
!        CALL abort(&
!__STAMP__&
!,' Error in PartSideToElem. Halo-Side cannot be connected to local element', ElemID  )
!        END IF
!        IF(GlobalProcID.EQ.TargetProc)THEN
!          ! caution:
!          ! native-proc-id is id in global list || PartMPI%COMM
!          ! local-proc-id is the nth neighbor in SurfCOMM%COMM
!          PartHaloSideToProc(NATIVE_PROC_ID,iSide)=GlobalProcID
!          PartHaloSideToProc(LOCAL_PROC_ID ,iSide)=SurfCOMM%nMPINeighbors
!        END IF
!      END DO ! iSide=nSides+1,nTotalSides
!    END DO ! iProc = 0, SurfCOMM%nProcs-1
!  ELSE
!    ! process receives only surface data from other processes, but does not send data.
!    DO iProc=0,SurfCOMM%nProcs-1
!      IF(iProc.EQ.SurfCOMM%MyRank) CYCLE
!      IF(isMPINeighbor(iProc)) SurfCOMM%nMPINeighbors=SurfCOMM%nMPINeighbors+1
!    END DO ! iProc = 0, SurfCOMM%nProcs-1
!  END IF
!END IF
!! build SurfMesh exchange information
!! next, allocate SurfCOMM%MPINeighbor
!ALLOCATE(SurfCOMM%MPINeighbor(1:SurfCOMM%nMPINeighbors))
!! set native proc-id of each SurfCOMM-MPI-Neighbor
!LocalProcID=0
!DO iProc = 0,SurfCOMM%nProcs-1
!  IF(iProc.EQ.SurfCOMM%MyRank) CYCLE
!  IF(isMPINeighbor(iProc))THEN
!    LocalProcID=LocalProcID+1
!    ! map from local proc id to global
!    SurfCOMM%MPINeighbor(LocalProcID)%NativeProcID=iProc !PartMPI%MPINeighbor(iProc)
!  END IF
!END DO ! iProc=1,PartMPI%nMPINeighbors
!
!! array how many data has to be communicated
!! number of Sides
!ALLOCATE(SurfExchange%nSidesSend(1:SurfCOMM%nMPINeighbors) &
!        ,SurfExchange%nSidesRecv(1:SurfCOMM%nMPINeighbors) &
!        ,SurfExchange%SendRequest(SurfCOMM%nMPINeighbors)  &
!        ,SurfExchange%RecvRequest(SurfCOMM%nMPINeighbors)  )
!
!SurfExchange%nSidesSend=0
!SurfExchange%nSidesRecv=0
!! loop over all neighbors
!DO iProc=1,SurfCOMM%nMPINeighbors
!  ! proc-id in SurfCOMM%nProcs
!  DO iSide=nSides+1,nTotalSides
!    SurfSideID=SurfMesh%SideIDToSurfID(iSide)
!    IF(SurfSideID.EQ.-1) CYCLE
!    IF(iProc.EQ.PartHaloSideToProc(LOCAL_PROC_ID,iSide))THEN
!      SurfExchange%nSidesSend(iProc)=SurfExchange%nSidesSend(iProc)+1
!      PartHaloSideToProc(LOCAL_SEND_ID,iSide) =SurfExchange%nSidesSend(iProc)
!    END IF
!  END DO ! iSide=nSides+1,nTotalSides
!END DO ! iProc=1,SurfCOMM%nMPINeighbors
!
!! open receive number of send particles
!ALLOCATE(RECV_STATUS_LIST(1:MPI_STATUS_SIZE,1:SurfCOMM%nMPINeighbors))
!DO iProc=1,SurfCOMM%nMPINeighbors
!  CALL MPI_IRECV( SurfExchange%nSidesRecv(iProc)            &
!                , 1                                         &
!                , MPI_INTEGER                               &
!                , SurfCOMM%MPINeighbor(iProc)%NativeProcID  &
!                , 1001                                      &
!                , SurfCOMM%COMM                             &
!                , SurfExchange%RecvRequest(iProc)           &
!                , IERROR )
!END DO ! iProc
!
!DO iProc=1,SurfCOMM%nMPINeighbors
!  ALLOCATE(SurfCOMM%MPINeighbor(iProc)%SendList(SurfExchange%nSidesSend(iProc)))
!  SurfCOMM%MPINeighbor(iProc)%SendList=0
!  CALL MPI_ISEND( SurfExchange%nSidesSend(iProc)           &
!                , 1                                        &
!                , MPI_INTEGER                              &
!                , SurfCOMM%MPINeighbor(iProc)%NativeProcID &
!                , 1001                                     &
!                , SurfCOMM%COMM                            &
!                , SurfExchange%SendRequest(iProc)          &
!                , IERROR )
!END DO ! iProc
!
!
!! 4) Finish Received number of particles
!DO iProc=1,SurfCOMM%nMPINeighbors
!  CALL MPI_WAIT(SurfExchange%SendRequest(iProc),MPIStatus,IERROR)
!  IF(IERROR.NE.MPI_SUCCESS) CALL abort(&
!__STAMP__&
!,' MPI Communication error', IERROR)
!  CALL MPI_WAIT(SurfExchange%RecvRequest(iProc),recv_status_list(:,iProc),IERROR)
!  IF(IERROR.NE.MPI_SUCCESS) CALL abort(&
!__STAMP__&
!          ,' MPI Communication error', IERROR)
!END DO ! iProc
!
!! allocate send and receive buffer
!ALLOCATE(SurfSendBuf(SurfCOMM%nMPINeighbors))
!ALLOCATE(SurfRecvBuf(SurfCOMM%nMPINeighbors))
!DO iProc=1,SurfCOMM%nMPINeighbors
!  IF(SurfExchange%nSidesSend(iProc).GT.0)THEN
!    ALLOCATE(SurfSendBuf(iProc)%content(2*SurfExchange%nSidesSend(iProc)),STAT=ALLOCSTAT)
!    SurfSendBuf(iProc)%Content=-1
!  END IF
!  IF(SurfExchange%nSidesRecv(iProc).GT.0)THEN
!    ALLOCATE(SurfRecvBuf(iProc)%content(2*SurfExchange%nSidesRecv(iProc)),STAT=ALLOCSTAT)
!  END IF
!END DO ! iProc=1,PartMPI%nMPINeighbors
!
!! open receive buffer
!DO iProc=1,SurfCOMM%nMPINeighbors
!  IF(SurfExchange%nSidesRecv(iProc).EQ.0) CYCLE
!  CALL MPI_IRECV( SurfRecvBuf(iProc)%content                   &
!                , 2*SurfExchange%nSidesRecv(iProc)             &
!                , MPI_DOUBLE_PRECISION                         &
!                , SurfCOMM%MPINeighbor(iProc)%NativeProcID     &
!                , 1004                                         &
!                , SurfCOMM%COMM                                &
!                , SurfExchange%RecvRequest(iProc)              &
!                , IERROR )
!END DO ! iProc
!
!! build message
!! after this message, the receiving process knows to which of his sides the sending process will send the
!  ! surface data
!DO iProc=1,SurfCOMM%nMPINeighbors
!  IF(SurfExchange%nSidesSend(iProc).EQ.0) CYCLE
!  iSendSide=0
!  iPos=1
!  DO iSide=nSides+1,nTotalSides
!    SurfSideID=SurfMesh%SideIDToSurfID(iSide)
!    IF(SurfSideID.EQ.-1) CYCLE
!    ! get elemid
!    IF(iProc.EQ.PartHaloSideToProc(LOCAL_PROC_ID,iSide))THEN
!      iSendSide=iSendSide+1
!      ! get elemid
!      ElemID=PartSideToElem(S2E_ELEM_ID,iSide)
!      LocSideID = PartSideToElem(S2E_LOC_SIDE_ID,iSide)
!      IF (ElemID.EQ.-1) THEN
!        ElemID=PartSideToElem(S2E_NB_ELEM_ID,iSide)
!        LocSideID = PartSideToElem(S2E_NB_LOC_SIDE_ID,iSide)
!      END IF
!      TargetElem=ElemInfo_Shared(ELEM_RANK,ElemID)
!      IF(ElemID.LE.PP_nElems)THEN
!       IPWRITE(UNIT_stdOut,*) ' Error in PartSideToElem'
!      END IF
!      IF(ElemID.LE.1)THEN
!       IPWRITE(UNIT_stdOut,*) ' Error in PartSideToElem'
!      END IF
!      SurfCOMM%MPINeighbor(iProc)%SendList(iSendSide)=iSide
!!       IPWRITE(*,*) 'negative elem id',ElemInfo_Shared(ELEM_RANK,ElemID),PartSideToElem(S2E_LOC_SIDE_ID,iSide)
!      SurfSendBuf(iProc)%content(iPos  )= REAL(TargetElem)
!      SurfSendBuf(iProc)%content(iPos+1)= REAL(LocSideID)
!      iPos=iPos+2
!    END IF
!  END DO ! iSide=nSides+1,nTotalSides
!  IF(iSendSide.NE.SurfExchange%nSidesSend(iProc)) CALL abort(&
!__STAMP__&
!          ,' Message too short!',iProc)
!  IF(ANY(SurfSendBuf(iProc)%content.LE.0))THEN
!    IPWRITE(UNIT_stdOut,*) ' nSendSides', SurfExchange%nSidesSend(iProc), ' to Proc ', iProc
!    CALL abort(&
!__STAMP__&
!          ,' Sent NATIVE_ELEM_ID or LOCSIDEID is zero!')
!  END IF
!END DO
!
!DO iProc=1,SurfCOMM%nMPINeighbors
!  IF(SurfExchange%nSidesSend(iProc).EQ.0) CYCLE
!  CALL MPI_ISEND( SurfSendBuf(iProc)%content               &
!                , 2*SurfExchange%nSidesSend(iProc)         &
!                , MPI_DOUBLE_PRECISION                     &
!                , SurfCOMM%MPINeighbor(iProc)%NativeProcID &
!                , 1004                                     &
!                , SurfCOMM%COMM                            &
!                , SurfExchange%SendRequest(iProc)          &
!                , IERROR )
!END DO ! iProc
!
!! 4) Finish Received number of particles
!DO iProc=1,SurfCOMM%nMPINeighbors
!  IF(SurfExchange%nSidesSend(iProc).NE.0) THEN
!    CALL MPI_WAIT(SurfExchange%SendRequest(iProc),MPIStatus,IERROR)
!    IF(IERROR.NE.MPI_SUCCESS) CALL abort(&
!__STAMP__&
!          ,' MPI Communication error', IERROR)
!  END IF
!  IF(SurfExchange%nSidesRecv(iProc).NE.0) THEN
!    CALL MPI_WAIT(SurfExchange%RecvRequest(iProc),recv_status_list(:,iProc),IERROR)
!    IF(IERROR.NE.MPI_SUCCESS) CALL abort(&
!__STAMP__&
!          ,' MPI Communication error', IERROR)
!  END IF
!END DO ! iProc
!
!! fill list with received side ids
!! store the receiving data
!DO iProc=1,SurfCOMM%nMPINeighbors
!  ALLOCATE(SurfCOMM%MPINeighbor(iProc)%RecvList(SurfExchange%nSidesRecv(iProc)))
!  IF(SurfExchange%nSidesRecv(iProc).EQ.0) CYCLE
!  iPos=1
!  DO iRecvSide=1,SurfExchange%nSidesRecv(iProc)
!    NativeElemID   =INT(SurfRecvBuf(iProc)%content(iPos))
!    NativeLocSideID=INT(SurfRecvBuf(iProc)%content(iPos+1))
!!     IPWRITE(*,*) 'received- elemid, locsideid',NativeElemID,NativeLocSideID
!    IF(NativeElemID.GT.PP_nElems)THEN
!     CALL abort(&
!__STAMP__&
!          ,' Cannot send halo-data to other procs. big error! ', ElemID, REAL(PP_nElems))
!    END IF
!    SideID=PartElemToSide(E2S_SIDE_ID,NativeLocSideID,NativeElemID)
!    IF(SideID.GT.nSides)THEN
!      IPWRITE(UNIT_stdOut,*) ' Received wrong sideid. Is not a BC side! '
!      IPWRITE(UNIT_stdOut,*) ' SideID, nBCSides, nSides ', SideID, nBCSides, nSides
!      IPWRITE(UNIT_stdOut,*) ' ElemID, locsideid        ', NativeElemID, NativeLocSideID
!      IPWRITE(UNIT_stdOut,*) ' Sending process has error in halo-region! ', SurfCOMM%MPINeighbor(iProc)%NativeProcID
!     CALL abort(&
!__STAMP__&
!          ,' Big error in halo region! NativeLocSideID ', NativeLocSideID )
!    END IF
!    SurfSideID=SurfMesh%SideIDToSurfID(SideID)
!    IF(SurfSideID.EQ.-1)THEN
!     CALL abort(&
!__STAMP__&
!          ,' Side is not even a reflective BC side! ', SideID )
!    END IF
!    SurfCOMM%MPINeighbor(iProc)%RecvList(iRecvSide)=SideID
!    iPos=iPos+2
!  END DO ! RecvSide=1,SurfExchange%nSidesRecv(iProc)-1,2
!END DO ! iProc
!
!DO iProc=1,SurfCOMM%nMPINeighbors
!  SDEALLOCATE(SurfSendBuf(iProc)%content)
!  SDEALLOCATE(SurfRecvBuf(iProc)%content)
!  SampSizeAllocate = SurfMesh%SampSize
!  ! Sampling of impact energy for each species (trans, rot, vib), impact vector (x,y,z), angle and number: Add 8*nSpecies to the
!  ! buffer length
!  IF(CalcSurfaceImpact) SampSizeAllocate = SampSizeAllocate + 8*nSpecies
!  IF(SurfExchange%nSidesSend(iProc).GT.0) THEN
!    ALLOCATE(SurfSendBuf(iProc)%content(SampSizeAllocate*nDOF*SurfExchange%nSidesSend(iProc)))
!    SurfSendBuf(iProc)%content=0.
!  END IF
!  IF(SurfExchange%nSidesRecv(iProc).GT.0) THEN
!    ALLOCATE(SurfRecvBuf(iProc)%content(SampSizeAllocate*nDOF*SurfExchange%nSidesRecv(iProc)))
!    SurfRecvBuf(iProc)%content=0.
!  END IF
!END DO ! iProc
!
!IF(nPorousBC.GT.0) THEN
!  ALLOCATE(PorousBCSendBuf(SurfCOMM%nMPINeighbors))
!  ALLOCATE(PorousBCRecvBuf(SurfCOMM%nMPINeighbors))
!  DO iProc=1,SurfCOMM%nMPINeighbors
!    IF(SurfExchange%nSidesSend(iProc).GT.0) THEN
!      ALLOCATE(PorousBCSendBuf(iProc)%content(nPorousBCVars*nPorousBC*SurfExchange%nSidesSend(iProc)))
!      PorousBCSendBuf(iProc)%content=0.
!    END IF
!    IF(SurfExchange%nSidesRecv(iProc).GT.0) THEN
!      ALLOCATE(PorousBCRecvBuf(iProc)%content(nPorousBCVars*nPorousBC*SurfExchange%nSidesRecv(iProc)))
!      PorousBCRecvBuf(iProc)%content=0.
!    END IF
!  END DO ! iProc
!END IF
!
!DEALLOCATE(recv_status_list)
!
!CALL MPI_BARRIER(SurfCOMM%Comm,iError)
!
!END SUBROUTINE GetHaloSurfMapping



!SUBROUTINE MapInnerSurfData()
!!===================================================================================================================================
!! Map the surface data from innerBC SlaveSides to corresponding HaloSide.
!! All sampled SampWall informations of a innerBC SlaveSide is added to corresponding HaloSide.
!! Afterwards, these informations are send to innerBC MasterSide in a second ExchangeSurfData call in SUBROUTINE CalcSurfaceValues.
!!===================================================================================================================================
!! MODULES                                                                                                                          !
!!----------------------------------------------------------------------------------------------------------------------------------!
!USE MOD_Globals
!USE MOD_Particle_Boundary_Vars,     ONLY:SurfMesh,nSurfSample,SampWall,PartBound,CalcSurfaceImpact
!USE MOD_Mesh_Vars,                  ONLY:nBCSides,nSides,BC
!USE MOD_SurfaceModel_Vars,          ONLY:Adsorption
!!----------------------------------------------------------------------------------------------------------------------------------!
!! IMPLICIT VARIABLE HANDLING
!IMPLICIT NONE
!! INPUT VARIABLES
!!----------------------------------------------------------------------------------------------------------------------------------!
!! OUTPUT VARIABLES
!!-----------------------------------------------------------------------------------------------------------------------------------
!! LOCAL VARIABLES
!INTEGER                         :: iSide,TargetHaloSide,q,p,SurfSideID,SurfSideHaloID,iReact
!!===================================================================================================================================
!
!IF(SurfMesh%nSides.GT.SurfMesh%nOutputSides) THEN ! There are reflective inner BCs on SlaveSide
!  DO iSide=nBCSides+1,nSides
!    IF(BC(iSide).EQ.0) CYCLE
!    IF (PartBound%TargetBoundCond(PartBound%MapToPartBC(BC(iSide))).EQ.PartBound%ReflectiveBC) THEN
!      TargetHaloSide = SurfMesh%innerBCSideToHaloMap(iSide)
!      IF(TargetHaloSide.NE.-1) THEN ! SlaveSide
!        DO q=1,nSurfSample
!          DO p=1,nSurfSample
!            SurfSideID=SurfMesh%SideIDToSurfID(iSide)
!            SurfSideHaloID=SurfMesh%SideIDToSurfID(TargetHaloSide)
!            SampWall(SurfSideHaloID)%State(:,p,q)=SampWall(SurfSideHaloID)%State(:,p,q) &
!                                                  +SampWall(SurfSideID)%State(:,p,q)
!            IF (ANY(PartBound%Reactive)) THEN
!              SampWall(SurfSideHaloID)%SurfModelState(:,p,q)=SampWall(SurfSideHaloID)%SurfModelState(:,p,q) &
!                                                            +SampWall(SurfSideID)%SurfModelState(:,p,q)
!              SampWall(SurfSideHaloID)%Accomodation(:,p,q)=SampWall(SurfSideHaloID)%Accomodation(:,p,q) &
!                                                          +SampWall(SurfSideID)%Accomodation(:,p,q)
!              DO iReact=1,2*Adsorption%ReactNum
!                SampWall(SurfSideHaloID)%SurfModelReactCount(iReact,:,p,q) = &
!                    SampWall(SurfSideHaloID)%SurfModelReactCount(iReact,:,p,q) &
!                    +SampWall(SurfSideID)%SurfModelReactCount(iReact,:,p,q)
!              END DO
!            END IF
!          END DO
!        END DO
!
!        ! Sampling of impact energy for each species (trans, rot, vib), impact vector (x,y,z) and angle
!        IF(CalcSurfaceImpact)THEN
!          DO q=1,nSurfSample
!            DO p=1,nSurfSample
!              ASSOCIATE( energy => SampWall(SurfSideHaloID)%ImpactEnergy(:,:,q,p) ,&
!                         vector => SampWall(SurfSideHaloID)%ImpactVector(:,:,q,p) ,&
!                         angle  => SampWall(SurfSideHaloID)%ImpactAngle(:,q,p)    ,&
!                         num    => SampWall(SurfSideHaloID)%Impactnumber(:,q,p)   )
!                energy = energy + SampWall(SurfSideID)%ImpactEnergy(:,:,q,p)
!                vector = vector + SampWall(SurfSideID)%ImpactVector(:,:,q,p)
!                angle  = angle  + SampWall(SurfSideID)%ImpactAngle(:,q,p)
!                num    = num    + SampWall(SurfSideID)%ImpactNumber(:,q,p)
!              END ASSOCIATE
!            END DO
!          END DO
!        END IF ! CalcSurfaceImpact
!      END IF
!    END IF
!  END DO
!END IF
!
!END SUBROUTINE MapInnerSurfData
#endif /*USE_MPI*/

SUBROUTINE WriteSurfSampleToHDF5(MeshFileName,OutputTime)
!===================================================================================================================================
!> write the final values of the surface sampling to a HDF5 state file
!> additional performs all the final required computations
!===================================================================================================================================
! MODULES                                                                                                                          !
!----------------------------------------------------------------------------------------------------------------------------------!
USE MOD_Globals
USE MOD_IO_HDF5
USE MOD_Globals_Vars           ,ONLY: ProjectName
USE MOD_SurfaceModel_Vars      ,ONLY: Adsorption
USE MOD_Particle_Boundary_Vars ,ONLY: nSurfSample,SurfMesh,offSetSurfSide,offsetInnerSurfSide,nPorousBC,CalcSurfaceImpact
USE MOD_DSMC_Vars              ,ONLY: MacroSurfaceVal,MacroSurfaceSpecVal, CollisMode
USE MOD_Particle_Vars          ,ONLY: nSpecies
USE MOD_HDF5_Output            ,ONLY: WriteAttributeToHDF5,WriteArrayToHDF5,WriteHDF5Header
USE MOD_Particle_Boundary_Vars ,ONLY: SurfCOMM,nSurfBC,SurfBCName, PartBound
!----------------------------------------------------------------------------------------------------------------------------------!
! IMPLICIT VARIABLE HANDLING
IMPLICIT NONE
! INPUT VARIABLES
CHARACTER(LEN=*),INTENT(IN)          :: MeshFileName
REAL,INTENT(IN)                      :: OutputTime
!----------------------------------------------------------------------------------------------------------------------------------!
! OUTPUT VARIABLES
!-----------------------------------------------------------------------------------------------------------------------------------
! LOCAL VARIABLES
CHARACTER(LEN=255)                  :: FileName,FileString,Statedummy
CHARACTER(LEN=255)                  :: H5_Name
CHARACTER(LEN=255)                  :: NodeTypeTemp
CHARACTER(LEN=255)                  :: SpecID, ReactID, PBCID
CHARACTER(LEN=255),ALLOCATABLE      :: Str2DVarNames(:)
INTEGER                             :: nVar2D, nVar2D_Spec, nVar2D_Total, nVarCount, iSpec, nAdsSamples, iReact, iPBC
REAL                                :: tstart,tend
!===================================================================================================================================

#if USE_MPI
CALL MPI_BARRIER(SurfCOMM%COMM,iERROR)
IF(SurfMesh%nOutputSides.EQ.0) RETURN
#endif /*USE_MPI*/
IF(SurfCOMM%MPIOutputRoot)THEN
  WRITE(UNIT_stdOut,'(a)',ADVANCE='NO')' WRITE DSMCSurfSTATE TO HDF5 FILE...'
  tstart=LOCALTIME()
END IF

FileName=TIMESTAMP(TRIM(ProjectName)//'_DSMCSurfState',OutputTime)
FileString=TRIM(FileName)//'.h5'

! Create dataset attribute "SurfVarNames"
nVar2D = 5
nVar2D_Spec = 1
IF(ANY(PartBound%Reactive)) THEN
  nAdsSamples = 5
  nVar2D = nVar2D + nAdsSamples
  nVar2D_Spec = nVar2D_Spec + 2 + 2*Adsorption%ReactNum
END IF

! Sampling of impact energy for each species (trans, rot, vib), impact vector (x,y,z), angle and number: Add 8 variables
IF(CalcSurfaceImpact) nVar2D_Spec = nVar2D_Spec + 8

IF(nPorousBC.GT.0)  nVar2D = nVar2D + nPorousBC

nVar2D_Total = nVar2D + nVar2D_Spec*nSpecies

! Generate skeleton for the file with all relevant data on a single proc (MPIRoot)
#if USE_MPI
IF(SurfCOMM%MPIOutputRoot)THEN
#endif
  CALL OpenDataFile(FileString,create=.TRUE.,single=.TRUE.,readOnly=.FALSE.)
  Statedummy = 'DSMCSurfState'

  ! Write file header
  CALL WriteHDF5Header(Statedummy,File_ID)
  CALL WriteAttributeToHDF5(File_ID,'DSMC_nSurfSample',1,IntegerScalar=nSurfSample)
  CALL WriteAttributeToHDF5(File_ID,'DSMC_nSpecies',1,IntegerScalar=nSpecies)
  CALL WriteAttributeToHDF5(File_ID,'DSMC_CollisMode',1,IntegerScalar=CollisMode)
  CALL WriteAttributeToHDF5(File_ID,'MeshFile',1,StrScalar=(/TRIM(MeshFileName)/))
  CALL WriteAttributeToHDF5(File_ID,'Time',1,RealScalar=OutputTime)
  CALL WriteAttributeToHDF5(File_ID,'BC_Surf',nSurfBC,StrArray=SurfBCName)
  CALL WriteAttributeToHDF5(File_ID,'N',1,IntegerScalar=nSurfSample)
  NodeTypeTemp='VISU'
  CALL WriteAttributeToHDF5(File_ID,'NodeType',1,StrScalar=(/NodeTypeTemp/))

  ALLOCATE(Str2DVarNames(1:nVar2D_Total))
  Str2DVarNames(:)=''
  nVarCount=1
  DO iSpec=1,nSpecies
    WRITE(SpecID,'(I3.3)') iSpec
    CALL AddVarName(Str2DVarNames,nVar2D_Total,nVarCount,'Spec'//TRIM(SpecID)//'_Counter')
    IF(ANY(PartBound%Reactive)) THEN
      CALL AddVarName(Str2DVarNames,nVar2D_Total,nVarCount,'Spec'//TRIM(SpecID)//'_Accomodation')
      CALL AddVarName(Str2DVarNames,nVar2D_Total,nVarCount,'Spec'//TRIM(SpecID)//'_Coverage')
      DO iReact=1,Adsorption%ReactNum
        WRITE(ReactID,'(I3.3)') iReact
        CALL AddVarName(Str2DVarNames,nVar2D_Total,nVarCount,'Spec'//TRIM(SpecID)//'_CollReact'//TRIM(ReactID)//'_Count')
      END DO
      DO iReact=1,Adsorption%ReactNum
        WRITE(ReactID,'(I3.3)') iReact
        CALL AddVarName(Str2DVarNames,nVar2D_Total,nVarCount,'Spec'//TRIM(SpecID)//'_SurfReact'//TRIM(ReactID)//'_Count')
      END DO
    END IF

    ! Sampling of impact energy for each species (trans, rot, vib), impact vector (x,y,z) and angle
    IF(CalcSurfaceImpact)THEN
      ! Add average impact energy for each species (trans, rot, vib)
      CALL AddVarName(Str2DVarNames,nVar2D_Total,nVarCount,'Spec'//TRIM(SpecID)//'_ImpactEnergyTrans')
      CALL AddVarName(Str2DVarNames,nVar2D_Total,nVarCount,'Spec'//TRIM(SpecID)//'_ImpactEnergyRot')
      CALL AddVarName(Str2DVarNames,nVar2D_Total,nVarCount,'Spec'//TRIM(SpecID)//'_ImpactEnergyVib')
      ! Add average impact vector for each species (x,y,z)
      CALL AddVarName(Str2DVarNames,nVar2D_Total,nVarCount,'Spec'//TRIM(SpecID)//'_ImpactVectorX')
      CALL AddVarName(Str2DVarNames,nVar2D_Total,nVarCount,'Spec'//TRIM(SpecID)//'_ImpactVectorY')
      CALL AddVarName(Str2DVarNames,nVar2D_Total,nVarCount,'Spec'//TRIM(SpecID)//'_ImpactVectorZ')
      ! Add average impact angle for each species
      CALL AddVarName(Str2DVarNames,nVar2D_Total,nVarCount,'Spec'//TRIM(SpecID)//'_ImpactAngle')
      ! Add number of impacts
      CALL AddVarName(Str2DVarNames,nVar2D_Total,nVarCount,'Spec'//TRIM(SpecID)//'_ImpactNumber')
    END IF ! CalcSurfaceImpact

  END DO ! iSpec=1,nSpecies

  ! fill varnames for total values
  CALL AddVarName(Str2DVarNames,nVar2D_Total,nVarCount,'ForcePerAreaX')
  CALL AddVarName(Str2DVarNames,nVar2D_Total,nVarCount,'ForcePerAreaY')
  CALL AddVarName(Str2DVarNames,nVar2D_Total,nVarCount,'ForcePerAreaZ')
  CALL AddVarName(Str2DVarNames,nVar2D_Total,nVarCount,'HeatFlux')
  CALL AddVarName(Str2DVarNames,nVar2D_Total,nVarCount,'Counter_Total')
  IF(ANY(PartBound%Reactive)) THEN
    CALL AddVarName(Str2DVarNames,nVar2D_Total,nVarCount,'HeatFlux_Portion_LH')
    CALL AddVarName(Str2DVarNames,nVar2D_Total,nVarCount,'HeatFlux_Portion_SurfDiss')
    CALL AddVarName(Str2DVarNames,nVar2D_Total,nVarCount,'HeatFlux_Portion_ER')
    CALL AddVarName(Str2DVarNames,nVar2D_Total,nVarCount,'HeatFlux_Portion_AdsDiss')
    CALL AddVarName(Str2DVarNames,nVar2D_Total,nVarCount,'HeatFlux_Portion_SurfReconstruct')
  END IF

  IF(nPorousBC.GT.0) THEN
    DO iPBC = 1, nPorousBC
      WRITE(PBCID,'(I2.2)') iPBC
      CALL AddVarName(Str2DVarNames,nVar2D_Total,nVarCount,'PorousBC'//TRIM(PBCID)//'_PumpCapacity')
    END DO
  END IF

  CALL WriteAttributeToHDF5(File_ID,'VarNamesSurface',nVar2D_Total,StrArray=Str2DVarNames)

  CALL CloseDataFile()
  DEALLOCATE(Str2DVarNames)
#if USE_MPI
END IF

CALL MPI_BARRIER(SurfCOMM%OutputCOMM,iERROR)

CALL OpenDataFile(FileString,create=.FALSE.,single=.FALSE.,readOnly=.FALSE.,communicatorOpt=SurfCOMM%OutputCOMM)
#else
CALL OpenDataFile(FileString,create=.FALSE.,single=.TRUE.,readOnly=.FALSE.)
#endif

nVarCount=0
WRITE(H5_Name,'(A)') 'SurfaceData'
ASSOCIATE (&
      nVar2D_Total         => INT(nVar2D_Total,IK)          ,&
      nSurfSample          => INT(nSurfSample,IK)           ,&
      nGlobalSides         => INT(SurfMesh%nGlobalSides,IK) ,&
      LocalnBCSides        => INT(SurfMesh%nBCSides,IK)     ,&
      nInnerSides          => INT(SurfMesh%nInnerSides,IK)  ,&
      offsetSurfSide       => INT(offsetSurfSide,IK)        ,&
      offsetInnerSurfSide  => INT(offsetInnerSurfSide,IK)   ,&
      nVar2D_Spec          => INT(nVar2D_Spec,IK)           ,&
      nVar2D               => INT(nVar2D,IK)                ,&
      nOutputSides         => INT(SurfMesh%nOutputSides,IK) )
  DO iSpec = 1,nSpecies
    CALL WriteArrayToHDF5(DataSetName=H5_Name             , rank=4                                      , &
                            nValGlobal =(/nVar2D_Total      , nSurfSample , nSurfSample , nGlobalSides/)  , &
                            nVal       =(/nVar2D_Spec       , nSurfSample , nSurfSample , LocalnBCSides/)        , &
                            offset     =(/INT(nVarCount,IK) , 0_IK        , 0_IK        , offsetSurfSide/), &
                            collective =.FALSE.,&
                            RealArray=MacroSurfaceSpecVal(1:nVar2D_Spec,1:nSurfSample,1:nSurfSample,1:LocalnBCSides,iSpec))
    nVarCount = nVarCount + INT(nVar2D_Spec)
  END DO
  CALL WriteArrayToHDF5(DataSetName=H5_Name            , rank=4                                     , &
                        nValGlobal =(/nVar2D_Total     , nSurfSample, nSurfSample , nGlobalSides/)  , &
                        nVal       =(/nVar2D           , nSurfSample, nSurfSample , LocalnBCSides/)        , &
                        offset     =(/INT(nVarCount,IK), 0_IK       , 0_IK        , offsetSurfSide/), &
                        collective =.FALSE.         ,&
                        RealArray=MacroSurfaceVal(1:nVar2D,1:nSurfSample,1:nSurfSample,1:LocalnBCSides))
  ! Output of InnerSurfSide Array
  ! HDF5 Output: collective=false is required to avoid a deadlock, since not all procs in this routine have inner sides
  IF(nInnerSides.GT.0) THEN
    nVarCount=0
    DO iSpec = 1,nSpecies
      CALL WriteArrayToHDF5(DataSetName=H5_Name             , rank=4                                      , &
                      nValGlobal =(/nVar2D_Total      , nSurfSample , nSurfSample , nGlobalSides/)  , &
                      nVal       =(/nVar2D_Spec       , nSurfSample , nSurfSample , nInnerSides/)        , &
                      offset     =(/INT(nVarCount,IK) , 0_IK        , 0_IK        , offsetInnerSurfSide/), &
                      collective =.FALSE.,&
                      RealArray=MacroSurfaceSpecVal(1:nVar2D_Spec,1:nSurfSample,1:nSurfSample,LocalnBCSides+1:nOutputSides,iSpec))
      nVarCount = nVarCount + INT(nVar2D_Spec)
    END DO
    CALL WriteArrayToHDF5(DataSetName=H5_Name            , rank=4                                     , &
                          nValGlobal =(/nVar2D_Total     , nSurfSample, nSurfSample , nGlobalSides/)  , &
                          nVal       =(/nVar2D           , nSurfSample, nSurfSample , nInnerSides/)        , &
                          offset     =(/INT(nVarCount,IK), 0_IK       , 0_IK        , offsetInnerSurfSide/), &
                          collective =.FALSE.         ,&
                          RealArray=MacroSurfaceVal(1:nVar2D,1:nSurfSample,1:nSurfSample,LocalnBCSides+1:nOutputSides))
  END IF
END ASSOCIATE

CALL CloseDataFile()

IF(SurfCOMM%MPIOutputROOT)THEN
  tend=LOCALTIME()
  WRITE(UNIT_stdOut,'(A,F0.3,A)',ADVANCE='YES')'DONE  [',tend-tstart,'s]'
END IF

END SUBROUTINE WriteSurfSampleToHDF5


SUBROUTINE ReadAnalyzeSurfCollisToHDF5()
!===================================================================================================================================
! Reading AnalyzeSurfCollis-Data from hdf5 file for restart
!===================================================================================================================================
! MODULES
USE MOD_Globals
USE MOD_PreProc
USE MOD_HDF5_input,         ONLY: OpenDataFile,CloseDataFile,ReadArray,File_ID,GetDataSize,nDims,HSize,ReadAttribute
USE MOD_Particle_Vars,      ONLY: nSpecies
USE MOD_PICDepo_Vars,       ONLY: LastAnalyzeSurfCollis, r_SF !, SFResampleAnalyzeSurfCollis
USE MOD_Particle_Boundary_Vars,ONLY: nPartBound, AnalyzeSurfCollis
! IMPLICIT VARIABLE HANDLING
IMPLICIT NONE
!-----------------------------------------------------------------------------------------------------------------------------------
! INPUT VARIABLES
!-----------------------------------------------------------------------------------------------------------------------------------
! OUTPUT VARIABLES
!-----------------------------------------------------------------------------------------------------------------------------------
! LOCAL VARIABLES
CHARACTER(LEN=255)             :: Filename, H5_Name
INTEGER                        :: PartDataSize, iSpec
REAL, ALLOCATABLE              :: PartSpecData(:,:,:)
INTEGER                        :: TotalNumberMPF, counter2, counter, BCTotalNumberMPF, counter3
REAL                           :: TotalFlowrateMPF, RandVal, BCTotalFlowrateMPF
LOGICAL,ALLOCATABLE            :: PartDone(:)
!===================================================================================================================================
  FileName = TRIM(LastAnalyzeSurfCollis%DSMCSurfCollisRestartFile)
  SWRITE(UNIT_stdOut,*)'Reading Particles from DSMCSurfCollis-File:',TRIM(FileName)

  !-- initialize data (check if file exists and determine size of arrays)
  PartDataSize=10
  IF(MPIRoot) THEN
    IF(.NOT.FILEEXISTS(FileName))  CALL abort(__STAMP__, &
          'DSMCSurfCollis-File "'//TRIM(FileName)//'" does not exist',999,999.)
    CALL OpenDataFile(TRIM(FileName),create=.FALSE.,single=.TRUE.,readOnly=.TRUE.)
    DO iSpec=1,nSpecies
      WRITE(H5_Name,'(A,I3.3)') 'SurfCollisData_Spec',iSpec
      CALL GetDataSize(File_ID,TRIM(H5_Name),nDims,HSize)
      AnalyzeSurfCollis%Number(iSpec)=INT(HSize(1),4) !global number of particles
      IF ( INT(HSize(nDims),4) .NE. PartDataSize ) THEN
        CALL Abort(&
        __STAMP__,&
        'Error in ReadAnalyzeSurfCollisToHDF5. Array has size of ',nDims,REAL(INT(HSize(nDims),4)))
      END IF
      DEALLOCATE(HSize)
    END DO !iSpec
    CALL CloseDataFile()
    AnalyzeSurfCollis%Number(nSpecies+1) = SUM( AnalyzeSurfCollis%Number(1:nSpecies) )
  END IF !MPIRoot
#if USE_MPI
  CALL MPI_BCAST(AnalyzeSurfCollis%Number(:),nSpecies+1,MPI_INTEGER,0,MPI_COMM_WORLD,iError)
#endif
  TotalNumberMPF=AnalyzeSurfCollis%Number(nSpecies+1)
  ALLOCATE( PartSpecData(nSpecies,MAXVAL(AnalyzeSurfCollis%Number(1:nSpecies)),PartDataSize) )

  !-- open file for actual read-in
#if USE_MPI
  CALL MPI_BARRIER(MPI_COMM_WORLD,iError)
#endif
  CALL OpenDataFile(TRIM(FileName),create=.FALSE.,single=.FALSE.,readOnly=.TRUE.,communicatorOpt=MPI_COMM_WORLD)
  ! Read in state
  DO iSpec=1,nSpecies
    WRITE(H5_Name,'(A,I3.3)') 'SurfCollisData_Spec',iSpec
    IF (AnalyzeSurfCollis%Number(iSpec).GT.0) THEN
      ! Associate construct for integer KIND=8 possibility
      ASSOCIATE (&
            AnalyzeSurfCollis  => INT(AnalyzeSurfCollis%Number(iSpec),IK) ,&
            PartDataSize       => INT(PartDataSize,IK)                    )
        CALL ReadArray(TRIM(H5_Name) , 2 , (/AnalyzeSurfCollis          , PartDataSize/)      , &
            0_IK                     , 1 , RealArray=PartSpecData(iSpec , 1:AnalyzeSurfCollis , 1:PartDataSize))
      END ASSOCIATE
    END IF
  END DO !iSpec
  CALL ReadAttribute(File_ID,'TotalFlowrateMPF',1,RealScalar=TotalFlowrateMPF)
  SWRITE(UNIT_stdOut,*)'DONE!'
  CALL CloseDataFile()

!--save data
  IF (TotalNumberMPF.GT.0) THEN
    ! determine number of parts at BC of interest
    BCTotalNumberMPF=0
    DO iSpec=1,nSpecies
      DO counter=1,AnalyzeSurfCollis%Number(iSpec)
        IF (INT(PartSpecData(iSpec,counter,10)).LT.1 .OR. INT(PartSpecData(iSpec,counter,10)).GT.nPartBound) THEN
          CALL Abort(&
            __STAMP__,&
            'Error 3 in AnalyzeSurfCollis!')
        ELSE IF ( ANY(LastAnalyzeSurfCollis%BCs.EQ.0) .OR. ANY(LastAnalyzeSurfCollis%BCs.EQ.INT(PartSpecData(iSpec,counter,10))) ) THEN
          BCTotalNumberMPF = BCTotalNumberMPF + 1
        END IF
      END DO
    END DO
    IF (BCTotalNumberMPF.EQ.0) THEN
      SWRITE(*,*) 'WARNING in ReadAnalyzeSurfCollisToHDF5: no parts found for BC of interest!'
      RETURN
    ELSE IF (BCTotalNumberMPF.EQ.AnalyzeSurfCollis%Number(nSpecies+1)) THEN
      BCTotalFlowrateMPF=TotalFlowrateMPF
      SWRITE(*,*) 'ReadAnalyzeSurfCollisToHDF5: all particles are used for resampling...'
    ELSE
      BCTotalFlowrateMPF=TotalFlowrateMPF*REAL(BCTotalNumberMPF)/REAL(AnalyzeSurfCollis%Number(nSpecies+1))
      SWRITE(*,*) 'ReadAnalyzeSurfCollisToHDF5: The fraction of particles used for resampling is: ',BCTotalFlowrateMPF/TotalFlowrateMPF
    END IF

    IF (LastAnalyzeSurfCollis%ReducePartNumber) THEN !reduce saved number of parts to MaxPartNumber
      LastAnalyzeSurfCollis%PartNumberSamp=MIN(BCTotalNumberMPF,LastAnalyzeSurfCollis%PartNumberReduced)
      ALLOCATE(PartDone(1:TotalNumberMPF))
      PartDone(:)=.FALSE.
    ELSE
      LastAnalyzeSurfCollis%PartNumberSamp=BCTotalNumberMPF
    END IF
    SWRITE(*,*) 'Number of saved particles for SFResampleAnalyzeSurfCollis: ',LastAnalyzeSurfCollis%PartNumberSamp
    SDEALLOCATE(LastAnalyzeSurfCollis%WallState)
    SDEALLOCATE(LastAnalyzeSurfCollis%Species)
    ALLOCATE(LastAnalyzeSurfCollis%WallState(6,LastAnalyzeSurfCollis%PartNumberSamp))
    ALLOCATE(LastAnalyzeSurfCollis%Species(LastAnalyzeSurfCollis%PartNumberSamp))
    LastAnalyzeSurfCollis%pushTimeStep = HUGE(LastAnalyzeSurfCollis%pushTimeStep)

    ! Add particle to list
    counter2 = 0
    DO counter = 1, LastAnalyzeSurfCollis%PartNumberSamp
      IF (LastAnalyzeSurfCollis%ReducePartNumber) THEN !reduce saved number of parts (differently for each proc. Could be changed)
        DO !get random (equal!) position between [1,TotalNumberMPF] and accept if .NOT.PartDone and with right BC
          CALL RANDOM_NUMBER(RandVal)
          counter2 = MIN(1+INT(RandVal*REAL(TotalNumberMPF)),TotalNumberMPF)
          IF (.NOT.PartDone(counter2)) THEN
            counter3=counter2
            iSpec=nSpecies
            DO !determine in which species-"batch" the counter is located (use logical since it is used for ReducePartNumber anyway)
              IF (iSpec.EQ.1) THEN
                IF ( counter2 .GE. 1 ) THEN
                  EXIT
                ELSE
                  CALL Abort(&
                    __STAMP__, &
                    'Error in SFResampleAnalyzeSurfCollis. Could not determine iSpec for counter2 ',counter2)
                END IF
              ELSE IF ( counter2 - SUM(AnalyzeSurfCollis%Number(1:iSpec-1)) .GE. 1 ) THEN
                EXIT
              ELSE
                iSpec = iSpec - 1
              END IF
            END DO
            IF (iSpec.GT.1) THEN
              counter2 = counter2 - SUM(AnalyzeSurfCollis%Number(1:iSpec-1))
            END IF
            IF (counter2 .GT. AnalyzeSurfCollis%Number(iSpec)) THEN
              CALL Abort(&
                __STAMP__, &
                'Error in SFResampleAnalyzeSurfCollis. Determined iSpec is wrong for counter2 ',counter2)
            END IF
            IF (( ANY(LastAnalyzeSurfCollis%BCs.EQ.0) .OR. ANY(LastAnalyzeSurfCollis%BCs.EQ.PartSpecData(iSpec,counter2,10)) )) THEN
              PartDone(counter3)=.TRUE.
              EXIT
            END IF
          END IF
        END DO
      ELSE
        counter2 = counter
        iSpec=nSpecies
        DO !determine in which species-"batch" the counter is located (use logical since it is used for ReducePartNumber anyway)
          IF (iSpec.EQ.1) THEN
            IF ( counter2 .GE. 1 ) THEN
              EXIT
            ELSE
              CALL Abort(&
                __STAMP__, &
                'Error in SFResampleAnalyzeSurfCollis. Could not determine iSpec for counter2 ',counter2)
            END IF
          ELSE IF ( counter2 - SUM(AnalyzeSurfCollis%Number(1:iSpec-1)) .GE. 1 ) THEN
            EXIT
          ELSE
            iSpec = iSpec - 1
          END IF
        END DO
        IF (iSpec.GT.1) THEN
          counter2 = counter2 - SUM(AnalyzeSurfCollis%Number(1:iSpec-1))
        END IF
        IF (counter2 .GT. AnalyzeSurfCollis%Number(iSpec)) THEN
          CALL Abort(&
            __STAMP__, &
            'Error in SFResampleAnalyzeSurfCollis. Determined iSpec is wrong for counter2 ',counter2)
        END IF
      END IF
      LastAnalyzeSurfCollis%WallState(:,counter) = PartSpecData(iSpec,counter2,1:6)
      LastAnalyzeSurfCollis%Species(counter) = iSpec
      IF (ANY(LastAnalyzeSurfCollis%SpeciesForDtCalc.EQ.0) .OR. &
          ANY(LastAnalyzeSurfCollis%SpeciesForDtCalc.EQ.LastAnalyzeSurfCollis%Species(counter))) &
        LastAnalyzeSurfCollis%pushTimeStep = MIN( LastAnalyzeSurfCollis%pushTimeStep &
        , DOT_PRODUCT(LastAnalyzeSurfCollis%NormVecOfWall,LastAnalyzeSurfCollis%WallState(4:6,counter)) )
    END DO

    IF (LastAnalyzeSurfCollis%pushTimeStep .LE. 0.) THEN
      CALL Abort(&
        __STAMP__,&
        'Error with SFResampleAnalyzeSurfCollis. Something is wrong with velocities or NormVecOfWall!',&
        999,LastAnalyzeSurfCollis%pushTimeStep)
    ELSE
      LastAnalyzeSurfCollis%pushTimeStep = r_SF / LastAnalyzeSurfCollis%pushTimeStep !dt required for smallest projected velo to cross r_SF
      LastAnalyzeSurfCollis%PartNumberDepo = NINT(BCTotalFlowrateMPF * LastAnalyzeSurfCollis%pushTimeStep)
      SWRITE(*,'(A,E12.5,x,I0)') 'Total Flowrate and to be inserted number of MP for SFResampleAnalyzeSurfCollis: ' &
        ,BCTotalFlowrateMPF, LastAnalyzeSurfCollis%PartNumberDepo
      IF (LastAnalyzeSurfCollis%PartNumberDepo .GT. LastAnalyzeSurfCollis%PartNumberSamp) THEN
        SWRITE(*,*) 'WARNING: PartNumberDepo .GT. PartNumberSamp!'
      END IF
      IF (LastAnalyzeSurfCollis%PartNumberDepo .GT. LastAnalyzeSurfCollis%PartNumThreshold) THEN
        CALL Abort(&
          __STAMP__,&
          'Error with SFResampleAnalyzeSurfCollis: PartNumberDepo .gt. PartNumThreshold',&
          LastAnalyzeSurfCollis%PartNumberDepo,r_SF/LastAnalyzeSurfCollis%pushTimeStep)
      END IF
    END IF
  END IF !TotalNumberMPF.GT.0

END SUBROUTINE ReadAnalyzeSurfCollisToHDF5

SUBROUTINE AddVarName(StrArray,ArrayDim,idx,VarName)
!----------------------------------------------------------------------------------------------------------------------------------!
! description
!----------------------------------------------------------------------------------------------------------------------------------!
! MODULES                                                                                                                          !
!----------------------------------------------------------------------------------------------------------------------------------!
! insert modules here
!----------------------------------------------------------------------------------------------------------------------------------!
IMPLICIT NONE
! INPUT / OUTPUT VARIABLES
INTEGER,INTENT(IN)             :: ArrayDim
CHARACTER(LEN=*),INTENT(INOUT) :: StrArray(ArrayDim)
INTEGER,INTENT(INOUT)          :: idx
CHARACTER(LEN=*),INTENT(IN)    :: VarName
! Space-separated list of input and output types. Use: (int|real|logical|...)_(in|out|inout)_dim(n)
!-----------------------------------------------------------------------------------------------------------------------------------
! LOCAL VARIABLES
!===================================================================================================================================
StrArray(idx)=TRIM(VarName)
idx=idx+1
END SUBROUTINE AddVarName


SUBROUTINE FinalizeParticleBoundarySampling()
!===================================================================================================================================
! deallocate everything
!===================================================================================================================================
! MODULES                                                                                                                          !
!----------------------------------------------------------------------------------------------------------------------------------!
USE MOD_Globals
USE MOD_Particle_Boundary_Vars
#if USE_MPI
USE MOD_Particle_MPI_Vars           ,ONLY:SurfSendBuf,SurfRecvBuf,SurfExchange,PartHaloSideToProc,PorousBCSendBuf,PorousBCRecvBuf
#endif /*USE_MPI*/
!----------------------------------------------------------------------------------------------------------------------------------!
! IMPLICIT VARIABLE HANDLING
IMPLICIT NONE
! INPUT VARIABLES
!----------------------------------------------------------------------------------------------------------------------------------!
! OUTPUT VARIABLES
!-----------------------------------------------------------------------------------------------------------------------------------
! LOCAL VARIABLES
INTEGER :: iSurfSide
#if USE_MPI
INTEGER :: iProc
#endif /*USE_MPI*/
!===================================================================================================================================

SDEALLOCATE(XiEQ_SurfSample)
SDEALLOCATE(SurfMesh%SurfaceArea)
SDEALLOCATE(SurfMesh%SideIDToSurfID)
SDEALLOCATE(SurfMesh%SurfIDToSideID)
SDEALLOCATE(SurfMesh%innerBCSideToHaloMap)
!SDALLOCATE(SampWall%Energy)
!SDEALLOCATE(SampWall%Force)
!SDEALLOCATE(SampWall%Counter)
DO iSurfSide=1,SurfMesh%nTotalSides
  SDEALLOCATE(SampWall(iSurfSide)%State)
  SDEALLOCATE(SampWall(iSurfSide)%SurfModelState)
  SDEALLOCATE(SampWall(iSurfSide)%Accomodation)
  SDEALLOCATE(SampWall(iSurfSide)%SurfModelReactCount)
  SDEALLOCATE(SampWall(iSurfSide)%ImpactEnergy)
  SDEALLOCATE(SampWall(iSurfSide)%ImpactVector)
  SDEALLOCATE(SampWall(iSurfSide)%ImpactAngle)
  SDEALLOCATE(SampWall(iSurfSide)%ImpactNumber)
END DO
SDEALLOCATE(SurfBCName)
SDEALLOCATE(SampWall)
#if USE_MPI
SDEALLOCATE(PartHaloSideToProc)
SDEALLOCATE(SurfExchange%nSidesSend)
SDEALLOCATE(SurfExchange%nSidesRecv)
SDEALLOCATE(SurfExchange%SendRequest)
SDEALLOCATE(SurfExchange%RecvRequest)
DO iProc=1,SurfCOMM%nMPINeighbors
  IF (ALLOCATED(SurfSendBuf))THEN
    SDEALLOCATE(SurfSendBuf(iProc)%content)
  END IF
  IF (ALLOCATED(SurfRecvBuf))THEN
    SDEALLOCATE(SurfRecvBuf(iProc)%content)
  END IF
  IF (ALLOCATED(SurfCOMM%MPINeighbor))THEN
    SDEALLOCATE(SurfCOMM%MPINeighbor(iProc)%SendList)
    SDEALLOCATE(SurfCOMM%MPINeighbor(iProc)%RecvList)
  END IF
END DO ! iProc=1,PartMPI%nMPINeighbors
SDEALLOCATE(SurfCOMM%MPINeighbor)
SDEALLOCATE(SurfSendBuf)
SDEALLOCATE(SurfRecvBuf)
SDEALLOCATE(PorousBCSendBuf)
SDEALLOCATE(PorousBCRecvBuf)
SDEALLOCATE(OffSetSurfSideMPI)
SDEALLOCATE(OffSetInnerSurfSideMPI)
IF(SurfCOMM%OutputCOMM.NE.MPI_COMM_NULL) CALL MPI_COMM_FREE(SurfCOMM%OutputCOMM,iERROR)
IF(SurfCOMM%COMM.NE.MPI_COMM_NULL) CALL MPI_COMM_FREE(SurfCOMM%COMM,iERROR)
#endif /*USE_MPI*/
SDEALLOCATE(CalcSurfCollis%SpeciesFlags)
SDEALLOCATE(AnalyzeSurfCollis%Data)
SDEALLOCATE(AnalyzeSurfCollis%Spec)
SDEALLOCATE(AnalyzeSurfCollis%BCid)
SDEALLOCATE(AnalyzeSurfCollis%Number)
!SDEALLOCATE(AnalyzeSurfCollis%Rate)
SDEALLOCATE(AnalyzeSurfCollis%BCs)

END SUBROUTINE FinalizeParticleBoundarySampling

END MODULE MOD_Particle_Boundary_Sampling
