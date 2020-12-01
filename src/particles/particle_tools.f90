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

MODULE MOD_part_tools
!===================================================================================================================================
! Contains tools for particle related operations. This routine is uses MOD_Particle_Boundary_Tools, but not vice versa!
!===================================================================================================================================
! MODULES
! IMPLICIT VARIABLE HANDLING
IMPLICIT NONE
PRIVATE

INTERFACE UpdateNextFreePosition
  MODULE PROCEDURE UpdateNextFreePosition
END INTERFACE

INTERFACE VeloFromDistribution
  MODULE PROCEDURE VeloFromDistribution
END INTERFACE

INTERFACE DiceUnitVector
  MODULE PROCEDURE DiceUnitVector
END INTERFACE

INTERFACE isChargedParticle
  MODULE PROCEDURE isChargedParticle
END INTERFACE

INTERFACE isPushParticle
  MODULE PROCEDURE isPushParticle
END INTERFACE

INTERFACE isDepositParticle
  MODULE PROCEDURE isDepositParticle
END INTERFACE

INTERFACE isInterpolateParticle
  MODULE PROCEDURE isInterpolateParticle
END INTERFACE

INTERFACE StoreLostParticleProperties
  MODULE PROCEDURE StoreLostParticleProperties
END INTERFACE

!-----------------------------------------------------------------------------------------------------------------------------------
! GLOBAL VARIABLES
!-----------------------------------------------------------------------------------------------------------------------------------
! Private Part ---------------------------------------------------------------------------------------------------------------------
! Public Part ----------------------------------------------------------------------------------------------------------------------
PUBLIC :: UpdateNextFreePosition, DiceUnitVector, VeloFromDistribution, GetParticleWeight, isChargedParticle
PUBLIC :: isPushParticle, isDepositParticle, isInterpolateParticle, StoreLostParticleProperties
!===================================================================================================================================

CONTAINS

SUBROUTINE UpdateNextFreePosition()
!===================================================================================================================================
! Updates next free position
!===================================================================================================================================
! MODULES
USE MOD_Globals
USE MOD_Particle_Vars        ,ONLY: PDM,PEM, PartSpecies, doParticleMerge, vMPF_SpecNumElem
USE MOD_Particle_Vars        ,ONLY: PartState, VarTimeStep, usevMPF
USE MOD_DSMC_Vars            ,ONLY: useDSMC, CollInf
USE MOD_Particle_VarTimeStep ,ONLY: CalcVarTimeStep
#if USE_LOADBALANCE
USE MOD_LoadBalance_Timers   ,ONLY: LBStartTime,LBSplitTime,LBPauseTime
#endif /*USE_LOADBALANCE*/
! IMPLICIT VARIABLE HANDLING
IMPLICIT NONE
!-----------------------------------------------------------------------------------------------------------------------------------
! INPUT VARIABLES
!-----------------------------------------------------------------------------------------------------------------------------------
! OUTPUT VARIABLES
!-----------------------------------------------------------------------------------------------------------------------------------
! LOCAL VARIABLES
INTEGER            :: counter1,i,n
INTEGER            :: ElemID
#if !USE_MPI
INTEGER            :: OffSetElemMPI(0) = 0            !> Dummy offset for single-thread mode
#endif
#if USE_LOADBALANCE
REAL               :: tLBStart
#endif /*USE_LOADBALANCE*/
!===================================================================================================================================
#if USE_LOADBALANCE
CALL LBStartTime(tLBStart)
#endif /*USE_LOADBALANCE*/

IF(PDM%maxParticleNumber.EQ.0) RETURN
counter1 = 1
IF (useDSMC.OR.doParticleMerge.OR.usevMPF) THEN
  PEM%pNumber(:) = 0
END IF

n = PDM%ParticleVecLength !PDM%maxParticleNumber
PDM%ParticleVecLength = 0
PDM%insideParticleNumber = 0
IF (doParticleMerge) vMPF_SpecNumElem = 0

IF (useDSMC.OR.doParticleMerge.OR.usevMPF) THEN
  DO i=1,n
    IF (.NOT.PDM%ParticleInside(i)) THEN
      IF (CollInf%ProhibitDoubleColl) CollInf%OldCollPartner(i) = 0
      PDM%nextFreePosition(counter1) = i
      counter1 = counter1 + 1
    ELSE
      ElemID = PEM%LocalElemID(i)
      IF (PEM%pNumber(ElemID).EQ.0) THEN
        PEM%pStart(ElemID) = i                     ! Start of Linked List for Particles in Elem
      ELSE
        PEM%pNext(PEM%pEnd(ElemID)) = i            ! Next Particle of same Elem (Linked List)
      END IF
      PEM%pEnd(ElemID) = i
      PEM%pNumber(ElemID) = &                      ! Number of Particles in Element
          PEM%pNumber(ElemID) + 1
      IF (VarTimeStep%UseVariableTimeStep) THEN
        VarTimeStep%ParticleTimeStep(i) = CalcVarTimeStep(PartState(1,i),PartState(2,i),ElemID)
      END IF
      PDM%ParticleVecLength = i
      IF(doParticleMerge) vMPF_SpecNumElem(ElemID,PartSpecies(i)) = vMPF_SpecNumElem(ElemID,PartSpecies(i)) + 1
    END IF
  END DO
ELSE ! no DSMC
  DO i=1,n
    IF (.NOT.PDM%ParticleInside(i)) THEN
      PDM%nextFreePosition(counter1) = i
      counter1 = counter1 + 1
    ELSE
      PDM%ParticleVecLength = i
    END IF
  END DO
ENDIF
PDM%insideParticleNumber = PDM%ParticleVecLength - counter1+1
PDM%CurrentNextFreePosition = 0
DO i = n+1,PDM%maxParticleNumber
  IF (CollInf%ProhibitDoubleColl) CollInf%OldCollPartner(i) = 0
  PDM%nextFreePosition(counter1) = i
  counter1 = counter1 + 1
END DO
PDM%nextFreePosition(counter1:PDM%MaxParticleNumber)=0 ! exists if MaxParticleNumber is reached!!!
IF (counter1.GT.PDM%MaxParticleNumber) PDM%nextFreePosition(PDM%MaxParticleNumber)=0

#if USE_LOADBALANCE
CALL LBPauseTime(LB_UNFP,tLBStart)
#endif /*USE_LOADBALANCE*/

  RETURN
END SUBROUTINE UpdateNextFreePosition


SUBROUTINE StoreLostParticleProperties(iPart,ElemID,UsePartState_opt)
!----------------------------------------------------------------------------------------------------------------------------------!
! Store information of a lost particle (during restart and during the simulation)
!----------------------------------------------------------------------------------------------------------------------------------!
! MODULES                                                                                                                          !
USE MOD_Globals                ,ONLY: abort
USE MOD_Particle_Vars          ,ONLY: usevMPF,PartMPF,PartSpecies,Species,PartState,LastPartPos
USE MOD_Particle_Tracking_Vars ,ONLY: PartStateLost,PartStateLostVecLength
USE MOD_TimeDisc_Vars          ,ONLY: time
!----------------------------------------------------------------------------------------------------------------------------------!
! insert modules here
!----------------------------------------------------------------------------------------------------------------------------------!
IMPLICIT NONE
! INPUT / OUTPUT VARIABLES 
INTEGER,INTENT(IN)          :: iPart
INTEGER,INTENT(IN)          :: ElemID ! Global element index
LOGICAL,INTENT(IN),OPTIONAL :: UsePartState_opt
INTEGER                     :: dims(2)
!-----------------------------------------------------------------------------------------------------------------------------------
! LOCAL VARIABLES
REAL                 :: MPF
! Temporary arrays
REAL, ALLOCATABLE    :: PartStateLost_tmp(:,:)   ! (1:11,1:NParts) 1st index: x,y,z,vx,vy,vz,SpecID,MPF,time,ElemID,iPart
!                                                !                 2nd index: 1 to number of lost particles
INTEGER              :: ALLOCSTAT
LOGICAL              :: UsePartState_loc
!===================================================================================================================================
UsePartState_loc = .FALSE.
IF (PRESENT(UsePartState_opt)) UsePartState_loc = UsePartState_opt

! Set macro particle factor
IF (usevMPF) THEN
  MPF = PartMPF(iPart)
ELSE
  MPF = Species(PartSpecies(iPart))%MacroParticleFactor
END IF

dims = SHAPE(PartStateLost)

ASSOCIATE( iMax => PartStateLostVecLength )
  ! Increase maximum number of boundary-impact particles
  iMax = iMax + 1

  ! Check if array maximum is reached. 
  ! If this happens, re-allocate the arrays and increase their size (every time this barrier is reached, double the size)
  IF(iMax.GT.dims(2))THEN

    ! --- PartStateLost ---
    ALLOCATE(PartStateLost_tmp(1:14,1:dims(2)), STAT=ALLOCSTAT)
    IF (ALLOCSTAT.NE.0) CALL abort(&
          __STAMP__&
          ,'ERROR in particle_boundary_tools.f90: Cannot allocate PartStateLost_tmp temporary array!')
    ! Save old data
    PartStateLost_tmp(1:14,1:dims(2)) = PartStateLost(1:14,1:dims(2))

    ! Re-allocate PartStateLost to twice the size
    DEALLOCATE(PartStateLost)
    ALLOCATE(PartStateLost(1:14,1:2*dims(2)), STAT=ALLOCSTAT)
    IF (ALLOCSTAT.NE.0) CALL abort(&
          __STAMP__&
          ,'ERROR in particle_boundary_tools.f90: Cannot allocate PartStateLost array!')
    PartStateLost(1:14,        1:  dims(2)) = PartStateLost_tmp(1:14,1:dims(2))
    PartStateLost(1:14,dims(2)+1:2*dims(2)) = 0.

  END IF

  !ParticlePositionX,
  !ParticlePositionY,
  !ParticlePositionZ,
  !VelocityX,
  !VelocityY,
  !VelocityZ,
  !Species,
  !ElementID,
  !PartID,
  !LastPos-X,
  !LastPos-Y,
  !LastPos-Z

  IF(UsePartState_loc)THEN
    PartStateLost(1:3,iMax) = PartState(1:3,iPart)
  ELSE
    PartStateLost(1:3,iMax) = LastPartPos(1:3,iPart)
  END IF ! UsePartState_loc
  PartStateLost(4:6  ,iMax) = PartState(4:6,iPart)
  PartStateLost(7    ,iMax) = REAL(PartSpecies(iPart))
  PartStateLost(8    ,iMax) = MPF
  PartStateLost(9    ,iMax) = time
  PartStateLost(10   ,iMax) = REAL(ElemID)
  PartStateLost(11   ,iMax) = REAL(iPart)
  PartStateLost(12:14,iMax) = PartState(1:3,iPart)
END ASSOCIATE

END SUBROUTINE StoreLostParticleProperties


FUNCTION DiceUnitVector()
!===================================================================================================================================
!> Calculates random unit vector
!===================================================================================================================================
! MODULES
! IMPLICIT VARIABLE HANDLING
USE MOD_Globals_Vars ,ONLY: Pi
IMPLICIT NONE
!-----------------------------------------------------------------------------------------------------------------------------------
! INPUT VARIABLES
!-----------------------------------------------------------------------------------------------------------------------------------
! OUTPUT VARIABLES
!-----------------------------------------------------------------------------------------------------------------------------------
! LOCAL VARIABLES
  REAL                     :: DiceUnitVector(3)
  REAL                     :: rRan, cos_scatAngle, sin_scatAngle, rotAngle
!===================================================================================================================================
  CALL RANDOM_NUMBER(rRan)

  cos_scatAngle     = 2.*rRan-1.
  sin_scatAngle     = SQRT(1. - cos_scatAngle ** 2.)
  DiceUnitVector(1) = cos_scatAngle

  CALL RANDOM_NUMBER(rRan)
  rotAngle          = 2. * Pi * rRan

  DiceUnitVector(2) = sin_scatAngle * COS(rotAngle)
  DiceUnitVector(3) = sin_scatAngle * SIN(rotAngle)

END FUNCTION DiceUnitVector

FUNCTION VeloFromDistribution(distribution,specID,Tempergy)
!===================================================================================================================================
!> calculation of velocityvector (Vx,Vy,Vz) sampled from given distribution function
!===================================================================================================================================
! MODULES
! IMPLICIT VARIABLE HANDLING
USE MOD_Globals                 ,ONLY: Abort,UNIT_stdOut
IMPLICIT NONE
!-----------------------------------------------------------------------------------------------------------------------------------
! INPUT VARIABLES
CHARACTER(LEN=*),INTENT(IN) :: distribution !< specifying keyword for velocity distribution
INTEGER,INTENT(IN)          :: specID       !< input species
REAL,INTENT(IN)             :: Tempergy     !< input temperature [K] or energy [J] or velocity [m/s]
!-----------------------------------------------------------------------------------------------------------------------------------
! OUTPUT VARIABLES
REAL            :: VeloFromDistribution(1:3)
!-----------------------------------------------------------------------------------------------------------------------------------
! LOCAL VARIABLES
!===================================================================================================================================
!-- set velocities
SELECT CASE(TRIM(distribution))
CASE('deltadistribution')
  !Velosq = 2
  !DO WHILE ((Velosq .GE. 1.) .OR. (Velosq .EQ. 0.))
    !CALL RANDOM_NUMBER(RandVal)
    !Velo1 = 2.*RandVal(1) - 1.
    !Velo2 = 2.*RandVal(2) - 1.
    !Velosq = Velo1**2 + Velo2**2
  !END DO
  !VeloFromDistribution(1) = Velo1*SQRT(-2*LOG(Velosq)/Velosq)
  !VeloFromDistribution(2) = Velo2*SQRT(-2*LOG(Velosq)/Velosq)
  !CALL RANDOM_NUMBER(RandVal)
  !VeloFromDistribution(3) = SQRT(-2*LOG(RandVal(1)))

  ! Get random vector
  VeloFromDistribution = DiceUnitVector()
  ! Mirror z-component of velocity (particles are emitted from surface!)
  VeloFromDistribution(3) = ABS(VeloFromDistribution(3))
  ! Set magnitude
  VeloFromDistribution = Tempergy*VeloFromDistribution
CASE DEFAULT
  WRITE (UNIT_stdOut,'(A)') "distribution =", distribution
  CALL abort(&
__STAMP__&
,'wrong velo-distri!')
END SELECT

END FUNCTION VeloFromDistribution


PURE REAL FUNCTION GetParticleWeight(iPart)
!===================================================================================================================================
!> Determines the appropriate particle weighting for the axisymmetric case with radial weighting and the variable time step. For
!> radial weighting, the radial factor is multiplied by the regular weighting factor. If only a variable time step is used, at the
!> moment, the regular weighting factor is not included.
!===================================================================================================================================
! MODULES
! IMPLICIT VARIABLE HANDLING
USE MOD_Particle_Vars           ,ONLY: usevMPF, VarTimeStep, PartMPF
USE MOD_DSMC_Vars               ,ONLY: RadialWeighting
IMPLICIT NONE
!-----------------------------------------------------------------------------------------------------------------------------------
! INPUT VARIABLES
INTEGER, INTENT(IN)             :: iPart
!===================================================================================================================================

IF(usevMPF.OR.RadialWeighting%DoRadialWeighting) THEN
  IF (VarTimeStep%UseVariableTimeStep) THEN
    GetParticleWeight = PartMPF(iPart) * VarTimeStep%ParticleTimeStep(iPart)
  ELSE
    GetParticleWeight = PartMPF(iPart)
  END IF
ELSE IF (VarTimeStep%UseVariableTimeStep) THEN
  GetParticleWeight = VarTimeStep%ParticleTimeStep(iPart)
ELSE
  GetParticleWeight = 1.
END IF

END FUNCTION GetParticleWeight


PURE FUNCTION isChargedParticle(iPart)
!----------------------------------------------------------------------------------------------------------------------------------!
! Check if particle has charge unequal to zero and return T/F logical.
!----------------------------------------------------------------------------------------------------------------------------------!
! MODULES                                                                                                                          !
!----------------------------------------------------------------------------------------------------------------------------------!
USE MOD_Particle_Vars ,ONLY: PartSpecies,Species
!----------------------------------------------------------------------------------------------------------------------------------!
IMPLICIT NONE
! INPUT / OUTPUT VARIABLES
INTEGER,INTENT(IN)  :: iPart
LOGICAL             :: isChargedParticle
!-----------------------------------------------------------------------------------------------------------------------------------
! LOCAL VARIABLES
!===================================================================================================================================
IF(ABS(Species(PartSpecies(iPart))%ChargeIC).GT.0.0)THEN
  isChargedParticle = .TRUE.
ELSE
  isChargedParticle = .FALSE.
END IF ! ABS(Species(PartSpecies(iPart))%ChargeIC).GT.0.0
END FUNCTION isChargedParticle


PURE FUNCTION isPushParticle(iPart)
!----------------------------------------------------------------------------------------------------------------------------------!
! Check if particle is to be evolved in time by the particle pusher (time integration).
!----------------------------------------------------------------------------------------------------------------------------------!
! MODULES                                                                                                                          !
!----------------------------------------------------------------------------------------------------------------------------------!
#if (PP_TimeDiscMethod==300) /*FP-Flow*/
USE MOD_Particle_Vars ,ONLY: PartSpecies,Species ! Change this when required
#elif (PP_TimeDiscMethod==400) /*BGK*/
USE MOD_Particle_Vars ,ONLY: PartSpecies,Species ! Change this when required
#else /*all other methods, mainly PIC*/
USE MOD_Particle_Vars ,ONLY: PartSpecies,Species
#endif
!----------------------------------------------------------------------------------------------------------------------------------!
IMPLICIT NONE
! INPUT / OUTPUT VARIABLES
INTEGER,INTENT(IN)  :: iPart
LOGICAL             :: isPushParticle
!-----------------------------------------------------------------------------------------------------------------------------------
! LOCAL VARIABLES
!===================================================================================================================================
IF(ABS(Species(PartSpecies(iPart))%ChargeIC).GT.0.0)THEN
  isPushParticle = .TRUE.
ELSE
  isPushParticle = .FALSE.
END IF ! ABS(Species(PartSpecies(iPart))%ChargeIC).GT.0.0
END FUNCTION isPushParticle


PURE FUNCTION isDepositParticle(iPart)
!----------------------------------------------------------------------------------------------------------------------------------!
! Check if particle is to be deposited on the grid (particle-to-grid coupling).
!----------------------------------------------------------------------------------------------------------------------------------!
! MODULES                                                                                                                          !
!----------------------------------------------------------------------------------------------------------------------------------!
#if (PP_TimeDiscMethod==300) /*FP-Flow*/
USE MOD_Particle_Vars ,ONLY: PartSpecies,Species ! Change this when required
#elif (PP_TimeDiscMethod==400) /*BGK*/
USE MOD_Particle_Vars ,ONLY: PartSpecies,Species ! Change this when required
#else /*all other methods, mainly PIC*/
USE MOD_Particle_Vars ,ONLY: PartSpecies,Species
#endif
!----------------------------------------------------------------------------------------------------------------------------------!
IMPLICIT NONE
! INPUT / OUTPUT VARIABLES
INTEGER,INTENT(IN)  :: iPart
LOGICAL             :: isDepositParticle
!-----------------------------------------------------------------------------------------------------------------------------------
! LOCAL VARIABLES
!===================================================================================================================================
IF(ABS(Species(PartSpecies(iPart))%ChargeIC).GT.0.0)THEN
  isDepositParticle = .TRUE.
ELSE
  isDepositParticle = .FALSE.
END IF ! ABS(Species(PartSpecies(iPart))%ChargeIC).GT.0.0
END FUNCTION isDepositParticle


PURE FUNCTION isInterpolateParticle(iPart)
!----------------------------------------------------------------------------------------------------------------------------------!
! Check if particle is to be interpolated (field-to-particle coupling), which is required for calculating the acceleration, e.g.,
! due to Lorentz forces at the position of the particle.
!----------------------------------------------------------------------------------------------------------------------------------!
! MODULES                                                                                                                          !
!----------------------------------------------------------------------------------------------------------------------------------!
#if (PP_TimeDiscMethod==300) /*FP-Flow*/
USE MOD_Particle_Vars ,ONLY: PartSpecies,Species ! Change this when required
#elif (PP_TimeDiscMethod==400) /*BGK*/
USE MOD_Particle_Vars ,ONLY: PartSpecies,Species ! Change this when required
#else /*all other methods, mainly PIC*/
USE MOD_Particle_Vars ,ONLY: PartSpecies,Species
#endif
!----------------------------------------------------------------------------------------------------------------------------------!
IMPLICIT NONE
! INPUT / OUTPUT VARIABLES
INTEGER,INTENT(IN)  :: iPart
LOGICAL             :: isInterpolateParticle
!-----------------------------------------------------------------------------------------------------------------------------------
! LOCAL VARIABLES
!===================================================================================================================================
IF(ABS(Species(PartSpecies(iPart))%ChargeIC).GT.0.0)THEN
  isInterpolateParticle = .TRUE.
ELSE
  isInterpolateParticle = .FALSE.
END IF ! ABS(Species(PartSpecies(iPart))%ChargeIC).GT.0.0
END FUNCTION isInterpolateParticle

END MODULE MOD_part_tools
