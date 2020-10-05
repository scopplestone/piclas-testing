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

MODULE MOD_DSMC_ChemReact
!===================================================================================================================================
! Module for chemical reactions including calculation of probabilities and collisions
!===================================================================================================================================
! MODULES
! IMPLICIT VARIABLE HANDLING
IMPLICIT NONE
PRIVATE

INTERFACE DSMC_Chemistry
  MODULE PROCEDURE DSMC_Chemistry
END INTERFACE

INTERFACE simpleCEX
  MODULE PROCEDURE simpleCEX
END INTERFACE

INTERFACE simpleMEX
  MODULE PROCEDURE simpleMEX
END INTERFACE

INTERFACE CalcBackwardRate
  MODULE PROCEDURE CalcBackwardRate
END INTERFACE

!-----------------------------------------------------------------------------------------------------------------------------------
! GLOBAL VARIABLES
!-----------------------------------------------------------------------------------------------------------------------------------
! Private Part ---------------------------------------------------------------------------------------------------------------------
! Public Part ----------------------------------------------------------------------------------------------------------------------
PUBLIC :: DSMC_Chemistry, simpleCEX, simpleMEX, CalcReactionProb, CalcBackwardRate, CalcPartitionFunction
PUBLIC :: CalcPhotoIonizationNumber
!===================================================================================================================================

CONTAINS

SUBROUTINE CalcReactionProb(iPair,iReac,ReactionProb,nPair,NumDens)
!===================================================================================================================================
! Calculates the reaction probability for dissociation, exchange, recombination and associative ionization reactions
!===================================================================================================================================
! MODULES
USE MOD_Globals
USE MOD_Globals_Vars            ,ONLY: BoltzmannConst
USE MOD_DSMC_PolyAtomicModel    ,ONLY: Calc_Beta_Poly
USE MOD_DSMC_Vars               ,ONLY: Coll_pData, DSMC, SpecDSMC, PartStateIntEn, ChemReac, CollInf, ReactionProbGTUnityCounter
USE MOD_DSMC_Vars               ,ONLY: RadialWeighting
USE MOD_Particle_Vars           ,ONLY: PartState, Species, PartSpecies, nSpecies, VarTimeStep
USE MOD_DSMC_Analyze            ,ONLY: CalcTVibPoly, CalcTelec
USE MOD_part_tools              ,ONLY: GetParticleWeight
USE MOD_DSMC_QK_Chemistry       ,ONLY: QK_GetAnalyticRate
! IMPLICIT VARIABLE HANDLING
IMPLICIT NONE
!-----------------------------------------------------------------------------------------------------------------------------------
! INPUT VARIABLES
INTEGER, INTENT(IN)           :: iPair, nPair
REAL, INTENT(IN)              :: NumDens
!-----------------------------------------------------------------------------------------------------------------------------------
! OUTPUT VARIABLES
REAL, INTENT(OUT)             :: ReactionProb
!-----------------------------------------------------------------------------------------------------------------------------------
! IN-OUTPUT VARIABLES
INTEGER, INTENT(INOUT)        :: iReac
!-----------------------------------------------------------------------------------------------------------------------------------
! LOCAL VARIABLES
INTEGER                       :: ReactInx(1:3), ProductReac(1:3), EductReac(1:3), iReacForward, iCase, iPart
REAL                          :: EZeroPoint_Educt, EZeroPoint_Prod, EReact, ReducedMass, ReducedMassUnweighted, omega, Tref
REAL                          :: Xi_vib(1:3), Xi_elec(1:3), Xi_Total
REAL                          :: BetaReaction, BackwardRate
REAL                          :: Rcoll, Tcoll, Telec, TiQK, NumWeightEduct, NumWeightProd
INTEGER                       :: iPath, PathIndex
REAL                          :: Weight(1:3), SumWeightEduct, SumWeightProd
!===================================================================================================================================

IF(ChemReac%XSec_Procedure(iReac)) RETURN

Weight = 0.; ReactInx = 0
NumWeightEduct = 2.; NumWeightProd = 2.
SumWeightEduct = 0.; SumWeightProd = 0.

EductReac(1:3) = ChemReac%DefinedReact(iReac,1,1:3)
iCase = CollInf%Coll_Case(EductReac(1), EductReac(2))

IF(EductReac(3).NE.0) THEN
  IF(ChemReac%RecombParticle.EQ.0) THEN
    IF(iPair.LT.(nPair - ChemReac%nPairForRec)) THEN
      ChemReac%LastPairForRec = nPair - ChemReac%nPairForRec
      ReactInx(3) = Coll_pData(ChemReac%LastPairForRec)%iPart_p1
      ChemReac%RecombParticle = ReactInx(3)
    ELSE
      ReactInx(3) = 0
    END IF
  ELSE
    ReactInx(3) = ChemReac%RecombParticle
  END IF
  IF(ReactInx(3).GT.0) THEN
    NumWeightEduct = 3.
    EductReac(3) = PartSpecies(ReactInx(3))
    ! Determine the number of the reaction path for this collision pair with the help of the reaction index
    DO iPath = 1, ChemReac%CollCaseInfo(iCase)%NumOfReactionPaths
      IF(iReac.EQ.ChemReac%CollCaseInfo(iCase)%ReactionIndex(iPath)) PathIndex = iPath
    END DO
    iReac = ChemReac%ReactNumRecomb(EductReac(1), EductReac(2), EductReac(3))
    ! Save the new reaction index (depending on the third partner) for the case to be used in DSMC_Chemistry
    ChemReac%CollCaseInfo(iCase)%ReactionIndex(PathIndex) = iReac
  ELSE
    ! If no third collision partner can be found e.g. last (available) pair, set reaction probability to zero and leave routine
    ReactionProb = 0.
    RETURN
  END IF
END IF

! Saving the product species, might be different for the recombination case as reaction index could have changed depending on the
! third reaction partner
ProductReac(1:3) = ChemReac%DefinedReact(iReac,2,1:3)

IF (ChemReac%DefinedReact(iReac,1,1).EQ.PartSpecies(Coll_pData(iPair)%iPart_p1)) THEN
  ReactInx(1) = Coll_pData(iPair)%iPart_p1
  ReactInx(2) = Coll_pData(iPair)%iPart_p2
ELSE
  ReactInx(1) = Coll_pData(iPair)%iPart_p2
  ReactInx(2) = Coll_pData(iPair)%iPart_p1
END IF

DO iPart = 1, NINT(NumWeightEduct)
  Weight(iPart) = GetParticleWeight(ReactInx(iPart))
  SumWeightEduct = SumWeightEduct + Weight(iPart)
END DO

SumWeightProd = Weight(1) + Weight(2)
IF(ProductReac(3).NE.0) THEN
  NumWeightProd = 3.
  IF(EductReac(3).EQ.0) Weight(3) = Weight(1)
  SumWeightProd = SumWeightProd + Weight(3)
END IF

IF (RadialWeighting%DoRadialWeighting.OR.VarTimeStep%UseVariableTimeStep) THEN
  ReducedMass = (Species(EductReac(1))%MassIC *Weight(1)  * Species(EductReac(2))%MassIC * Weight(2)) &
    / (Species(EductReac(1))%MassIC * Weight(1)+ Species(EductReac(2))%MassIC * Weight(2))
  ReducedMassUnweighted = ReducedMass * 2./(Weight(1)+Weight(2))
ELSE
  ReducedMass = CollInf%MassRed(Coll_pData(iPair)%PairType)
  ReducedMassUnweighted = CollInf%MassRed(Coll_pData(iPair)%PairType)
END IF

!---------------------------------------------------------------------------------------------------------------------------------
! Calculation of the collision energy
!---------------------------------------------------------------------------------------------------------------------------------
Coll_pData(iPair)%Ec = 0.5 * ReducedMass*Coll_pData(iPair)%CRela2
DO iPart = 1, NINT(NumWeightEduct)
  Coll_pData(iPair)%Ec = Coll_pData(iPair)%Ec + PartStateIntEn(1,ReactInx(iPart))*Weight(iPart) &
                                              + PartStateIntEn(2,ReactInx(iPart))*Weight(iPart)
  IF (DSMC%ElectronicModel) Coll_pData(iPair)%Ec = Coll_pData(iPair)%Ec + PartStateIntEn(3,ReactInx(iPart))*Weight(iPart)
END DO
! Add the translational energy of the third particle in case of a recombination reaction
IF(EductReac(3).NE.0) THEN
  Coll_pData(iPair)%Ec = Coll_pData(iPair)%Ec + 0.5 * Species(EductReac(3))%MassIC * DOTPRODUCT(PartState(4:6,ReactInx(3)))
END IF
!---------------------------------------------------------------------------------------------------------------------------------
! Calculation of the zero-point-energies
!---------------------------------------------------------------------------------------------------------------------------------
EZeroPoint_Educt = 0.0; EZeroPoint_Prod = 0.0
DO iPart = 1, NINT(NumWeightEduct)
  IF((SpecDSMC(EductReac(iPart))%InterID.EQ.2).OR.(SpecDSMC(EductReac(iPart))%InterID.EQ.20)) THEN
    EZeroPoint_Educt = EZeroPoint_Educt + SpecDSMC(EductReac(iPart))%EZeroPoint * Weight(iPart)
  END IF
END DO
DO iPart = 1, NINT(NumWeightProd)
  IF((SpecDSMC(ProductReac(iPart))%InterID.EQ.2).OR.(SpecDSMC(ProductReac(iPart))%InterID.EQ.20)) THEN
    EZeroPoint_Prod = EZeroPoint_Prod + SpecDSMC(ProductReac(iPart))%EZeroPoint * Weight(iPart)
  END IF
END DO
!---------------------------------------------------------------------------------------------------------------------------------
! Calculation of the reaction probability, if collision energy minus the zero-point energy of the EDUCTS is greater than the
! activation energy AND collision energy minus the zero-point energy of the PRODUCTS is greater than the heat of formation
!---------------------------------------------------------------------------------------------------------------------------------
IF(((Coll_pData(iPair)%Ec-EZeroPoint_Educt).GE.(SumWeightEduct/NumWeightEduct*ChemReac%EActiv(iReac))) .AND. &
    ((Coll_pData(iPair)%Ec-EZeroPoint_Prod).GE.(-1.*SumWeightProd/NumWeightProd*ChemReac%EForm(iReac)))) THEN
  !---------------------------------------------------------------------------------------------------------------------------------
  ! Calculation of the vibrational degrees of freedom and electronic shell
  !---------------------------------------------------------------------------------------------------------------------------------
  Xi_vib = 0.0; Xi_elec = 0.0
  DO iPart = 1, NINT(NumWeightEduct)
    IF((SpecDSMC(EductReac(iPart))%InterID.EQ.2).OR.(SpecDSMC(EductReac(iPart))%InterID.EQ.20)) THEN
      IF(SpecDSMC(EductReac(iPart))%PolyatomicMol) THEN
        IF (PartStateIntEn(1,ReactInx(iPart)).GT.SpecDSMC(EductReac(iPart))%EZeroPoint) THEN
          Xi_vib(iPart) = 2.*(PartStateIntEn(1,ReactInx(iPart))-SpecDSMC(EductReac(iPart))%EZeroPoint)  &
                  / (BoltzmannConst*CalcTVibPoly(PartStateIntEn(1,ReactInx(iPart)), EductReac(iPart)))
        END IF
      ELSE
        Xi_vib(iPart) = ChemReac%MeanXiVib_PerIter(EductReac(iPart))
      END IF
    END IF
    IF (DSMC%ElectronicModel) THEN
      IF((SpecDSMC(EductReac(iPart))%InterID.NE.4).AND.(.NOT.SpecDSMC(EductReac(iPart))%FullyIonized)) THEN
        IF(PartStateIntEn(3,ReactInx(iPart)).GT.0.0)THEN
          Telec=CalcTelec( PartStateIntEn(3,ReactInx(iPart)) , EductReac(iPart))
          Xi_elec(iPart)=2.*PartStateIntEn(3,ReactInx(iPart))/(BoltzmannConst*Telec)
        END IF
      END IF
    END IF
  END DO
  !---------------------------------------------------------------------------------------------------------------------------------
  ! Determination of the total degree of freedom
  !---------------------------------------------------------------------------------------------------------------------------------
  omega = CollInf%omega(EductReac(1),EductReac(2))
  Tref = CollInf%Tref(EductReac(1),EductReac(2))
  Xi_Total = 2.*(2.-omega)
  DO iPart = 1, NINT(NumWeightEduct)
    Xi_Total = Xi_Total + Xi_elec(iPart) + Xi_vib(iPart) + SpecDSMC(EductReac(iPart))%Xi_Rot
  END DO
  IF(EductReac(3).NE.0) Xi_Total = Xi_Total + 3.
  ! Zero-point energy of educts is removed from the collision energy utilized for the calculation of the reaction probability
  EReact = NumWeightEduct*(Coll_pData(iPair)%Ec - EZeroPoint_Educt)/ SumWeightEduct
  ! Determination of the Beta coefficient (array for diatomic molecules, calculation for polyatomic)
  IF(.NOT.ChemReac%QKProcedure(iReac))THEN
    IF (SpecDSMC(EductReac(1))%PolyatomicMol.OR.SpecDSMC(EductReac(2))%PolyatomicMol           &
        .OR.SpecDSMC(ProductReac(1))%PolyatomicMol.OR.SpecDSMC(ProductReac(2))%PolyatomicMol) THEN
      BetaReaction = Calc_Beta_Poly(iReac,Xi_Total)
    ELSE
      IF((TRIM(ChemReac%ReactType(iReac)).EQ.'D').OR.(TRIM(ChemReac%ReactType(iReac)).EQ.'E')) THEN
        BetaReaction = ChemReac%ReactInfo(iReac)%Beta_Arrhenius(ChemReac%MeanEVibQua_PerIter(EductReac(1)), &
                                                                ChemReac%MeanEVibQua_PerIter(EductReac(2)))
      ELSE IF(TRIM(ChemReac%ReactType(iReac)).EQ.'R') THEN
        IF(SpecDSMC(EductReac(3))%PolyatomicMol) THEN
          BetaReaction = Calc_Beta_Poly(iReac,Xi_Total)
        ELSE
          BetaReaction = &
            ChemReac%ReactInfo(iReac)%Beta_Rec_Arrhenius(EductReac(3),ChemReac%MeanEVibQua_PerIter(EductReac(3)))
        END IF
      END IF
    END IF
  END IF
  !---------------------------------------------------------------------------------------------------------------------------------
  ! Calculation of the backward reaction rate coefficient and applying to Beta coefficient after Boyd "Modeling backward chemical
  ! rate processes in the direct simulation Monte Carlo method", Phys. Fluids 19, 1261103 (2007)
  !---------------------------------------------------------------------------------------------------------------------------------
  IF(DSMC%BackwardReacRate.AND.((iReac.GT.ChemReac%NumOfReact/2))) THEN
    iReacForward = iReac - ChemReac%NumOfReact/2
    IF(DSMC%InstantTransTemp(nSpecies+1).GT.0.0) THEN
      CALL CalcBackwardRate(iReac,DSMC%InstantTransTemp(nSpecies+1),BackwardRate)
      IF(TRIM(ChemReac%ReactType(iReac)).EQ.'E') THEN
        BetaReaction = BetaReaction * BackwardRate &
          / EXP(-(ChemReac%EActiv(iReacForward)-ChemReac%EActiv(iReac))/(BoltzmannConst*DSMC%InstantTransTemp(nSpecies+1))) &
          / (ChemReac%Arrhenius_Prefactor(iReac) * DSMC%InstantTransTemp(nSpecies+1)**ChemReac%Arrhenius_Powerfactor(iReac))
      END IF
    ELSE
      BackwardRate = 0.0
      BetaReaction = 0.0
    END IF
  END IF
  !---------------------------------------------------------------------------------------------------------------------------------
  ! Actual calculation of the reaction probability, different equation for recombination reaction
  !---------------------------------------------------------------------------------------------------------------------------------
  IF((TRIM(ChemReac%ReactType(iReac)).EQ.'R').OR.(TRIM(ChemReac%ReactType(iReac)).EQ.'r')) THEN
    IF(DSMC%BackwardReacRate.AND.((iReac.GT.ChemReac%NumOfReact/2))) THEN
      Tcoll =ReducedMassUnweighted*Coll_pData(iPair)%CRela2 / (BoltzmannConst * 2.*(2.-omega))
      Rcoll = (Tcoll / Tref)**(0.5 - omega) &
              * ChemReac%QKRColl(iCase) / SQRT(ReducedMassUnweighted) * ChemReac%QKTCollCorrFac(iCase)
      ReactionProb = BackwardRate / Rcoll * NumDens
    ELSE
      ! Reaction probability after regular TCE-model
      ReactionProb = BetaReaction * NumDens &
                * EReact**(ChemReac%Arrhenius_Powerfactor(iReac) - 0.5 + CollInf%omega(EductReac(3),EductReac(3)))
    END IF
  ELSE IF(TRIM(ChemReac%ReactType(iReac)).EQ.'iQK') THEN
    TiQK = (ReducedMassUnweighted*Coll_pData(iPair)%CRela2 + 2.*PartStateIntEn(3,ReactInx(1)))/((2.*(2.-omega) &
              + Xi_elec(1))*BoltzmannConst)
    Tcoll = ReducedMassUnweighted*Coll_pData(iPair)%CRela2 / (BoltzmannConst * 2.*(2.-omega))
    Rcoll = (Tcoll / Tref)**(0.5 - omega) * ChemReac%QKRColl(iCase) &
              / SQRT(ReducedMassUnweighted) * ChemReac%QKTCollCorrFac(iCase)
    ReactionProb = QK_GetAnalyticRate(iReac,TiQK) / Rcoll
  ELSE IF(TRIM(ChemReac%ReactType(iReac)).EQ.'D'.AND.ChemReac%QKProcedure(iReac)) THEN
    TiQK = (ReducedMassUnweighted*Coll_pData(iPair)%CRela2  &
              + 2.*PartStateIntEn(1,ReactInx(1)))/((2.*(2.-omega) + Xi_vib(1))*BoltzmannConst)
    Tcoll = ReducedMassUnweighted*Coll_pData(iPair)%CRela2 / (BoltzmannConst * 2.*(2.-omega))
    Rcoll = (Tcoll / Tref)**(0.5 - omega) * ChemReac%QKRColl(iCase) &
              / SQRT(ReducedMassUnweighted) * ChemReac%QKTCollCorrFac(iCase)
    ! Get the analytic forward rate for QK
    ReactionProb = QK_GetAnalyticRate(iReac,TiQK) / Rcoll
  ELSE
    IF(SpecDSMC(EductReac(2))%PolyatomicMol.OR.SpecDSMC(EductReac(1))%PolyatomicMol) THEN
      ! Energy is multiplied by a factor to increase the resulting exponent and avoid floating overflows for high vibrational
      ! degree of freedom, later the reaction probability is scaled again with the same factor and the respective exponents
      ReactionProb = BetaReaction * ((EReact - ChemReac%EActiv(iReac))*1E6) &
            ** (ChemReac%Arrhenius_Powerfactor(iReac)-1.5+omega+Xi_Total/2.) * (EReact * 1E6)**(1.0 - Xi_Total/2.)
      ReactionProb = ReactionProb / ((1E6)**(ChemReac%Arrhenius_Powerfactor(iReac) - 0.5 + omega))
    ELSE
      ReactionProb = BetaReaction * ((EReact - ChemReac%EActiv(iReac))) &
            ** (ChemReac%Arrhenius_Powerfactor(iReac) - 1.5 + omega + Xi_Total/2.) * (EReact) ** (1.0 - Xi_Total/2.)
    END IF
  END IF
ELSE
  ReactionProb = 0.0
END IF

IF(DSMC%ReservoirSimu) THEN
#if (PP_TimeDiscMethod==42)
  IF(DSMC%ReservoirRateStatistic) THEN
#endif
    IF((ReactionProb.GT.1).AND.(ReactionProbGTUnityCounter.LT.100)) THEN
      ReactionProbGTUnityCounter=ReactionProbGTUnityCounter+1
      IPWRITE(*,*) 'Warning: ReactionProb greater than unity! ReacNbr:', iReac,'    ReactionProb:',ReactionProb
      IF(ReactionProbGTUnityCounter.EQ.100)THEN
        IPWRITE(*,*) ' Counted 100 ReactionProb greater than unity. Turning this warning off.'
      END IF
    END IF
#if (PP_TimeDiscMethod==42)
  END IF
#endif
END IF

#if (PP_TimeDiscMethod==42)
IF (.NOT.DSMC%ReservoirRateStatistic) THEN
  ChemReac%NumReac(iReac) = ChemReac%NumReac(iReac) + ReactionProb
  ChemReac%ReacCount(iReac) = ChemReac%ReacCount(iReac) + 1
END IF
#endif

END SUBROUTINE CalcReactionProb


SUBROUTINE DSMC_Chemistry(iPair, iReac)
!===================================================================================================================================
! Routine performs an exchange reaction of the type A + B + C -> D + E + F, where A, B, C, D, E, F can be anything
!===================================================================================================================================
! MODULES
USE MOD_Globals                ,ONLY: abort
USE MOD_DSMC_Vars              ,ONLY: Coll_pData, DSMC_RHS, DSMC, CollInf, SpecDSMC, DSMCSumOfFormedParticles
USE MOD_DSMC_Vars              ,ONLY: ChemReac, PartStateIntEn, PolyatomMolDSMC, VibQuantsPar, RadialWeighting, BGGas
USE MOD_Particle_Vars          ,ONLY: PartSpecies, PartState, PDM, PEM, PartPosRef, Species, PartMPF, VarTimeStep
USE MOD_DSMC_ElectronicModel   ,ONLY: ElectronicEnergyExchange, CalcXiElec
USE MOD_DSMC_PolyAtomicModel   ,ONLY: DSMC_RotRelaxPoly, DSMC_RelaxVibPolyProduct
USE MOD_DSMC_Relaxation        ,ONLY: DSMC_VibRelaxDiatomic, CalcXiTotalEqui
USE MOD_DSMC_CollisVec         ,ONLY: PostCollVec
USE MOD_Particle_Tracking_Vars ,ONLY: DoRefmapping
USE MOD_Particle_Analyze_Vars  ,ONLY: ChemEnergySum
USE MOD_part_tools             ,ONLY: GetParticleWeight
USE MOD_part_operations        ,ONLY: RemoveParticle
#ifdef CODE_ANALYZE
USE MOD_Globals                ,ONLY: unit_stdout,myrank
USE MOD_Particle_Vars          ,ONLY: Symmetry
#endif /* CODE_ANALYZE */
USE MOD_Particle_Analyze_Vars   ,ONLY: CalcPartBalance,nPartIn,nPartOut,PartEkinIn,PartEkinOut
USE MOD_Particle_Analyze_Tools  ,ONLY: CalcEkinPart
! IMPLICIT VARIABLE HANDLING
IMPLICIT NONE
!-----------------------------------------------------------------------------------------------------------------------------------
! INPUT VARIABLES
INTEGER, INTENT(IN)           :: iPair, iReac
!-----------------------------------------------------------------------------------------------------------------------------------
! OUTPUT VARIABLES
!-----------------------------------------------------------------------------------------------------------------------------------
! LOCAL VARIABLES
INTEGER                       :: ReactInx(1:3), ProductReac(1:3), EductReac(1:3), nProd, nDOFMAX, iProd, iPolyatMole, iSpec
INTEGER                       :: SpecToDelete, iPart
REAL                          :: FracMassCent1, FracMassCent2, MassRed     ! mx/(mx+my)
REAL                          :: VeloMx, VeloMy, VeloMz           ! center of mass velo
REAL                          :: FakXi, Xi_rel, iRan, FacEtraDistri
REAL                          :: ERel_React1_React2, ERel_React1_React3
REAL                          :: Xi_elec(1:3), Telec(1:3), EZeroTempToExec(1:3)
REAL, ALLOCATABLE             :: Xi_Vib1(:), Xi_Vib2(:), Xi_Vib3(:), XiVibPart(:,:)
REAL                          :: VxPseuMolec, VyPseuMolec, VzPseuMolec
REAL                          :: Weight1, Weight2, Weight3, WeightProd, NumWeightEduct, NumWeightProd, ReducedMass
REAL                          :: cRelaNew(3) ! relative velocity
#ifdef CODE_ANALYZE
REAL,PARAMETER                :: RelMomTol=2e-9  ! Relative tolerance applied to conservation of momentum before/after reaction
REAL,PARAMETER                :: RelEneTol=1e-12 ! Relative tolerance applied to conservation of energy before/after reaction
REAL                          :: Energy_old,Energy_new,Momentum_old(3),Momentum_new(3)
INTEGER                       :: iMom, iMomDim
#endif /* CODE_ANALYZE */
!===================================================================================================================================

EductReac(1:3) = ChemReac%DefinedReact(iReac,1,1:3)
ProductReac(1:3) = ChemReac%DefinedReact(iReac,2,1:3)

IF(EductReac(3).NE.0) THEN
  IF(ChemReac%RecombParticle.NE.0) THEN
    ReactInx(3) = ChemReac%RecombParticle
    ! If a pair ahead in the list was broken, check which of the particles is used
    IF(ChemReac%LastPairForRec.GT.0) THEN
      IF(ChemReac%RecombParticle.EQ.Coll_pData(ChemReac%LastPairForRec)%iPart_p2) THEN
        ! Both particles of the pair were already used, set the RecombParticle index to zero and advance the nPairForRec counter
        ! -> New pair will be broken up (in CalcReactionProb routine)
        ChemReac%RecombParticle = 0
        ChemReac%nPairForRec = ChemReac%nPairForRec + 1
      ELSE
        ! Utilize the second particle of the pair for the recombination
        Coll_pData(ChemReac%LastPairForRec)%NeedForRec = .TRUE.
        ChemReac%RecombParticle = Coll_pData(ChemReac%LastPairForRec)%iPart_p2
      END IF
    END IF
  ELSE
    CALL Abort(__STAMP__,&
      'New Particle Number greater max Part Num in DSMC_Chemistry. Reaction: ',iReac)
  END IF
END IF

! Do not perform the reaction in case the reaction is to be calculated at a constant gas composition (DSMC%ReservoirSimuRate = T)
#if (PP_TimeDiscMethod==42)
IF (DSMC%ReservoirSimuRate) THEN
  ! Count the number of reactions to determine the actual reaction rate
  IF (DSMC%ReservoirRateStatistic) THEN
    ChemReac%NumReac(iReac) = ChemReac%NumReac(iReac) + 1
  END IF
  ! Leave the routine again
  RETURN
END IF
#endif

Xi_elec = 0.
Telec = 0.
EZeroTempToExec = 0.

Weight1=0.; Weight2=0.; Weight3=0.; WeightProd = 0.
NumWeightEduct = 2.
NumWeightProd = 2.

!..Get the index of react1 and the react2
IF (PartSpecies(Coll_pData(iPair)%iPart_p1).EQ.ChemReac%DefinedReact(iReac,1,1)) THEN
  ReactInx(1) = Coll_pData(iPair)%iPart_p1
  ReactInx(2) = Coll_pData(iPair)%iPart_p2
ELSE
  ReactInx(2) = Coll_pData(iPair)%iPart_p1
  ReactInx(1) = Coll_pData(iPair)%iPart_p2
END IF

IF(EductReac(3).NE.0) THEN
  IF((TRIM(ChemReac%ReactType(iReac)).EQ.'R').OR.(TRIM(ChemReac%ReactType(iReac)).EQ.'r')) THEN
    EductReac(3) = PartSpecies(ReactInx(3))
    ProductReac(2) = PartSpecies(ReactInx(3))
    NumWeightEduct = 3.
  END IF
  IF(ProductReac(3).EQ.0) THEN
    CALL RemoveParticle(ReactInx(3))
  ELSE
    PartSpecies(ReactInx(3)) = ProductReac(3)
    WeightProd = GetParticleWeight(ReactInx(3))
    NumWeightProd = 3.
  END IF
END IF

IF(CalcPartBalance) THEN
  IF(TRIM(ChemReac%ReactType(iReac)).NE.'phIon') THEN
    DO iPart = 1, NINT(NumWeightEduct)
      IF(BGGas%BackgroundSpecies(EductReac(iPart))) CYCLE
      nPartOut(EductReac(iPart))=nPartOut(EductReac(iPart)) + 1
      PartEkinOut(EductReac(iPart))=PartEkinOut(EductReac(iPart))+CalcEkinPart(ReactInx(iPart))
    END DO
  END IF
END IF

Weight1 = GetParticleWeight(ReactInx(1))
Weight2 = GetParticleWeight(ReactInx(2))
IF(EductReac(3).NE.0) Weight3 = GetParticleWeight(ReactInx(3))

IF (RadialWeighting%DoRadialWeighting.OR.VarTimeStep%UseVariableTimeStep) THEN
  ReducedMass = Species(EductReac(1))%MassIC*Weight1 * Species(EductReac(2))%MassIC*Weight2 &
              / (Species(EductReac(1))%MassIC*Weight1 + Species(EductReac(2))%MassIC*Weight2)
ELSE IF(TRIM(ChemReac%ReactType(iReac)).EQ.'phIon') THEN
  ReducedMass = 0.
ELSE
  ReducedMass = CollInf%MassRed(Coll_pData(iPair)%PairType)
END IF

IF(EductReac(3).EQ.0) THEN
  IF(ProductReac(3).NE.0) THEN
    !.... Get free particle index for the 3rd particle produced
    DSMCSumOfFormedParticles = DSMCSumOfFormedParticles + 1
    ReactInx(3) = PDM%nextFreePosition(DSMCSumOfFormedParticles+PDM%CurrentNextFreePosition)
    IF (ReactInx(3).EQ.0) THEN
      CALL abort(__STAMP__,&
      'New Particle Number greater max Part Num in DSMC_Chemistry. Reaction: ',iReac)
    END IF
    !Set new Species of new particle
    PDM%ParticleInside(ReactInx(3)) = .true.
    PDM%IsNewPart(ReactInx(3)) = .true.
    PDM%dtFracPush(ReactInx(3)) = .FALSE.
    PartSpecies(ReactInx(3)) = ProductReac(3)
    PartState(1:3,ReactInx(3)) = PartState(1:3,ReactInx(1))
    IF(DoRefMapping)THEN ! here Nearst-GP is missing
      PartPosRef(1:3,ReactInx(3))=PartPosRef(1:3,ReactInx(1))
    END IF
    PartStateIntEn( 1,ReactInx(3)) = 0.
    PartStateIntEn( 2,ReactInx(3)) = 0.
    IF ( DSMC%ElectronicModel )  PartStateIntEn( 3,ReactInx(3)) = 0.
    PEM%GlobalElemID(ReactInx(3)) = PEM%GlobalElemID(ReactInx(1))
    PEM%LastGlobalElemID(ReactInx(3)) = PEM%GlobalElemID(ReactInx(3))
    IF(RadialWeighting%DoRadialWeighting) PartMPF(ReactInx(3)) = PartMPF(ReactInx(1))
    IF(VarTimeStep%UseVariableTimeStep) VarTimeStep%ParticleTimeStep(ReactInx(3)) = VarTimeStep%ParticleTimeStep(ReactInx(1))
    WeightProd = Weight1
    NumWeightProd = 3.
  END IF
END IF

#ifdef CODE_ANALYZE
! Energy conservation
Energy_old=0.5*Species(PartSpecies(ReactInx(1)))%MassIC*DOTPRODUCT(PartState(4:6,ReactInx(1))) * Weight1 &
          +0.5*Species(PartSpecies(ReactInx(2)))%MassIC*DOTPRODUCT(PartState(4:6,ReactInx(2))) * Weight2 &
          + (PartStateIntEn(1,ReactInx(1)) + PartStateIntEn(2,ReactInx(1))) * Weight1 &
          + (PartStateIntEn(1,ReactInx(2)) + PartStateIntEn(2,ReactInx(2))) * Weight2 &
          + ChemReac%EForm(iReac)/NumWeightProd*(Weight1+Weight2+WeightProd)
IF(DSMC%ElectronicModel) Energy_old=Energy_old + PartStateIntEn(3,ReactInx(1))*Weight1 + PartStateIntEn(3,ReactInx(2)) * Weight2
IF (EductReac(3).NE.0) THEN
  Energy_old=Energy_old+(0.5*Species(PartSpecies(ReactInx(3)))%MassIC*DOTPRODUCT(PartState(4:6,ReactInx(3)))&
      + PartStateIntEn(1,ReactInx(3))+PartStateIntEn(2,ReactInx(3))) * Weight3
  IF(DSMC%ElectronicModel) Energy_old=Energy_old + PartStateIntEn(3,ReactInx(3)) * Weight3
END IF
! Momentum conservation
Momentum_old(1:3) = Species(PartSpecies(ReactInx(1)))%MassIC * PartState(4:6,ReactInx(1)) * Weight1 &
                  + Species(PartSpecies(ReactInx(2)))%MassIC * PartState(4:6,ReactInx(2)) * Weight2
IF (EductReac(3).NE.0) Momentum_old(1:3) = Momentum_old(1:3) + Species(PartSpecies(ReactInx(3)))%MassIC &
                                                                * PartState(4:6,ReactInx(3)) * Weight3
#endif /* CODE_ANALYZE */

! Add heat of formation to collision energy
Coll_pData(iPair)%Ec = 0.5 * ReducedMass *Coll_pData(iPair)%CRela2 &
        + ChemReac%EForm(iReac)/NumWeightProd*(Weight1+Weight2+WeightProd)

IF(RadialWeighting%DoRadialWeighting) THEN
  ! Weighting factor already included in the weights
  ChemEnergySum = ChemEnergySum + ChemReac%EForm(iReac)/NumWeightProd*(Weight1+Weight2+WeightProd)
ELSE
  ChemEnergySum = ChemEnergySum + ChemReac%EForm(iReac)*Species(EductReac(1))%MacroParticleFactor &
                                  /NumWeightProd*(Weight1+Weight2+WeightProd)
END IF
!-------------------------------------------------------------------------------------------------------------------------------
! Rotational degrees of freedom
!-------------------------------------------------------------------------------------------------------------------------------
IF(ProductReac(3).EQ.0) THEN
  Xi_rel = 2.*(2. - CollInf%omega(ProductReac(1),ProductReac(2)))
  FakXi = 0.5*(Xi_rel + SpecDSMC(ProductReac(1))%Xi_Rot &
        + SpecDSMC(ProductReac(2))%Xi_Rot) - 1.0
  nProd = 2
ELSE
  Xi_rel = 4.*(2. - CollInf%omega(ProductReac(1),ProductReac(2)))
  FakXi = 0.5*(Xi_rel + SpecDSMC(ProductReac(1))%Xi_Rot &
        + SpecDSMC(ProductReac(2))%Xi_Rot + SpecDSMC(ProductReac(3))%Xi_Rot) - 1.0
  nProd = 3
END IF

! Adding the vibrational and rotational energy to the collision energy
Coll_pData(iPair)%Ec = Coll_pData(iPair)%Ec + (PartStateIntEn(2,ReactInx(1)) + PartStateIntEn(1,ReactInx(1)))*Weight1 &
                      + (PartStateIntEn(2,ReactInx(2)) + PartStateIntEn(1,ReactInx(2)))*Weight2
! Addition of the electronic energy to the collision energy)
IF (DSMC%ElectronicModel) THEN
  Coll_pData(iPair)%Ec = Coll_pData(iPair)%Ec + PartStateIntEn(3,ReactInx(1))*Weight1 + PartStateIntEn(3,ReactInx(2))*Weight2
END IF

IF(EductReac(3).NE.0) THEN
  ! If a third collision partner exists (recombination/exchange reactions with defined third educt, A + B+ C), calculation of
  ! the centre of mass of a pseudo-molecule consisting of the first two educts -> (AB) + C
  IF (RadialWeighting%DoRadialWeighting) THEN
    FracMassCent1 = Species(EductReac(1))%MassIC *Weight1 &
        /(Species(EductReac(1))%MassIC* Weight1 + Species(EductReac(2))%MassIC * Weight2)
    FracMassCent2 = Species(EductReac(2))%MassIC *Weight2 &
        /(Species(EductReac(1))%MassIC* Weight1 + Species(EductReac(2))%MassIC * Weight2)
  ELSE
    FracMassCent1 = CollInf%FracMassCent(EductReac(1), Coll_pData(iPair)%PairType)
    FracMassCent2 = CollInf%FracMassCent(EductReac(2), Coll_pData(iPair)%PairType)
  END IF

  VeloMx = FracMassCent1 * PartState(4,ReactInx(1)) &
          + FracMassCent2 * PartState(4,ReactInx(2))
  VeloMy = FracMassCent1 * PartState(5,ReactInx(1)) &
          + FracMassCent2 * PartState(5,ReactInx(2))
  VeloMz = FracMassCent1 * PartState(6,ReactInx(1)) &
          + FracMassCent2 * PartState(6,ReactInx(2))

  ! Overwriting the PartState of the first particle with the new PartState of the pseudo-molecule (AB)
  PartState(4,ReactInx(1)) = VeloMx
  PartState(5,ReactInx(1)) = VeloMy
  PartState(6,ReactInx(1)) = VeloMz

  ! Calculation of the reduced mass of the pseudo-molecule and third collision partner
  CALL CalcPseudoScatterVars(EductReac(1),EductReac(2),EductReac(3),FracMassCent1,FracMassCent2,MassRed, &
        (/Weight1,Weight2,Weight3/))
  ! Addition of the relative translation energy between (AB) and C, rotational and vibrational energy of the third
  Coll_pData(iPair)%Ec = Coll_pData(iPair)%Ec + (PartStateIntEn(1,ReactInx(3)) + PartStateIntEn(2,ReactInx(3))) * Weight3 &
    + 0.5 * MassRed * ((VeloMx-PartState(4,ReactInx(3)))**2+(VeloMy-PartState(5,ReactInx(3)))**2+(VeloMz-PartState(6,ReactInx(3)))**2)
  IF(DSMC%ElectronicModel) Coll_pData(iPair)%Ec = Coll_pData(iPair)%Ec + PartStateIntEn(3,ReactInx(3))*Weight3
END IF

!-------------------------------------------------------------------------------------------------------------------------------
! Redistribution of collisional energy according to the equipartion theorem
!-------------------------------------------------------------------------------------------------------------------------------
! Determining the maximal number of vibrational SHOs for allocation of the XiVibPart array
nDOFMAX = 0
DO iProd = 1, nProd
  IF((SpecDSMC(ProductReac(iProd))%InterID.EQ.2).OR.(SpecDSMC(ProductReac(iProd))%InterID.EQ.20)) THEN
    IF(SpecDSMC(ProductReac(iProd))%PolyatomicMol) THEN
      iPolyatMole = SpecDSMC(ProductReac(iProd))%SpecToPolyArray
      nDOFMAX = MAX(nDOFMAX,PolyatomMolDSMC(iPolyatMole)%VibDOF)
    ELSE
      nDOFMAX = MAX(nDOFMAX,1)
    END IF
  END IF
END DO

! Root-finding algorithm to determine the vibrational and electronic degrees of freedom
IF((nDOFMAX.GT.0).AND.(DSMC%ElectronicModel)) THEN
  ALLOCATE(XiVibPart(nProd,nDOFMAX))
  XiVibPart = 0.
  CALL CalcXiTotalEqui(iReac,iPair,Xi_rel,Weight1,Weight2,WeightProd,XiVibPart=XiVibPart,XiElecPart=Xi_elec)
ELSEIF(DSMC%ElectronicModel) THEN
  CALL CalcXiTotalEqui(iReac,iPair,Xi_rel,Weight1,Weight2,WeightProd,XiElecPart=Xi_elec)
ELSEIF(nDOFMAX.GT.0) THEN
  ALLOCATE(XiVibPart(nProd,nDOFMAX))
  XiVibPart = 0.
  CALL CalcXiTotalEqui(iReac,iPair,Xi_rel,Weight1,Weight2,WeightProd,XiVibPart=XiVibPart)
END IF

IF(nDOFMAX.GT.0) THEN
  IF((SpecDSMC(ProductReac(1))%InterID.EQ.2).OR.(SpecDSMC(ProductReac(1))%InterID.EQ.20)) THEN
    IF(SpecDSMC(ProductReac(1))%PolyatomicMol) THEN
      iPolyatMole = SpecDSMC(ProductReac(1))%SpecToPolyArray
      ALLOCATE(Xi_vib1(PolyatomMolDSMC(iPolyatMole)%VibDOF))
      Xi_vib1(1:PolyatomMolDSMC(iPolyatMole)%VibDOF)=XiVibPart(1,1:PolyatomMolDSMC(iPolyatMole)%VibDOF)
    ELSE
      ALLOCATE(Xi_vib1(1))
      Xi_vib1(1) = XiVibPart(1,1)
    END IF
    FakXi = FakXi + 0.5*SUM(Xi_vib1)
    EZeroTempToExec(1) = SpecDSMC(ProductReac(1))%EZeroPoint*Weight1
  END IF
  IF((SpecDSMC(ProductReac(2))%InterID.EQ.2).OR.(SpecDSMC(ProductReac(2))%InterID.EQ.20)) THEN
    IF(SpecDSMC(ProductReac(2))%PolyatomicMol) THEN
      iPolyatMole = SpecDSMC(ProductReac(2))%SpecToPolyArray
      ALLOCATE(Xi_vib2(PolyatomMolDSMC(iPolyatMole)%VibDOF))
      Xi_vib2(1:PolyatomMolDSMC(iPolyatMole)%VibDOF)=XiVibPart(2,1:PolyatomMolDSMC(iPolyatMole)%VibDOF)
    ELSE
      ALLOCATE(Xi_vib2(1))
      Xi_vib2(1) = XiVibPart(2,1)
    END IF
    FakXi = FakXi + 0.5*SUM(Xi_vib2)
    EZeroTempToExec(2) = SpecDSMC(ProductReac(2))%EZeroPoint*Weight2
  END IF
  IF(ProductReac(3).NE.0) THEN
    IF((SpecDSMC(ProductReac(3))%InterID.EQ.2).OR.(SpecDSMC(ProductReac(3))%InterID.EQ.20)) THEN
      IF(SpecDSMC(ProductReac(3))%PolyatomicMol) THEN
        iPolyatMole = SpecDSMC(ProductReac(3))%SpecToPolyArray
        ALLOCATE(Xi_vib3(PolyatomMolDSMC(iPolyatMole)%VibDOF))
        Xi_vib3(1:PolyatomMolDSMC(iPolyatMole)%VibDOF)= XiVibPart(3,1:PolyatomMolDSMC(iPolyatMole)%VibDOF)
      ELSE
        ALLOCATE(Xi_vib3(1))
        Xi_vib3(1) = XiVibPart(3,1)
      END IF
      FakXi = FakXi + 0.5*SUM(Xi_vib3)
      EZeroTempToExec(3) = SpecDSMC(ProductReac(3))%EZeroPoint*WeightProd
    END IF
  END IF
END IF

! Substracting the zero-point energy of the products (is added back later)
Coll_pData(iPair)%Ec = Coll_pData(iPair)%Ec - SUM(EZeroTempToExec(:))
! Set new Species of molec and atom
PartSpecies(ReactInx(1)) = ProductReac(1)
PartSpecies(ReactInx(2)) = ProductReac(2)

!--------------------------------------------------------------------------------------------------
! Electronic energy exchange
!--------------------------------------------------------------------------------------------------
IF (DSMC%ElectronicModel) THEN
  FakXi = FakXi + 0.5*(Xi_elec(1)+Xi_elec(2))
  IF(ProductReac(3).NE.0) THEN
    IF((SpecDSMC(ProductReac(3))%InterID.EQ.4).OR.SpecDSMC(ProductReac(3))%FullyIonized) THEN
      PartStateIntEn(3,ReactInx(3)) = 0.0
    ELSE
      CALL ElectronicEnergyExchange(iPair,ReactInx(3),FakXi)
      Coll_pData(iPair)%Ec = Coll_pData(iPair)%Ec - PartStateIntEn(3,ReactInx(3))*WeightProd
    END IF
  END IF
  FakXi = FakXi - 0.5*Xi_elec(2)
  IF((SpecDSMC(ProductReac(2))%InterID.EQ.4).OR.SpecDSMC(ProductReac(2))%FullyIonized) THEN
    PartStateIntEn(3,ReactInx(2)) = 0.0
  ELSE
    CALL ElectronicEnergyExchange(iPair,ReactInx(2),FakXi)
    Coll_pData(iPair)%Ec = Coll_pData(iPair)%Ec - PartStateIntEn(3,ReactInx(2))*Weight2
  END IF
  FakXi = FakXi - 0.5*Xi_elec(1)
  IF((SpecDSMC(ProductReac(1))%InterID.EQ.4).OR.SpecDSMC(ProductReac(1))%FullyIonized) THEN
    PartStateIntEn(3,ReactInx(1)) = 0.0
  ELSE
    CALL ElectronicEnergyExchange(iPair,ReactInx(1),FakXi)
    Coll_pData(iPair)%Ec = Coll_pData(iPair)%Ec - PartStateIntEn(3,ReactInx(1))*Weight1
  END IF
END IF ! DSMC%ElectronicModel
!--------------------------------------------------------------------------------------------------
! Vibrational energy exchange
!--------------------------------------------------------------------------------------------------
IF(ProductReac(3).NE.0) THEN
  ! Relaxation of third collision partner
  IF((SpecDSMC(ProductReac(3))%InterID.EQ.2).OR.(SpecDSMC(ProductReac(3))%InterID.EQ.20)) THEN
    FakXi = FakXi - 0.5*Xi_vib3(1)
    IF(SpecDSMC(ProductReac(3))%PolyatomicMol) THEN
      ! Zero-point energy is added (for every vibrational dof separately) and new vibrational state is substracted
      ! from the collision energy within the routine
      CALL DSMC_RelaxVibPolyProduct(iPair, ReactInx(3), FakXi, Xi_Vib3, WeightProd)
    ELSE
      IF(EductReac(3).NE.0) THEN
        IF(SpecDSMC(EductReac(3))%PolyatomicMol) DEALLOCATE(VibQuantsPar(ReactInx(3))%Quants)
      END IF
      Coll_pData(iPair)%Ec = Coll_pData(iPair)%Ec + EZeroTempToExec(3)
      CALL DSMC_VibRelaxDiatomic(iPair,ReactInx(3),FakXi)
      Coll_pData(iPair)%Ec = Coll_pData(iPair)%Ec - PartStateIntEn(1,ReactInx(3))*WeightProd
    END IF
  END IF
END IF

! Relaxation of first product
IF((SpecDSMC(ProductReac(1))%InterID.EQ.2).OR.(SpecDSMC(ProductReac(1))%InterID.EQ.20)) THEN
  FakXi = FakXi - 0.5*Xi_vib1(1)
  IF(SpecDSMC(ProductReac(1))%PolyatomicMol) THEN
    ! Zero-point energy is added (for every vibrational dof separately) and new vibrational state is substracted
    ! from the collision energy within the routine
    CALL DSMC_RelaxVibPolyProduct(iPair, ReactInx(1), FakXi, Xi_Vib1, Weight1)
  ELSE
    Coll_pData(iPair)%Ec = Coll_pData(iPair)%Ec + EZeroTempToExec(1)
    IF(SpecDSMC(EductReac(1))%PolyatomicMol) DEALLOCATE(VibQuantsPar(ReactInx(1))%Quants)
    CALL DSMC_VibRelaxDiatomic(iPair,ReactInx(1),FakXi)
    Coll_pData(iPair)%Ec = Coll_pData(iPair)%Ec - PartStateIntEn(1,ReactInx(1))*Weight1
  END IF
END IF

! Relaxation of second product
IF((SpecDSMC(ProductReac(2))%InterID.EQ.2).OR.(SpecDSMC(ProductReac(2))%InterID.EQ.20)) THEN
  FakXi = FakXi - 0.5*Xi_vib2(1)
  IF(SpecDSMC(ProductReac(2))%PolyatomicMol) THEN
    ! Zero-point energy is added (for every vibrational dof separately) and new vibrational state is substracted
    ! from the collision energy within the routine
    CALL DSMC_RelaxVibPolyProduct(iPair, ReactInx(2), FakXi, Xi_Vib2, Weight2)
  ELSE
    Coll_pData(iPair)%Ec = Coll_pData(iPair)%Ec + EZeroTempToExec(2)
    CALL DSMC_VibRelaxDiatomic(iPair,ReactInx(2),FakXi)
    Coll_pData(iPair)%Ec = Coll_pData(iPair)%Ec - PartStateIntEn(1,ReactInx(2))*Weight2
  END IF
END IF

!--------------------------------------------------------------------------------------------------
! Rotational energy exchange (additional check: If new particle is an atom, internal energies are zero)
!--------------------------------------------------------------------------------------------------
! Rotational Relaxation 3
IF(ProductReac(3).NE.0) THEN
  IF ((SpecDSMC(ProductReac(3))%InterID.EQ.2).OR.(SpecDSMC(ProductReac(3))%InterID.EQ.20)) THEN
    IF(SpecDSMC(ProductReac(3))%Xi_Rot.EQ.3) THEN
      FakXi = FakXi - 0.5*SpecDSMC(ProductReac(3))%Xi_Rot
      CALL DSMC_RotRelaxPoly(iPair, ReactInx(3), FakXi)
    ELSE
      CALL RANDOM_NUMBER(iRan)
      PartStateIntEn(2,ReactInx(3)) = Coll_pData(iPair)%Ec * (1.0 - iRan**(1.0/FakXi))
      FakXi = FakXi - 0.5*SpecDSMC(ProductReac(3))%Xi_Rot
    END IF
    Coll_pData(iPair)%Ec = Coll_pData(iPair)%Ec - PartStateIntEn(2,ReactInx(3))
    PartStateIntEn(2,ReactInx(3)) = PartStateIntEn(2,ReactInx(3))/WeightProd
  ELSE
    PartStateIntEn(1,ReactInx(3)) = 0.0
    PartStateIntEn(2,ReactInx(3)) = 0.0
  END IF
END IF
! Rotational Relaxation 1
IF((SpecDSMC(ProductReac(1))%InterID.EQ.2).OR.(SpecDSMC(ProductReac(1))%InterID.EQ.20)) THEN
  IF(SpecDSMC(ProductReac(1))%Xi_Rot.EQ.3) THEN
    FakXi = FakXi - 0.5*SpecDSMC(ProductReac(1))%Xi_Rot
    CALL DSMC_RotRelaxPoly(iPair, ReactInx(1), FakXi)
  ELSE
    CALL RANDOM_NUMBER(iRan)
    PartStateIntEn(2,ReactInx(1)) = Coll_pData(iPair)%Ec * (1.0 - iRan**(1.0/FakXi))
    FakXi = FakXi - 0.5*SpecDSMC(ProductReac(1))%Xi_Rot
  END IF
  Coll_pData(iPair)%Ec = Coll_pData(iPair)%Ec - PartStateIntEn(2,ReactInx(1))
  PartStateIntEn(2,ReactInx(1)) = PartStateIntEn(2,ReactInx(1)) / Weight1
ELSE
  PartStateIntEn(1,ReactInx(1)) = 0.0
  PartStateIntEn(2,ReactInx(1)) = 0.0
END IF
! Rotational Relaxation 2
IF((SpecDSMC(ProductReac(2))%InterID.EQ.2).OR.(SpecDSMC(ProductReac(2))%InterID.EQ.20)) THEN
  IF(SpecDSMC(ProductReac(2))%Xi_Rot.EQ.3) THEN
    FakXi = FakXi - 0.5*SpecDSMC(ProductReac(2))%Xi_Rot
    CALL DSMC_RotRelaxPoly(iPair, ReactInx(2), FakXi)
  ELSE
    CALL RANDOM_NUMBER(iRan)
    PartStateIntEn(2,ReactInx(2)) = Coll_pData(iPair)%Ec * (1.0 - iRan**(1.0/FakXi))
    FakXi = FakXi - 0.5*SpecDSMC(ProductReac(2))%Xi_Rot
  END IF
  Coll_pData(iPair)%Ec = Coll_pData(iPair)%Ec - PartStateIntEn(2,ReactInx(2))
  PartStateIntEn(2,ReactInx(2)) = PartStateIntEn(2,ReactInx(2)) / Weight2
ELSE
  PartStateIntEn(1,ReactInx(2)) = 0.0
  PartStateIntEn(2,ReactInx(2)) = 0.0
END IF

!--------------------------------------------------------------------------------------------------!
! Calculation of new particle velocities
!--------------------------------------------------------------------------------------------------!
IF(ProductReac(3).NE.0) THEN
  ! If a third product exists, the remaining collision energy has to distributed onto three particles
  CALL RANDOM_NUMBER(iRan)
  FacEtraDistri = iRan
  CALL RANDOM_NUMBER(iRan)
  DO WHILE ((4 *FacEtraDistri*(1-FacEtraDistri))**(1-CollInf%omega(ProductReac(1),ProductReac(2))).LT.iRan)
    CALL RANDOM_NUMBER(iRan)
    FacEtraDistri = iRan
    CALL RANDOM_NUMBER(iRan)
  END DO
  ERel_React1_React2 = Coll_pData(iPair)%Ec * FacEtraDistri
  ERel_React1_React3 = Coll_pData(iPair)%Ec - ERel_React1_React2
  IF(EductReac(3).NE.0) THEN
    ! Scattering 3 -> 3: Utilizing the FracMassCent's from above, calculated for the pseudo-molecule and the third educt,
    ! PartState(ReactInx(1)) is the centre of mass of the pseudo-molecule
    VeloMx = FracMassCent1 * PartState(4,ReactInx(1)) &
            + FracMassCent2 * PartState(4,ReactInx(3))
    VeloMy = FracMassCent1 * PartState(5,ReactInx(1)) &
            + FracMassCent2 * PartState(5,ReactInx(3))
    VeloMz = FracMassCent1 * PartState(6,ReactInx(1)) &
            + FracMassCent2 * PartState(6,ReactInx(3))
  ELSE
    ! Scattering 2 -> 3
    IF(TRIM(ChemReac%ReactType(iReac)).EQ.'phIon') THEN
    ! Do not consider the momentum of the photon
      FracMassCent1 = 1.
      FracMassCent2 = 0.
    ELSE
      IF (RadialWeighting%DoRadialWeighting) THEN
        FracMassCent1 = Species(EductReac(1))%MassIC *Weight1 &
            /(Species(EductReac(1))%MassIC* Weight1 + Species(EductReac(2))%MassIC * Weight2)
        FracMassCent2 = Species(EductReac(2))%MassIC *Weight2 &
            /(Species(EductReac(1))%MassIC* Weight1 + Species(EductReac(2))%MassIC * Weight2)
      ELSE
        FracMassCent1 = CollInf%FracMassCent(EductReac(1),Coll_pData(iPair)%PairType)
        FracMassCent2 = CollInf%FracMassCent(EductReac(2),Coll_pData(iPair)%PairType)
      END IF
    END IF

    !Calculation of velo from center of mass
    VeloMx = FracMassCent1 * PartState(4,ReactInx(1)) &
            + FracMassCent2 * PartState(4,ReactInx(2))
    VeloMy = FracMassCent1 * PartState(5,ReactInx(1)) &
            + FracMassCent2 * PartState(5,ReactInx(2))
    VeloMz = FracMassCent1 * PartState(6,ReactInx(1)) &
            + FracMassCent2 * PartState(6,ReactInx(2))
  END IF

  ! FracMassCent's and reduced mass are calculated for the pseudo-molecule 1-3 and the second product, in the case of dissociation
  ! this is the non-reacting collision partner
  CALL CalcPseudoScatterVars(ProductReac(1),ProductReac(3),ProductReac(2),FracMassCent1,FracMassCent2,MassRed &
        , (/Weight1,WeightProd,Weight2/))

  Coll_pData(iPair)%CRela2 = 2 * ERel_React1_React2 / MassRed

  cRelaNew(1:3) = PostCollVec(iPair)

  DSMC_RHS(1,ReactInx(2)) = VeloMx - FracMassCent1*cRelaNew(1) - PartState(4,ReactInx(2))
  DSMC_RHS(2,ReactInx(2)) = VeloMy - FracMassCent1*cRelaNew(2) - PartState(5,ReactInx(2))
  DSMC_RHS(3,ReactInx(2)) = VeloMz - FracMassCent1*cRelaNew(3) - PartState(6,ReactInx(2))

#ifdef CODE_ANALYZE
  Energy_new=0.5*Species(PartSpecies(ReactInx(2)))%MassIC*((VeloMx - FracMassCent1*cRelaNew(1))**2 &
                                                        + (VeloMy - FracMassCent1*cRelaNew(2))**2 &
                                                        + (VeloMz - FracMassCent1*cRelaNew(3))**2) * Weight2
  Momentum_new(1:3) = Species(PartSpecies(ReactInx(2)))%MassIC* (/VeloMx - FracMassCent1*cRelaNew(1),&
                                                                VeloMy - FracMassCent1*cRelaNew(2),&
                                                                VeloMz - FracMassCent1*cRelaNew(3)/) * Weight2
#endif /* CODE_ANALYZE */

  ! Set velocity of pseudo molec (AB) and calculate the centre of mass frame velocity: m_pseu / (m_3 + m_4) * v_pseu
  ! (Velocity of pseudo molecule is NOT equal to the COM frame velocity)
  VxPseuMolec = (VeloMx + FracMassCent2*cRelaNew(1))
  VyPseuMolec = (VeloMy + FracMassCent2*cRelaNew(2))
  VzPseuMolec = (VeloMz + FracMassCent2*cRelaNew(3))

  ! Scattering of (AB)
  IF (RadialWeighting%DoRadialWeighting) THEN
    FracMassCent1 = Species(ProductReac(1))%MassIC *Weight1 &
        /(Species(ProductReac(1))%MassIC* Weight1 + Species(ProductReac(3))%MassIC * WeightProd)
    FracMassCent2 = Species(ProductReac(3))%MassIC *WeightProd &
        /(Species(ProductReac(1))%MassIC* Weight1 + Species(ProductReac(3))%MassIC * WeightProd)
    ReducedMass = Species(ProductReac(1))%MassIC *Weight1* Species(ProductReac(3))%MassIC *WeightProd &
        / (Species(ProductReac(1))%MassIC*Weight1 + Species(ProductReac(3))%MassIC *WeightProd)
  ELSE
    FracMassCent1 = CollInf%FracMassCent(ProductReac(1),CollInf%Coll_Case(ProductReac(1),ProductReac(3)))
    FracMassCent2 = CollInf%FracMassCent(ProductReac(3),CollInf%Coll_Case(ProductReac(1),ProductReac(3)))
    ReducedMass = CollInf%MassRed(CollInf%Coll_Case(ProductReac(1),ProductReac(3)))
  END IF

  Coll_pData(iPair)%cRela2 = 2 * ERel_React1_React3 / ReducedMass

  cRelaNew(1:3) = PostCollVec(iPair)

  !deltaV particle 1
  DSMC_RHS(1,ReactInx(1)) = VxPseuMolec + FracMassCent2*cRelaNew(1) - PartState(4,ReactInx(1))
  DSMC_RHS(2,ReactInx(1)) = VyPseuMolec + FracMassCent2*cRelaNew(2) - PartState(5,ReactInx(1))
  DSMC_RHS(3,ReactInx(1)) = VzPseuMolec + FracMassCent2*cRelaNew(3) - PartState(6,ReactInx(1))

  !deltaV particle 3
  PartState(4:6,ReactInx(3)) = 0.
  DSMC_RHS(1,ReactInx(3)) = VxPseuMolec - FracMassCent1*cRelaNew(1)
  DSMC_RHS(2,ReactInx(3)) = VyPseuMolec - FracMassCent1*cRelaNew(2)
  DSMC_RHS(3,ReactInx(3)) = VzPseuMolec - FracMassCent1*cRelaNew(3)

#ifdef CODE_ANALYZE
  ! New total energy
  Energy_new=Energy_new + 0.5*Species(PartSpecies(ReactInx(1)))%MassIC*((VxPseuMolec + FracMassCent2*cRelaNew(1))**2    &
                                                                      +(VyPseuMolec + FracMassCent2*cRelaNew(2))**2    &
                                                                      +(VzPseuMolec + FracMassCent2*cRelaNew(3))**2) * Weight1 &
                        + 0.5*Species(PartSpecies(ReactInx(3)))%MassIC*((VxPseuMolec - FracMassCent1*cRelaNew(1))**2    &
                                                                      +(VyPseuMolec - FracMassCent1*cRelaNew(2))**2    &
                                                                      +(VzPseuMolec - FracMassCent1*cRelaNew(3))**2) * WeightProd &
                        + (PartStateIntEn(1,ReactInx(1)) + PartStateIntEn(2,ReactInx(1))) * Weight1 &
                        + (PartStateIntEn(1,ReactInx(2)) + PartStateIntEn(2,ReactInx(2))) * Weight2 &
                        + (PartStateIntEn(1,ReactInx(3)) + PartStateIntEn(2,ReactInx(3))) * WeightProd
  IF(DSMC%ElectronicModel) Energy_new = Energy_new + PartStateIntEn(3,ReactInx(1)) * Weight1 &
                                                    + PartStateIntEn(3,ReactInx(2)) * Weight2 &
                                                    + PartStateIntEn(3,ReactInx(3)) * WeightProd
  ! New total momentum
  Momentum_new(1:3) = Momentum_new(1:3) &
                    + Species(PartSpecies(ReactInx(1)))%MassIC * (/VxPseuMolec + FracMassCent2*cRelaNew(1),  &
                                                                  VyPseuMolec + FracMassCent2*cRelaNew(2),  &
                                                                  VzPseuMolec + FracMassCent2*cRelaNew(3)/) * Weight1 &
                    + Species(PartSpecies(ReactInx(3)))%MassIC * (/VxPseuMolec - FracMassCent1*cRelaNew(1),  &
                                                                  VyPseuMolec - FracMassCent1*cRelaNew(2),  &
                                                                  VzPseuMolec - FracMassCent1*cRelaNew(3)/) * WeightProd
#endif /* CODE_ANALYZE */

ELSEIF(ProductReac(3).EQ.0) THEN
  IF(EductReac(3).NE.0) THEN
    ! Scattering 3 -> 2
    VxPseuMolec = FracMassCent1 * PartState(4,ReactInx(1)) + FracMassCent2 * PartState(4,ReactInx(3))
    VyPseuMolec = FracMassCent1 * PartState(5,ReactInx(1)) + FracMassCent2 * PartState(5,ReactInx(3))
    VzPseuMolec = FracMassCent1 * PartState(6,ReactInx(1)) + FracMassCent2 * PartState(6,ReactInx(3))
    ! When RHS is set, ReactInx(2) is utilized, not an error as the old state cancels out after the particle push in the time disc,
    ! therefore, there is no need to set change the index as the proper species, ProductReac(2), was utilized for the relaxation
  ELSE
    ! Scattering 2 -> 2
    IF(TRIM(ChemReac%ReactType(iReac)).EQ.'phIon') THEN
    ! Do not consider the momentum of the photon
      FracMassCent1 = 1.
      FracMassCent2 = 0.
    ELSE
      IF (RadialWeighting%DoRadialWeighting) THEN
        FracMassCent1 = Species(EductReac(1))%MassIC *Weight1 &
            /(Species(EductReac(1))%MassIC* Weight1 + Species(EductReac(2))%MassIC * Weight2)
        FracMassCent2 = Species(EductReac(2))%MassIC *Weight2 &
            /(Species(EductReac(1))%MassIC* Weight1 + Species(EductReac(2))%MassIC * Weight2)
      ELSE
        FracMassCent1 = CollInf%FracMassCent(EductReac(1),CollInf%Coll_Case(EductReac(1),EductReac(2)))
        FracMassCent2 = CollInf%FracMassCent(EductReac(2),CollInf%Coll_Case(EductReac(1),EductReac(2)))
      END IF
    END IF

    VxPseuMolec = FracMassCent1 * PartState(4,ReactInx(1)) + FracMassCent2 * PartState(4,ReactInx(2))
    VyPseuMolec = FracMassCent1 * PartState(5,ReactInx(1)) + FracMassCent2 * PartState(5,ReactInx(2))
    VzPseuMolec = FracMassCent1 * PartState(6,ReactInx(1)) + FracMassCent2 * PartState(6,ReactInx(2))
  END IF
  ERel_React1_React3 = Coll_pData(iPair)%Ec

  IF (RadialWeighting%DoRadialWeighting) THEN
    FracMassCent1 = Species(ProductReac(1))%MassIC *Weight1 &
        /(Species(ProductReac(1))%MassIC* Weight1 + Species(ProductReac(2))%MassIC * Weight2)
    FracMassCent2 = Species(ProductReac(2))%MassIC *Weight2 &
        /(Species(ProductReac(1))%MassIC* Weight1 + Species(ProductReac(2))%MassIC * Weight2)
    ReducedMass = Species(ProductReac(1))%MassIC *Weight1* Species(ProductReac(2))%MassIC *Weight2 &
        / (Species(ProductReac(1))%MassIC*Weight1 + Species(ProductReac(2))%MassIC *Weight2)
  ELSE
    ! Scattering of (AB)
    FracMassCent1 = CollInf%FracMassCent(ProductReac(1),CollInf%Coll_Case(ProductReac(1),ProductReac(2)))
    FracMassCent2 = CollInf%FracMassCent(ProductReac(2),CollInf%Coll_Case(ProductReac(1),ProductReac(2)))
    ReducedMass = CollInf%MassRed(CollInf%Coll_Case(ProductReac(1),ProductReac(2)))
  END IF

  Coll_pData(iPair)%cRela2 = 2 * ERel_React1_React3 / ReducedMass
  cRelaNew(1:3) = PostCollVec(iPair)

  !deltaV particle 1
  DSMC_RHS(1,ReactInx(1)) = VxPseuMolec + FracMassCent2*cRelaNew(1) - PartState(4,ReactInx(1))
  DSMC_RHS(2,ReactInx(1)) = VyPseuMolec + FracMassCent2*cRelaNew(2) - PartState(5,ReactInx(1))
  DSMC_RHS(3,ReactInx(1)) = VzPseuMolec + FracMassCent2*cRelaNew(3) - PartState(6,ReactInx(1))
  !deltaV particle 2
  DSMC_RHS(1,ReactInx(2)) = VxPseuMolec - FracMassCent1*cRelaNew(1) - PartState(4,ReactInx(2))
  DSMC_RHS(2,ReactInx(2)) = VyPseuMolec - FracMassCent1*cRelaNew(2) - PartState(5,ReactInx(2))
  DSMC_RHS(3,ReactInx(2)) = VzPseuMolec - FracMassCent1*cRelaNew(3) - PartState(6,ReactInx(2))

#ifdef CODE_ANALYZE
  ! New total energy of remaining products (here, recombination: 2 products)
  Energy_new = 0.5*Species(PartSpecies(ReactInx(1)))%MassIC*((VxPseuMolec + FracMassCent2*cRelaNew(1))**2  &
                                                          +(VyPseuMolec + FracMassCent2*cRelaNew(2))**2  &
                                                          +(VzPseuMolec + FracMassCent2*cRelaNew(3))**2) * Weight1 &
              +0.5*Species(PartSpecies(ReactInx(2)))%MassIC*((VxPseuMolec - FracMassCent1*cRelaNew(1))**2  &
                                                          +(VyPseuMolec - FracMassCent1*cRelaNew(2))**2  &
                                                          +(VzPseuMolec - FracMassCent1*cRelaNew(3))**2) * Weight2 &
              + (PartStateIntEn(1,ReactInx(1)) + PartStateIntEn(2,ReactInx(1))) * Weight1 &
              + (PartStateIntEn(1,ReactInx(2)) + PartStateIntEn(2,ReactInx(2))) * Weight2
  IF(DSMC%ElectronicModel) Energy_new = Energy_new + PartStateIntEn(3,ReactInx(1)) * Weight1 + PartStateIntEn(3,ReactInx(2)) * Weight2
  ! New total momentum
    Momentum_new(1:3) = Species(PartSpecies(ReactInx(1)))%MassIC * (/VxPseuMolec + FracMassCent2*cRelaNew(1),  &
                                                                    VyPseuMolec + FracMassCent2*cRelaNew(2),  &
                                                                    VzPseuMolec + FracMassCent2*cRelaNew(3)/) * Weight1 &
                      + Species(PartSpecies(ReactInx(2)))%MassIC * (/VxPseuMolec - FracMassCent1*cRelaNew(1),  &
                                                                    VyPseuMolec - FracMassCent1*cRelaNew(2),  &
                                                                    VzPseuMolec - FracMassCent1*cRelaNew(3)/) * Weight2
#endif /* CODE_ANALYZE */
END IF

IF(ChemReac%NumDeleteProducts.GT.0) THEN
  DO iSpec = 1, ChemReac%NumDeleteProducts
    SpecToDelete = ChemReac%DeleteProductsList(iSpec)
    DO iProd = 1, nProd
      IF(ProductReac(iProd).EQ.SpecToDelete) THEN
        ! Remove the respective particle
        CALL RemoveParticle(ReactInx(iProd))
        ! Remove the newly created particle from chemistry counter
        IF(iProd.EQ.3) DSMCSumOfFormedParticles = DSMCSumOfFormedParticles - 1
      END IF
    END DO
  END DO
END IF

IF(CalcPartBalance) THEN
  DO iPart = 1, NINT(NumWeightProd)
    nPartIn(ProductReac(iPart))=nPartIn(ProductReac(iPart)) + 1
    PartEkinIn(ProductReac(iPart))=PartEkinIn(ProductReac(iPart))+CalcEkinPart(ReactInx(iPart))
  END DO
END IF

#ifdef CODE_ANALYZE
! Check for energy difference
IF (.NOT.ALMOSTEQUALRELATIVE(Energy_old,Energy_new,RelEneTol)) THEN
  WRITE(UNIT_StdOut,*) '\n'
  IPWRITE(UNIT_StdOut,'(I0,A,ES25.14E3)')    " Energy_old             : ",Energy_old
  IPWRITE(UNIT_StdOut,'(I0,A,ES25.14E3)')    " Energy_new             : ",Energy_new
  IPWRITE(UNIT_StdOut,'(I0,A,ES25.14E3)')    " abs. Energy difference : ",Energy_old-Energy_new
  ASSOCIATE( energy => MAX(ABS(Energy_old),ABS(Energy_new)) )
    IF(energy.GT.0.0)THEN
      IPWRITE(UNIT_StdOut,'(I0,A,ES25.14E3)')" rel. Energy difference : ",(Energy_old-Energy_new)/energy
    END IF
  END ASSOCIATE
  IPWRITE(UNIT_StdOut,'(I0,A,ES25.14E3)')    " Applied tolerance      : ",RelEneTol
  CALL abort(&
      __STAMP__&
      ,'CODE_ANALYZE: DSMC_Chemistry is not energy conserving for chemical reaction:', IntInfoOpt=iReac)
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
  IF (.NOT.ALMOSTEQUALRELATIVE(Momentum_old(iMom),Momentum_new(iMom),RelMomTol)) THEN
    WRITE(UNIT_StdOut,*) '\n'
    IPWRITE(UNIT_StdOut,'(I0,A,I0)')           " Direction (x,y,z)        : ",iMom
    IPWRITE(UNIT_StdOut,'(I0,A,ES25.14E3)')    " Momentum_old             : ",Momentum_old(iMom)
    IPWRITE(UNIT_StdOut,'(I0,A,ES25.14E3)')    " Momentum_new             : ",Momentum_new(iMom)
    IPWRITE(UNIT_StdOut,'(I0,A,ES25.14E3)')    " abs. Momentum difference : ",Momentum_old(iMom)-Momentum_new(iMom)
    ASSOCIATE( Momentum => MAX(ABS(Momentum_old(iMom)),ABS(Momentum_new(iMom))) )
      IF(Momentum.GT.0.0)THEN
        IPWRITE(UNIT_StdOut,'(I0,A,ES25.14E3)')" rel. Momentum difference : ",(Momentum_old(iMom)-Momentum_new(iMom))/Momentum
      END IF
    END ASSOCIATE
    IPWRITE(UNIT_StdOut,'(I0,A,ES25.14E3)')    " Applied tolerance      : ",RelMomTol
    CALL abort(&
        __STAMP__&
        ,'CODE_ANALYZE: DSMC_Chemistry is not momentum conserving for chemical reaction:', IntInfoOpt=iReac)
  END IF
END DO
#endif /* CODE_ANALYZE */

END SUBROUTINE DSMC_Chemistry


SUBROUTINE simpleCEX(iReac, iPair, resetRHS_opt)
!===================================================================================================================================
! simple charge exchange interaction
! ION(v1) + ATOM(v2) -> ATOM(v1) + ION(v2)
!===================================================================================================================================
! MODULES
  USE MOD_DSMC_Vars,             ONLY : Coll_pData, DSMC_RHS
  USE MOD_DSMC_Vars,             ONLY : ChemReac
  USE MOD_Particle_Vars,         ONLY : PartSpecies
! IMPLICIT VARIABLE HANDLING
  IMPLICIT NONE
!-----------------------------------------------------------------------------------------------------------------------------------
! INPUT VARIABLES
  INTEGER, INTENT(IN)           :: iPair, iReac
  LOGICAL, INTENT(IN), OPTIONAL :: resetRHS_opt
!-----------------------------------------------------------------------------------------------------------------------------------
! OUTPUT VARIABLES
!-----------------------------------------------------------------------------------------------------------------------------------
! LOCAL VARIABLES
  INTEGER                       :: ReactInx(1:2)
  LOGICAL                       :: resetRHS
!===================================================================================================================================

  IF (PRESENT(resetRHS_opt)) THEN
    resetRHS=resetRHS_opt
  ELSE
    resetRHS=.TRUE.
  END IF

  IF (PartSpecies(Coll_pData(iPair)%iPart_p1).EQ.ChemReac%DefinedReact(iReac,1,1)) THEN
    ReactInx(1) = Coll_pData(iPair)%iPart_p1
    ReactInx(2) = Coll_pData(iPair)%iPart_p2
  ELSE
    ReactInx(2) = Coll_pData(iPair)%iPart_p1
    ReactInx(1) = Coll_pData(iPair)%iPart_p2
  END IF
  ! change species
  PartSpecies(ReactInx(1)) = ChemReac%DefinedReact(iReac,2,1)
  PartSpecies(ReactInx(2)) = ChemReac%DefinedReact(iReac,2,2)

  IF (resetRHS) THEN
    ! deltaV particle 1
    DSMC_RHS(1,Coll_pData(iPair)%iPart_p1) = 0.
    DSMC_RHS(2,Coll_pData(iPair)%iPart_p1) = 0.
    DSMC_RHS(3,Coll_pData(iPair)%iPart_p1) = 0.
    ! deltaV particle 2
    DSMC_RHS(1,Coll_pData(iPair)%iPart_p2) = 0.
    DSMC_RHS(2,Coll_pData(iPair)%iPart_p2) = 0.
    DSMC_RHS(3,Coll_pData(iPair)%iPart_p2) = 0.
  END IF

END SUBROUTINE simpleCEX


SUBROUTINE simpleMEX(iReac, iPair)
!===================================================================================================================================
! simple momentum exchange interaction
! ION(v1) + ATOM(v2) -> ION2(v1') + ATOM(v2')
!===================================================================================================================================
! MODULES
  USE MOD_Globals,               ONLY : abort
  USE MOD_DSMC_Vars,             ONLY : Coll_pData !, DSMC_RHS
  USE MOD_DSMC_Vars,             ONLY : ChemReac
  USE MOD_Particle_Vars,         ONLY : PartSpecies,Species
! IMPLICIT VARIABLE HANDLING
  IMPLICIT NONE
!-----------------------------------------------------------------------------------------------------------------------------------
! INPUT VARIABLES
  INTEGER, INTENT(IN)           :: iPair, iReac
!-----------------------------------------------------------------------------------------------------------------------------------
! OUTPUT VARIABLES
!-----------------------------------------------------------------------------------------------------------------------------------
! LOCAL VARIABLES
  INTEGER                       :: ReactInx(1:2)
!===================================================================================================================================

  IF (PartSpecies(Coll_pData(iPair)%iPart_p1).EQ.ChemReac%DefinedReact(iReac,1,1)) THEN
    ReactInx(1) = Coll_pData(iPair)%iPart_p1
    ReactInx(2) = Coll_pData(iPair)%iPart_p2
  ELSE
    ReactInx(2) = Coll_pData(iPair)%iPart_p1
    ReactInx(1) = Coll_pData(iPair)%iPart_p2
  END IF
  ! change species of educt-ion to product-ion
  IF (Species(PartSpecies(ReactInx(1)))%ChargeIC.NE.0. .AND. Species(PartSpecies(ReactInx(2)))%ChargeIC.EQ.0.) THEN
    PartSpecies(ReactInx(1)) = ChemReac%DefinedReact(iReac,2,2)
  ELSE IF (Species(PartSpecies(ReactInx(2)))%ChargeIC.NE.0. .AND. Species(PartSpecies(ReactInx(1)))%ChargeIC.EQ.0.) THEN
    PartSpecies(ReactInx(2)) = ChemReac%DefinedReact(iReac,2,1)
  ELSE
    CALL abort(&
     __STAMP__&
      ,'ERROR in simpleMEX: one of the products must be an ion!')
  END IF

END SUBROUTINE simpleMEX


SUBROUTINE CalcPartitionFunction(iSpec, Temp, Qtra, Qrot, Qvib, Qelec)
!===================================================================================================================================
!> Calculation of the partition function for a species at the given temperature
!===================================================================================================================================
! MODULES
USE MOD_Globals
USE MOD_Globals_Vars        ,ONLY: Pi, PlanckConst, BoltzmannConst
USE MOD_DSMC_Vars           ,ONLY: SpecDSMC, PolyatomMolDSMC
USE MOD_Particle_Vars       ,ONLY: Species

! IMPLICIT VARIABLE HANDLING
IMPLICIT NONE
!-----------------------------------------------------------------------------------------------------------------------------------
! INPUT VARIABLES
INTEGER, INTENT(IN)         :: iSpec
REAL, INTENT(IN)            :: Temp
!-----------------------------------------------------------------------------------------------------------------------------------
! OUTPUT VARIABLES
REAL, INTENT(OUT)           :: Qtra, Qrot, Qvib, Qelec
!-----------------------------------------------------------------------------------------------------------------------------------
! LOCAL VARIABLES
INTEGER                     :: iPolyatMole, iDOF
REAL                        :: TempRatio
!===================================================================================================================================

Qtra = (2. * Pi * Species(iSpec)%MassIC * BoltzmannConst * Temp / (PlanckConst**2))**(1.5)
Qvib = 1.
Qrot = 1.
IF((SpecDSMC(iSpec)%InterID.EQ.2).OR.(SpecDSMC(iSpec)%InterID.EQ.20)) THEN
  IF(SpecDSMC(iSpec)%PolyatomicMol) THEN
    iPolyatMole = SpecDSMC(iSpec)%SpecToPolyArray
    IF(PolyatomMolDSMC(iPolyatMole)%LinearMolec) THEN
      Qrot = Temp / (SpecDSMC(iSpec)%SymmetryFactor * PolyatomMolDSMC(iPolyatMole)%CharaTRotDOF(1))
    ELSE
      Qrot = SQRT(Pi) / SpecDSMC(iSpec)%SymmetryFactor * SQRT(Temp**3/( PolyatomMolDSMC(iPolyatMole)%CharaTRotDOF(1)    &
                                                                      * PolyatomMolDSMC(iPolyatMole)%CharaTRotDOF(2)    &
                                                                      * PolyatomMolDSMC(iPolyatMole)%CharaTRotDOF(3)))
    END IF
    DO iDOF = 1, PolyatomMolDSMC(iPolyatMole)%VibDOF
      TempRatio = PolyatomMolDSMC(iPolyatMole)%CharaTVibDOF(iDOF)/Temp
      IF(CHECKEXP(TempRatio)) THEN
        Qvib = Qvib / (1. - EXP(-TempRatio))
      END IF
    END DO
  ELSE
    Qrot = Temp / (SpecDSMC(iSpec)%SymmetryFactor * SpecDSMC(iSpec)%CharaTRot)
    TempRatio = SpecDSMC(iSpec)%CharaTVib/Temp
    IF(CHECKEXP(TempRatio)) THEN
      Qvib = 1. / (1. - EXP(-TempRatio))
    END IF
  END IF
END IF
IF((SpecDSMC(iSpec)%InterID.EQ.4).OR.SpecDSMC(iSpec)%FullyIonized) THEN
  Qelec = 1.
ELSE
  Qelec = 0.
  DO iDOF=0, SpecDSMC(iSpec)%MaxElecQuant - 1
    TempRatio = SpecDSMC(iSpec)%ElectronicState(2,iDOF) / Temp
    IF(CHECKEXP(TempRatio)) THEN
      Qelec = Qelec + SpecDSMC(iSpec)%ElectronicState(1,iDOF) * EXP(-TempRatio)
    END IF
  END DO
END IF

IF(Qelec.EQ.0.) Qelec = 1.

END SUBROUTINE CalcPartitionFunction


SUBROUTINE CalcBackwardRate(iReacTmp,LocalTemp,BackwardRate)
!===================================================================================================================================
! Calculation of the backward reaction rate with partition sums, interpolation within the given temperature interval
!===================================================================================================================================
! MODULES
USE MOD_Globals
USE MOD_DSMC_Vars             ,ONLY: DSMC, SpecDSMC, ChemReac, QKChemistry
USE MOD_Particle_Vars         ,ONLY: nSpecies
USE MOD_DSMC_QK_Chemistry     ,ONLY: QK_CalcAnalyticRate
! IMPLICIT VARIABLE HANDLING
IMPLICIT NONE
!-----------------------------------------------------------------------------------------------------------------------------------
! INPUT VARIABLES
INTEGER, INTENT(IN)           :: iReacTmp
REAL, INTENT(IN)              :: LocalTemp
REAL, INTENT(OUT)             :: BackwardRate
!-----------------------------------------------------------------------------------------------------------------------------------
! OUTPUT VARIABLES
!-----------------------------------------------------------------------------------------------------------------------------------
! LOCAL VARIABLES
INTEGER                         :: iReac, iSpec, LowerLevel, UpperLevel, iChemDir, MaxElecQua
REAL                            :: PartFuncProduct(2), k_b_lower, k_b_upper, ActivationEnergy_K, PartitionFunction
REAL                            :: Qtra, Qrot, Qvib, Qelec
!===================================================================================================================================
  ! Determination of the lower and upper value of the temperature interval
  LowerLevel = INT(LocalTemp/DSMC%PartitionInterval)
  UpperLevel = LowerLevel + 1

  ! Reading the stoichiometric coefficients from the reactants
  iReac = iReacTmp - ChemReac%NumOfReact/2
  IF (ChemReac%QKProcedure(iReac)) THEN
    IF (TRIM(ChemReac%ReactType(iReac)).EQ.'iQK') THEN
      MaxElecQua=SpecDSMC(ChemReac%DefinedReact(iReac,1,1))%MaxElecQuant - 1
      ActivationEnergy_K = SpecDSMC(ChemReac%DefinedReact(iReac,1,1))%ElectronicState(2,MaxElecQua)
    ELSEIF(TRIM(ChemReac%ReactType(iReac)).EQ.'D') THEN
      ActivationEnergy_K = SpecDSMC(ChemReac%DefinedReact(iReac,1,1))%Ediss_eV * 11604.52500617 ! eV -> K
    END IF
  END IF

  ! Calculation of the backward reaction rate using the equilibrium constant)
  IF((UpperLevel.GT.INT(DSMC%PartitionMaxTemp / DSMC%PartitionInterval)).OR.(LowerLevel.EQ.0)) THEN
  ! Direct calculation at given temperature
    PartFuncProduct(1:2) = 1.
    DO iSpec = 1, nSpecies
      DO iChemDir = 1,2
        IF(ChemReac%ReactInfo(iReac)%StoichCoeff(iSpec,iChemDir).NE.0) THEN
          CALL CalcPartitionFunction(iSpec, LocalTemp, Qtra, Qrot, Qvib, Qelec)
          PartitionFunction = Qtra * Qrot * Qvib * Qelec
          PartFuncProduct(iChemDir) = PartFuncProduct(iChemDir)   &
            * PartitionFunction**(ChemReac%ReactInfo(iReac)%StoichCoeff(iSpec,iChemDir))
        END IF
      END DO
    END DO
    IF (ChemReac%QKProcedure(iReac)) THEN
      BackwardRate = QK_CalcAnalyticRate(iReac,LocalTemp)*(PartFuncProduct(1)/PartFuncProduct(2))*EXP(ActivationEnergy_K/LocalTemp)
    ELSE
      BackwardRate = ChemReac%Arrhenius_Prefactor(iReac)  &
              * (LocalTemp)**ChemReac%Arrhenius_Powerfactor(iReac) &
              * (PartFuncProduct(1)/PartFuncProduct(2))
    END IF
  ELSE
  ! Interpolation between tabulated lower and upper values
    PartFuncProduct(1:2) = 1.
    DO iSpec = 1, nSpecies
      DO iChemDir = 1,2
        IF(ChemReac%ReactInfo(iReac)%StoichCoeff(iSpec,iChemDir).NE.0) THEN
          PartFuncProduct(iChemDir) = PartFuncProduct(iChemDir)   &
            * SpecDSMC(iSpec)%PartitionFunction(LowerLevel)**(ChemReac%ReactInfo(iReac)%StoichCoeff(iSpec,iChemDir))
        END IF
      END DO
    END DO
    IF((PartFuncProduct(1).NE.0.).AND.(PartFuncProduct(2).NE.0.)) THEN
      IF (ChemReac%QKProcedure(iReac)) THEN
        k_b_lower = QKChemistry(iReac)%ForwardRate(LowerLevel)* (PartFuncProduct(1)/PartFuncProduct(2)) &
            * EXP(ActivationEnergy_K/(LowerLevel * DSMC%PartitionInterval))
      ELSE
        k_b_lower = ChemReac%Arrhenius_Prefactor(iReac)  &
                * (LowerLevel * DSMC%PartitionInterval)**ChemReac%Arrhenius_Powerfactor(iReac) &
                * (PartFuncProduct(1)/PartFuncProduct(2))
      END IF
    ELSE
      k_b_lower = 0.0
    END IF

    PartFuncProduct(1:2) = 1.
    DO iSpec = 1, nSpecies
      DO iChemDir = 1,2
        IF(ChemReac%ReactInfo(iReac)%StoichCoeff(iSpec,iChemDir).NE.0) THEN
          PartFuncProduct(iChemDir) = PartFuncProduct(iChemDir)   &
            * SpecDSMC(iSpec)%PartitionFunction(UpperLevel)**(ChemReac%ReactInfo(iReac)%StoichCoeff(iSpec,iChemDir))
        END IF
      END DO
    END DO
    IF((PartFuncProduct(1).NE.0.).AND.(PartFuncProduct(2).NE.0.)) THEN
      IF (ChemReac%QKProcedure(iReac)) THEN
        k_b_upper = QKChemistry(iReac)%ForwardRate(UpperLevel)* (PartFuncProduct(1)/PartFuncProduct(2)) &
            * EXP(ActivationEnergy_K/(UpperLevel * DSMC%PartitionInterval))
      ELSE
        k_b_upper = ChemReac%Arrhenius_Prefactor(iReac) &
              * (UpperLevel * DSMC%PartitionInterval)**ChemReac%Arrhenius_Powerfactor(iReac) &
              * (PartFuncProduct(1)/PartFuncProduct(2))
      END IF
    ELSE
      k_b_upper = 0.0
    END IF
  ! Linear interpolation of the backward rate coefficient at the actual temperature
    BackwardRate = k_b_lower &
              + (k_b_upper - k_b_lower)  &
              / (DSMC%PartitionInterval) * (LocalTemp - LowerLevel * DSMC%PartitionInterval)
  END IF

END SUBROUTINE CalcBackwardRate


SUBROUTINE CalcPseudoScatterVars(PseuSpec1, PseuSpec2, ScatterSpec3, FracMassCent1, FracMassCent2, MassRed, Weight)
!===================================================================================================================================
! Routine determines the reduced mass and the mass fraction between a pseudo-molecule and third species
!===================================================================================================================================
! MODULES
  USE MOD_Globals
  USE MOD_Particle_Vars,         ONLY : Species
! IMPLICIT VARIABLE HANDLING
  IMPLICIT NONE
!-----------------------------------------------------------------------------------------------------------------------------------
! INPUT VARIABLES
  INTEGER, INTENT(IN)           :: PseuSpec1, PseuSpec2, ScatterSpec3
!-----------------------------------------------------------------------------------------------------------------------------------
! OUTPUT VARIABLES
  REAL, INTENT(OUT)             :: FracMassCent1, FracMassCent2, MassRed
  REAL, INTENT(IN), OPTIONAL    :: Weight(3)
!-----------------------------------------------------------------------------------------------------------------------------------
! LOCAL VARIABLES
  REAL                            :: Mass
!===================================================================================================================================
  IF (PRESENT(Weight)) THEN
    Mass = Species(PseuSpec1)%MassIC*Weight(1) + Species(PseuSpec2)%MassIC*Weight(2)
    FracMassCent1 = Mass / (Mass + Species(ScatterSpec3)%MassIC*Weight(3))
    FracMassCent2 = Species(ScatterSpec3)%MassIC*Weight(3) / (Mass + Species(ScatterSpec3)%MassIC*Weight(3))
    MassRed = (Mass*Species(ScatterSpec3)%MassIC*Weight(3)) &
                           / (Mass+Species(ScatterSpec3)%MassIC*Weight(3))
  ELSE
  Mass = Species(PseuSpec1)%MassIC + Species(PseuSpec2)%MassIC
  FracMassCent1 = Mass / (Mass + Species(ScatterSpec3)%MassIC)
  FracMassCent2 = Species(ScatterSpec3)%MassIC / (Mass + Species(ScatterSpec3)%MassIC)
  MassRed = (Mass*Species(ScatterSpec3)%MassIC) &
                         / (Mass+Species(ScatterSpec3)%MassIC)
  END IF
END SUBROUTINE CalcPseudoScatterVars


SUBROUTINE CalcPhotoIonizationNumber(NbrOfPhotons,NbrOfReactions)
!===================================================================================================================================
!>
!===================================================================================================================================
! MODULES
USE MOD_Globals
USE MOD_Globals_Vars  ,ONLY: c
USE MOD_Particle_Vars ,ONLY: Species
USE MOD_DSMC_Vars     ,ONLY: BGGas, ChemReac
USE MOD_TimeDisc_Vars ,ONLY: dt
! IMPLICIT VARIABLE HANDLING
IMPLICIT NONE
!-----------------------------------------------------------------------------------------------------------------------------------
! INPUT VARIABLES
REAL, INTENT(IN)              :: NbrOfPhotons
!-----------------------------------------------------------------------------------------------------------------------------------
! OUTPUT VARIABLES
REAL, INTENT(OUT)             :: NbrOfReactions
!-----------------------------------------------------------------------------------------------------------------------------------
! LOCAL VARIABLES
INTEGER                       :: bgSpec, iReac
!===================================================================================================================================

NbrOfReactions = 0.

DO iReac = 1, ChemReac%NumOfReact
  ! Only treat photoionization reactions
  IF(TRIM(ChemReac%ReactType(iReac)).NE.'phIon') CYCLE
  ! First reactant of the reaction is the actual heavy particle species
  bgSpec = BGGas%MapSpecToBGSpec(ChemReac%DefinedReact(iReac,1,1))
  ! Collision number: Z = n_gas * n_ph * sigma_reac * v (in the case of photons its speed of light)
  ! Number of reactions: N = Z * dt * V (number of photons cancels out the volume)
  NbrOfReactions = NbrOfReactions + BGGas%NumberDensity(bgSpec) * NbrOfPhotons * ChemReac%CrossSection(iReac) * c &
                                     *dt / Species(ChemReac%DefinedReact(iReac,1,1))%MacroParticleFactor
END DO

END SUBROUTINE CalcPhotoIonizationNumber


END MODULE MOD_DSMC_ChemReact
