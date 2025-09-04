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

MODULE MOD_PICDepo_MPI
#if USE_MPI
#if !((PP_TimeDiscMethod==4) || (PP_TimeDiscMethod==300) || (PP_TimeDiscMethod==400))
!===================================================================================================================================
! MOD PIC Depo
!===================================================================================================================================
IMPLICIT NONE
PRIVATE

TYPE NodeDepoMapping
  INTEGER                                     :: NodeID
  TYPE (NodeDepoMapping), POINTER             :: next => NULL()
END TYPE
!===================================================================================================================================
PUBLIC :: InitDepoNodesMPI
PUBLIC :: InitDepoSurfNodesMPI
PUBLIC :: ExchangeNodeSource
PUBLIC :: ExchangeNodeSourceExtMPI
PUBLIC :: ExchangeSurfNodeSourceMPI
!===================================================================================================================================

CONTAINS

!===================================================================================================================================
!> Initialize the MPI communication for the volume node deposition
!===================================================================================================================================
SUBROUTINE InitDepoNodesMPI(DoNodeMapping,SendNode)
! MODULES
USE MOD_Preproc
USE MOD_Globals
USE MOD_PICDepo_Vars
USE MOD_Dielectric_Vars        ,ONLY: DoDielectricSurfaceCharge
USE MOD_Mesh_Vars              ,ONLY: nElems
USE MOD_Particle_Mesh_Vars     ,ONLY: nUniqueGlobalNodes
USE MOD_Mesh_Tools             ,ONLY: GetGlobalElemID, GetCNElemID
USE MOD_Mesh_Vars              ,ONLY: offsetElem,ELEM_RANK
USE MOD_Particle_Mesh_Vars     ,ONLY: NodeToElemInfo,NodeToElemMapping,ElemNodeID_Shared,NodeInfo_Shared
USE MOD_MPI_Shared_Vars        ,ONLY: nComputeNodeTotalElems
USE MOD_MPI_Shared_Vars        ,ONLY: nProcessors_Global
USE MOD_Particle_Mesh_Vars     ,ONLY: ElemInfo_Shared
! IMPLICIT VARIABLE HANDLING
IMPLICIT NONE
!-----------------------------------------------------------------------------------------------------------------------------------
! INPUT VARIABLES
LOGICAL,INTENT(INOUT) :: DoNodeMapping(0:nProcessors_Global-1)
LOGICAL,INTENT(INOUT) :: SendNode(1:nUniqueGlobalNodes)
!-----------------------------------------------------------------------------------------------------------------------------------
! OUTPUT VARIABLES
!-----------------------------------------------------------------------------------------------------------------------------------
! LOCAL VARIABLES
INTEGER                   :: iElem, iNode
INTEGER                   :: UniqueNodeID, testNode
INTEGER                   :: GlobalRankToNodeSendDepoRank(0:nProcessors_Global-1)
INTEGER                   :: jElem,TestElemID
INTEGER                   :: NonUniqueNodeID
INTEGER                   :: SendNodeCount, GlobalElemRank, iProc
INTEGER                   :: GlobalElemRankOrig, iRank
LOGICAL,ALLOCATABLE       :: IsDepoNode(:)
LOGICAL                   :: bordersMyrank
! Non-symmetric particle exchange
TYPE(MPI_Request)         :: SendRequestNonSymDepo(0:nProcessors_Global-1)      , RecvRequestNonSymDepo(0:nProcessors_Global-1)
INTEGER                   :: nSendUniqueNodesNonSymDepo(0:nProcessors_Global-1) , nRecvUniqueNodesNonSymDepo(0:nProcessors_Global-1)
TYPE tElemNodeDepoMap
  TYPE (NodeDepoMapping), POINTER :: first => NULL()
  LOGICAL               :: firstNode
  INTEGER               :: nNodes
END TYPE
TYPE(tElemNodeDepoMap), ALLOCATABLE :: ElemNodeDepoMap(:)
TYPE (NodeDepoMapping), POINTER :: node
!===================================================================================================================================
IF(DoDielectricSurfaceCharge)THEN
  ALLOCATE(NodeSourceExtMPI(1:nUniqueGlobalNodes))
  NodeSourceExtMPI = 0.
END IF ! DoDielectricSurfaceCharge

! Loop over the elements of the complete compute-node region (including the halo region)
DO iElem = 1,nComputeNodeTotalElems
  IF (FlagShapeElem(iElem)) THEN
    bordersMyrank = .FALSE.
    ! Loop all local nodes
    TestElemID = GetGlobalElemID(iElem)
    GlobalElemRankOrig = ElemInfo_Shared(ELEM_RANK,TestElemID)
    IF (DoHaloDepo.AND.(GlobalElemRankOrig.NE.myRank)) DoNodeMapping(GlobalElemRankOrig) = .TRUE.

    DO iNode = 1, 8
    NonUniqueNodeID = ElemNodeID_Shared(iNode,iElem)
    UniqueNodeID = NodeInfo_Shared(NonUniqueNodeID)
    ! Loop 1D array [offset + 1 : offset + NbrOfElems]
    ! (all CN elements that are connected to the local nodes)
    DO jElem = NodeToElemMapping(1,UniqueNodeID) + 1, NodeToElemMapping(1,UniqueNodeID) + NodeToElemMapping(2,UniqueNodeID)
      TestElemID = GetGlobalElemID(NodeToElemInfo(jElem))
      GlobalElemRank = ElemInfo_Shared(ELEM_RANK,TestElemID)
      IF (DoHaloDepo) THEN
        SendNode(UniqueNodeID) = .TRUE.
        IF (GlobalElemRank.NE.myRank) DoNodeMapping(GlobalElemRank) = .TRUE.
      ELSE
        IF (GlobalElemRank.EQ.myRank) THEN
          bordersMyrank = .TRUE.
          SendNode(UniqueNodeID) = .TRUE.
        END IF
      END IF
    END DO
    IF (.NOT.DoHaloDepo.AND.bordersMyrank) THEN
      DoNodeMapping(GlobalElemRankOrig) = .TRUE.
    END IF
    END DO
  END IF
END DO

! Flag the unique deposition nodes per processor
nDepoNodes = 0
ALLOCATE(IsDepoNode(1:nUniqueGlobalNodes))
IsDepoNode = .FALSE.
DO iElem =1, nElems
  TestElemID = GetCNElemID(iElem + offsetElem)
  DO iNode = 1, 8
    NonUniqueNodeID = ElemNodeID_Shared(iNode,TestElemID)
    UniqueNodeID = NodeInfo_Shared(NonUniqueNodeID)
    IsDepoNode(UniqueNodeID) = .TRUE.
  END DO
END DO
! Count the number of unique deposition nodes per processor
nDepoNodes = COUNT(IsDepoNode)
! Add number of nodes to be sent
nDepoNodesTotal = nDepoNodes
DO iNode=1, nUniqueGlobalNodes
  IF (.NOT.IsDepoNode(iNode).AND.SendNode(iNode)) THEN
    nDepoNodesTotal = nDepoNodesTotal + 1
  END IF
END DO
! Create mapping from unique deposition node to global unique node
ALLOCATE(DepoNodetoGlobalNode(1:nDepoNodesTotal))
nDepoNodesTotal = 0
DO iNode=1, nUniqueGlobalNodes
  IF (IsDepoNode(iNode)) THEN
    nDepoNodesTotal = nDepoNodesTotal + 1
    DepoNodetoGlobalNode(nDepoNodesTotal) = iNode
  END IF
END DO
DO iNode=1, nUniqueGlobalNodes
  IF (.NOT.IsDepoNode(iNode).AND.SendNode(iNode)) THEN
    nDepoNodesTotal = nDepoNodesTotal + 1
    DepoNodetoGlobalNode(nDepoNodesTotal) = iNode
  END IF
END DO
! Create mapping of exchange processor rank to global rank
GlobalRankToNodeSendDepoRank = -1
nNodeSendExchangeProcs = COUNT(DoNodeMapping)
ALLOCATE(NodeSendDepoRankToGlobalRank(1:nNodeSendExchangeProcs))
NodeSendDepoRankToGlobalRank = 0
nNodeSendExchangeProcs = 0
DO iRank= 0, nProcessors_Global-1
  IF (iRank.EQ.myRank) CYCLE
  IF (DoNodeMapping(iRank)) THEN
    nNodeSendExchangeProcs = nNodeSendExchangeProcs + 1
    GlobalRankToNodeSendDepoRank(iRank) = nNodeSendExchangeProcs
    NodeSendDepoRankToGlobalRank(nNodeSendExchangeProcs) = iRank
  END IF
END DO
! ALLOCATE(NodeDepoMapping(1:nNodeSendExchangeProcs, 1:nUniqueGlobalNodes))
! NodeDepoMapping = .FALSE.
ALLOCATE(ElemNodeDepoMap(1:nNodeSendExchangeProcs))
ElemNodeDepoMap(:)%firstNode = .TRUE.
ElemNodeDepoMap(:)%nNodes = 0

DO iNode = 1, nUniqueGlobalNodes
  IF (SendNode(iNode)) THEN
    ElemLoop: DO jElem = NodeToElemMapping(1,iNode) + 1, NodeToElemMapping(1,iNode) + NodeToElemMapping(2,iNode)
      TestElemID = GetGlobalElemID(NodeToElemInfo(jElem))
      GlobalElemRank = ElemInfo_Shared(ELEM_RANK,TestElemID)
      IF (GlobalElemRank.NE.myRank) THEN
        iRank = GlobalRankToNodeSendDepoRank(GlobalElemRank)
        IF (iRank.LT.1) CALL ABORT(__STAMP__,'Found not connected Rank!', myRank)
        ! NodeDepoMapping(iRank, iNode) = .TRUE.
        IF (ElemNodeDepoMap(iRank)%firstNode) THEN
          ElemNodeDepoMap(iRank)%firstNode = .FALSE.
          ElemNodeDepoMap(iRank)%nNodes = ElemNodeDepoMap(iRank)%nNodes + 1
          ALLOCATE(ElemNodeDepoMap(iRank)%first)
          ElemNodeDepoMap(iRank)%first%NodeID = iNode
        ELSE
          ! Check if node already exists
          node => ElemNodeDepoMap(iRank)%first
          DO testNode = 1, ElemNodeDepoMap(iRank)%nNodes
          IF (node%NodeID.EQ.iNode) CYCLE ElemLoop
          IF (.NOT.ASSOCIATED(node%next)) EXIT
          node => node%next
          END DO
          ! Add new node at the end of the list
          ALLOCATE(node%next)
          node%next%NodeID = iNode
          ElemNodeDepoMap(iRank)%nNodes = ElemNodeDepoMap(iRank)%nNodes + 1
        END IF
      END IF
    END DO ElemLoop
  END IF
END DO
! Get number of send nodes for each proc: Size of each message for each proc for deposition
nSendUniqueNodesNonSymDepo         = 0
nRecvUniqueNodesNonSymDepo(myrank) = 0
ALLOCATE(NodeMappingSend(1:nNodeSendExchangeProcs))
DO iProc = 1, nNodeSendExchangeProcs
  NodeMappingSend(iProc)%nSendUniqueNodes = 0
  ! DO iNode = 1, nUniqueGlobalNodes
  !   IF (NodeDepoMapping(iProc,iNode)) NodeMappingSend(iProc)%nSendUniqueNodes = NodeMappingSend(iProc)%nSendUniqueNodes + 1
  ! END DO
  NodeMappingSend(iProc)%nSendUniqueNodes =  ElemNodeDepoMap(iProc)%nNodes
  ! local to global array
  nSendUniqueNodesNonSymDepo(NodeSendDepoRankToGlobalRank(iProc)) = NodeMappingSend(iProc)%nSendUniqueNodes
END DO

! Open receive buffer for non-symmetric exchange identification
DO iProc = 0,nProcessors_Global-1
  IF (iProc.EQ.myRank) CYCLE
  CALL MPI_IRECV( nRecvUniqueNodesNonSymDepo(iProc)  &
    , 1                                              &
    , MPI_INTEGER                                    &
    , iProc                                          &
    , 2000                                           &
    , MPI_COMM_PICLAS                                &
    , RecvRequestNonSymDepo(iProc)                   &
    , IERROR)
END DO

! Send each proc the number of nodes that can be reached by deposition
DO iProc = 0,nProcessors_Global-1
  IF (iProc.EQ.myRank) CYCLE
  CALL MPI_ISEND( nSendUniqueNodesNonSymDepo(iProc) &
    , 1                                             &
    , MPI_INTEGER                                   &
    , iProc                                         &
    , 2000                                          &
    , MPI_COMM_PICLAS                               &
    , SendRequestNonSymDepo(iProc)                  &
    , IERROR)
END DO

! Finish communication
DO iProc = 0,nProcessors_Global-1
  IF (iProc.EQ.myRank) CYCLE
  CALL MPI_WAIT(RecvRequestNonSymDepo(iProc),MPI_STATUS_IGNORE,IERROR)
  IF(IERROR.NE.MPI_SUCCESS) CALL ABORT(__STAMP__,' MPI Communication error', IERROR)
  CALL MPI_WAIT(SendRequestNonSymDepo(iProc),MPI_STATUS_IGNORE,IERROR)
  IF(IERROR.NE.MPI_SUCCESS) CALL ABORT(__STAMP__,' MPI Communication error', IERROR)
END DO

nNodeRecvExchangeProcs = COUNT(nRecvUniqueNodesNonSymDepo.GT.0)
ALLOCATE(NodeMappingRecv(1:nNodeRecvExchangeProcs))
ALLOCATE(NodeRecvDepoRankToGlobalRank(1:nNodeRecvExchangeProcs))
NodeRecvDepoRankToGlobalRank = 0
nNodeRecvExchangeProcs = 0
DO iRank= 0, nProcessors_Global-1
  IF (iRank.EQ.myRank) CYCLE
  IF (nRecvUniqueNodesNonSymDepo(iRank).GT.0) THEN
    nNodeRecvExchangeProcs = nNodeRecvExchangeProcs + 1
    ! Store global rank of iRecvRank
    NodeRecvDepoRankToGlobalRank(nNodeRecvExchangeProcs) = iRank
    ! Store number of nodes of iRecvRank
    NodeMappingRecv(nNodeRecvExchangeProcs)%nRecvUniqueNodes = nRecvUniqueNodesNonSymDepo(iRank)
  END IF
END DO

! Open receive buffer
ALLOCATE(RecvRequest(1:nNodeRecvExchangeProcs))
DO iProc = 1, nNodeRecvExchangeProcs
  ALLOCATE(NodeMappingRecv(iProc)%RecvNodeUniqueGlobalID(1:NodeMappingRecv(iProc)%nRecvUniqueNodes))
  ALLOCATE(NodeMappingRecv(iProc)%RecvNodeSourceCharge(1:NodeMappingRecv(iProc)%nRecvUniqueNodes))
  ALLOCATE(NodeMappingRecv(iProc)%RecvNodeSourceCurrent(1:3,1:NodeMappingRecv(iProc)%nRecvUniqueNodes))
  IF(DoDielectricSurfaceCharge) ALLOCATE(NodeMappingRecv(iProc)%RecvNodeSourceExt(1:NodeMappingRecv(iProc)%nRecvUniqueNodes))
  CALL MPI_IRECV( NodeMappingRecv(iProc)%RecvNodeUniqueGlobalID &
    , NodeMappingRecv(iProc)%nRecvUniqueNodes                   &
    , MPI_INTEGER                                               &
    , NodeRecvDepoRankToGlobalRank(iProc)                       &
    , 666                                                       &
    , MPI_COMM_PICLAS                                           &
    , RecvRequest(iProc)                                        &
    , IERROR)
END DO

! Open send buffer
ALLOCATE(SendRequest(1:nNodeSendExchangeProcs))
DO iProc = 1, nNodeSendExchangeProcs
  ALLOCATE(NodeMappingSend(iProc)%SendNodeUniqueGlobalID(1:NodeMappingSend(iProc)%nSendUniqueNodes))
  NodeMappingSend(iProc)%SendNodeUniqueGlobalID=-1
  ALLOCATE(NodeMappingSend(iProc)%SendNodeSourceCharge(1:NodeMappingSend(iProc)%nSendUniqueNodes))
  NodeMappingSend(iProc)%SendNodeSourceCharge=0.
  ALLOCATE(NodeMappingSend(iProc)%SendNodeSourceCurrent(1:3,1:NodeMappingSend(iProc)%nSendUniqueNodes))
  NodeMappingSend(iProc)%SendNodeSourceCurrent=0.
  IF(DoDielectricSurfaceCharge) ALLOCATE(NodeMappingSend(iProc)%SendNodeSourceExt(1:NodeMappingSend(iProc)%nSendUniqueNodes))
  SendNodeCount = 0
  ! DO iNode = 1, nUniqueGlobalNodes
  !   IF (NodeDepoMapping(iProc,iNode)) THEN
  !     SendNodeCount = SendNodeCount + 1
  !     NodeMappingSend(iProc)%SendNodeUniqueGlobalID(SendNodeCount) = iNode
  !   END IF
  ! END DO
  ! ALLOCATE(node)
  ! node => ElemNodeDepoMap(iProc)%first
  ! DO testNode = 1, ElemNodeDepoMap(iProc)%nNodes
  !   SendNodeCount = SendNodeCount + 1
  !   NodeMappingSend(iProc)%SendNodeUniqueGlobalID(SendNodeCount) = node%NodeID
  !   node => node%next
  ! END DO

  ! First loop: Traverse the list and populate NodeMappingSend
  node => ElemNodeDepoMap(iProc)%first
  DO WHILE (ASSOCIATED(node))
    SendNodeCount = SendNodeCount + 1
    NodeMappingSend(iProc)%SendNodeUniqueGlobalID(SendNodeCount) = node%NodeID
    node => node%next
  END DO

  ! node => ElemNodeDepoMap(iProc)%first
  ! DO testNode = 1, ElemNodeDepoMap(iProc)%nNodes
  !   ElemNodeDepoMap(iProc)%first => ElemNodeDepoMap(iProc)%first%next
  !   DEALLOCATE(node)
  !   node => ElemNodeDepoMap(iProc)%first
  ! END DO
  ! IF(ASSOCIATED(ElemNodeDepoMap(iProc)%first)) THEN
  !   DEALLOCATE(ElemNodeDepoMap(iProc)%first)
  ! END IF
  ! IF(ASSOCIATED(node)) THEN
  !   DEALLOCATE(node)
  ! END IF

  ! Deallocate the list
  CALL DeallocateNodeList(ElemNodeDepoMap(iProc)%first)
  NULLIFY(ElemNodeDepoMap(iProc)%first)
  ElemNodeDepoMap(iProc)%nNodes = 0

  CALL MPI_ISEND( NodeMappingSend(iProc)%SendNodeUniqueGlobalID                   &
    , NodeMappingSend(iProc)%nSendUniqueNodes                         &
    , MPI_INTEGER                                                 &
    , NodeSendDepoRankToGlobalRank(iProc)                         &
    , 666                                                         &
    , MPI_COMM_PICLAS                                              &
    , SendRequest(iProc)                                          &
    , IERROR)
END DO

! Finish send
DO iProc = 1, nNodeSendExchangeProcs
  CALL MPI_WAIT(SendRequest(iProc),MPI_STATUS_IGNORE,IERROR)
  IF (IERROR.NE.MPI_SUCCESS) CALL ABORT(__STAMP__,' MPI Communication error', IERROR)
END DO

! Finish receive
DO iProc = 1, nNodeRecvExchangeProcs
  CALL MPI_WAIT(RecvRequest(iProc),MPI_STATUS_IGNORE,IERROR)
  IF (IERROR.NE.MPI_SUCCESS) CALL ABORT(__STAMP__,' MPI Communication error', IERROR)
END DO

END SUBROUTINE InitDepoNodesMPI


!===================================================================================================================================
!> Initialize the MPI communication for the 2D surface node deposition
!===================================================================================================================================
SUBROUTINE InitDepoSurfNodesMPI()
! MODULES
USE MOD_Preproc
USE MOD_Globals
USE MOD_PICDepo_Vars
USE MOD_Dielectric_Vars        ,ONLY: DoDielectricSurfaceCharge
USE MOD_Mesh_Vars              ,ONLY: nElems
USE MOD_Particle_Mesh_Vars     ,ONLY: nUniqueGlobalNodes
USE MOD_Mesh_Tools             ,ONLY: GetGlobalElemID, GetCNElemID
USE MOD_Mesh_Vars              ,ONLY: offsetElem,ELEM_RANK
USE MOD_Particle_Mesh_Vars     ,ONLY: NodeToElemInfo,NodeToElemMapping,ElemNodeID_Shared,NodeInfo_Shared
USE MOD_MPI_Shared_Vars        ,ONLY: nComputeNodeTotalElems
USE MOD_MPI_Shared_Vars        ,ONLY: nProcessors_Global
USE MOD_Particle_Mesh_Vars     ,ONLY: ElemInfo_Shared
! IMPLICIT VARIABLE HANDLING
IMPLICIT NONE
!-----------------------------------------------------------------------------------------------------------------------------------
! INPUT VARIABLES
LOGICAL :: DoNodeMapping(0:nProcessors_Global-1)
LOGICAL :: SendNode(1:nUniqueGlobalNodes)
!-----------------------------------------------------------------------------------------------------------------------------------
! OUTPUT VARIABLES
!-----------------------------------------------------------------------------------------------------------------------------------
! LOCAL VARIABLES
INTEGER                   :: iElem, iNode
INTEGER                   :: UniqueNodeID, testNode
INTEGER                   :: GlobalRankToNodeSendDepoRank(0:nProcessors_Global-1)
INTEGER                   :: jElem,TestElemID
INTEGER                   :: NonUniqueNodeID
INTEGER                   :: SendNodeCount, GlobalElemRank, iProc
INTEGER                   :: GlobalElemRankOrig, iRank
LOGICAL,ALLOCATABLE       :: IsDepoNode(:)
LOGICAL                   :: bordersMyrank
! Non-symmetric particle exchange
TYPE(MPI_Request)         :: SendRequestNonSymDepo(0:nProcessors_Global-1)      , RecvRequestNonSymDepo(0:nProcessors_Global-1)
INTEGER                   :: nSendUniqueNodesNonSymDepo(0:nProcessors_Global-1) , nRecvUniqueNodesNonSymDepo(0:nProcessors_Global-1)
TYPE tElemNodeDepoMap
  TYPE (NodeDepoMapping), POINTER :: first => NULL()
  LOGICAL               :: firstNode
  INTEGER               :: nNodes
END TYPE
TYPE(tElemNodeDepoMap), ALLOCATABLE :: ElemNodeDepoMap(:)
TYPE (NodeDepoMapping), POINTER :: node
!===================================================================================================================================



CALL abort(__STAMP__,' not implemented', IERROR)







ALLOCATE(SurfNodeSourceMPI(1:nDepoSurfNodesTotal))
NodeSourceExtMPI = 0.

! Loop over the elements of the complete compute-node region (including the halo region)
DO iElem = 1,nComputeNodeTotalElems
  IF (FlagShapeElem(iElem)) THEN
    bordersMyrank = .FALSE.
    ! Loop all local nodes
    TestElemID = GetGlobalElemID(iElem)
    GlobalElemRankOrig = ElemInfo_Shared(ELEM_RANK,TestElemID)
    IF (DoHaloDepo.AND.(GlobalElemRankOrig.NE.myRank)) DoNodeMapping(GlobalElemRankOrig) = .TRUE.

    DO iNode = 1, 8
    NonUniqueNodeID = ElemNodeID_Shared(iNode,iElem)
    UniqueNodeID = NodeInfo_Shared(NonUniqueNodeID)
    ! Loop 1D array [offset + 1 : offset + NbrOfElems]
    ! (all CN elements that are connected to the local nodes)
    DO jElem = NodeToElemMapping(1,UniqueNodeID) + 1, NodeToElemMapping(1,UniqueNodeID) + NodeToElemMapping(2,UniqueNodeID)
      TestElemID = GetGlobalElemID(NodeToElemInfo(jElem))
      GlobalElemRank = ElemInfo_Shared(ELEM_RANK,TestElemID)
      IF (DoHaloDepo) THEN
        SendNode(UniqueNodeID) = .TRUE.
        IF (GlobalElemRank.NE.myRank) DoNodeMapping(GlobalElemRank) = .TRUE.
      ELSE
        IF (GlobalElemRank.EQ.myRank) THEN
          bordersMyrank = .TRUE.
          SendNode(UniqueNodeID) = .TRUE.
        END IF
      END IF
    END DO
    IF (.NOT.DoHaloDepo.AND.bordersMyrank) THEN
      DoNodeMapping(GlobalElemRankOrig) = .TRUE.
    END IF
    END DO
  END IF
END DO

! Flag the unique deposition nodes per processor
nDepoNodes = 0
ALLOCATE(IsDepoNode(1:nUniqueGlobalNodes))
IsDepoNode = .FALSE.
DO iElem =1, nElems
  TestElemID = GetCNElemID(iElem + offsetElem)
  DO iNode = 1, 8
    NonUniqueNodeID = ElemNodeID_Shared(iNode,TestElemID)
    UniqueNodeID = NodeInfo_Shared(NonUniqueNodeID)
    IsDepoNode(UniqueNodeID) = .TRUE.
  END DO
END DO
! Count the number of unique deposition nodes per processor
nDepoNodes = COUNT(IsDepoNode)
! Add number of nodes to be sent
nDepoNodesTotal = nDepoNodes
DO iNode=1, nUniqueGlobalNodes
  IF (.NOT.IsDepoNode(iNode).AND.SendNode(iNode)) THEN
    nDepoNodesTotal = nDepoNodesTotal + 1
  END IF
END DO
! Create mapping from unique deposition node to global unique node
ALLOCATE(DepoNodetoGlobalNode(1:nDepoNodesTotal))
nDepoNodesTotal = 0
DO iNode=1, nUniqueGlobalNodes
  IF (IsDepoNode(iNode)) THEN
    nDepoNodesTotal = nDepoNodesTotal + 1
    DepoNodetoGlobalNode(nDepoNodesTotal) = iNode
  END IF
END DO
DO iNode=1, nUniqueGlobalNodes
  IF (.NOT.IsDepoNode(iNode).AND.SendNode(iNode)) THEN
    nDepoNodesTotal = nDepoNodesTotal + 1
    DepoNodetoGlobalNode(nDepoNodesTotal) = iNode
  END IF
END DO
! Create mapping of exchange processor rank to global rank
GlobalRankToNodeSendDepoRank = -1
nNodeSendExchangeProcs = COUNT(DoNodeMapping)
ALLOCATE(NodeSendDepoRankToGlobalRank(1:nNodeSendExchangeProcs))
NodeSendDepoRankToGlobalRank = 0
nNodeSendExchangeProcs = 0
DO iRank= 0, nProcessors_Global-1
  IF (iRank.EQ.myRank) CYCLE
  IF (DoNodeMapping(iRank)) THEN
    nNodeSendExchangeProcs = nNodeSendExchangeProcs + 1
    GlobalRankToNodeSendDepoRank(iRank) = nNodeSendExchangeProcs
    NodeSendDepoRankToGlobalRank(nNodeSendExchangeProcs) = iRank
  END IF
END DO
! ALLOCATE(NodeDepoMapping(1:nNodeSendExchangeProcs, 1:nUniqueGlobalNodes))
! NodeDepoMapping = .FALSE.
ALLOCATE(ElemNodeDepoMap(1:nNodeSendExchangeProcs))
ElemNodeDepoMap(:)%firstNode = .TRUE.
ElemNodeDepoMap(:)%nNodes = 0

DO iNode = 1, nUniqueGlobalNodes
  IF (SendNode(iNode)) THEN
    ElemLoop: DO jElem = NodeToElemMapping(1,iNode) + 1, NodeToElemMapping(1,iNode) + NodeToElemMapping(2,iNode)
      TestElemID = GetGlobalElemID(NodeToElemInfo(jElem))
      GlobalElemRank = ElemInfo_Shared(ELEM_RANK,TestElemID)
      IF (GlobalElemRank.NE.myRank) THEN
        iRank = GlobalRankToNodeSendDepoRank(GlobalElemRank)
        IF (iRank.LT.1) CALL ABORT(__STAMP__,'Found not connected Rank!', myRank)
        ! NodeDepoMapping(iRank, iNode) = .TRUE.
        IF (ElemNodeDepoMap(iRank)%firstNode) THEN
          ElemNodeDepoMap(iRank)%firstNode = .FALSE.
          ElemNodeDepoMap(iRank)%nNodes = ElemNodeDepoMap(iRank)%nNodes + 1
          ALLOCATE(ElemNodeDepoMap(iRank)%first)
          ElemNodeDepoMap(iRank)%first%NodeID = iNode
        ELSE
          ! Check if node already exists
          node => ElemNodeDepoMap(iRank)%first
          DO testNode = 1, ElemNodeDepoMap(iRank)%nNodes
          IF (node%NodeID.EQ.iNode) CYCLE ElemLoop
          IF (.NOT.ASSOCIATED(node%next)) EXIT
          node => node%next
          END DO
          ! Add new node at the end of the list
          ALLOCATE(node%next)
          node%next%NodeID = iNode
          ElemNodeDepoMap(iRank)%nNodes = ElemNodeDepoMap(iRank)%nNodes + 1
        END IF
      END IF
    END DO ElemLoop
  END IF
END DO
! Get number of send nodes for each proc: Size of each message for each proc for deposition
nSendUniqueNodesNonSymDepo         = 0
nRecvUniqueNodesNonSymDepo(myrank) = 0
ALLOCATE(NodeMappingSend(1:nNodeSendExchangeProcs))
DO iProc = 1, nNodeSendExchangeProcs
  NodeMappingSend(iProc)%nSendUniqueNodes = 0
  ! DO iNode = 1, nUniqueGlobalNodes
  !   IF (NodeDepoMapping(iProc,iNode)) NodeMappingSend(iProc)%nSendUniqueNodes = NodeMappingSend(iProc)%nSendUniqueNodes + 1
  ! END DO
  NodeMappingSend(iProc)%nSendUniqueNodes =  ElemNodeDepoMap(iProc)%nNodes
  ! local to global array
  nSendUniqueNodesNonSymDepo(NodeSendDepoRankToGlobalRank(iProc)) = NodeMappingSend(iProc)%nSendUniqueNodes
END DO

! Open receive buffer for non-symmetric exchange identification
DO iProc = 0,nProcessors_Global-1
  IF (iProc.EQ.myRank) CYCLE
  CALL MPI_IRECV( nRecvUniqueNodesNonSymDepo(iProc)  &
    , 1                                              &
    , MPI_INTEGER                                    &
    , iProc                                          &
    , 2000                                           &
    , MPI_COMM_PICLAS                                &
    , RecvRequestNonSymDepo(iProc)                   &
    , IERROR)
END DO

! Send each proc the number of nodes that can be reached by deposition
DO iProc = 0,nProcessors_Global-1
  IF (iProc.EQ.myRank) CYCLE
  CALL MPI_ISEND( nSendUniqueNodesNonSymDepo(iProc) &
    , 1                                             &
    , MPI_INTEGER                                   &
    , iProc                                         &
    , 2000                                          &
    , MPI_COMM_PICLAS                               &
    , SendRequestNonSymDepo(iProc)                  &
    , IERROR)
END DO

! Finish communication
DO iProc = 0,nProcessors_Global-1
  IF (iProc.EQ.myRank) CYCLE
  CALL MPI_WAIT(RecvRequestNonSymDepo(iProc),MPI_STATUS_IGNORE,IERROR)
  IF(IERROR.NE.MPI_SUCCESS) CALL ABORT(__STAMP__,' MPI Communication error', IERROR)
  CALL MPI_WAIT(SendRequestNonSymDepo(iProc),MPI_STATUS_IGNORE,IERROR)
  IF(IERROR.NE.MPI_SUCCESS) CALL ABORT(__STAMP__,' MPI Communication error', IERROR)
END DO

nNodeRecvExchangeProcs = COUNT(nRecvUniqueNodesNonSymDepo.GT.0)
ALLOCATE(NodeMappingRecv(1:nNodeRecvExchangeProcs))
ALLOCATE(NodeRecvDepoRankToGlobalRank(1:nNodeRecvExchangeProcs))
NodeRecvDepoRankToGlobalRank = 0
nNodeRecvExchangeProcs = 0
DO iRank= 0, nProcessors_Global-1
  IF (iRank.EQ.myRank) CYCLE
  IF (nRecvUniqueNodesNonSymDepo(iRank).GT.0) THEN
    nNodeRecvExchangeProcs = nNodeRecvExchangeProcs + 1
    ! Store global rank of iRecvRank
    NodeRecvDepoRankToGlobalRank(nNodeRecvExchangeProcs) = iRank
    ! Store number of nodes of iRecvRank
    NodeMappingRecv(nNodeRecvExchangeProcs)%nRecvUniqueNodes = nRecvUniqueNodesNonSymDepo(iRank)
  END IF
END DO

! Open receive buffer
ALLOCATE(RecvRequest(1:nNodeRecvExchangeProcs))
DO iProc = 1, nNodeRecvExchangeProcs
  ALLOCATE(NodeMappingRecv(iProc)%RecvNodeUniqueGlobalID(1:NodeMappingRecv(iProc)%nRecvUniqueNodes))
  ALLOCATE(NodeMappingRecv(iProc)%RecvNodeSourceCharge(1:NodeMappingRecv(iProc)%nRecvUniqueNodes))
  ALLOCATE(NodeMappingRecv(iProc)%RecvNodeSourceCurrent(1:3,1:NodeMappingRecv(iProc)%nRecvUniqueNodes))
  IF(DoDielectricSurfaceCharge) ALLOCATE(NodeMappingRecv(iProc)%RecvNodeSourceExt(1:NodeMappingRecv(iProc)%nRecvUniqueNodes))
  CALL MPI_IRECV( NodeMappingRecv(iProc)%RecvNodeUniqueGlobalID &
    , NodeMappingRecv(iProc)%nRecvUniqueNodes                   &
    , MPI_INTEGER                                               &
    , NodeRecvDepoRankToGlobalRank(iProc)                       &
    , 666                                                       &
    , MPI_COMM_PICLAS                                           &
    , RecvRequest(iProc)                                        &
    , IERROR)
END DO

! Open send buffer
ALLOCATE(SendRequest(1:nNodeSendExchangeProcs))
DO iProc = 1, nNodeSendExchangeProcs
  ALLOCATE(NodeMappingSend(iProc)%SendNodeUniqueGlobalID(1:NodeMappingSend(iProc)%nSendUniqueNodes))
  NodeMappingSend(iProc)%SendNodeUniqueGlobalID=-1
  ALLOCATE(NodeMappingSend(iProc)%SendNodeSourceCharge(1:NodeMappingSend(iProc)%nSendUniqueNodes))
  NodeMappingSend(iProc)%SendNodeSourceCharge=0.
  ALLOCATE(NodeMappingSend(iProc)%SendNodeSourceCurrent(1:3,1:NodeMappingSend(iProc)%nSendUniqueNodes))
  NodeMappingSend(iProc)%SendNodeSourceCurrent=0.
  IF(DoDielectricSurfaceCharge) ALLOCATE(NodeMappingSend(iProc)%SendNodeSourceExt(1:NodeMappingSend(iProc)%nSendUniqueNodes))
  SendNodeCount = 0
  ! DO iNode = 1, nUniqueGlobalNodes
  !   IF (NodeDepoMapping(iProc,iNode)) THEN
  !     SendNodeCount = SendNodeCount + 1
  !     NodeMappingSend(iProc)%SendNodeUniqueGlobalID(SendNodeCount) = iNode
  !   END IF
  ! END DO
  ! ALLOCATE(node)
  ! node => ElemNodeDepoMap(iProc)%first
  ! DO testNode = 1, ElemNodeDepoMap(iProc)%nNodes
  !   SendNodeCount = SendNodeCount + 1
  !   NodeMappingSend(iProc)%SendNodeUniqueGlobalID(SendNodeCount) = node%NodeID
  !   node => node%next
  ! END DO

  ! First loop: Traverse the list and populate NodeMappingSend
  node => ElemNodeDepoMap(iProc)%first
  DO WHILE (ASSOCIATED(node))
    SendNodeCount = SendNodeCount + 1
    NodeMappingSend(iProc)%SendNodeUniqueGlobalID(SendNodeCount) = node%NodeID
    node => node%next
  END DO

  ! node => ElemNodeDepoMap(iProc)%first
  ! DO testNode = 1, ElemNodeDepoMap(iProc)%nNodes
  !   ElemNodeDepoMap(iProc)%first => ElemNodeDepoMap(iProc)%first%next
  !   DEALLOCATE(node)
  !   node => ElemNodeDepoMap(iProc)%first
  ! END DO
  ! IF(ASSOCIATED(ElemNodeDepoMap(iProc)%first)) THEN
  !   DEALLOCATE(ElemNodeDepoMap(iProc)%first)
  ! END IF
  ! IF(ASSOCIATED(node)) THEN
  !   DEALLOCATE(node)
  ! END IF

  ! Deallocate the list
  CALL DeallocateNodeList(ElemNodeDepoMap(iProc)%first)
  NULLIFY(ElemNodeDepoMap(iProc)%first)
  ElemNodeDepoMap(iProc)%nNodes = 0

  CALL MPI_ISEND( NodeMappingSend(iProc)%SendNodeUniqueGlobalID                   &
    , NodeMappingSend(iProc)%nSendUniqueNodes                         &
    , MPI_INTEGER                                                 &
    , NodeSendDepoRankToGlobalRank(iProc)                         &
    , 666                                                         &
    , MPI_COMM_PICLAS                                              &
    , SendRequest(iProc)                                          &
    , IERROR)
END DO

! Finish send
DO iProc = 1, nNodeSendExchangeProcs
  CALL MPI_WAIT(SendRequest(iProc),MPI_STATUS_IGNORE,IERROR)
  IF (IERROR.NE.MPI_SUCCESS) CALL ABORT(__STAMP__,' MPI Communication error', IERROR)
END DO

! Finish receive
DO iProc = 1, nNodeRecvExchangeProcs
  CALL MPI_WAIT(RecvRequest(iProc),MPI_STATUS_IGNORE,IERROR)
  IF (IERROR.NE.MPI_SUCCESS) CALL ABORT(__STAMP__,' MPI Communication error', IERROR)
END DO

END SUBROUTINE InitDepoSurfNodesMPI


RECURSIVE SUBROUTINE DeallocateNodeList(node)
!-----------------------------------------------------------------------------------------------------------------------------------
! LOCAL VARIABLES
TYPE(NodeDepoMapping), POINTER    :: node
!===================================================================================================================================

IF (ASSOCIATED(node)) THEN
  CALL DeallocateNodeList(node%next)
  DEALLOCATE(node)
END IF

END SUBROUTINE DeallocateNodeList


!===================================================================================================================================
!> Exchange the node source container between MPI processes
!===================================================================================================================================
SUBROUTINE ExchangeNodeSource(SourceDim,doCalculateCurrentDensity)
! MODULES
USE MOD_Globals
USE MOD_PreProc
USE MOD_PICDepo_Vars ,ONLY: NodeSource
USE MOD_PICDepo_Vars ,ONLY: NodeMappingRecv,NodeMappingSend
USE MOD_PICDepo_Vars ,ONLY: nNodeSendExchangeProcs,NodeSendDepoRankToGlobalRank
USE MOD_PICDepo_Vars ,ONLY: nNodeRecvExchangeProcs
USE MOD_PICDepo_Vars ,ONLY: NodeRecvDepoRankToGlobalRank
USE MOD_PICDepo_Vars ,ONLY: NodeMappingSend,NodeMappingRecv, nNodeSendExchangeProcs, NodeSendDepoRankToGlobalRank
USE MOD_PICDepo_Vars ,ONLY: nNodeRecvExchangeProcs,NodeRecvDepoRankToGlobalRank
#if defined(MEASURE_MPI_WAIT)
USE MOD_Particle_MPI_Vars  ,ONLY: MPIW8TimePart,MPIW8CountPart
#endif /*defined(MEASURE_MPI_WAIT)*/
! IMPLICIT VARIABLE HANDLING
IMPLICIT NONE
!-----------------------------------------------------------------------------------------------------------------------------------
! INPUT/OUTPUT VARIABLES
INTEGER, INTENT(IN) :: SourceDim
LOGICAL, INTENT(IN) :: doCalculateCurrentDensity
!-----------------------------------------------------------------------------------------------------------------------------------
! LOCAL VARIABLES
INTEGER           :: iProc
TYPE(MPI_Request) :: RecvRequest(1:nNodeRecvExchangeProcs),SendRequest(1:nNodeSendExchangeProcs)
INTEGER           :: iNode
#if defined(MEASURE_MPI_WAIT)
INTEGER(KIND=8)   :: CounterStart,CounterEnd
REAL(KIND=8)      :: Rate
#endif /*defined(MEASURE_MPI_WAIT)*/
!===================================================================================================================================
! 1.1) Receive charge density
DO iProc = 1, nNodeRecvExchangeProcs
  ! Open receive buffer
  CALL MPI_IRECV( NodeMappingRecv(iProc)%RecvNodeSourceCharge(:) &
            , NodeMappingRecv(iProc)%nRecvUniqueNodes            &
            , MPI_DOUBLE_PRECISION                               &
            , NodeRecvDepoRankToGlobalRank(iProc)                &
            , 666                                                &
            , MPI_COMM_PICLAS                                    &
            , RecvRequest(iProc)                                 &
            , IERROR)
END DO

! 1.2) Send charge density
DO iProc = 1, nNodeSendExchangeProcs
  ! Send message (non-blocking)
  DO iNode = 1, NodeMappingSend(iProc)%nSendUniqueNodes
    NodeMappingSend(iProc)%SendNodeSourceCharge(iNode) = NodeSource(4,NodeMappingSend(iProc)%SendNodeUniqueGlobalID(iNode))
  END DO
  CALL MPI_ISEND( NodeMappingSend(iProc)%SendNodeSourceCharge(:) &
                , NodeMappingSend(iProc)%nSendUniqueNodes        &
                , MPI_DOUBLE_PRECISION                           &
                , NodeSendDepoRankToGlobalRank(iProc)            &
                , 666                                            &
                , MPI_COMM_PICLAS                                &
                , SendRequest(iProc)                             &
                , IERROR)
END DO

! Finish communication
#if defined(MEASURE_MPI_WAIT)
CALL SYSTEM_CLOCK(count=CounterStart)
#endif /*defined(MEASURE_MPI_WAIT)*/
DO iProc = 1, nNodeSendExchangeProcs
  CALL MPI_WAIT(SendRequest(iProc),MPI_STATUS_IGNORE,IERROR)
  IF (IERROR.NE.MPI_SUCCESS) CALL ABORT(__STAMP__,' MPI Communication error', IERROR)
END DO
DO iProc = 1, nNodeRecvExchangeProcs
  CALL MPI_WAIT(RecvRequest(iProc),MPI_STATUS_IGNORE,IERROR)
  IF (IERROR.NE.MPI_SUCCESS) CALL ABORT(__STAMP__,' MPI Communication error', IERROR)
END DO
#if defined(MEASURE_MPI_WAIT)
CALL SYSTEM_CLOCK(count=CounterEnd, count_rate=Rate)
MPIW8TimePart(6)  = MPIW8TimePart(6) + REAL(CounterEnd-CounterStart,8)/Rate
MPIW8CountPart(6) = MPIW8CountPart(6) + 1_8
#endif /*defined(MEASURE_MPI_WAIT)*/

! 2) Send/Receive current density
IF(doCalculateCurrentDensity)THEN
  DO iProc = 1, nNodeRecvExchangeProcs
    ! Open receive buffer
    CALL MPI_IRECV( NodeMappingRecv(iProc)%RecvNodeSourceCurrent(1:3,:) &
        , 3*NodeMappingRecv(iProc)%nRecvUniqueNodes                     &
        , MPI_DOUBLE_PRECISION                                          &
        , NodeRecvDepoRankToGlobalRank(iProc)                           &
        , 666                                                           &
        , MPI_COMM_PICLAS                                               &
        , RecvRequest(iProc)                                            &
        , IERROR)
  END DO

  DO iProc = 1, nNodeSendExchangeProcs
    ! Send message (non-blocking)
    DO iNode = 1, NodeMappingSend(iProc)%nSendUniqueNodes
      NodeMappingSend(iProc)%SendNodeSourceCurrent(1:3,iNode) = NodeSource(1:3,NodeMappingSend(iProc)%SendNodeUniqueGlobalID(iNode))
    END DO
    CALL MPI_ISEND( NodeMappingSend(iProc)%SendNodeSourceCurrent(1:3,:) &
        , 3*NodeMappingSend(iProc)%nSendUniqueNodes                     &
        , MPI_DOUBLE_PRECISION                                          &
        , NodeSendDepoRankToGlobalRank(iProc)                           &
        , 666                                                           &
        , MPI_COMM_PICLAS                                               &
        , SendRequest(iProc)                                            &
        , IERROR)
  END DO

  ! Finish communication
#if defined(MEASURE_MPI_WAIT)
  CALL SYSTEM_CLOCK(count=CounterStart)
#endif /*defined(MEASURE_MPI_WAIT)*/
  DO iProc = 1, nNodeSendExchangeProcs
    CALL MPI_WAIT(SendRequest(iProc),MPI_STATUS_IGNORE,IERROR)
    IF (IERROR.NE.MPI_SUCCESS) CALL ABORT(__STAMP__,' MPI Communication error', IERROR)
  END DO
  DO iProc = 1, nNodeRecvExchangeProcs
    CALL MPI_WAIT(RecvRequest(iProc),MPI_STATUS_IGNORE,IERROR)
    IF (IERROR.NE.MPI_SUCCESS) CALL ABORT(__STAMP__,' MPI Communication error', IERROR)
  END DO
#if defined(MEASURE_MPI_WAIT)
  CALL SYSTEM_CLOCK(count=CounterEnd, count_rate=Rate)
  MPIW8TimePart(6)  = MPIW8TimePart(6) + REAL(CounterEnd-CounterStart,8)/Rate
  MPIW8CountPart(6) = MPIW8CountPart(6) + 1_8
#endif /*defined(MEASURE_MPI_WAIT)*/

  ! 3) Extract messages
  DO iProc = 1, nNodeRecvExchangeProcs
    DO iNode = 1, NodeMappingRecv(iProc)%nRecvUniqueNodes
      ASSOCIATE( NS => NodeSource(SourceDim:4,NodeMappingRecv(iProc)%RecvNodeUniqueGlobalID(iNode)))
        NS = NS + (/NodeMappingRecv(iProc)%RecvNodeSourceCurrent(1:3,iNode), NodeMappingRecv(iProc)%RecvNodeSourceCharge(iNode)/)
      END ASSOCIATE
    END DO
  END DO
ELSE ! Only the charge density is communicated
  DO iProc = 1, nNodeRecvExchangeProcs
    DO iNode = 1, NodeMappingRecv(iProc)%nRecvUniqueNodes
      ASSOCIATE( NS => NodeSource(4,NodeMappingRecv(iProc)%RecvNodeUniqueGlobalID(iNode)))
        NS = NS + NodeMappingRecv(iProc)%RecvNodeSourceCharge(iNode)
      END ASSOCIATE
    END DO
  END DO
END IF ! doCalculateCurrentDensity
END SUBROUTINE ExchangeNodeSource


!===================================================================================================================================
!> Exchange the node source container between MPI processes (either during load balance or hdf5 output) and nullify the local charge
!> container NodeSourceExtMPI. Updates the node charge container NodeSourceExt at MPI interfaces.
!===================================================================================================================================
SUBROUTINE ExchangeNodeSourceExtMPI()
! MODULES
USE MOD_Globals
USE MOD_PreProc
USE MOD_PICDepo_Vars       ,ONLY: NodeSourceExt
#if USE_MPI
USE MOD_PICDepo_Vars       ,ONLY: NodeMappingRecv,NodeMappingSend,NodeSourceExtMPI
USE MOD_PICDepo_Vars       ,ONLY: nDepoNodesTotal,nNodeSendExchangeProcs,NodeSendDepoRankToGlobalRank,DepoNodetoGlobalNode
USE MOD_PICDepo_Vars       ,ONLY: nNodeRecvExchangeProcs
USE MOD_PICDepo_Vars       ,ONLY: NodeRecvDepoRankToGlobalRank
#endif  /*USE_MPI*/
#if defined(MEASURE_MPI_WAIT)
USE MOD_Particle_MPI_Vars  ,ONLY: MPIW8TimePart,MPIW8CountPart
#endif /*defined(MEASURE_MPI_WAIT)*/
! IMPLICIT VARIABLE HANDLING
IMPLICIT NONE
!-----------------------------------------------------------------------------------------------------------------------------------
! INPUT/OUTPUT VARIABLES
!-----------------------------------------------------------------------------------------------------------------------------------
! LOCAL VARIABLES
#if USE_MPI
INTEGER                        :: iProc
TYPE(MPI_Request)              :: RecvRequest(1:nNodeRecvExchangeProcs),SendRequest(1:nNodeSendExchangeProcs)
#endif /*USE_MPI*/
INTEGER                        :: globalNode, iNode
#if defined(MEASURE_MPI_WAIT)
INTEGER(KIND=8)                :: CounterStart,CounterEnd
REAL(KIND=8)                   :: Rate
#endif /*defined(MEASURE_MPI_WAIT)*/
!===================================================================================================================================
! 1) Receive charge density
DO iProc = 1, nNodeRecvExchangeProcs
  ! Open receive buffer
  CALL MPI_IRECV( NodeMappingRecv(iProc)%RecvNodeSourceExt(:) &
      , NodeMappingRecv(iProc)%nRecvUniqueNodes               &
      , MPI_DOUBLE_PRECISION                                  &
      , NodeRecvDepoRankToGlobalRank(iProc)                   &
      , 666                                                   &
      , MPI_COMM_PICLAS                                       &
      , RecvRequest(iProc)                                    &
      , IERROR)
END DO

DO iProc = 1, nNodeSendExchangeProcs
  ! Send message (non-blocking)
  DO iNode = 1, NodeMappingSend(iProc)%nSendUniqueNodes
    NodeMappingSend(iProc)%SendNodeSourceExt(iNode) = NodeSourceExtMPI(NodeMappingSend(iProc)%SendNodeUniqueGlobalID(iNode))
  END DO
  CALL MPI_ISEND( NodeMappingSend(iProc)%SendNodeSourceExt(:) &
      , NodeMappingSend(iProc)%nSendUniqueNodes               &
      , MPI_DOUBLE_PRECISION                                  &
      , NodeSendDepoRankToGlobalRank(iProc)                   &
      , 666                                                   &
      , MPI_COMM_PICLAS                                       &
      , SendRequest(iProc)                                    &
      , IERROR)
END DO
! Finish communication
#if defined(MEASURE_MPI_WAIT)
CALL SYSTEM_CLOCK(count=CounterStart)
#endif /*defined(MEASURE_MPI_WAIT)*/
DO iProc = 1, nNodeSendExchangeProcs
  CALL MPI_WAIT(SendRequest(iProc),MPI_STATUS_IGNORE,IERROR)
  IF (IERROR.NE.MPI_SUCCESS) CALL ABORT(__STAMP__,' MPI Communication error', IERROR)
END DO
DO iProc = 1, nNodeRecvExchangeProcs
  CALL MPI_WAIT(RecvRequest(iProc),MPI_STATUS_IGNORE,IERROR)
  IF (IERROR.NE.MPI_SUCCESS) CALL ABORT(__STAMP__,' MPI Communication error', IERROR)
END DO
#if defined(MEASURE_MPI_WAIT)
CALL SYSTEM_CLOCK(count=CounterEnd, count_rate=Rate)
MPIW8TimePart(6)  = MPIW8TimePart(6) + REAL(CounterEnd-CounterStart,8)/Rate
MPIW8CountPart(6) = MPIW8CountPart(6) + 1_8
#endif /*defined(MEASURE_MPI_WAIT)*/

! 3) Extract messages
DO iProc = 1, nNodeRecvExchangeProcs
  DO iNode = 1, NodeMappingRecv(iProc)%nRecvUniqueNodes
    ASSOCIATE( NS => NodeSourceExtMPI(NodeMappingRecv(iProc)%RecvNodeUniqueGlobalID(iNode)))
      NS = NS + NodeMappingRecv(iProc)%RecvNodeSourceExt(iNode)
    END ASSOCIATE
  END DO
END DO

! Add NodeSourceExtMPI values of the last boundary interaction
DO iNode = 1, nDepoNodesTotal
  globalNode = DepoNodetoGlobalNode(iNode)
  NodeSourceExt(globalNode) = NodeSourceExt(globalNode) + NodeSourceExtMPI(globalNode)
END DO
! Reset local surface charge
NodeSourceExtMPI = 0.
END SUBROUTINE ExchangeNodeSourceExtMPI


!===================================================================================================================================
!> Exchange the node source container between MPI processes (either during load balance or hdf5 output) and nullify the local charge
!> container SurfNodeSourceMPI. Updates the node charge container SurfNodeSource at MPI interfaces.
!===================================================================================================================================
SUBROUTINE ExchangeSurfNodeSourceMPI()
! MODULES
USE MOD_Globals
USE MOD_PreProc
USE MOD_PICDepo_Vars       ,ONLY: SurfNodeSource
#if USE_MPI
USE MOD_PICDepo_Vars       ,ONLY: SurfNodeMappingRecv,SurfNodeMappingSend,SurfNodeSourceMPI
USE MOD_PICDepo_Vars       ,ONLY: nDepoSurfNodesTotal,nSurfNodeSendExchangeProcs,SurfNodeSendDepoRankToGlobalRank
USE MOD_PICDepo_Vars       ,ONLY: DepoSurfNodetoGlobalNode
USE MOD_PICDepo_Vars       ,ONLY: nSurfNodeRecvExchangeProcs
USE MOD_PICDepo_Vars       ,ONLY: SurfNodeRecvDepoRankToGlobalRank
#endif  /*USE_MPI*/
#if defined(MEASURE_MPI_WAIT)
USE MOD_Particle_MPI_Vars  ,ONLY: MPIW8TimePart,MPIW8CountPart
#endif /*defined(MEASURE_MPI_WAIT)*/
! IMPLICIT VARIABLE HANDLING
IMPLICIT NONE
!-----------------------------------------------------------------------------------------------------------------------------------
! INPUT/OUTPUT VARIABLES
!-----------------------------------------------------------------------------------------------------------------------------------
! LOCAL VARIABLES
#if USE_MPI
INTEGER                        :: iProc
TYPE(MPI_Request)              :: RecvRequest(1:nSurfNodeRecvExchangeProcs),SendRequest(1:nSurfNodeSendExchangeProcs)
#endif /*USE_MPI*/
INTEGER                        :: globalNode, iNode
#if defined(MEASURE_MPI_WAIT)
INTEGER(KIND=8)                :: CounterStart,CounterEnd
REAL(KIND=8)                   :: Rate
#endif /*defined(MEASURE_MPI_WAIT)*/
!===================================================================================================================================
! 1) Receive charge density
DO iProc = 1, nSurfNodeRecvExchangeProcs
  ! Open receive buffer
  CALL MPI_IRECV( SurfNodeMappingRecv(iProc)%RecvSurfNodeSource(:)    &
      , SurfNodeMappingRecv(iProc)%nRecvUniqueSurfNodes               &
      , MPI_DOUBLE_PRECISION                                          &
      , SurfNodeRecvDepoRankToGlobalRank(iProc)                       &
      , 666                                                           &
      , MPI_COMM_PICLAS                                               &
      , RecvRequest(iProc)                                            &
      , IERROR)
END DO

DO iProc = 1, nSurfNodeSendExchangeProcs
  ! Send message (non-blocking)
  DO iNode = 1, SurfNodeMappingSend(iProc)%nSendUniqueSurfNodes
    SurfNodeMappingSend(iProc)%SendSurfNodeSource(iNode) = SurfNodeSourceMPI(SurfNodeMappingSend(iProc)%SendSurfNodeUniqueGlobalID(iNode))
  END DO
  CALL MPI_ISEND( SurfNodeMappingSend(iProc)%SendSurfNodeSource(:)    &
      , SurfNodeMappingSend(iProc)%nSendUniqueSurfNodes               &
      , MPI_DOUBLE_PRECISION                                          &
      , SurfNodeSendDepoRankToGlobalRank(iProc)                       &
      , 666                                                           &
      , MPI_COMM_PICLAS                                               &
      , SendRequest(iProc)                                            &
      , IERROR)
END DO
! Finish communication
#if defined(MEASURE_MPI_WAIT)
CALL SYSTEM_CLOCK(count=CounterStart)
#endif /*defined(MEASURE_MPI_WAIT)*/
DO iProc = 1, nSurfNodeSendExchangeProcs
  CALL MPI_WAIT(SendRequest(iProc),MPI_STATUS_IGNORE,IERROR)
  IF (IERROR.NE.MPI_SUCCESS) CALL ABORT(__STAMP__,' MPI Communication error', IERROR)
END DO
DO iProc = 1, nSurfNodeRecvExchangeProcs
  CALL MPI_WAIT(RecvRequest(iProc),MPI_STATUS_IGNORE,IERROR)
  IF (IERROR.NE.MPI_SUCCESS) CALL ABORT(__STAMP__,' MPI Communication error', IERROR)
END DO
#if defined(MEASURE_MPI_WAIT)
CALL SYSTEM_CLOCK(count=CounterEnd, count_rate=Rate)
MPIW8TimePart(6)  = MPIW8TimePart(6) + REAL(CounterEnd-CounterStart,8)/Rate
MPIW8CountPart(6) = MPIW8CountPart(6) + 1_8
#endif /*defined(MEASURE_MPI_WAIT)*/

! 3) Extract messages
DO iProc = 1, nSurfNodeRecvExchangeProcs
  DO iNode = 1, SurfNodeMappingRecv(iProc)%nRecvUniqueSurfNodes
    ASSOCIATE( NS => SurfNodeSourceMPI(SurfNodeMappingRecv(iProc)%RecvSurfNodeUniqueGlobalID(iNode)))
      NS = NS + SurfNodeMappingRecv(iProc)%RecvSurfNodeSource(iNode)
    END ASSOCIATE
  END DO
END DO

! Add SurfNodeSourceMPI values of the last boundary interaction
CALL abort(__STAMP__,' SurfNodeSourceMPI to SurfNodeSource', IERROR)
DO iNode = 1, nDepoSurfNodesTotal
  globalNode = DepoSurfNodetoGlobalNode(iNode)
  SurfNodeSource(globalNode) = SurfNodeSource(globalNode) + SurfNodeSourceMPI(globalNode)
END DO
! Reset local surface charge
SurfNodeSourceMPI = 0.
END SUBROUTINE ExchangeSurfNodeSourceMPI

#endif /*!((PP_TimeDiscMethod==4) || (PP_TimeDiscMethod==300) || (PP_TimeDiscMethod==400))*/
#endif /*USE_MPI*/
END MODULE MOD_PICDepo_MPI
