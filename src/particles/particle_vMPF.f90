!==================================================================================================================================
! Copyright (c) 2018 - 2019 Marcel Pfeiffer and Asim Mirza
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

MODULE MOD_vMPF
!===================================================================================================================================
! Module controlling particle number by merge and split routines
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
PUBLIC :: SplitMerge_main
!===================================================================================================================================

CONTAINS

SUBROUTINE SplitMerge_main()
!===================================================================================================================================
!> Main routine for split and merge particles
!> Loop over all elements:
!> 1.) build partindx list for cell
!> 2.) build partindx list for species
!> 3.) Call split or merge routine
!===================================================================================================================================
! MODULES
USE MOD_PARTICLE_Vars         ,ONLY: vMPFNewPartNum, PEM, nSpecies, PartSpecies,PDM
USE MOD_Mesh_Vars             ,ONLY: nElems
! IMPLICIT VARIABLE HANDLING
IMPLICIT NONE
!-----------------------------------------------------------------------------------------------------------------------------------
! INPUT VARIABLES
!-----------------------------------------------------------------------------------------------------------------------------------
! OUTPUT VARIABLES
!-----------------------------------------------------------------------------------------------------------------------------------
! LOCAL VARIABLES
INTEGER               :: iElem, iLoop, iPart, nPartCell, iSpec
INTEGER, ALLOCATABLE  :: iPartIndx_Node(:), nPart(:),iPartIndx_Node_Temp(:,:)
!===================================================================================================================================
ALLOCATE(nPart(nSpecies))
DO iElem = 1, nElems
  nPart(:) = 0
  nPartCell = PEM%pNumber(iElem)
  ALLOCATE(iPartIndx_Node_Temp(nSpecies,nPartCell))
  DO iSpec = 1, nSpecies
    iPartIndx_Node_Temp(iSpec,1:nPartCell) = 0
  END DO
  iPart = PEM%pStart(iElem)
  ! 1.) build partindx list for cell
  DO iLoop = 1, nPartCell
    IF (.NOT.PDM%ParticleInside(iPart)) THEN
      iPart = PEM%pNext(iPart)
      CYCLE
    END IF
    nPart(PartSpecies(iPart)) = nPart(PartSpecies(iPart)) + 1
    iPartIndx_Node_Temp(PartSpecies(iPart),nPart(PartSpecies(iPart))) = iPart
    iPart = PEM%pNext(iPart)
  END DO
  DO iSpec = 1, nSpecies
    IF (nPart(iSpec).LT.vMPFNewPartNum) CYCLE
  ! 2.) build partindx list for species
    ALLOCATE(iPartIndx_Node(nPart(iSpec)))
    DO iLoop = 1, nPart(iSpec)
      iPartIndx_Node(iLoop) = iPartIndx_Node_Temp(iSpec,iLoop)
    END DO
  ! 3.) Call split or merge routine
    CALL MergeParticles(iPartIndx_Node, nPart(iSpec), vMPFNewPartNum)
    DEALLOCATE(iPartIndx_Node)
  END DO
  DEALLOCATE(iPartIndx_Node_Temp)
END DO
DEALLOCATE(nPart)

END SUBROUTINE SplitMerge_main

SUBROUTINE MergeParticles(iPartIndx_Node, nPart, nPartNew)
!===================================================================================================================================
!> Routine for merge particles
!> 1.) Calc bulkvelocity (for momentum conservation)
!> 2.) Calc energy (for energy conservation)
!> 3.) Delete particles randomly (until nPartNew is reached)
!> 4.) Calc bulkvelocity after deleting
!> 5.) Calc energy after deleting
!> 6.) Ensuring momentum and energy conservation
!===================================================================================================================================
! MODULES
USE MOD_Particle_Vars         ,ONLY: PartState, PDM, PartMPF, PartSpecies, Species
USE MOD_part_tools            ,ONLY: GetParticleWeight
USE MOD_DSMC_Vars             ,ONLY: PartStateIntEn, CollisMode, SpecDSMC, DSMC
#ifdef CODE_ANALYZE
USE MOD_Globals               ,ONLY: unit_stdout,myrank,abort
USE MOD_Particle_Vars         ,ONLY: Symmetry
#endif /* CODE_ANALYZE */
! IMPLICIT VARIABLE HANDLING
IMPLICIT NONE
!-----------------------------------------------------------------------------------------------------------------------------------
! INPUT VARIABLES
INTEGER, INTENT(IN)                  :: nPart, nPartNew
INTEGER, INTENT(INOUT)                  :: iPartIndx_Node(:)
!-----------------------------------------------------------------------------------------------------------------------------------
! OUTPUT VARIABLES
!-----------------------------------------------------------------------------------------------------------------------------------
! LOCAL VARIABLES
REAL                  :: V_rel(3), vmag2, iRan, vBulk(3), EOld
INTEGER               :: iLoop, nDelete, nTemp, iPart, iPartIndx_NodeTMP(nPart),iSpec
REAL                  :: partWeight, totalWeight, vBulkTmp(3), ENew, alpha
REAL                  :: EOld_Inner,ENew_Inner
#ifdef CODE_ANALYZE
REAL                  :: Energy_old, Momentum_old(3),Energy_new, Momentum_new(3)
INTEGER               :: iMomDim, iMom
#endif /* CODE_ANALYZE */
!===================================================================================================================================
vBulk = 0.0; totalWeight = 0.0; EOld = 0.
EOld_Inner = 0.0

#ifdef CODE_ANALYZE
Energy_old = 0.0; Energy_new = 0.0; Momentum_old = 0.0; Momentum_new = 0.0
#endif /* CODE_ANALYZE */

! 1.) calc bulkvelocity (for momentum conservation)
DO iLoop = 1, nPart
  partWeight = GetParticleWeight(iPartIndx_Node(iLoop))
  totalWeight = totalWeight + partWeight
  vBulk(1:3) = vBulk(1:3) + PartState(4:6,iPartIndx_Node(iLoop)) * partWeight
  iSpec = PartSpecies(iPartIndx_Node(iLoop))

#ifdef CODE_ANALYZE
  ! Energy conservation
  Energy_old = Energy_old + 0.5 * Species(iSpec)%MassIC &
  * DOT_PRODUCT(PartState(4:6,iPartIndx_Node(iLoop)),PartState(4:6,iPartIndx_Node(iLoop))) * partWeight
  IF(CollisMode.GT.1) THEN
    IF((SpecDSMC(iSpec)%InterID.EQ.2).OR.(SpecDSMC(iSpec)%InterID.EQ.20)) THEN
      Energy_old = Energy_old + (PartStateIntEn(1,iPartIndx_Node(iLoop)) +  PartStateIntEn(2,iPartIndx_Node(iLoop))) * partWeight
    END IF
    IF(DSMC%ElectronicModel.GT.0) Energy_old = Energy_old + PartStateIntEn(3,iPartIndx_Node(iLoop))*partWeight
  END IF
  ! Momentum conservation
  Momentum_old(1:3) = Momentum_old(1:3) + Species(iSpec)%MassIC * PartState(4:6,iPartIndx_Node(iLoop)) * partWeight
#endif /* CODE_ANALYZE */

END DO
vBulk(1:3) = vBulk(1:3) / totalWeight

! 2.) calc energy (for energy conservation)
DO iLoop = 1, nPart
  partWeight = GetParticleWeight(iPartIndx_Node(iLoop))
  iSpec = PartSpecies(iPartIndx_Node(iLoop))
  V_rel(1:3)=PartState(4:6,iPartIndx_Node(iLoop))-vBulk(1:3)
  vmag2 = V_rel(1)**2 + V_rel(2)**2 + V_rel(3)**2
  EOld = EOld + 0.5 * vmag2 * partWeight * Species(iSpec)%MassIC
  IF(CollisMode.GT.1) THEN
    IF((SpecDSMC(iSpec)%InterID.EQ.2).OR.(SpecDSMC(iSpec)%InterID.EQ.20)) THEN
      ! Rotational and vibrational energy
      EOld_Inner = EOld_Inner + partWeight * (PartStateIntEn(1,iPartIndx_Node(iLoop)) +  PartStateIntEn(2,iPartIndx_Node(iLoop)))
    END IF
    ! Electronic energy
    IF(DSMC%ElectronicModel.GT.0.AND.SpecDSMC(iSpec)%InterID.NE.4) EOld_Inner = EOld_Inner + partWeight * PartStateIntEn(3,iPartIndx_Node(iLoop))
  END IF
END DO

! 3.) delete particles randomly (until nPartNew is reached)
iPartIndx_NodeTMP = iPartIndx_Node
nTemp = nPart
nDelete = nPart - nPartNew
DO iLoop = 1, nDelete
  CALL RANDOM_NUMBER(iRan)
  iPart = INT(iRan*nTemp) + 1
  PDM%ParticleInside(iPartIndx_Node(iPart)) = .FALSE.
  iPartIndx_Node(iPart) = iPartIndx_Node(nTemp)
  nTemp = nTemp - 1
END DO

! 4.) calc bulkvelocity after deleting and set new MPF
vBulkTmp = 0.
DO iLoop = 1, nPartNew
  PartMPF(iPartIndx_Node(iLoop)) = totalWeight / REAL(nPartNew)
  partWeight = GetParticleWeight(iPartIndx_Node(iLoop))
  vBulkTmp(1:3) = vBulkTmp(1:3) + PartState(4:6,iPartIndx_Node(iLoop)) * partWeight
END DO
vBulkTmp(1:3) = vBulkTmp(1:3) / totalWeight

! 5.) calc energy after deleting
ENew = 0.
ENew_Inner=0.
totalWeight=0.0
DO iLoop = 1, nPartNew
  partWeight = GetParticleWeight(iPartIndx_Node(iLoop))
  iSpec = PartSpecies(iPartIndx_Node(iLoop))
  totalWeight = totalWeight + partWeight
  V_rel(1:3)=PartState(4:6,iPartIndx_Node(iLoop))-vBulkTmp(1:3)
  vmag2 = V_rel(1)**2 + V_rel(2)**2 + V_rel(3)**2
  ENew = ENew + 0.5 * vmag2 * partWeight * Species(iSpec)%MassIC
  IF(CollisMode.GT.1) THEN
    IF((SpecDSMC(iSpec)%InterID.EQ.2).OR.(SpecDSMC(iSpec)%InterID.EQ.20)) THEN
      ! Rotational and vibrational energy
      ENew_Inner = ENew_Inner + partWeight * (PartStateIntEn(1,iPartIndx_Node(iLoop)) + PartStateIntEn(2,iPartIndx_Node(iLoop)))
    END IF
    ! Electronic energy
    IF(DSMC%ElectronicModel.GT.0.AND.SpecDSMC(iSpec)%InterID.NE.4) ENew_Inner = ENew_Inner + partWeight * PartStateIntEn(3,iPartIndx_Node(iLoop))
  END IF
END DO

! 6.) ensuring momentum and energy conservation
IF(EOld+EOld_Inner-ENew_Inner.GT.0.0) THEN
  alpha = SQRT((EOld+EOld_Inner-ENew_Inner)/ENew)
  DO iLoop = 1, nPartNew
    PartState(4:6,iPartIndx_Node(iLoop)) = vBulk(1:3) + alpha*(PartState(4:6,iPartIndx_Node(iLoop))-vBulkTmp(1:3))

#ifdef CODE_ANALYZE
    partWeight = GetParticleWeight(iPartIndx_Node(iLoop))
    iSpec = PartSpecies(iPartIndx_Node(iLoop))
    ! Energy conservation
    Energy_new = Energy_new + 0.5*Species(iSpec)%MassIC &
    * DOT_PRODUCT(PartState(4:6,iPartIndx_Node(iLoop)),PartState(4:6,iPartIndx_Node(iLoop))) * partWeight
    IF(CollisMode.GT.1) THEN
      IF((SpecDSMC(iSpec)%InterID.EQ.2).OR.(SpecDSMC(iSpec)%InterID.EQ.20)) THEN
        Energy_new = Energy_new + (PartStateIntEn(1,iPartIndx_Node(iLoop)) + PartStateIntEn(2,iPartIndx_Node(iLoop))) * partWeight
      END IF
      IF(DSMC%ElectronicModel.GT.0) Energy_new = Energy_new + PartStateIntEn(3,iPartIndx_Node(iLoop))*partWeight
    END IF
    ! Momentum conservation
    Momentum_new(1:3) = Momentum_new(1:3) + Species(iSpec)%MassIC * PartState(4:6,iPartIndx_Node(iLoop)) * partWeight
#endif /* CODE_ANALYZE */

  END DO
ELSE
  alpha = 0
  DO iLoop = 1, nPartNew
    PartState(4:6,iPartIndx_Node(iLoop)) = vBulk(1:3) + alpha*(PartState(4:6,iPartIndx_Node(iLoop))-vBulkTmp(1:3))
#ifdef CODE_ANALYZE
    partWeight = GetParticleWeight(iPartIndx_Node(iLoop))
    iSpec = PartSpecies(iPartIndx_Node(iLoop))
    ! Energy conservation
    Energy_new = Energy_new + 0.5*Species(iSpec)%MassIC &
    * DOT_PRODUCT(PartState(4:6,iPartIndx_Node(iLoop)),PartState(4:6,iPartIndx_Node(iLoop))) * partWeight
    IF(CollisMode.GT.1) THEN
      IF((SpecDSMC(iSpec)%InterID.EQ.2).OR.(SpecDSMC(iSpec)%InterID.EQ.20)) THEN
        Energy_new = Energy_new + (PartStateIntEn(1,iPartIndx_Node(iLoop)) + PartStateIntEn(2,iPartIndx_Node(iLoop))) * partWeight
      END IF
      IF(DSMC%ElectronicModel.GT.0) Energy_new = Energy_new + PartStateIntEn(3,iPartIndx_Node(iLoop))*partWeight
    END IF
    ! Momentum conservation
    Momentum_new(1:3) = Momentum_new(1:3) + Species(iSpec)%MassIC * PartState(4:6,iPartIndx_Node(iLoop)) * partWeight
#endif /* CODE_ANALYZE */
  END DO
END IF ! EOld+EOld_Inner-ENew_Inner.GT.0.0

#ifdef CODE_ANALYZE
  ! Check for energy difference
  IF (.NOT.ALMOSTEQUALRELATIVE(Energy_old,Energy_new,1.0e-12)) THEN
    WRITE(UNIT_StdOut,*) '\n'
    IPWRITE(UNIT_StdOut,'(I0,A,ES25.14E3)')    " Energy_old             : ",Energy_old
    IPWRITE(UNIT_StdOut,'(I0,A,ES25.14E3)')    " Energy_new             : ",Energy_new
    IPWRITE(UNIT_StdOut,'(I0,A,ES25.14E3)')    " abs. Energy difference : ",Energy_new-Energy_old
    IPWRITE(UNIT_StdOut,'(I0,A,ES25.14E3)')    " alpha                  : ",alpha
    ASSOCIATE( energy => MAX(ABS(Energy_old),ABS(Energy_new)) )
      IF(energy.GT.0.0)THEN
        IPWRITE(UNIT_StdOut,'(I0,A,ES25.14E3)')" rel. Energy difference : ",(Energy_new-Energy_old)/energy
      END IF
    END ASSOCIATE
    IPWRITE(UNIT_StdOut,'(I0,A,ES25.14E3)')    " Applied tolerance      : ",1.0e-12
    IPWRITE(UNIT_StdOut,*)                     " Old/new particle number: ", nPart, nPartNew
    IPWRITE(UNIT_StdOut,*)                     " Species                : ", iSpec
    CALL abort(&
        __STAMP__&
        ,'CODE_ANALYZE: part merge is not energy conserving!')
  END IF
  ! Check for momentum difference
  IF(Symmetry%Order.EQ.3) THEN
    ! Do not check the momentum in z as it can be very small (close to machine precision), leading to greater relative errors
    iMomDim = 3
  ELSE IF(Symmetry%Order.EQ.2) THEN
    iMomDim = 2
  ELSE
    iMomDim = 1
  END IF
  DO iMom=1,iMomDim
    IF (.NOT.ALMOSTEQUALRELATIVE(Momentum_old(iMom),Momentum_new(iMom),1.0e-10)) THEN
      WRITE(UNIT_StdOut,*) '\n'
      IPWRITE(UNIT_StdOut,'(I0,A,I0)')           " Direction (x,y,z)        : ",iMom
      IPWRITE(UNIT_StdOut,'(I0,A,ES25.14E3)')    " Momentum_old             : ",Momentum_old(iMom)
      IPWRITE(UNIT_StdOut,'(I0,A,ES25.14E3)')    " Momentum_new             : ",Momentum_new(iMom)
      IPWRITE(UNIT_StdOut,'(I0,A,ES25.14E3)')    " abs. Momentum difference : ",Momentum_new(iMom)-Momentum_old(iMom)
      ASSOCIATE( Momentum => MAX(ABS(Momentum_old(iMom)),ABS(Momentum_new(iMom))) )
        IF(Momentum.GT.0.0)THEN
          IPWRITE(UNIT_StdOut,'(I0,A,ES25.14E3)')" rel. Momentum difference : ",(Momentum_new(iMom)-Momentum_old(iMom))/Momentum
        END IF
      END ASSOCIATE
      IPWRITE(UNIT_StdOut,'(I0,A,ES25.14E3)')    " Applied tolerance      : ",1.0e-10
      CALL abort(&
          __STAMP__&
          ,'CODE_ANALYZE: part merge is not momentum conserving!')
    END IF
  END DO
#endif /* CODE_ANALYZE */


END SUBROUTINE MergeParticles

SUBROUTINE MergeParticles_New(iPartIndx_Node, nPart, nPartNew)
!===================================================================================================================================
!> Routine for merge particles
!> 1.) Calc bulkvelocity v_bulk (for momentum conservation)
!> 2.) Calc temperature, energy and degree of fredoms (for energy conservation)
!> 2.1) T_trans, E_trans
!> 2.2) T_elec, E_elec, DOF_elec
!> 2.3) T_vib, E_vib, DOF_vib
!> 2.4) T_rot, E_rot, DOF_rot
!> 3.) Delete particles randomly (until nPartNew is reached)
!> 4.) Calc bulkvelocity v_bulk_new after deleting
!> 5.) Calc energy after deleting
!> 5.1) E_trans_new
!> 5.2) E_elec_new
!> 5.3) E_vib_new
!> 5.4) E_rot_new
!> 6.) Ensuring momentum and energy conservation
!===================================================================================================================================
! MODULES
USE MOD_Particle_Vars         ,ONLY: PartState, PDM, PartMPF, PartSpecies, Species
USE MOD_part_tools            ,ONLY: GetParticleWeight
USE MOD_DSMC_Vars             ,ONLY: PartStateIntEn, CollisMode, SpecDSMC, DSMC
!USE MOD_Macro_Restart       ,ONLY: CalcEElec_particle
USE MOD_DSMC_Analyze        ,ONLY: CalcTelec

#ifdef CODE_ANALYZE
USE MOD_Globals               ,ONLY: unit_stdout,myrank,abort
USE MOD_Particle_Vars         ,ONLY: Symmetry
#endif /* CODE_ANALYZE */
! IMPLICIT VARIABLE HANDLING
IMPLICIT NONE
!-----------------------------------------------------------------------------------------------------------------------------------
! INPUT VARIABLES
INTEGER, INTENT(IN)                  :: nPart, nPartNew
INTEGER, INTENT(INOUT)                  :: iPartIndx_Node(:)
!-----------------------------------------------------------------------------------------------------------------------------------
! OUTPUT VARIABLES
!-----------------------------------------------------------------------------------------------------------------------------------
! LOCAL VARIABLES
REAL                  :: iRan, EOld
INTEGER               :: iLoop, nDelete, nTemp, iPart, iPartIndx_NodeTMP(nPart),iSpec
REAL                  :: partWeight, totalWeight, vBulkTmp(3), ENew, alpha
REAL                  :: EOld_Inner,ENew_Inner
REAL                  :: V_rel(3), vmag2, vBulk(3)
REAL                  :: V_rel_new(3), vmag2_new, vBulk_new(3)
REAL                  :: T_trans, T_elec, T_vib, T_rot, DOF_elec, DOF_vib, DOF_rot
REAL                  :: E_trans, E_trans_new
REAL                  :: E_elec, E_elec_new
REAL                  :: E_vib, E_vib_new
REAL                  :: E_rot, E_rot_new
#ifdef CODE_ANALYZE
REAL                  :: Energy_old, Momentum_old(3),Energy_new, Momentum_new(3)
INTEGER               :: iMomDim, iMom
#endif /* CODE_ANALYZE */
!===================================================================================================================================
vBulk = 0.0; vBulk_new = 0.0;  totalWeight = 0.0
E_trans = 0.0; E_trans_new = 0.0
E_elec = 0.0; E_elec_new = 0.0; DOF_elec = 0.0
E_vib = 0.0; E_vib_new = 0.0; DOF_vib = 0.0
E_rot = 0.0; E_rot_new = 0.0; DOF_rot = 0.0
iSpec = PartSpecies(iPartIndx_Node(1))  ! in iPartIndx_Node all particles are from same species

EOld_Inner = 0.0; EOld = 0.

#ifdef CODE_ANALYZE
Energy_old = 0.0; Energy_new = 0.0; Momentum_old = 0.0; Momentum_new = 0.0
#endif /* CODE_ANALYZE */

! 1.) calc bulkvelocity (for momentum conservation)
DO iLoop = 1, nPart
  partWeight = GetParticleWeight(iPartIndx_Node(iLoop))
  totalWeight = totalWeight + partWeight
  vBulk(1:3) = vBulk(1:3) + PartState(4:6,iPartIndx_Node(iLoop)) * partWeight

#ifdef CODE_ANALYZE
  ! Energy conservation
  Energy_old = Energy_old + 0.5 * Species(iSpec)%MassIC &
  * DOT_PRODUCT(PartState(4:6,iPartIndx_Node(iLoop)),PartState(4:6,iPartIndx_Node(iLoop))) * partWeight
  IF(CollisMode.GT.1) THEN
    IF((SpecDSMC(iSpec)%InterID.EQ.2).OR.(SpecDSMC(iSpec)%InterID.EQ.20)) THEN
      Energy_old = Energy_old + (PartStateIntEn(1,iPartIndx_Node(iLoop)) +  PartStateIntEn(2,iPartIndx_Node(iLoop))) * partWeight
    END IF
    IF(DSMC%ElectronicModel.GT.0) Energy_old = Energy_old + PartStateIntEn(3,iPartIndx_Node(iLoop))*partWeight
  END IF
  ! Momentum conservation
  Momentum_old(1:3) = Momentum_old(1:3) + Species(iSpec)%MassIC * PartState(4:6,iPartIndx_Node(iLoop)) * partWeight
#endif /* CODE_ANALYZE */

END DO
vBulk(1:3) = vBulk(1:3) / totalWeight

! 2.) Calc energy, temperature and degree of fredoms (for energy conservation)
! 2.1) Calc energy
DO iLoop = 1, nPart
  partWeight = GetParticleWeight(iPartIndx_Node(iLoop))
  V_rel(1:3)=PartState(4:6,iPartIndx_Node(iLoop))-vBulk(1:3)
  vmag2 = V_rel(1)**2 + V_rel(2)**2 + V_rel(3)**2
!  u2 = u2 + vmag2*partWeight
  E_trans = E_trans + 0.5 * vmag2 * partWeight * Species(iSpec)%MassIC
  IF(CollisMode.GT.1) THEN
    IF((SpecDSMC(iSpec)%InterID.EQ.2).OR.(SpecDSMC(iSpec)%InterID.EQ.20)) THEN
      ! Rotational and vibrational energy
      E_vib = E_vib + (PartStateIntEn(1,iPartIndx_Node(iLoop)) - SpecDSMC(iSpec)%EZeroPoint) * partWeight 
      E_rot = E_rot + partWeight * PartStateIntEn(2,iPartIndx_Node(iLoop))
    END IF
    ! Electronic energy
    IF(DSMC%ElectronicModel.GT.0.AND.SpecDSMC(iSpec)%InterID.NE.4) THEN
      E_elec = E_elec + partWeight * PartStateIntEn(3,iPartIndx_Node(iLoop))
    END IF
  END IF
END DO

! 2.2) Calc temperature and degree of fredoms
!u2 = u2 / (totalWeight - totalWeight2/totalWeight)
!CellTemp = Species(1)%MassIC * u2 / (3.0*BoltzmannConst)
IF(CollisMode.GT.1) THEN
  IF((SpecDSMC(iSpec)%InterID.EQ.2).OR.(SpecDSMC(iSpec)%InterID.EQ.20)) THEN
    IF(SpecDSMC(iSpec)%PolyatomicMol) THEN        
      iPolyatMole = SpecDSMC(iSpec)%SpecToPolyArray
      T_vib = CalcTVibPoly(E_vib/totalWeight, iSpec)
      IF (T_vib.GT.0.0) THEN
        DO iDOF = 1, PolyatomMolDSMC(iPolyatMole)%VibDOF
          DOF_vib= DOF_vib + 2.*PolyatomMolDSMC(iPolyatMole)%CharaTVibDOF(iDOF)/T_vib &
                              /(EXP(PolyatomMolDSMC(iPolyatMole)%CharaTVibDOF(iDOF)/T_vib) - 1.)
        END DO
      END IF
    ELSE
      T_vib=E_vib / (totalWeight*BoltzmannConst*SpecDSMC(iSpec)%CharaTVib)
      IF (T_vib.GT.0.0) THEN
        T_vib= SpecDSMC(iSpec)%CharaTVib/LOG(1. + 1./(T_vib))
        DOF_vib = 2.* E_vib / (totalWeight*BoltzmannConst*T_vib)
      END IF
    END IF
    DOF_rot = SpecDSMC(iSpec)%Xi_Rot
    T_rot = 2.*E_rot/(DOF_rot*totalWeight*BoltzmannConst)    
  END IF
  IF(DSMC%ElectronicModel.GT.0.AND.SpecDSMC(iSpec)%InterID.NE.4) THEN
    T_elec = CalcTelec(E_elec/totalWeight, iSpec)
    IF (T_elec.GT.0.0) DOF_elec = 2.*E_elec/(totalWeight*BoltzmannConst*T_elec)
  END IF
END IF

! 3.) delete particles randomly (until nPartNew is reached)
iPartIndx_NodeTMP = iPartIndx_Node
nTemp = nPart
nDelete = nPart - nPartNew
DO iLoop = 1, nDelete
  CALL RANDOM_NUMBER(iRan)
  iPart = INT(iRan*nTemp) + 1
  PDM%ParticleInside(iPartIndx_Node(iPart)) = .FALSE.
  iPartIndx_Node(iPart) = iPartIndx_Node(nTemp)
  nTemp = nTemp - 1
END DO





! 4.) calc bulkvelocity after deleting and set new MPF
vBulkTmp = 0.
DO iLoop = 1, nPartNew
  PartMPF(iPartIndx_Node(iLoop)) = totalWeight / REAL(nPartNew)
  partWeight = GetParticleWeight(iPartIndx_Node(iLoop))
  vBulkTmp(1:3) = vBulkTmp(1:3) + PartState(4:6,iPartIndx_Node(iLoop)) * partWeight
END DO
vBulkTmp(1:3) = vBulkTmp(1:3) / totalWeight

! 5.) calc energy after deleting

!totalWeight=0.0
DO iLoop = 1, nPartNew
  partWeight = GetParticleWeight(iPartIndx_Node(iLoop))
!  totalWeight = totalWeight + partWeight
  V_rel(1:3)=PartState(4:6,iPartIndx_Node(iLoop))-vBulkTmp(1:3)
  vmag2 = V_rel(1)**2 + V_rel(2)**2 + V_rel(3)**2
  E_trans_new = E_trans_new + 0.5 * vmag2 * partWeight * Species(iSpec)%MassIC
  IF(CollisMode.GT.1) THEN
    IF((SpecDSMC(iSpec)%InterID.EQ.2).OR.(SpecDSMC(iSpec)%InterID.EQ.20)) THEN
      ! Rotational and vibrational energy
      E_vib_new = E_vib_new + (PartStateIntEn(1,iPartIndx_Node(iLoop)) - SpecDSMC(iSpec)%EZeroPoint) * partWeight 
      E_rot_new = E_rot_new + partWeight * PartStateIntEn(2,iPartIndx_Node(iLoop))
    END IF
    ! Electronic energy
    IF(DSMC%ElectronicModel.GT.0.AND.SpecDSMC(iSpec)%InterID.NE.4) THEN
      E_elec_new = E_elec_new + partWeight * PartStateIntEn(3,iPartIndx_Node(iLoop))
    END IF
  END IF
END DO


IF(CollisMode.GT.1) THEN
  IF(DSMC%ElectronicModel.GT.0.AND.SpecDSMC(iSpec)%InterID.NE.4) THEN
    IF (E_elec.GT.0.0) THEN
      IF (E_elec_new.EQ.0.0) THEN
        DO iLoop = 1, nPartNew
          iPart = iPartIndx_Node(iLoop)
          CALL RANDOM_NUMBER(iRan)
          PartStateIntEn( 3,iPart) = -LOG(iRan)*DOF_elec/2.*T_elec*BoltzmannConst
        END DO        
      END IF
    END IF
  END IF
END IF



!!!! 6.) ensuring momentum and energy conservation
!!!IF(EOld+EOld_Inner-ENew_Inner.GT.0.0) THEN
!!!  alpha = SQRT((EOld+EOld_Inner-ENew_Inner)/ENew)
!!!  DO iLoop = 1, nPartNew
!!!    PartState(4:6,iPartIndx_Node(iLoop)) = vBulk(1:3) + alpha*(PartState(4:6,iPartIndx_Node(iLoop))-vBulkTmp(1:3))

!!!#ifdef CODE_ANALYZE
!!!    partWeight = GetParticleWeight(iPartIndx_Node(iLoop))
!!!    ! Energy conservation
!!!    Energy_new = Energy_new + 0.5*Species(iSpec)%MassIC &
!!!    * DOT_PRODUCT(PartState(4:6,iPartIndx_Node(iLoop)),PartState(4:6,iPartIndx_Node(iLoop))) * partWeight
!!!    IF(CollisMode.GT.1) THEN
!!!      IF((SpecDSMC(iSpec)%InterID.EQ.2).OR.(SpecDSMC(iSpec)%InterID.EQ.20)) THEN
!!!        Energy_new = Energy_new + (PartStateIntEn(1,iPartIndx_Node(iLoop)) + PartStateIntEn(2,iPartIndx_Node(iLoop))) * partWeight
!!!      END IF
!!!      IF(DSMC%ElectronicModel.GT.0) Energy_new = Energy_new + PartStateIntEn(3,iPartIndx_Node(iLoop))*partWeight
!!!    END IF
!!!    ! Momentum conservation
!!!    Momentum_new(1:3) = Momentum_new(1:3) + Species(iSpec)%MassIC * PartState(4:6,iPartIndx_Node(iLoop)) * partWeight
!!!#endif /* CODE_ANALYZE */

!!!  END DO
!!!ELSE
!!!  alpha = 0
!!!  DO iLoop = 1, nPartNew
!!!    PartState(4:6,iPartIndx_Node(iLoop)) = vBulk(1:3) + alpha*(PartState(4:6,iPartIndx_Node(iLoop))-vBulkTmp(1:3))
!!!#ifdef CODE_ANALYZE
!!!    partWeight = GetParticleWeight(iPartIndx_Node(iLoop))
!!!    ! Energy conservation
!!!    Energy_new = Energy_new + 0.5*Species(iSpec)%MassIC &
!!!    * DOT_PRODUCT(PartState(4:6,iPartIndx_Node(iLoop)),PartState(4:6,iPartIndx_Node(iLoop))) * partWeight
!!!    IF(CollisMode.GT.1) THEN
!!!      IF((SpecDSMC(iSpec)%InterID.EQ.2).OR.(SpecDSMC(iSpec)%InterID.EQ.20)) THEN
!!!        Energy_new = Energy_new + (PartStateIntEn(1,iPartIndx_Node(iLoop)) + PartStateIntEn(2,iPartIndx_Node(iLoop))) * partWeight
!!!      END IF
!!!      IF(DSMC%ElectronicModel.GT.0) Energy_new = Energy_new + PartStateIntEn(3,iPartIndx_Node(iLoop))*partWeight
!!!    END IF
!!!    ! Momentum conservation
!!!    Momentum_new(1:3) = Momentum_new(1:3) + Species(iSpec)%MassIC * PartState(4:6,iPartIndx_Node(iLoop)) * partWeight
!!!#endif /* CODE_ANALYZE */
!!!  END DO
!!!END IF ! EOld+EOld_Inner-ENew_Inner.GT.0.0

#ifdef CODE_ANALYZE
  ! Check for energy difference
  IF (.NOT.ALMOSTEQUALRELATIVE(Energy_old,Energy_new,1.0e-12)) THEN
    WRITE(UNIT_StdOut,*) '\n'
    IPWRITE(UNIT_StdOut,'(I0,A,ES25.14E3)')    " Energy_old             : ",Energy_old
    IPWRITE(UNIT_StdOut,'(I0,A,ES25.14E3)')    " Energy_new             : ",Energy_new
    IPWRITE(UNIT_StdOut,'(I0,A,ES25.14E3)')    " abs. Energy difference : ",Energy_new-Energy_old
    IPWRITE(UNIT_StdOut,'(I0,A,ES25.14E3)')    " alpha                  : ",alpha
    ASSOCIATE( energy => MAX(ABS(Energy_old),ABS(Energy_new)) )
      IF(energy.GT.0.0)THEN
        IPWRITE(UNIT_StdOut,'(I0,A,ES25.14E3)')" rel. Energy difference : ",(Energy_new-Energy_old)/energy
      END IF
    END ASSOCIATE
    IPWRITE(UNIT_StdOut,'(I0,A,ES25.14E3)')    " Applied tolerance      : ",1.0e-12
    IPWRITE(UNIT_StdOut,*)                     " Old/new particle number: ", nPart, nPartNew
    IPWRITE(UNIT_StdOut,*)                     " Species                : ", iSpec
    CALL abort(&
        __STAMP__&
        ,'CODE_ANALYZE: part merge is not energy conserving!')
  END IF
  ! Check for momentum difference
  IF(Symmetry%Order.EQ.3) THEN
    ! Do not check the momentum in z as it can be very small (close to machine precision), leading to greater relative errors
    iMomDim = 3
  ELSE IF(Symmetry%Order.EQ.2) THEN
    iMomDim = 2
  ELSE
    iMomDim = 1
  END IF
  DO iMom=1,iMomDim
    IF (.NOT.ALMOSTEQUALRELATIVE(Momentum_old(iMom),Momentum_new(iMom),1.0e-10)) THEN
      WRITE(UNIT_StdOut,*) '\n'
      IPWRITE(UNIT_StdOut,'(I0,A,I0)')           " Direction (x,y,z)        : ",iMom
      IPWRITE(UNIT_StdOut,'(I0,A,ES25.14E3)')    " Momentum_old             : ",Momentum_old(iMom)
      IPWRITE(UNIT_StdOut,'(I0,A,ES25.14E3)')    " Momentum_new             : ",Momentum_new(iMom)
      IPWRITE(UNIT_StdOut,'(I0,A,ES25.14E3)')    " abs. Momentum difference : ",Momentum_new(iMom)-Momentum_old(iMom)
      ASSOCIATE( Momentum => MAX(ABS(Momentum_old(iMom)),ABS(Momentum_new(iMom))) )
        IF(Momentum.GT.0.0)THEN
          IPWRITE(UNIT_StdOut,'(I0,A,ES25.14E3)')" rel. Momentum difference : ",(Momentum_new(iMom)-Momentum_old(iMom))/Momentum
        END IF
      END ASSOCIATE
      IPWRITE(UNIT_StdOut,'(I0,A,ES25.14E3)')    " Applied tolerance      : ",1.0e-10
      CALL abort(&
          __STAMP__&
          ,'CODE_ANALYZE: part merge is not momentum conserving!')
    END IF
  END DO
#endif /* CODE_ANALYZE */


END SUBROUTINE MergeParticles_New

#ifdef WIP
SUBROUTINE CalculateDistMoments(iPartIndx_Node, nPart, vBulk, Vtherm2, PressTens, HeatVec, Energy)
!===================================================================================================================================
!> Calculation of distribution moments
!> 1.) Calc bulk velocity
!> 2.) Summing up the relative velocities and their squares to calculate the moments (PressTens, HeatVec)
!> 3.) Fill missing entries in PressTens
!===================================================================================================================================
! MODULES
USE MOD_Particle_Vars         ,ONLY: PartState
USE MOD_part_tools            ,ONLY: GetParticleWeight
! IMPLICIT VARIABLE HANDLING
IMPLICIT NONE
!-----------------------------------------------------------------------------------------------------------------------------------
! INPUT VARIABLES
INTEGER, INTENT(INOUT)                  :: nPart
INTEGER, INTENT(INOUT)                  :: iPartIndx_Node(:)
REAL, INTENT(INOUT)                       :: vBulk(3), Energy, Vtherm2, PressTens(3,3), HeatVec(3)
!-----------------------------------------------------------------------------------------------------------------------------------
! OUTPUT VARIABLES
!-----------------------------------------------------------------------------------------------------------------------------------
! LOCAL VARIABLES
REAL                  :: V_rel(3), vmag2
INTEGER               :: iLoop,fillMa1, fillMa2
REAL                  :: partWeight, totalWeight
!===================================================================================================================================
Vtherm2 = 0.0; PressTens = 0.0; HeatVec = 0.0
vBulk = 0.0; totalWeight = 0.0; Energy = 0.

! 1.) calc bulkvelocity
DO iLoop = 1, nPart
  partWeight = GetParticleWeight(iPartIndx_Node(iLoop))
  totalWeight = totalWeight + partWeight
  vBulk(1:3) = vBulk(1:3) + PartState(4:6,iPartIndx_Node(iLoop)) * partWeight
END DO
vBulk(1:3) = vBulk(1:3)/ totalWeight

! 2.) Summing up the relative velocities and their square to calculate the moments (PressTens, HeatVec)
DO iLoop = 1, nPart
  partWeight = GetParticleWeight(iPartIndx_Node(iLoop))
  V_rel(1:3)=PartState(4:6,iPartIndx_Node(iLoop))-vBulk(1:3)
  vmag2 = V_rel(1)**2 + V_rel(2)**2 + V_rel(3)**2
  Vtherm2 = Vtherm2 + vmag2 * partWeight
  DO fillMa1 =1, 3
    DO fillMa2 =fillMa1, 3
      PressTens(fillMa1, fillMa2)= PressTens(fillMa1, fillMa2) + V_rel(fillMa1)*V_rel(fillMa2) * partWeight
    END DO
  END DO
  HeatVec(1:3) = HeatVec(1:3) + V_rel(1:3)*vmag2 * partWeight
  Energy = Energy + 0.5 * vmag2 * partWeight
  ! sample inner energies here!
END DO
IF(nPart.GT.2) THEN
  HeatVec = HeatVec*nPart*nPart/((nPart-1.)*(nPart-2.)*totalWeight)
ELSE
  HeatVec = 0.0
END IF
Vtherm2 = Vtherm2*nPart/((nPart-1.)*totalWeight)
! 3.) Fill missing entries in PressTens
PressTens(2,1)=PressTens(1,2)
PressTens(3,1)=PressTens(1,3)
PressTens(3,2)=PressTens(2,3)
PressTens = PressTens/totalWeight

END SUBROUTINE CalculateDistMoments
#endif /*WIP*/

END MODULE MOD_vMPF
