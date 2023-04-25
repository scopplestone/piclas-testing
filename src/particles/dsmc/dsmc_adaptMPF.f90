!==================================================================================================================================
! Copyright (c) 2010 - 2018 Prof. Claus-Dieter Munz and Prof. Stefanos Fasoulas
!
! This file is part of PICLas (piclas.boltzplatz.eu/piclas/piclas). PICLas is free software: you can redistribute it and/or modify
! it under the terms of the GNU General Public License as published by the Free Software Foundation, either version 3
! of the License, or (at your option) any later version.
!
! PICLas is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty
! of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License v3.0 for more details.
!
! You should have received a copy of the GNU General Public License along with PICLas. If not, see <http://www.gnu.org/licenses/>.
!==================================================================================================================================
#include "piclas.h"

MODULE MOD_DSMC_AdaptMPF
!===================================================================================================================================
!> Routines for the node mapping and the adaption of the particle weights
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
  PUBLIC :: DefineParametersAdaptMPF, DSMC_InitAdaptiveWeights, DSMC_AdaptiveWeights, NodeMappingFilterMPF
!===================================================================================================================================

CONTAINS

!==================================================================================================================================
!> Define parameters for particles
!==================================================================================================================================
SUBROUTINE DefineParametersAdaptMPF()
! MODULES
USE MOD_ReadInTools ,ONLY: prms,addStrListEntry
IMPLICIT NONE

CALL prms%SetSection("MPF Adaption")
CALL prms%CreateRealOption(   'Part-AdaptMPF-MinParticleNumber', 'Target minimum simulation particle number per cell')
CALL prms%CreateRealOption(   'Part-AdaptMPF-MaxParticleNumber', 'Target maximum simulation particle number per cell')
CALL prms%CreateLogicalOption('Part-AdaptMPF-ApplyMedianFilter', 'Applies a median filter to the distribution  '//&
                              'of the adapted optimal MPF', '.FALSE.')
CALL prms%CreateRealOption(   'Part-AdaptMPF-MaxMPFRatio', 'Maximum deviation, after which the filtering is applied', '1.5')
CALL prms%CreateIntOption(    'Part-AdaptMPF-RefinementNumber', 'Number of times the MPF filter is applied', '5')

CALL prms%CreateIntOption(    'Part-AdaptMPF-SymAxis-MinPartNum', 'Target minimum particle number close to the symmetry axis', '10')

END SUBROUTINE DefineParametersAdaptMPF

SUBROUTINE DSMC_InitAdaptiveWeights()
!===================================================================================================================================
!> Initialization of the adaptive particle weights
!===================================================================================================================================
! MODULES
USE MOD_Globals
USE MOD_ReadInTools
USE MOD_PreProc
USE MOD_io_hdf5
USE MOD_DSMC_Vars     
USE MOD_MPI_Shared    
USE MOD_MPI_Shared_Vars     
USE MOD_DSMC_Symmetry
USE MOD_Mesh_Tools              ,ONLY: GetCNElemID, GetGlobalElemID     
USE MOD_Mesh_Vars               ,ONLY: nGlobalElems, nElems
USE MOD_Particle_Mesh_Vars      ,ONLY: nComputeNodeElems
USE MOD_HDF5_Input              ,ONLY: OpenDataFile, CloseDataFile, ReadArray, ReadAttribute, GetDataProps
USE MOD_HDF5_Input              ,ONLY: GetDataSize, nDims, HSize, File_ID
USE MOD_Restart_Vars            ,ONLY: DoMacroscopicRestart, MacroRestartFileName
USE MOD_StringTools             ,ONLY: STRICMP
! IMPLICIT VARIABLE HANDLING
IMPLICIT NONE
!-----------------------------------------------------------------------------------------------------------------------------------
! INPUT VARIABLES
!-----------------------------------------------------------------------------------------------------------------------------------
! OUTPUT VARIABLES
!-----------------------------------------------------------------------------------------------------------------------------------
! LOCAL VARIABLES
INTEGER                             :: nVar_HDF5, N_HDF5, iVar
INTEGER                             :: nVar_TotalPartNum, nVar_TotalDens, nVar_Ratio, nVar_DSMC, nVar_BGK, nVar_AdaptMPF
INTEGER                             :: offSetLocal
INTEGER                             :: iElem, ReadInElems, iCNElem, firstElem, lastElem
REAL, ALLOCATABLE                   :: ElemData_HDF5(:,:)
CHARACTER(LEN=255),ALLOCATABLE      :: VarNames_tmp(:)
!===================================================================================================================================
SWRITE(UNIT_StdOut,'(132("-"))')
SWRITE(UNIT_stdOut,'(A)') ' INIT ADAPTIVE PARTICLE WEIGHTS...'

ALLOCATE(TestVar(nElems))
TestVar = 0.

CALL InitNodeMapping

IF(DoMacroscopicRestart) THEN

  IF (AdaptMPF%DoAdaptMPF) THEN
    ! Check if the variable MPF is already initialized
    IF (.NOT.(VarWeighting%DoVariableWeighting)) THEN
      CALL DSMC_InitVarWeighting
    END IF

    ! Read-in of the parameter boundaries
    AdaptMPF%MinPartNum         = GETREAL('Part-AdaptMPF-MinParticleNumber')
    AdaptMPF%MaxPartNum         = GETREAL('Part-AdaptMPF-MaxParticleNumber')
    ! Parameters for the filtering subroutine
    AdaptMPF%SymAxis_MinPartNum = GETREAL('Part-AdaptMPF-SymAxis-MinPartNum')
    IF (AdaptMPF%UseMedianFilter) THEN
      AdaptMPF%MaxRatio         = GETREAL('Part-AdaptMPF-MaxMPFRatio')
      AdaptMPF%nRefine          = GETINT('Part-AdaptMPF-RefinementNumber')
    END IF

  END IF

  ! Open DSMC state file
  CALL OpenDataFile(MacroRestartFileName,create=.FALSE.,single=.FALSE.,readOnly=.TRUE.,communicatorOpt=MPI_COMM_WORLD)
  CALL GetDataProps('ElemData',nVar_HDF5,N_HDF5,nGlobalElems)
  
  IF(nVar_HDF5.LE.0) THEN
    SWRITE(*,*) 'ERROR: Something is wrong with our MacroscopicRestart file:', TRIM(MacroRestartFileName)
    CALL abort(__STAMP__,&
    'ERROR: Number of variables in the ElemData array appears to be zero!')
  END IF
  
  ! Get the variable names from the DSMC state and find the position of required quality factors
  ALLOCATE(VarNames_tmp(1:nVar_HDF5))
  CALL ReadAttribute(File_ID,'VarNamesAdd',nVar_HDF5,StrArray=VarNames_tmp(1:nVar_HDF5))
  
  DO iVar=1,nVar_HDF5
    IF (STRICMP(VarNames_tmp(iVar),"Total_SimPartNum")) THEN
      nVar_TotalPartNum = iVar
    END IF
    IF (STRICMP(VarNames_tmp(iVar),"Total_NumberDensity")) THEN
      nVar_TotalDens = iVar
    END IF
    IF (STRICMP(VarNames_tmp(iVar),"DSMC_MCS_over_MFP")) THEN
      nVar_DSMC = iVar
    ELSE
      nVar_DSMC = 0
    END IF
    IF (STRICMP(VarNames_tmp(iVar),"BGK_DSMC_Ratio")) THEN
      nVar_Ratio = iVar
    ELSE 
      nVar_Ratio = 0
    END IF
    IF (STRICMP(VarNames_tmp(iVar),"BGK_MaxRelaxationFactor")) THEN
      nVar_BGK = iVar
    ELSE
      nVar_BGK = 0
    END IF
    IF (STRICMP(VarNames_tmp(iVar),"OptimalAdaptMPF")) THEN
      nVar_AdaptMPF = iVar
    ELSE
      nVar_AdaptMPF = 0
    END IF
  END DO

#if USE_MPI
firstElem = INT(REAL(myComputeNodeRank)*REAL(nComputeNodeElems)/REAL(nComputeNodeProcessors))+1
lastElem = INT(REAL(myComputeNodeRank+1)*REAL(nComputeNodeElems)/REAL(nComputeNodeProcessors))
offsetLocal = GetGlobalElemID(firstElem)-1
ReadInElems = lastElem - firstElem +1
#else
firstElem = 1
lastElem = nGlobalElems
offSetLocal = 0
ReadInElems = nGlobalElems
#endif
  
  ALLOCATE(ElemData_HDF5(1:nVar_HDF5,1:ReadInElems))
  ! Associate construct for integer KIND=8 possibility
  ASSOCIATE (nVar_HDF5     => INT(nVar_HDF5,IK) ,&
              offSetLocal   => INT(offSetLocal,IK) ,&
              ReadInElems   => INT(ReadInElems,IK))
    CALL ReadArray('ElemData',2,(/nVar_HDF5,ReadInElems/),offSetLocal,2,RealArray=ElemData_HDF5(:,:))
  END ASSOCIATE

#if USE_MPI
CALL Allocate_Shared((/7,nComputeNodeElems/),AdaptMPFInfo_Shared_Win,AdaptMPFInfo_Shared)
CALL MPI_WIN_LOCK_ALL(0,AdaptMPFInfo_Shared_Win,iError)
#else
ALLOCATE(AdaptMPFInfo_Shared(7,nComputeNodeElems))
#endif

DO iCNElem=firstElem, lastElem
  iElem = iCNElem - firstElem +1
  AdaptMPFInfo_Shared(1,iCNElem) = ElemData_HDF5(nVar_TotalPartNum,iElem)
  AdaptMPFInfo_Shared(2,iCNElem) = ElemData_HDF5(nVar_TotalDens,iElem)
  IF (nVar_DSMC.NE.0) THEN
    AdaptMPFInfo_Shared(3,iCNElem) = ElemData_HDF5(nVar_DSMC,iElem)
  ELSE 
    AdaptMPFInfo_Shared(3,iCNElem) = 0.
  END IF
  IF (nVar_BGK.NE.0) THEN
    AdaptMPFInfo_Shared(4,iCNElem) = ElemData_HDF5(nVar_BGK,iElem)
  ELSE 
    AdaptMPFInfo_Shared(4,iCNElem) = 0.
  END IF

  IF (nVar_Ratio.NE.0) THEN
    AdaptMPFInfo_Shared(5,iCNElem) = ElemData_HDF5(nVar_Ratio,iElem)
  ELSE IF (nVar_BGK.NE.0) THEN
    AdaptMPFInfo_Shared(5,iCNElem) = 1.
  ELSE
    AdaptMPFInfo_Shared(5,iCNElem) = 0.
  END IF
  AdaptMPFInfo_Shared(6,iCNElem) = 0.
  IF (nVar_AdaptMPF.NE.0) THEN
    AdaptMPFInfo_Shared(7,iCNElem) = ElemData_HDF5(nVar_AdaptMPF,iElem)
  ELSE 
    AdaptMPFInfo_Shared(7,iCNElem) = 0.
  END IF
END DO

#if USE_MPI
CALL BARRIER_AND_SYNC(AdaptMPFInfo_Shared_Win,MPI_COMM_SHARED)
#endif
  
#if USE_MPI
CALL Allocate_Shared((/nComputeNodeElems/),OptimalMPF_Shared_Win,OptimalMPF_Shared)
CALL MPI_WIN_LOCK_ALL(0,OptimalMPF_Shared_Win,iError)
#else
ALLOCATE(OptimalMPF_Shared(nComputeNodeElems))
#endif

  CALL CloseDataFile()
  
  CALL DSMC_AdaptiveWeights()

  ! Check if the variable MPF is already initialized
  IF (.NOT.(VarWeighting%DoVariableWeighting)) THEN
    CALL DSMC_InitVarWeighting
  END IF
END IF ! DoRestart

SWRITE(UNIT_StdOut,'(132("-"))')

END SUBROUTINE DSMC_InitAdaptiveWeights
  
  
SUBROUTINE DSMC_AdaptiveWeights()
!===================================================================================================================================
!> Routine for the automatic adaption of the particles weights in each simulation cell based on the read-in of the particle
!> number density and simulation particle number from a previous simulation
!===================================================================================================================================
! MODULES
USE MOD_Globals
USE MOD_ReadInTools
USE MOD_PreProc
USE MOD_MPI_Shared    
USE MOD_MPI_Shared_Vars   
USE MOD_DSMC_Symmetry
USE MOD_Mesh_Vars               ,ONLY: nGlobalElems
USE MOD_Globals_Vars            ,ONLY: Pi
USE MOD_Mesh_Tools              ,ONLY: GetCNElemID, GetGlobalElemID
USE MOD_Particle_Vars           ,ONLY: Symmetry, Species
USE MOD_Particle_Mesh_Vars      ,ONLY: ElemVolume_Shared, ElemMidPoint_Shared, nComputeNodeElems, GEO
USE MOD_DSMC_Vars               
USE MOD_part_tools              ,ONLY: CalcVarWeightMPF, CalcRadWeightMPF
!----------------------------------------------------------------------------------------------------------------------------------!
IMPLICIT NONE
! INPUT / OUTPUT VARIABLES
!----------------------------------------------------------------------------------------------------------------------------------!
! LOCAL VARIABLES
INTEGER                           :: iCNElem, firstElem, lastElem, offSetLocal, ReadInElems
INTEGER                           :: iRefine
REAL                              :: MinPartNum
!===================================================================================================================================
#if USE_MPI
firstElem = INT(REAL(myComputeNodeRank)*REAL(nComputeNodeElems)/REAL(nComputeNodeProcessors))+1
lastElem = INT(REAL(myComputeNodeRank+1)*REAL(nComputeNodeElems)/REAL(nComputeNodeProcessors))
offsetLocal = GetGlobalElemID(firstElem)-1
ReadInElems = lastElem - firstElem +1
#else
firstElem = 1
lastElem = nGlobalElems
offSetLocal = 0
ReadInElems = nGlobalElems
#endif

! ! Determine the MPF based on the particle number from the reference simulation
DO iCNElem = firstElem, lastElem
  ! Determine the reference MPF
  IF (AdaptMPFInfo_Shared(7,iCNElem).NE.0.) then
    AdaptMPFInfo_Shared(6,iCNElem) = AdaptMPFInfo_Shared(7,iCNElem)
  ELSE IF (VarWeighting%DoVariableWeighting) THEN
    AdaptMPFInfo_Shared(6,iCNElem) = CalcVarWeightMPF(ElemMidPoint_Shared(:,iCNElem), 1)
  ELSE IF (RadialWeighting%DoRadialWeighting) THEN
    AdaptMPFInfo_Shared(6,iCNElem) = CalcRadWeightMPF(ElemMidPoint_Shared(2,iCNElem), 1)
  ELSE 
    AdaptMPFInfo_Shared(6,iCNElem) = Species(1)%MacroParticleFactor
  END IF

  IF (AdaptMPFInfo_Shared(5,iCNElem).EQ.1.) THEN
    ! Adaption based on the BGK quality factor
    IF (AdaptMPFInfo_Shared(4,iCNElem).GT.0.8) THEN
      OptimalMPF_Shared(iCNElem) = AdaptMPFInfo_Shared(6,iCNElem)*(0.8/AdaptMPFInfo_Shared(4,iCNElem))
    ! Adaption based on the particle number per simulation cell  
    ELSE ! BGKQualityFactors
      ! Further refinement for the elements close to the symmetry axis in the axisymmetric case
      IF ((Symmetry%Axisymmetric).AND.(ElemMidPoint_Shared(2,iCNElem).LE.(GEO%ymaxglob*0.05))) THEN
        MinPartNum = AdaptMPF%SymAxis_MinPartNum
      ELSE 
        MinPartNum = AdaptMPF%MinPartNum
      END IF
      MinPartNum = AdaptMPF%MinPartNum
      IF(AdaptMPFInfo_Shared(1,iCNElem).LT.MinPartNum) THEN
        OptimalMPF_Shared(iCNElem) = AdaptMPFInfo_Shared(2,iCNElem)*ElemVolume_Shared(iCNElem)/MinPartNum
      ELSE IF(AdaptMPFInfo_Shared(1,iCNElem).GT.AdaptMPF%MaxPartNum) THEN
        OptimalMPF_Shared(iCNElem) = AdaptMPFInfo_Shared(2,iCNElem)*ElemVolume_Shared(iCNElem)/AdaptMPF%MaxPartNum
      ELSE 
        OptimalMPF_Shared(iCNElem) = AdaptMPFInfo_Shared(6,iCNElem)
      END IF
    END IF ! BGKQualityFactors
  ELSE 

    ! Adaption based on the DSMC quality factor
    IF (AdaptMPFInfo_Shared(3,iCNElem).GT.0.8) THEN
      IF (Symmetry%Order.EQ.2) THEN
        OptimalMPF_Shared(iCNElem) = AdaptMPFInfo_Shared(6,iCNElem)*(0.8/AdaptMPFInfo_Shared(3,iCNElem))**2
      ELSE 
        OptimalMPF_Shared(iCNElem) = AdaptMPFInfo_Shared(6,iCNElem)*(0.8/AdaptMPFInfo_Shared(3,iCNElem))**3
      END IF
    ! Adaption based on the particle number per simulation cell
    ELSE ! DSMCQualityFactors
      IF ((Symmetry%Axisymmetric).AND.(ElemMidPoint_Shared(2,iCNElem).LE.(GEO%ymaxglob*0.05))) THEN
        MinPartNum = AdaptMPF%SymAxis_MinPartNum
      ELSE 
        MinPartNum = AdaptMPF%MinPartNum
      END IF
      MinPartNum = AdaptMPF%MinPartNum
      IF(AdaptMPFInfo_Shared(1,iCNElem).LT.MinPartNum) THEN
        OptimalMPF_Shared(iCNElem) = AdaptMPFInfo_Shared(2,iCNElem)*ElemVolume_Shared(iCNElem)/MinPartNum
      ELSE IF(AdaptMPFInfo_Shared(1,iCNElem).GT.AdaptMPF%MaxPartNum) THEN
        OptimalMPF_Shared(iCNElem) = AdaptMPFInfo_Shared(2,iCNElem)*ElemVolume_Shared(iCNElem)/AdaptMPF%MaxPartNum 
      ELSE
        OptimalMPF_Shared(iCNElem) = AdaptMPFInfo_Shared(6,iCNElem)
      END IF
    END IF ! DSMCQualityFactors 
  END IF !BGK_DSMC_Ratio

  ! If not defined, determine the optimal MPF from the previous simulation
  IF (OptimalMPF_Shared(iCNElem).LE.0.) THEN
    OptimalMPF_Shared(iCNElem) = AdaptMPFInfo_Shared(6,iCNElem)
  END IF!
END DO ! iGlobalElem

#if USE_MPI
CALL BARRIER_AND_SYNC(OptimalMPF_Shared_Win,MPI_COMM_SHARED)
#endif

CALL NodeMappingAdaptMPF

! Average the MPF distribution by the neighbour values
IF (AdaptMPF%UseMedianFilter) THEN
  DO iRefine=1, AdaptMPF%nRefine 
    CALL NodeMappingFilterMPF
  END DO
END IF ! UseMedianFilter


! Enable the calculation based on the adaptive MPF for the later steps
AdaptMPF%UseOptMPF = .TRUE.

#if USE_MPI
CALL UNLOCK_AND_FREE(AdaptMPFInfo_Shared_Win)
#endif
ADEALLOCATE(AdaptMPFInfo_Shared)

#if USE_MPI
CALL UNLOCK_AND_FREE(OptimalMPF_Shared_Win)
#endif
ADEALLOCATE(OptimalMPF_Shared)

END SUBROUTINE DSMC_AdaptiveWeights
  
SUBROUTINE InitNodeMapping()
!===================================================================================================================================
!> Mapping of the adapted particle weights from the elements to the nodes and interpolation 
!===================================================================================================================================
! MODULES
USE MOD_Globals
USE MOD_Preproc
USE MOD_Particle_Vars
USE MOD_Particle_Mesh_Vars    
USE MOD_Mesh_Vars              ,ONLY: nElems
#if USE_MPI
USE MOD_MPI_Shared
USE MOD_Mesh_Vars              ,ONLY: offsetElem
USE MOD_MPI_Shared             ,ONLY: BARRIER_AND_SYNC
USE MOD_Mesh_Tools             ,ONLY: GetGlobalElemID, GetCNElemID
USE MOD_MPI_Shared_Vars        ,ONLY: nComputeNodeTotalElems, nLeaderGroupProcs, nProcessors_Global
#endif /*USE_MPI*/
#if USE_LOADBALANCE
USE MOD_LoadBalance_Vars       ,ONLY: PerformLoadBalance
#endif /*USE_LOADBALANCE*/
! IMPLICIT VARIABLE HANDLING
IMPLICIT NONE
!-----------------------------------------------------------------------------------------------------------------------------------
! INPUT VARIABLES
!-----------------------------------------------------------------------------------------------------------------------------------
! OUTPUT VARIABLES
!-----------------------------------------------------------------------------------------------------------------------------------
! LOCAL VARIABLES
INTEGER                   :: iElem, iNode, ElemID
#if USE_MPI
INTEGER                   :: UniqueNodeID
INTEGER                   :: jElem, NonUniqueNodeID
INTEGER                   :: SendNodeCount, GlobalElemRank, iProc
INTEGER                   :: TestElemID, GlobalElemRankOrig, iRank
LOGICAL,ALLOCATABLE       :: NodeMapping(:,:), DoNodeMapping(:), SendNode(:), IsMappedNode(:) 
LOGICAL                   :: bordersMyrank
INTEGER                   :: SendRequestNonSym(0:nProcessors_Global-1)      , RecvRequestNonSym(0:nProcessors_Global-1)
INTEGER                   :: nSendUniqueNodesNonSym(0:nProcessors_Global-1) , nRecvUniqueNodesNonSym(0:nProcessors_Global-1)
INTEGER                   :: GlobalRankToNodeSendRank(0:nProcessors_Global-1)
#endif
LOGICAL,ALLOCATABLE       :: FlagShapeElemAdapt(:) 
!===================================================================================================================================
! Initialization
LBWRITE(UNIT_stdOut,'(A)') ' INIT NODE MAPPING...'

ALLOCATE(FlagShapeElemAdapt(nComputeNodeTotalElems))
FlagShapeElemAdapt = .FALSE.

DO iElem = 1,nComputeNodeTotalElems
  ElemID    = GetGlobalElemID(iElem)
  IF (ElemInfo_Shared(ELEM_HALOFLAG,ElemID).NE.4) FlagShapeElemAdapt(iElem) = .TRUE.
END DO

#if USE_MPI
  ALLOCATE(RecvRequestCN(0:nLeaderGroupProcs-1), SendRequestCN(0:nLeaderGroupProcs-1))
#endif

ALLOCATE(NodeValue(1:2,1:nUniqueGlobalNodes))
NodeValue=0.0
#if USE_MPI
ALLOCATE(DoNodeMapping(0:nProcessors_Global-1),SendNode(1:nUniqueGlobalNodes))
DoNodeMapping = .FALSE.
SendNode = .FALSE.
DO iElem = 1,nComputeNodeTotalElems
  IF (FlagShapeElemAdapt(iElem)) THEN
    bordersMyrank = .FALSE.
    ! Loop all local nodes
    TestElemID = GetGlobalElemID(iElem)
    GlobalElemRankOrig = ElemInfo_Shared(ELEM_RANK,TestElemID)

    DO iNode = 1, 8
      NonUniqueNodeID = ElemNodeID_Shared(iNode,iElem)
      UniqueNodeID = NodeInfo_Shared(NonUniqueNodeID)
      ! Loop 1D array [offset + 1 : offset + NbrOfElems]
      ! (all CN elements that are connected to the local nodes)
      DO jElem = NodeToElemMapping(1,UniqueNodeID) + 1, NodeToElemMapping(1,UniqueNodeID) + NodeToElemMapping(2,UniqueNodeID)
        TestElemID = GetGlobalElemID(NodeToElemInfo(jElem))
        GlobalElemRank = ElemInfo_Shared(ELEM_RANK,TestElemID)
        ! check if element for this side is on the current compute-node. Alternative version to the check above
        IF (GlobalElemRank.EQ.myRank) THEN
          bordersMyrank = .TRUE.
          SendNode(UniqueNodeID) = .TRUE.
        END IF
      END DO
      IF (bordersMyrank) DoNodeMapping(GlobalElemRankOrig) = .TRUE.
    END DO
  END IF
END DO

nMapNodes = 0 
ALLOCATE(IsMappedNode(1:nUniqueGlobalNodes))
IsMappedNode = .FALSE.
DO iElem =1, nElems
  TestElemID = GetCNElemID(iElem + offsetElem)
  DO iNode = 1, 8
    NonUniqueNodeID = ElemNodeID_Shared(iNode,TestElemID)
    UniqueNodeID = NodeInfo_Shared(NonUniqueNodeID)
    IsMappedNode(UniqueNodeID) = .TRUE.
  END DO
END DO
nMapNodes = COUNT(IsMappedNode)
nMapNodesTotal = nMapNodes
DO iNode=1, nUniqueGlobalNodes
  IF (.NOT.IsMappedNode(iNode).AND.SendNode(iNode)) THEN
    nMapNodesTotal = nMapNodesTotal + 1
  END IF
END DO

ALLOCATE(NodetoGlobalNode(1:nMapNodesTotal))
nMapNodesTotal = 0
DO iNode=1, nUniqueGlobalNodes
  IF (IsMappedNode(iNode)) THEN
    nMapNodesTotal = nMapNodesTotal + 1
    NodetoGlobalNode(nMapNodesTotal) = iNode
  END IF
END DO
DO iNode=1, nUniqueGlobalNodes
  IF (.NOT.IsMappedNode(iNode).AND.SendNode(iNode)) THEN
    nMapNodesTotal = nMapNodesTotal + 1
    NodetoGlobalNode(nMapNodesTotal) = iNode
  END IF
END DO

GlobalRankToNodeSendRank = -1
nNodeSendExchangeProcs = COUNT(DoNodeMapping)
ALLOCATE(NodeSendRankToGlobalRank(1:nNodeSendExchangeProcs))
NodeSendRankToGlobalRank = 0
nNodeSendExchangeProcs = 0
DO iRank= 0, nProcessors_Global-1
  IF (iRank.EQ.myRank) CYCLE
  IF (DoNodeMapping(iRank)) THEN
    nNodeSendExchangeProcs = nNodeSendExchangeProcs + 1
    GlobalRankToNodeSendRank(iRank) = nNodeSendExchangeProcs
    NodeSendRankToGlobalRank(nNodeSendExchangeProcs) = iRank
  END IF
END DO
ALLOCATE(NodeMapping(1:nNodeSendExchangeProcs, 1:nUniqueGlobalNodes))
NodeMapping = .FALSE.

DO iNode = 1, nUniqueGlobalNodes
  IF (SendNode(iNode)) THEN
    DO jElem = NodeToElemMapping(1,iNode) + 1, NodeToElemMapping(1,iNode) + NodeToElemMapping(2,iNode)
        TestElemID = GetGlobalElemID(NodeToElemInfo(jElem))
        GlobalElemRank = ElemInfo_Shared(ELEM_RANK,TestElemID)
        ! check if element for this side is on the current compute-node. Alternative version to the check above
        IF (GlobalElemRank.NE.myRank) THEN
          iRank = GlobalRankToNodeSendRank(GlobalElemRank)
          IF (iRank.LT.1) CALL ABORT(__STAMP__,'Found not connected Rank!', IERROR)
          NodeMapping(iRank, iNode) = .TRUE.
        END IF
      END DO
  END IF
END DO

! Get number of send nodes for each proc: Size of each message for each proc 
nSendUniqueNodesNonSym        = 0
nRecvUniqueNodesNonSym(myrank) = 0
ALLOCATE(NodeMappingSend(1:nNodeSendExchangeProcs))
DO iProc = 1, nNodeSendExchangeProcs
  NodeMappingSend(iProc)%nSendUniqueNodes = 0
  DO iNode = 1, nUniqueGlobalNodes
    IF (NodeMapping(iProc,iNode)) NodeMappingSend(iProc)%nSendUniqueNodes = NodeMappingSend(iProc)%nSendUniqueNodes + 1
  END DO
  ! local to global array
  nSendUniqueNodesNonSym(NodeSendRankToGlobalRank(iProc)) = NodeMappingSend(iProc)%nSendUniqueNodes
END DO

! Open receive buffer for non-symmetric exchange identification
DO iProc = 0,nProcessors_Global-1
  IF (iProc.EQ.myRank) CYCLE
  CALL MPI_IRECV( nRecvUniqueNodesNonSym(iProc) &
                , 1                             &
                , MPI_INTEGER                   &
                , iProc                         &
                , 1999                          &
                , MPI_COMM_WORLD                &
                , RecvRequestNonSym(iProc)      &
                , IERROR)
END DO

! Send each proc the number of nodes 
DO iProc = 0,nProcessors_Global-1
  IF (iProc.EQ.myRank) CYCLE
  CALL MPI_ISEND( nSendUniqueNodesNonSym(iProc) &
                , 1                             &
                , MPI_INTEGER                   &
                , iProc                         &
                , 1999                          &
                , MPI_COMM_WORLD                &
                , SendRequestNonSym(iProc)      &
                , IERROR)
END DO

! Finish communication
DO iProc = 0,nProcessors_Global-1
  IF (iProc.EQ.myRank) CYCLE
  CALL MPI_WAIT(RecvRequestNonSym(iProc),MPIStatus,IERROR)
  IF(IERROR.NE.MPI_SUCCESS) CALL ABORT(__STAMP__,' MPI Communication error', IERROR)
  CALL MPI_WAIT(SendRequestNonSym(iProc),MPIStatus,IERROR)
  IF(IERROR.NE.MPI_SUCCESS) CALL ABORT(__STAMP__,' MPI Communication error', IERROR)
END DO

nNodeRecvExchangeProcs = COUNT(nRecvUniqueNodesNonSym.GT.0)
ALLOCATE(NodeMappingRecv(1:nNodeRecvExchangeProcs))
ALLOCATE(NodeRecvRankToGlobalRank(1:nNodeRecvExchangeProcs))
NodeRecvRankToGlobalRank = 0
nNodeRecvExchangeProcs = 0
DO iRank= 0, nProcessors_Global-1
  IF (iRank.EQ.myRank) CYCLE
  IF (nRecvUniqueNodesNonSym(iRank).GT.0) THEN
    nNodeRecvExchangeProcs = nNodeRecvExchangeProcs + 1
    ! Store global rank of iRecvRank
    NodeRecvRankToGlobalRank(nNodeRecvExchangeProcs) = iRank
    ! Store number of nodes of iRecvRank
    NodeMappingRecv(nNodeRecvExchangeProcs)%nRecvUniqueNodes = nRecvUniqueNodesNonSym(iRank)
  END IF
END DO

! Open receive buffer
ALLOCATE(RecvRequest(1:nNodeRecvExchangeProcs))
DO iProc = 1, nNodeRecvExchangeProcs
  ALLOCATE(NodeMappingRecv(iProc)%RecvNodeUniqueGlobalID(1:NodeMappingRecv(iProc)%nRecvUniqueNodes))
  ALLOCATE(NodeMappingRecv(iProc)%RecvNodeFilterMPF(1:2,1:NodeMappingRecv(iProc)%nRecvUniqueNodes))
  CALL MPI_IRECV( NodeMappingRecv(iProc)%RecvNodeUniqueGlobalID                   &
                , NodeMappingRecv(iProc)%nRecvUniqueNodes                         &
                , MPI_INTEGER                                                 &
                , NodeRecvRankToGlobalRank(iProc)                         &
                , 666                                                         &
                , MPI_COMM_WORLD                                              &
                , RecvRequest(iProc)                                          &
                , IERROR)
END DO

! Open send buffer
ALLOCATE(SendRequest(1:nNodeSendExchangeProcs))
DO iProc = 1, nNodeSendExchangeProcs
  ALLOCATE(NodeMappingSend(iProc)%SendNodeUniqueGlobalID(1:NodeMappingSend(iProc)%nSendUniqueNodes))
  NodeMappingSend(iProc)%SendNodeUniqueGlobalID=-1
  ALLOCATE(NodeMappingSend(iProc)%SendNodeFilterMPF(1:2,1:NodeMappingSend(iProc)%nSendUniqueNodes))
  NodeMappingSend(iProc)%SendNodeFilterMPF=0.
  SendNodeCount = 0
  DO iNode = 1, nUniqueGlobalNodes
    IF (NodeMapping(iProc,iNode)) THEN
      SendNodeCount = SendNodeCount + 1
      NodeMappingSend(iProc)%SendNodeUniqueGlobalID(SendNodeCount) = iNode
    END IF
  END DO
  CALL MPI_ISEND( NodeMappingSend(iProc)%SendNodeUniqueGlobalID                   &
                , NodeMappingSend(iProc)%nSendUniqueNodes                         &
                , MPI_INTEGER                                                 &
                , NodeSendRankToGlobalRank(iProc)                         &
                , 666                                                         &
                , MPI_COMM_WORLD                                              &
                , SendRequest(iProc)                                          &
                , IERROR)
END DO

! Finish send
DO iProc = 1, nNodeSendExchangeProcs
  CALL MPI_WAIT(SendRequest(iProc),MPISTATUS,IERROR)
  IF (IERROR.NE.MPI_SUCCESS) CALL ABORT(__STAMP__,' MPI Communication error', IERROR)
END DO

! Finish receive
DO iProc = 1, nNodeRecvExchangeProcs
  CALL MPI_WAIT(RecvRequest(iProc),MPISTATUS,IERROR)
  IF (IERROR.NE.MPI_SUCCESS) CALL ABORT(__STAMP__,' MPI Communication error', IERROR)
END DO
#else
nMapNodes      = nUniqueGlobalNodes
nMapNodesTotal = nMapNodes
ALLOCATE(NodetoGlobalNode(1:nMapNodesTotal))
DO iNode=1, nUniqueGlobalNodes
  NodetoGlobalNode(iNode) = iNode
END DO
#endif /*USE_MPI*/

SDEALLOCATE(FlagShapeElemAdapt)

LBWRITE(UNIT_stdOut,'(A)')' INIT NODE MAPPING DONE!'

END SUBROUTINE InitNodeMapping

SUBROUTINE NodeMappingAdaptMPF()
!===================================================================================================================================
! Mapping of the adapted MPF to the node
!===================================================================================================================================
! MODULES
USE MOD_Globals
USE MOD_PreProc
USE MOD_Particle_Mesh_Vars
USE MOD_DSMC_Symmetry
USE MOD_Mesh_Vars          ,ONLY: nElems, offsetElem
USE MOD_Mesh_Tools         ,ONLY: GetCNElemID
USE MOD_DSMC_Vars          ,ONLY: OptimalMPF_Shared
#if USE_MPI
USE MOD_MPI_Shared         ,ONLY: BARRIER_AND_SYNC
#endif  
#if USE_LOADBALANCE
USE MOD_LoadBalance_Vars   ,ONLY: PerformLoadBalance
#endif /*USE_LOADBALANCE*/
! IMPLICIT VARIABLE HANDLING
IMPLICIT NONE
!-----------------------------------------------------------------------------------------------------------------------------------
! INPUT VARIABLES
!-----------------------------------------------------------------------------------------------------------------------------------
! OUTPUT VARIABLES
!-----------------------------------------------------------------------------------------------------------------------------------
! LOCAL VARIABLES
INTEGER                    :: iElem, NodeID(1:8), iNode, globalNode
#if USE_MPI
INTEGER                    :: iProc
#endif /*USE_MPI*/
!===================================================================================================================================
LBWRITE(UNIT_stdOut,'(A)') 'NODE COMMUNICATION...'

! Nullify NodeValue
DO iNode = 1, nMapNodesTotal
  globalNode = NodetoGlobalNode(iNode)
  NodeValue(:,globalNode) = 0.0 
END DO

! Loop over all elements and map their weighting factor from the element to the nodes
DO iElem =1, nElems
  NodeID = NodeInfo_Shared(ElemNodeID_Shared(:,GetCNElemID(iElem+offsetElem))) 
  DO iNode = 1, 8
    NodeValue(1,NodeID(iNode)) = NodeValue(1,NodeID(iNode)) + OptimalMPF_Shared(GetCNElemID(iElem+offsetElem))
    NodeValue(2,NodeID(iNode)) = NodeValue(2,NodeID(iNode)) + 1.
  END DO
END DO 

#if USE_MPI
! 1) Receive MPF values

  DO iProc = 1, nNodeRecvExchangeProcs
    ! Open receive buffer
    CALL MPI_IRECV( NodeMappingRecv(iProc)%RecvNodeFilterMPF(1:2,:) &
        , 2*NodeMappingRecv(iProc)%nRecvUniqueNodes               &
        , MPI_DOUBLE_PRECISION                                  &
        , NodeRecvRankToGlobalRank(iProc)                       &
        , 666                                                   &
        , MPI_COMM_WORLD                                        &
        , RecvRequest(iProc)                                    &
        , IERROR)
  END DO

  ! 2) Send MPF values
  DO iProc = 1, nNodeSendExchangeProcs
    ! Send message (non-blocking)
    DO iNode = 1, NodeMappingSend(iProc)%nSendUniqueNodes
      NodeMappingSend(iProc)%SendNodeFilterMPF(1:2,iNode) = NodeValue(1:2,NodeMappingSend(iProc)%SendNodeUniqueGlobalID(iNode))
    END DO
    CALL MPI_ISEND( NodeMappingSend(iProc)%SendNodeFilterMPF(1:2,:)     &
        , 2*NodeMappingSend(iProc)%nSendUniqueNodes                   &
        , MPI_DOUBLE_PRECISION                                      &
        , NodeSendRankToGlobalRank(iProc)                           &
        , 666                                                       &
        , MPI_COMM_WORLD                                            &
        , SendRequest(iProc)                                        &
        , IERROR)
  END DO

  ! Finish communication/
  DO iProc = 1, nNodeSendExchangeProcs
    CALL MPI_WAIT(SendRequest(iProc),MPISTATUS,IERROR)
    IF (IERROR.NE.MPI_SUCCESS) CALL ABORT(__STAMP__,' MPI Communication error', IERROR)
  END DO
  DO iProc = 1, nNodeRecvExchangeProcs
    CALL MPI_WAIT(RecvRequest(iProc),MPISTATUS,IERROR)
    IF (IERROR.NE.MPI_SUCCESS) CALL ABORT(__STAMP__,' MPI Communication error', IERROR)
  END DO

  ! 3) Extract messages
  DO iProc = 1, nNodeRecvExchangeProcs
    DO iNode = 1, NodeMappingRecv(iProc)%nRecvUniqueNodes
      ASSOCIATE( NV => NodeValue(1:2,NodeMappingRecv(iProc)%RecvNodeUniqueGlobalID(iNode)))
        NV = NV +  NodeMappingRecv(iProc)%RecvNodeFilterMPF(1:2,iNode)
      END ASSOCIATE
    END DO
  END DO
#endif /*USE_MPI*/

! Determine the average node value
DO iNode = 1, nMapNodesTotal
  globalNode = NodetoGlobalNode(iNode)
  IF (NodeValue(2,globalNode).GT.0.) THEN
    NodeValue(1,globalNode) = NodeValue(1,globalNode) / NodeValue(2,globalNode)
  END IF
END DO

LBWRITE(UNIT_stdOut,'(A)') 'NODE COMMUNICATION DONE'
END SUBROUTINE NodeMappingAdaptMPF

SUBROUTINE NodeMappingFilterMPF()
!===================================================================================================================================
! Filter the adapted MPF by multiple mapping from the element to the node and back
!===================================================================================================================================
! MODULES
USE MOD_Globals
USE MOD_PreProc
USE MOD_Particle_Mesh_Vars
USE MOD_DSMC_Symmetry
USE MOD_Mesh_Vars          ,ONLY: nElems, offsetElem
USE MOD_Mesh_Tools         ,ONLY: GetCNElemID
USE MOD_DSMC_Vars          ,ONLY: OptimalMPF_Shared
#if USE_MPI
USE MOD_MPI_Shared         ,ONLY: BARRIER_AND_SYNC
#endif  
! IMPLICIT VARIABLE HANDLING
IMPLICIT NONE
!-----------------------------------------------------------------------------------------------------------------------------------
! INPUT VARIABLES
!-----------------------------------------------------------------------------------------------------------------------------------
! OUTPUT VARIABLES
!-----------------------------------------------------------------------------------------------------------------------------------
! LOCAL VARIABLES
INTEGER                    :: iElem, NodeID(1:8), iNode, globalNode, CNElemID
#if USE_MPI
INTEGER                    :: iProc
#endif /*USE_MPI*/
!===================================================================================================================================
DO iElem =1, nElems
  CNElemID = GetCNElemID(iElem+offsetElem)
  ! Set the optimal MPF to zero and recalculate it based on the surrounding node values
  OptimalMPF_Shared(CNElemID) = 0.
  NodeID = NodeInfo_Shared(ElemNodeID_Shared(:,GetCNElemID(iElem+offsetElem)))
    DO iNode = 1, 8
      OptimalMPF_Shared(CNElemID) = OptimalMPF_Shared(CNElemID) + NodeValue(1,NodeID(iNode))
    END DO
    OptimalMPF_Shared(CNElemID) = OptimalMPF_Shared(CNElemID)/8.
END DO

! Nullify NodeValue
DO iNode = 1, nMapNodesTotal
  globalNode = NodetoGlobalNode(iNode)
  NodeValue(:,globalNode) = 0.0 
END DO

! Loop over all elements and map their weighting factor from the element to the nodes
DO iElem =1, nElems
  NodeID = NodeInfo_Shared(ElemNodeID_Shared(:,GetCNElemID(iElem+offsetElem))) 
  DO iNode = 1, 8
    NodeValue(1,NodeID(iNode)) = NodeValue(1,NodeID(iNode)) + OptimalMPF_Shared(GetCNElemID(iElem+offsetElem))
    NodeValue(2,NodeID(iNode)) = NodeValue(2,NodeID(iNode)) + 1.
  END DO
END DO 

#if USE_MPI
! 1) Receive MPF values

  DO iProc = 1, nNodeRecvExchangeProcs
    ! Open receive buffer
    CALL MPI_IRECV( NodeMappingRecv(iProc)%RecvNodeFilterMPF(1:2,:) &
        , 2*NodeMappingRecv(iProc)%nRecvUniqueNodes             &
        , MPI_DOUBLE_PRECISION                                  &
        , NodeRecvRankToGlobalRank(iProc)                       &
        , 666                                                   &
        , MPI_COMM_WORLD                                        &
        , RecvRequest(iProc)                                    &
        , IERROR)
  END DO

  ! 2) Send MPF values
  DO iProc = 1, nNodeSendExchangeProcs
    ! Send message (non-blocking)
    DO iNode = 1, NodeMappingSend(iProc)%nSendUniqueNodes
      NodeMappingSend(iProc)%SendNodeFilterMPF(1:2,iNode) = NodeValue(1:2,NodeMappingSend(iProc)%SendNodeUniqueGlobalID(iNode))
    END DO
    CALL MPI_ISEND( NodeMappingSend(iProc)%SendNodeFilterMPF(1:2,:) &
        , 2*NodeMappingSend(iProc)%nSendUniqueNodes                 &
        , MPI_DOUBLE_PRECISION                                      &
        , NodeSendRankToGlobalRank(iProc)                           &
        , 666                                                       &
        , MPI_COMM_WORLD                                            &
        , SendRequest(iProc)                                        &
        , IERROR)
  END DO

  ! Finish communication/
  DO iProc = 1, nNodeSendExchangeProcs
    CALL MPI_WAIT(SendRequest(iProc),MPISTATUS,IERROR)
    IF (IERROR.NE.MPI_SUCCESS) CALL ABORT(__STAMP__,' MPI Communication error', IERROR)
  END DO
  DO iProc = 1, nNodeRecvExchangeProcs
    CALL MPI_WAIT(RecvRequest(iProc),MPISTATUS,IERROR)
    IF (IERROR.NE.MPI_SUCCESS) CALL ABORT(__STAMP__,' MPI Communication error', IERROR)
  END DO

  ! 3) Extract messages
  DO iProc = 1, nNodeRecvExchangeProcs
    DO iNode = 1, NodeMappingRecv(iProc)%nRecvUniqueNodes
      ASSOCIATE( NV => NodeValue(1:2,NodeMappingRecv(iProc)%RecvNodeUniqueGlobalID(iNode)))
        NV = NV +  NodeMappingRecv(iProc)%RecvNodeFilterMPF(1:2,iNode)
      END ASSOCIATE
    END DO
  END DO
#endif /*USE_MPI*/

! Determine the average node value
DO iNode = 1, nMapNodesTotal
  globalNode = NodetoGlobalNode(iNode)
  IF (NodeValue(2,globalNode).GT.0.) THEN
    NodeValue(1,globalNode) = NodeValue(1,globalNode) / NodeValue(2,globalNode)
  END IF
END DO

END SUBROUTINE NodeMappingFilterMPF

END MODULE MOD_DSMC_AdaptMPF
