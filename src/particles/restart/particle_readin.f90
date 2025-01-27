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

MODULE MOD_Particle_Readin
!===================================================================================================================================
! Module to handle PICLas's restart
!===================================================================================================================================
! MODULES
! IMPLICIT VARIABLE HANDLING
IMPLICIT NONE
PRIVATE
!-----------------------------------------------------------------------------------------------------------------------------------
INTERFACE ParticleReadin
  MODULE PROCEDURE ParticleReadin
END INTERFACE

PUBLIC :: ParticleReadin
!===================================================================================================================================

CONTAINS

SUBROUTINE ParticleReadin()
!===================================================================================================================================
! Distribute or readin particle data
!===================================================================================================================================
! MODULES
USE MOD_Globals
USE MOD_PreProc
USE MOD_Particle_Restart_Vars
! HDF5
USE MOD_IO_HDF5
USE MOD_HDF5_Input             ,ONLY: OpenDataFile,CloseDataFile,ReadArray,ReadAttribute,GetDataSize
USE MOD_HDF5_Input             ,ONLY: File_ID,DatasetExists,nDims,HSize
USE MOD_HDF5_Output            ,ONLY: FlushHDF5
! Mesh
USE MOD_Mesh_Vars              ,ONLY: OffsetElem
! DSMC
USE MOD_DSMC_Vars              ,ONLY: UseDSMC,CollisMode,DSMC,PolyatomMolDSMC,SpecDSMC
! Particles
USE MOD_Dielectric_Vars        ,ONLY: DoDielectricSurfaceCharge
USE MOD_HDF5_Input_Particles   ,ONLY: ReadEmissionVariablesFromHDF5,ReadNodeSourceExtFromHDF5
USE MOD_Particle_Vars          ,ONLY: PartInt,PartData,nSpecies,usevMPF
USE MOD_PICDepo_Vars           ,ONLY: DoDeposition,RelaxDeposition,PartSourceOld
! Restart
USE MOD_Restart_Vars           ,ONLY: RestartFile,InterpolateSolution,RestartNullifySolution
USE MOD_Restart_Vars           ,ONLY: DoMacroscopicRestart
! HDG
#if USE_HDG
USE MOD_Part_BR_Elecron_Fluid  ,ONLY: CreateElectronsFromBRFluid
#endif /*USE_HDG*/
! LoadBalance
#if USE_LOADBALANCE
USE MOD_LoadBalance_Vars       ,ONLY: PerformLoadBalance,UseH5IOLoadBalance
USE MOD_LoadBalance_Vars       ,ONLY: nElemsOld,offsetElemOld,ElemInfoRank_Shared
USE MOD_LoadBalance_Vars       ,ONLY: MPInElemSend,MPInElemRecv,MPIoffsetElemSend,MPIoffsetElemRecv
USE MOD_LoadBalance_Vars       ,ONLY: MPInPartSend,MPInPartRecv,MPIoffsetPartSend,MPIoffsetPartRecv
USE MOD_LoadBalance_Vars       ,ONLY: PartSourceLB,NodeSourceExtEquiLB
USE MOD_Mesh_Vars              ,ONLY: nElems
USE MOD_Particle_Mesh_Vars     ,ONLY: ElemInfo_Shared
USE MOD_PICDepo_Vars           ,ONLY: NodeSourceExt
USE MOD_Particle_Mesh_Vars     ,ONLY: ElemNodeID_Shared,NodeInfo_Shared,nUniqueGlobalNodes
USE MOD_Mesh_Tools             ,ONLY: GetCNElemID
USE MOD_Mesh_Vars              ,ONLY: offsetElem
USE MOD_Particle_Vars          ,ONLY: DelayTime
USE MOD_PICDepo_Vars           ,ONLY: PartSource
USE MOD_TimeDisc_Vars          ,ONLY: time
#endif /*USE_LOADBALANCE*/
USE MOD_Particle_Vars          ,ONLY: VibQuantData,ElecDistriData,AD_Data
USE MOD_Particle_Vars          ,ONLY: PartDataSize,PartIntSize
! IMPLICIT VARIABLE HANDLING
IMPLICIT NONE
!-----------------------------------------------------------------------------------------------------------------------------------
! INPUT VARIABLES
!-----------------------------------------------------------------------------------------------------------------------------------
! OUTPUT VARIABLES
!-----------------------------------------------------------------------------------------------------------------------------------
! LOCAL VARIABLES
! Parameters
INTEGER,PARAMETER                  :: ELEM_FirstPartInd = 1
INTEGER,PARAMETER                  :: ELEM_LastPartInd  = 2
! Counters
INTEGER(KIND=IK)                   :: locnPart,offsetnPart
INTEGER                            :: iElem
INTEGER                            :: FirstElemInd,LastelemInd,i,j,k
INTEGER                            :: MaxQuantNum,iPolyatMole,iSpec,iVar,MaxElecQuant
! VarNames
CHARACTER(LEN=255),ALLOCATABLE     :: StrVarNames(:)
CHARACTER(LEN=255),ALLOCATABLE     :: StrVarNames_HDF5(:)
! HDF5 checkes
LOGICAL                            :: VibQuantDataExists,changedVars,DGSourceExists
LOGICAL                            :: ElecDistriDataExists,AD_DataExists,implemented
LOGICAL                            :: FileVersionExists
REAL                               :: FileVersionHDF5Real
INTEGER                            :: FileVersionHDF5Int
INTEGER                            :: PartDataSize_HDF5              ! number of entries in each line of PartData
REAL,ALLOCATABLE                   :: PartSource_HDF5(:,:,:,:,:)
! Temporary arrays
INTEGER(KIND=IK),ALLOCATABLE       :: PartIntTmp(:,:)
#if USE_LOADBALANCE
! LoadBalance
INTEGER(KIND=IK)                   :: PartRank
INTEGER                            :: offsetPartSend,offsetPartRecv
INTEGER,PARAMETER                  :: N_variables=1
REAL,ALLOCATABLE                   :: NodeSourceExtEquiLBTmp(:,:,:,:,:)
INTEGER                            :: NodeID(1:8)
#if USE_MPI
! MPI
INTEGER                            :: iProc
#endif /*USE_MPI*/
! Temporary arrays
REAL,ALLOCATABLE                   :: PartDataTmp(:,:)
INTEGER,ALLOCATABLE                :: VibQuantDataTmp(:,:)
REAL,ALLOCATABLE                   :: ElecDistriDataTmp(:,:)
REAL,ALLOCATABLE                   :: AD_DataTmp(:,:)
! Custom data type
INTEGER                            :: MPI_LENGTH(1),MPI_TYPE(1),MPI_STRUCT
INTEGER(KIND=MPI_ADDRESS_KIND)     :: MPI_DISPLACEMENT(1)
#endif /*USE_LOADBALANCE*/
CHARACTER(LEN=32)                  :: hilf
!===================================================================================================================================

FirstElemInd = offsetElem+1
LastElemInd  = offsetElem+PP_nElems

#if USE_LOADBALANCE
IF (PerformLoadBalance.AND.(.NOT.UseH5IOLoadBalance)) THEN
  SWRITE(UNIT_stdOut,'(A)',ADVANCE='NO') ' Restarting particles during loadbalance...'

  ! ------------------------------------------------
  ! PartSource
  ! ------------------------------------------------
  ! 1.) relax deposition
  ! 2.) particle delay time active
  IF (DoDeposition .AND. (RelaxDeposition.OR.(time.LT.DelayTime))) THEN
    ALLOCATE(PartSource_HDF5(1:4,0:PP_N,0:PP_N,0:PP_N,nElems))
    ASSOCIATE (&
            counts_send  => INT(MPInElemSend     ) ,&
            disp_send    => INT(MPIoffsetElemSend) ,&
            counts_recv  => INT(MPInElemRecv     ) ,&
            disp_recv    => INT(MPIoffsetElemRecv))
      ! Communicate PartSource over MPI
      MPI_LENGTH       = 4*(PP_N+1)**3
      MPI_DISPLACEMENT = 0  ! 0*SIZEOF(MPI_SIZE)
      MPI_TYPE         = MPI_DOUBLE_PRECISION
      CALL MPI_TYPE_CREATE_STRUCT(1,MPI_LENGTH,MPI_DISPLACEMENT,MPI_TYPE,MPI_STRUCT,iError)
      CALL MPI_TYPE_COMMIT(MPI_STRUCT,iError)

      CALL MPI_ALLTOALLV(PartSourceLB,counts_send,disp_send,MPI_STRUCT,PartSource_HDF5,counts_recv,disp_recv,MPI_STRUCT,MPI_COMM_WORLD,iError)
    END ASSOCIATE
    DEALLOCATE(PartSourceLB)

    ! 1.) relax deposition
    IF(RelaxDeposition)THEN
      DO iElem =1,PP_nElems
        DO k=0, PP_N; DO j=0, PP_N; DO i=0, PP_N
#if ((USE_HDG) && (PP_nVar==1))
          PartSourceOld(1,1,i,j,k,iElem) = PartSource_HDF5(4,i,j,k,iElem)
          PartSourceOld(1,2,i,j,k,iElem) = PartSource_HDF5(4,i,j,k,iElem)
#else
          PartSourceOld(1:4,1,i,j,k,iElem) = PartSource_HDF5(1:4,i,j,k,iElem)
          PartSourceOld(1:4,2,i,j,k,iElem) = PartSource_HDF5(1:4,i,j,k,iElem)
#endif
        END DO; END DO; END DO
      END DO
    END IF ! RelaxDeposition

    ! 2.) particle delay time active
    IF(time.LT.DelayTime)THEN
      DO iElem =1,PP_nElems
        DO k=0, PP_N; DO j=0, PP_N; DO i=0, PP_N
#if ((USE_HDG) && (PP_nVar==1))
          PartSource(1,i,j,k,iElem) = PartSource_HDF5(4,i,j,k,iElem)
#else
          PartSource(1:4,i,j,k,iElem) = PartSource_HDF5(1:4,i,j,k,iElem)
#endif
        END DO; END DO; END DO
      END DO
    END IF ! time.LE.DelayTime
  END IF ! (DoDeposition .AND. RelaxDeposition)

  ! ------------------------------------------------
  ! NodeSourceExt (external/additional charge source terms)
  ! ------------------------------------------------
  IF(DoDielectricSurfaceCharge)THEN
    ! This array is not allocated when DoDeposition=F, however, the previously calculated surface charge might still be required in
    ! the future, when DoDeposition is activated again. Therefore, read the old data and store in the new state file.
    IF(.NOT.DoDeposition) THEN
      ALLOCATE(NodeSourceExt(1:nUniqueGlobalNodes))
      NodeSourceExt = 0.
    END IF
    ALLOCATE(NodeSourceExtEquiLBTmp(1:N_variables,0:1,0:1,0:1,nElems))
    ASSOCIATE (&
            counts_send  => INT(MPInElemSend     ) ,&
            disp_send    => INT(MPIoffsetElemSend) ,&
            counts_recv  => INT(MPInElemRecv     ) ,&
            disp_recv    => INT(MPIoffsetElemRecv))
      ! Communicate PartSource over MPI
      MPI_LENGTH       = (PP_N+1)**3
      MPI_DISPLACEMENT = 0  ! 0*SIZEOF(MPI_SIZE)
      MPI_TYPE         = MPI_DOUBLE_PRECISION
      CALL MPI_TYPE_CREATE_STRUCT(1,MPI_LENGTH,MPI_DISPLACEMENT,MPI_TYPE,MPI_STRUCT,iError)
      CALL MPI_TYPE_COMMIT(MPI_STRUCT,iError)

      CALL MPI_ALLTOALLV(NodeSourceExtEquiLB,counts_send,disp_send,MPI_STRUCT,NodeSourceExtEquiLBTmp,counts_recv,disp_recv,MPI_STRUCT,MPI_COMM_WORLD,iError)
    END ASSOCIATE
    DEALLOCATE(NodeSourceExtEquiLB)
    ! Loop over all elements and store absolute charge values in equidistantly distributed nodes of PP_N=1
    DO iElem=1,PP_nElems
      ! Copy values to equidistant distribution
      NodeID = NodeInfo_Shared(ElemNodeID_Shared(:,GetCNElemID(iElem+offsetElem)))
      NodeSourceExt(NodeID(1)) = NodeSourceExtEquiLBTmp(1,0,0,0,iElem)
      NodeSourceExt(NodeID(2)) = NodeSourceExtEquiLBTmp(1,1,0,0,iElem)
      NodeSourceExt(NodeID(3)) = NodeSourceExtEquiLBTmp(1,1,1,0,iElem)
      NodeSourceExt(NodeID(4)) = NodeSourceExtEquiLBTmp(1,0,1,0,iElem)
      NodeSourceExt(NodeID(5)) = NodeSourceExtEquiLBTmp(1,0,0,1,iElem)
      NodeSourceExt(NodeID(6)) = NodeSourceExtEquiLBTmp(1,1,0,1,iElem)
      NodeSourceExt(NodeID(7)) = NodeSourceExtEquiLBTmp(1,1,1,1,iElem)
      NodeSourceExt(NodeID(8)) = NodeSourceExtEquiLBTmp(1,0,1,1,iElem)
    END DO!iElem
    DEALLOCATE(NodeSourceExtEquiLBTmp)
  END IF ! DoDeposition.AND.DoDielectricSurfaceCharge

  ! ------------------------------------------------
  ! Check and set sizes
  ! ------------------------------------------------
  ! Check the PartDataSize
  IF (PartDataSize.EQ.0) CALL Abort(__STAMP__,'PartDataSize.EQ.0 but should have been set before loadbalance!')

  ALLOCATE(readVarFromState(PartDataSize))
  readVarFromState=.TRUE.

  ! Set polyatomic and electronic shell variables
  IF (useDSMC) THEN
    IF (DSMC%NumPolyatomMolecs.GT.0) THEN
      MaxQuantNum = 0
      DO iSpec = 1,nSpecies
        IF (SpecDSMC(iSpec)%PolyatomicMol) THEN
          iPolyatMole = SpecDSMC(iSpec)%SpecToPolyArray
          IF (PolyatomMolDSMC(iPolyatMole)%VibDOF.GT.MaxQuantNum) MaxQuantNum = PolyatomMolDSMC(iPolyatMole)%VibDOF
        END IF ! SpecDSMC(iSpec)%PolyatomicMol
      END DO ! iSpec = 1, nSpecies
    END IF ! DSMC%NumPolyatomMolecs.GT.0

    IF (DSMC%ElectronicModel.EQ.2) THEN
      MaxElecQuant = 0
      DO iSpec = 1,nSpecies
        IF (.NOT.((SpecDSMC(iSpec)%InterID.EQ.4).OR.SpecDSMC(iSpec)%FullyIonized)) THEN
          IF (SpecDSMC(iSpec)%MaxElecQuant.GT.MaxElecQuant) MaxElecQuant = SpecDSMC(iSpec)%MaxElecQuant
        END IF
      END DO
    END IF ! DSMC%ElectronicModel.EQ.2
  END IF ! useDSMC

  ! ------------------------------------------------
  ! PartInt and PartData
  ! ------------------------------------------------

  ! PartInt and PartData are still allocated from last WriteState
  ALLOCATE(PartIntTmp(PartIntSize,FirstElemInd:LastElemInd))
  ASSOCIATE (&
          counts_send  => INT(MPInElemSend     ) ,&
          disp_send    => INT(MPIoffsetElemSend) ,&
          counts_recv  => INT(MPInElemRecv     ) ,&
          disp_recv    => INT(MPIoffsetElemRecv))
    MPI_LENGTH       = 2
    MPI_DISPLACEMENT = 0  ! 0*SIZEOF(MPI_SIZE)
    MPI_TYPE         = MPI_INTEGER_INT_KIND
    CALL MPI_TYPE_CREATE_STRUCT(1,MPI_LENGTH,MPI_DISPLACEMENT,MPI_TYPE,MPI_STRUCT,iError)
    CALL MPI_TYPE_COMMIT(MPI_STRUCT,iError)

    ! Communicate PartInt over MPI
    CALL MPI_ALLTOALLV(PartInt,counts_send,disp_send,MPI_STRUCT,PartIntTmp,counts_recv,disp_recv,MPI_STRUCT,MPI_COMM_WORLD,iError)
  END ASSOCIATE

  ! Calculate the PartInt deltas
  MPInPartSend      = 0
  MPIoffsetPartSend = 0
  ! Calculate the particles to send
  ! Loop with the old element over the new particle distribution
  DO iElem = 1,nElemsOld
    PartRank               = ElemInfo_Shared(ELEM_RANK,offsetElemOld+iElem)+1
    MPInPartSend(PartRank) = MPInPartSend(PartRank) + PartInt(2,offsetElemOld+iElem) - PartInt(1,offsetElemOld+iElem)
  END DO

  offsetPartSend = 0
  DO iProc = 2,nProcessors
    MPIoffsetPartSend(iProc) = SUM(MPInPartSend(1:iProc-1))
  END DO

  ! Calculate the elements to send
  MPInPartRecv      = 0
  MPIoffsetPartRecv = 0
  ! Loop with the new element over the old particle distribution
  DO iElem = 1,nElems
    PartRank               = ElemInfoRank_Shared(offsetElem+iElem)+1
    MPInPartRecv(PartRank) = MPInPartRecv(PartRank) + PartIntTmp(2,offsetElem+iElem) - PartIntTmp(1,offsetElem+iElem)
  END DO

  offsetPartRecv = 0
  DO iProc = 2,nProcessors
    MPIoffsetPartRecv(iProc) = SUM(MPInPartRecv(1:iProc-1))
  END DO
  CALL MOVE_ALLOC(PartIntTmp,PartInt)
  PartIntExists = .TRUE.

  locnPart    = PartInt(ELEM_LastPartInd,LastElemInd)-PartInt(ELEM_FirstPartInd,FirstElemInd)
  offsetnPart = PartInt(ELEM_FirstPartInd,FirstElemInd)
  ALLOCATE(PartDataTmp(PartDataSize,offsetnPart+1_IK:offsetnPart+locnPart))

  ASSOCIATE (&
          counts_send  => INT(MPInPartSend     ) ,&
          disp_send    => INT(MPIoffsetPartSend) ,&
          counts_recv  => INT(MPInPartRecv     ) ,&
          disp_recv    => INT(MPIoffsetPartRecv))

    MPI_LENGTH       = PartDataSize
    MPI_DISPLACEMENT = 0
    MPI_TYPE         = MPI_DOUBLE_PRECISION
    CALL MPI_TYPE_CREATE_STRUCT(1,MPI_LENGTH,MPI_DISPLACEMENT,MPI_TYPE,MPI_STRUCT,iError)
    CALL MPI_TYPE_COMMIT(MPI_STRUCT,iError)

    ! Communicate PartData over MPI
    CALL MPI_ALLTOALLV(PartData,counts_send,disp_send,MPI_STRUCT,PartDataTmp,counts_recv,disp_recv,MPI_STRUCT,MPI_COMM_WORLD,iError)
  END ASSOCIATE
  CALL MOVE_ALLOC(PartDataTmp,PartData)
  PartDataExists   = .TRUE.

  ! ------------------------------------------------
  ! DSMC-specific arrays
  ! ------------------------------------------------
  IF(useDSMC)THEN
    ! Polyatomic
    IF (DSMC%NumPolyatomMolecs.GT.0) THEN
      ALLOCATE(VibQuantDataTmp(MaxQuantNum,offsetnPart+1_IK:offsetnPart+locnPart))
      ASSOCIATE (&
              counts_send  => INT(MPInPartSend     ) ,&
              disp_send    => INT(MPIoffsetPartSend) ,&
              counts_recv  => INT(MPInPartRecv     ) ,&
              disp_recv    => INT(MPIoffsetPartRecv))

        MPI_LENGTH       = MaxQuantNum
        MPI_DISPLACEMENT = 0
        MPI_TYPE         = MPI_INTEGER_INT_KIND
        CALL MPI_TYPE_CREATE_STRUCT(1,MPI_LENGTH,MPI_DISPLACEMENT,MPI_TYPE,MPI_STRUCT,iError)
        CALL MPI_TYPE_COMMIT(MPI_STRUCT,iError)

        ! Communicate VibQuantData over MPI
        CALL MPI_ALLTOALLV(VibQuantData,counts_send,disp_send,MPI_STRUCT,VibQuantDataTmp,counts_recv,disp_recv,MPI_STRUCT,MPI_COMM_WORLD,iError)
      END ASSOCIATE
      CALL MOVE_ALLOC(VibQuantDataTmp,VibQuantData)
    END IF

    ! Electronic
    IF (DSMC%ElectronicModel.EQ.2) THEN
      ALLOCATE(ElecDistriDataTmp(MaxElecQuant,offsetnPart+1_IK:offsetnPart+locnPart))
      ASSOCIATE (&
              counts_send  => INT(MaxElecQuant*MPInPartSend     ) ,&
              disp_send    => INT(MaxElecQuant*MPIoffsetPartSend) ,&
              counts_recv  => INT(MaxElecQuant*MPInPartRecv     ) ,&
              disp_recv    => INT(MaxElecQuant*MPIoffsetPartRecv))

        ! Create MPI_STRUCT with the correct size
        MPI_LENGTH       = MaxElecQuant
        MPI_DISPLACEMENT = 0
        MPI_TYPE         = MPI_DOUBLE_PRECISION
        CALL MPI_TYPE_CREATE_STRUCT(1,MPI_LENGTH,MPI_DISPLACEMENT,MPI_TYPE,MPI_STRUCT,iError)
        CALL MPI_TYPE_COMMIT(MPI_STRUCT,iError)

        ! Communicate ElecDistriData over MPI
        CALL MPI_ALLTOALLV(ElecDistriData,counts_send,disp_send,MPI_STRUCT,ElecDistriDataTmp,counts_recv,disp_recv,MPI_STRUCT,MPI_COMM_WORLD,iError)
      END ASSOCIATE
      CALL MOVE_ALLOC(ElecDistriDataTmp,ElecDistriData)
    END IF

    ! Ambipolar Diffusion
    IF (DSMC%DoAmbipolarDiff) THEN
      ALLOCATE(AD_DataTmp(3,offsetnPart+1_IK:offsetnPart+locnPart))
      ASSOCIATE (&
              counts_send  => INT(MPInPartSend     ) ,&
              disp_send    => INT(MPIoffsetPartSend) ,&
              counts_recv  => INT(MPInPartRecv     ) ,&
              disp_recv    => INT(MPIoffsetPartRecv))

        ! Create MPI_STRUCT with the correct size
        MPI_LENGTH       = 3
        MPI_DISPLACEMENT = 0
        MPI_TYPE         = MPI_DOUBLE_PRECISION
        CALL MPI_TYPE_CREATE_STRUCT(1,MPI_LENGTH,MPI_DISPLACEMENT,MPI_TYPE,MPI_STRUCT,iError)
        CALL MPI_TYPE_COMMIT(MPI_STRUCT,iError)

        ! Communicate AD_Data over MPI
        CALL MPI_ALLTOALLV(AD_Data,counts_send,disp_send,MPI_STRUCT,AD_DataTmp,counts_recv,disp_recv,MPI_STRUCT,MPI_COMM_WORLD,iError)
      END ASSOCIATE
      CALL MOVE_ALLOC(AD_DataTmp,AD_Data)
    END IF
  END IF ! useDSMC

! NOT. PerformLoadBalance
ELSE
#endif /*USE_LOADBALANCE*/
  SWRITE(UNIT_stdOut,'(A)',ADVANCE='NO') ' Reading particles from Restartfile...'

  ! FIXME: Deallocate PartInt/PartData until loadbalance is always handled with MPI
   SDEALLOCATE(PartInt)
   SDEALLOCATE(PartData)

  ! ------------------------------------------------
  ! PartSource
  ! ------------------------------------------------
  IF(.NOT.RestartNullifySolution)THEN ! Use the solution in the restart file
    !-- read PartSource if relaxation is performed (might be needed for RestartHDG)
    IF (DoDeposition .AND. RelaxDeposition) THEN
      CALL OpenDataFile(RestartFile,create=.FALSE.,single=.FALSE.,readOnly=.TRUE.,communicatorOpt=MPI_COMM_WORLD)
      CALL DatasetExists(File_ID,'DG_Source',DGSourceExists)
      IF(DGSourceExists)THEN
        IF(.NOT.InterpolateSolution)THEN! No interpolation needed, read solution directly from file
          ALLOCATE(PartSource_HDF5(1:4,0:PP_N,0:PP_N,0:PP_N,PP_nElems))

          ! Associate construct for integer KIND=8 possibility
          ASSOCIATE (&
                    PP_NTmp       => INT(PP_N,IK)       ,&
                    OffsetElemTmp => INT(OffsetElem,IK) ,&
                    PP_nElemsTmp  => INT(PP_nElems,IK))
            CALL ReadArray('DG_Source' ,5,(/4_IK,PP_NTmp+1,PP_NTmp+1,PP_NTmp+1,PP_nElemsTmp/),OffsetElemTmp,5,RealArray=PartSource_HDF5)
          END ASSOCIATE

          DO iElem =1,PP_nElems
            DO k=0, PP_N; DO j=0, PP_N; DO i=0, PP_N
#if ((USE_HDG) && (PP_nVar==1))
              PartSourceOld(1,1,i,j,k,iElem) = PartSource_HDF5(4,i,j,k,iElem)
              PartSourceOld(1,2,i,j,k,iElem) = PartSource_HDF5(4,i,j,k,iElem)
#else
              PartSourceOld(1:4,1,i,j,k,iElem) = PartSource_HDF5(1:4,i,j,k,iElem)
              PartSourceOld(1:4,2,i,j,k,iElem) = PartSource_HDF5(1:4,i,j,k,iElem)
#endif
            END DO; END DO; END DO
          END DO

          DEALLOCATE(PartSource_HDF5)
        ELSE ! We need to interpolate the solution to the new computational grid
          CALL abort(__STAMP__,' Restart with changed polynomial degree not implemented for DG_Source!')
        END IF ! .NOT.InterpolateSolution
      END IF ! DGSourceExists
      CALL CloseDataFile()
    END IF ! DoDeposition .AND. RelaxDeposition
  END IF ! IF(.NOT. RestartNullifySolution)

  IF (DoMacroscopicRestart) RETURN

  ! Reconstruct the VarNames
  implemented=.FALSE.
  IF(useDSMC)THEN
    IF((CollisMode.GT.1).AND.(usevMPF).AND.(DSMC%ElectronicModel.GT.0))THEN
      PartDataSize=11
      ALLOCATE(StrVarNames(PartDataSize))
      StrVarNames( 8)='Vibrational'
      StrVarNames( 9)='Rotational'
      StrVarNames(10)='Electronic'
      StrVarNames(11)='MPF'
      implemented = .TRUE.
    ELSE IF ( (CollisMode .GT. 1) .AND. (usevMPF) ) THEN
      PartDataSize=10
      ALLOCATE(StrVarNames(PartDataSize))
      StrVarNames( 8)='Vibrational'
      StrVarNames( 9)='Rotational'
      StrVarNames(10)='MPF'
      implemented = .TRUE.
    ELSE IF ( (CollisMode .GT. 1) .AND. (DSMC%ElectronicModel.GT.0) ) THEN
      PartDataSize=10
      ALLOCATE(StrVarNames(PartDataSize))
      StrVarNames( 8)='Vibrational'
      StrVarNames( 9)='Rotational'
      StrVarNames(10)='Electronic'
    ELSE IF (CollisMode.GT.1) THEN
      implemented=.TRUE.
      PartDataSize=9 !int ener + 2
      ALLOCATE(StrVarNames(PartDataSize))
      StrVarNames( 8)='Vibrational'
      StrVarNames( 9)='Rotational'
    ELSE IF (usevMPF) THEN
      PartDataSize=8 !+ 1 vmpf
      ALLOCATE(StrVarNames(PartDataSize))
      StrVarNames( 8)='MPF'
      implemented=.TRUE.
    ELSE
      PartDataSize=7 !+ 0
      ALLOCATE(StrVarNames(PartDataSize))
    END IF
  ELSE IF (usevMPF) THEN
    PartDataSize=8 !vmpf +1
    ALLOCATE(StrVarNames(PartDataSize))
    StrVarNames( 8)='MPF'
  ELSE
    PartDataSize=7
    ALLOCATE(StrVarNames(PartDataSize))
  END IF ! UseDSMC
  StrVarNames(1)='ParticlePositionX'
  StrVarNames(2)='ParticlePositionY'
  StrVarNames(3)='ParticlePositionZ'
  StrVarNames(4)='VelocityX'
  StrVarNames(5)='VelocityY'
  StrVarNames(6)='VelocityZ'
  StrVarNames(7)='Species'
  ALLOCATE(readVarFromState(PartDataSize))
  readVarFromState=.TRUE.

  IF (useDSMC.AND.(DSMC%NumPolyatomMolecs.GT.0)) THEN
    MaxQuantNum = 0
    DO iSpec = 1, nSpecies
      IF(SpecDSMC(iSpec)%PolyatomicMol) THEN
        iPolyatMole = SpecDSMC(iSpec)%SpecToPolyArray
        IF (PolyatomMolDSMC(iPolyatMole)%VibDOF.GT.MaxQuantNum) MaxQuantNum = PolyatomMolDSMC(iPolyatMole)%VibDOF
      END IF ! SpecDSMC(iSpec)%PolyatomicMol
    END DO ! iSpec = 1, nSpecies
  END IF ! useDSMC.AND.(DSMC%NumPolyatomMolecs.GT.0)

  IF (useDSMC.AND.(DSMC%ElectronicModel.EQ.2)) THEN
    MaxElecQuant = 0
    DO iSpec = 1, nSpecies
      IF (.NOT.((SpecDSMC(iSpec)%InterID.EQ.4).OR.SpecDSMC(iSpec)%FullyIonized)) THEN
        IF (SpecDSMC(iSpec)%MaxElecQuant.GT.MaxElecQuant) MaxElecQuant = SpecDSMC(iSpec)%MaxElecQuant
      END IF
    END DO
  END IF

  CALL OpenDataFile(RestartFile,create=.FALSE.,single=.FALSE.,readOnly=.TRUE.,communicatorOpt=MPI_COMM_WORLD)
  ! ------------------------------------------------
  ! NodeSourceExt (external/additional charge source terms)
  ! ------------------------------------------------
  IF(DoDielectricSurfaceCharge) CALL ReadNodeSourceExtFromHDF5()

  ! ------------------------------------------------
  ! PartInt
  ! ------------------------------------------------
  CALL DatasetExists(File_ID,'PartInt',PartIntExists)
  IF(PartIntExists)THEN
    ALLOCATE(PartInt(PartIntSize,FirstElemInd:LastElemInd))

    ! Check file version
    CALL DatasetExists(File_ID,'File_Version',FileVersionExists,attrib=.TRUE.)
    IF(FileVersionExists)THEN
      CALL ReadAttribute(File_ID,'File_Version',1,RealScalar=FileVersionHDF5Real)

      ! Associate construct for integer KIND=8 possibility
      ASSOCIATE (&
            PP_nElems   => INT(PP_nElems,IK)   ,&
            PartIntSize => INT(PartIntSize,IK) ,&
            offsetElem  => INT(offsetElem,IK)   )
        ! Depending on the file version, PartInt may have switched dimensions
        IF(FileVersionHDF5Real.LT.2.8)THEN
          ALLOCATE(PartIntTmp(FirstElemInd:LastElemInd,PartIntSize))
          CALL ReadArray('PartInt',2,(/PP_nElems,PartIntSize/),offsetElem,1,IntegerArray=PartIntTmp)
          ! Switch dimensions
          DO iElem = FirstElemInd, LastElemInd
            PartInt(:,iElem) = PartIntTmp(iElem,:)
          END DO ! iElem = FirstElemInd, LastElemInd
          DEALLOCATE(PartIntTmp)
        ELSE
          CALL ReadArray('PartInt',2,(/PartIntSize,PP_nElems/),offsetElem,2,IntegerArray=PartInt)
        END IF ! FileVersionHDF5Real.LT.2.7
      END ASSOCIATE
    ELSE
      CALL DatasetExists(File_ID,'Piclas_VersionInt',FileVersionExists,attrib=.TRUE.)
      IF (FileVersionExists) THEN
        CALL ReadAttribute(File_ID,'Piclas_VersionInt',1,IntScalar=FileVersionHDF5Int)
      ELSE
        CALL abort(__STAMP__,'Error in ParticleRestart(): Attribute "Piclas_VersionInt" does not exist!')
      END IF
    ENDIF


    ! ------------------------------------------------
    ! PartData
    ! ------------------------------------------------
    locnPart    = PartInt(ELEM_LastPartInd,LastElemInd)-PartInt(ELEM_FirstPartInd,FirstElemInd)
    offsetnPart = PartInt(ELEM_FirstPartInd,FirstElemInd)

    CALL DatasetExists(File_ID,'PartData',PartDataExists)
    IF(PartDataExists)THEN
      ! Read in parameters from the State file
      CALL GetDataSize(File_ID,'VarNamesParticles',nDims,HSize,attrib=.TRUE.)
      PartDataSize_HDF5 = INT(HSize(1),4)
      DEALLOCATE(HSize)

      ALLOCATE(StrVarNames_HDF5(PartDataSize_HDF5))
      CALL ReadAttribute(File_ID,'VarNamesParticles',PartDataSize_HDF5,StrArray=StrVarNames_HDF5)

      IF (PartDataSize_HDF5.NE.PartDataSize) THEN
        changedVars=.TRUE.
      ELSE IF (.NOT.ALL(StrVarNames_HDF5.EQ.StrVarNames)) THEN
        changedVars=.TRUE.
      ELSE
        changedVars=.FALSE.
      END IF ! PartDataSize_HDF5.NE.PartDataSize

      IF (changedVars) THEN
        SWRITE(*,*) 'WARNING: VarNamesParticles have changed from restart-file'
        IF (.NOT.implemented) CALL Abort(__STAMP__,"change in VarNamesParticles not implemented yet")
        ! Check which variables were found in the .h5 file and flag the ones that were not found
        readVarFromState=.FALSE.
        DO iVar=1,PartDataSize_HDF5
          IF (TRIM(StrVarNames(iVar)).EQ.TRIM(StrVarNames_HDF5(iVar))) THEN
            readVarFromState(iVar)=.TRUE.
          ELSE
            CALL Abort(__STAMP__,"not associated VarNamesParticles in HDF5!")
          END IF
        END DO ! iVar=1,PartDataSize_HDF5
        DO iVar=1,PartDataSize
          IF (.NOT.readVarFromState(iVar)) THEN
            IF (TRIM(StrVarNames(iVar)).EQ.'Vibrational' .OR. TRIM(StrVarNames(iVar)).EQ.'Rotational') THEN
              WRITE(UNIT=hilf,FMT='(I0)') iVar
              SWRITE(*,*) 'WARNING: The following VarNamesParticles(iVar='//TRIM(hilf)//') will be set to zero: '//TRIM(StrVarNames(iVar))
            ELSE IF(TRIM(StrVarNames(iVar)).EQ.'MPF') THEN
              SWRITE(*,*) 'WARNING: The particle weighting factor will be initialized with the given global weighting factor!'
            ELSE
              CALL Abort(__STAMP__,"not associated VarNamesParticles to be reset! StrVarNames(iVar)="//TRIM(StrVarNames(iVar))//&
              '. Note that initializing electronic DOF and vibrational molecular species with zero ist not imeplemted.')
            END IF ! TRIM(StrVarNames(iVar)).EQ.'Vibrational' .OR. TRIM(StrVarNames(iVar)).EQ.'Rotational'
          END IF ! .NOT.readVarFromState(iVar)
        END DO ! iVar=1,PartDataSize
      END IF ! changedVars

      ALLOCATE(PartData(PartDataSize_HDF5,offsetnPart+1_IK:offsetnPart+locnPart))
      CALL ReadArray('PartData',2,(/INT(PartDataSize_HDF5,IK),locnPart/),offsetnPart,2,RealArray=PartData)

      ! ------------------------------------------------
      ! DSMC-specific arrays
      ! ------------------------------------------------
      IF(useDSMC)THEN
        ! Polyatomic
        IF (DSMC%NumPolyatomMolecs.GT.0) THEN
          CALL DatasetExists(File_ID,'VibQuantData',VibQuantDataExists)
          IF (.NOT.VibQuantDataExists) CALL abort(__STAMP__,' Restart file does not contain "VibQuantData" (polyatomic data)')
          ALLOCATE(VibQuantData(MaxQuantNum,offsetnPart+1_IK:offsetnPart+locnPart))
          CALL ReadArray('VibQuantData',2,(/INT(MaxQuantNum,IK),locnPart/),offsetnPart,2,IntegerArray_i4=VibQuantData)
          !+1 is real number of necessary vib quants for the particle
        END IF

        ! Electronic
        IF (DSMC%ElectronicModel.EQ.2) THEN
          CALL DatasetExists(File_ID,'ElecDistriData',ElecDistriDataExists)
          IF (.NOT.ElecDistriDataExists) CALL abort(__STAMP__,' Restart file does not contain "ElecDistriData" (electronic data)')
          ALLOCATE(ElecDistriData(MaxElecQuant,offsetnPart+1_IK:offsetnPart+locnPart))
          CALL ReadArray('ElecDistriData',2,(/INT(MaxElecQuant,IK),locnPart/),offsetnPart,2,RealArray=ElecDistriData)
          !+1 is real number of necessary vib quants for the particle
        END IF

        ! Ambipolar Diffusion
        IF (DSMC%DoAmbipolarDiff) THEN
          CALL DatasetExists(File_ID,'ADVeloData',AD_DataExists)
          IF (.NOT.AD_DataExists) CALL abort(__STAMP__,' Restart file does not contain "ADVeloData" (ambipolar diffusion data)')
          ALLOCATE(AD_Data(3,offsetnPart+1_IK:offsetnPart+locnPart))
          CALL ReadArray('ADVeloData',2,(/INT(3,IK),locnPart/),offsetnPart,2,RealArray=AD_Data)
          !+1 is real number of necessary vib quants for the particle
        END IF
      END IF ! useDSMC
    END IF ! PartDataExists
  END IF ! PartIntExits

  CALL CloseDataFile()
#if USE_LOADBALANCE
END IF ! PerformLoadBalance
#endif /*USE_LOADBALANCE*/

END SUBROUTINE ParticleReadin

END MODULE MOD_Particle_Readin
