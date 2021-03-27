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

#if (PP_TimeDiscMethod==1) || (PP_TimeDiscMethod==2) || (PP_TimeDiscMethod==6)
MODULE MOD_TimeStep
!===================================================================================================================================
! Module for the Temporal discretization
!===================================================================================================================================
! MODULES
! IMPLICIT VARIABLE HANDLING
IMPLICIT NONE
PRIVATE
!-----------------------------------------------------------------------------------------------------------------------------------
PUBLIC :: TimeStepByLSERK
!===================================================================================================================================
CONTAINS

SUBROUTINE TimeStepByLSERK()
!===================================================================================================================================
! Hesthaven book, page 64
! Low-Storage Runge-Kutta integration of degree 4 with 5 stages.
! This procedure takes the current time (time), the time step dt and the solution at
! the current time U(time) and returns the solution at the next time level.
!===================================================================================================================================
! MODULES
USE MOD_Globals
USE MOD_PreProc
USE MOD_Vector
USE MOD_TimeDisc_Vars          ,ONLY: dt,iStage,time
USE MOD_TimeDisc_Vars          ,ONLY: RK_a,RK_b,RK_c,nRKStages
USE MOD_DG_Vars                ,ONLY: U,Ut
USE MOD_PML_Vars               ,ONLY: U2,U2t,nPMLElems,DoPML,PMLnVar
USE MOD_PML                    ,ONLY: PMLTimeDerivative,CalcPMLSource
USE MOD_Equation               ,ONLY: DivCleaningDamping
USE MOD_Equation               ,ONLY: CalcSource
USE MOD_DG                     ,ONLY: DGTimeDerivative_weakForm
#ifdef PP_POIS
USE MOD_Equation               ,ONLY: DivCleaningDamping_Pois,EvalGradient
USE MOD_DG                     ,ONLY: DGTimeDerivative_weakForm_Pois
USE MOD_Equation_Vars          ,ONLY: Phi,Phit,nTotalPhi
#endif /*PP_POIS*/
#ifdef PARTICLES
USE MOD_Particle_Tracking      ,ONLY: PerformTracking
USE MOD_Particle_Tracking_vars ,ONLY: tTracking,tLocalization,MeasureTrackTime
USE MOD_PICDepo                ,ONLY: Deposition
USE MOD_PICInterpolation       ,ONLY: InterpolateFieldToParticle
USE MOD_Particle_Vars          ,ONLY: PartState, Pt, Pt_temp, LastPartPos, DelayTime, PEM, PDM, &
                                      doParticleMerge,DoFieldIonization
USE MOD_PICModels              ,ONLY: FieldIonization
USE MOD_part_RHS               ,ONLY: CalcPartRHS
USE MOD_PICInterpolation_Vars  ,ONLY: DoInterpolation
USE MOD_part_emission          ,ONLY: ParticleInserting
USE MOD_DSMC                   ,ONLY: DSMC_main
USE MOD_DSMC_Vars              ,ONLY: useDSMC, DSMC_RHS
USE MOD_part_MPFtools          ,ONLY: StartParticleMerge
USE MOD_Part_Tools             ,ONLY: UpdateNextFreePosition,isPushParticle
USE MOD_Particle_Localization  ,ONLY: CountPartsPerElem
USE MOD_TimeDisc_Vars          ,ONLY: iter
#if USE_MPI
USE MOD_Particle_MPI           ,ONLY: IRecvNbOfParticles, MPIParticleSend,MPIParticleRecv,SendNbOfparticles
USE MOD_Particle_MPI_Vars      ,ONLY: PartMPIExchange
#endif /*USE_MPI*/
#endif /*PARTICLES*/
#if USE_LOADBALANCE
USE MOD_LoadBalance_Timers     ,ONLY: LBStartTime,LBSplitTime,LBPauseTime
#endif /*USE_LOADBALANCE*/
! IMPLICIT VARIABLE HANDLING
IMPLICIT NONE
!-----------------------------------------------------------------------------------------------------------------------------------
! INPUT VARIABLES
!-----------------------------------------------------------------------------------------------------------------------------------
! LOCAL VARIABLES
REAL                          :: Ut_temp(   1:PP_nVar,0:PP_N,0:PP_N,0:PP_N,1:PP_nElems) ! temporal variable for Ut
REAL                          :: U2t_temp(  1:PMLnVar,0:PP_N,0:PP_N,0:PP_N,1:nPMLElems) ! temporal variable for U2t
REAL                          :: tStage,b_dt(1:nRKStages)
#ifdef PARTICLES
REAL                          :: timeStart,timeEnd
INTEGER                       :: iPart
#endif /*PARTICLES*/
#ifdef PP_POIS
REAL                          :: Phit_temp(1:4,0:PP_N,0:PP_N,0:PP_N,1:PP_nElems)
#endif /*PP_POIS*/
#if USE_LOADBALANCE
REAL                          :: tLBStart ! load balance
#endif /*USE_LOADBALANCE*/
!===================================================================================================================================

! RK coefficients
DO iStage=1,nRKStages
  b_dt(iStage)=RK_b(iStage)*dt
END DO
iStage=1

#ifdef PARTICLES
CALL CountPartsPerElem(ResetNumberOfParticles=.TRUE.) !for scaling of tParts of LB. Also done for state output of PartsPerElem

#if USE_LOADBALANCE
    CALL LBStartTime(tLBStart)
#endif /*USE_LOADBALANCE*/
IF (time.GE.DelayTime) THEN
  ! forces on particle
  ! can be used to hide sending of number of particles
  CALL InterpolateFieldToParticle()
  IF(DoFieldIonization) CALL FieldIonization()
  IF(DoInterpolation) CALL CalcPartRHS()
END IF
#if USE_LOADBALANCE
    CALL LBPauseTime(LB_INTERPOLATION,tLBStart)
#endif /*USE_LOADBALANCE*/

IF ((time.GE.DelayTime).OR.(iter.EQ.0)) THEN
  CALL Deposition()
END IF
#endif /*PARTICLES*/

! field solver
! time measurement in weakForm
CALL DGTimeDerivative_weakForm(time,time,0,doSource=.TRUE.)
#if USE_LOADBALANCE
CALL LBStartTime(tLBStart)
#endif /*USE_LOADBALANCE*/
IF(DoPML) THEN
  CALL CalcPMLSource()
  CALL PMLTimeDerivative()
END IF
#if USE_LOADBALANCE
  CALL LBPauseTime(LB_PML,tLBStart)
#endif /*USE_LOADBALANCE*/
CALL DivCleaningDamping()

#ifdef PP_POIS
! Potential
CALL DGTimeDerivative_weakForm_Pois(time,time,0)
CALL DivCleaningDamping_Pois()
#endif /*PP_POIS*/

! first RK step
#if USE_LOADBALANCE
CALL LBStartTime(tLBStart)
#endif /*USE_LOADBALANCE*/

! EM field
Ut_temp = Ut
U = U + Ut*b_dt(1)

#ifdef PP_POIS
Phit_temp = Phit
Phi = Phi + Phit*b_dt(1)
CALL EvalGradient()
#endif /*PP_POIS*/

#if USE_LOADBALANCE
CALL LBSplitTime(LB_DG,tLBStart)
#endif /*USE_LOADBALANCE*/
!PML auxiliary variables
IF(DoPML) THEN
  U2t_temp = U2t
  U2 = U2 + U2t*b_dt(1)
END IF
#if USE_LOADBALANCE
CALL LBSplitTime(LB_PML,tLBStart)
#endif /*USE_LOADBALANCE*/


#ifdef PARTICLES
LastPartPos(1:3,1:PDM%ParticleVecLength)=PartState(1:3,1:PDM%ParticleVecLength)
PEM%LastGlobalElemID(1:PDM%ParticleVecLength)=PEM%GlobalElemID(1:PDM%ParticleVecLength)
IF (time.GE.DelayTime) THEN
  DO iPart=1,PDM%ParticleVecLength
    IF (PDM%ParticleInside(iPart)) THEN
      Pt_temp(1:3,iPart) = PartState(4:6,iPart)
      PartState(1:3,iPart) = PartState(1:3,iPart) + PartState(4:6,iPart) * b_dt(1)
      ! Don't push the velocity component of neutral particles!
      IF(isPushParticle(iPart))THEN
        Pt_temp(4:6,iPart) = Pt(1:3,iPart)
        PartState(4:6,iPart) = PartState(4:6,iPart) + Pt(1:3,iPart)*b_dt(1)
      END IF
    END IF ! PDM%ParticleInside(iPart)
  END DO ! iPart=1,PDM%ParticleVecLength
#if USE_LOADBALANCE
  CALL LBPauseTime(LB_PUSH,tLBStart)
#endif /*USE_LOADBALANCE*/
END IF

IF ((time.GE.DelayTime).OR.(iter.EQ.0)) THEN
#if USE_LOADBALANCE
  CALL LBStartTime(tLBStart)
#endif /*USE_LOADBALANCE*/
#if USE_MPI
  CALL IRecvNbofParticles()
#endif /*USE_MPI*/
#if USE_LOADBALANCE
  CALL LBSplitTime(LB_PARTCOMM,tLBStart)
#endif /*USE_LOADBALANCE*/

  IF(MeasureTrackTime) CALL CPU_TIME(TimeStart)
  CALL PerformTracking()
  IF(MeasureTrackTime) THEN
    CALL CPU_TIME(TimeEnd)
    tTracking=tTracking+TimeEnd-TimeStart
  END IF
#if USE_LOADBALANCE
  CALL LBSplitTime(LB_TRACK,tLBStart)
#endif /*USE_LOADBALANCE*/
#if USE_MPI
  CALL SendNbOfParticles()
#endif /*USE_MPI*/
#if USE_LOADBALANCE
  CALL LBPauseTime(LB_PARTCOMM,tLBStart)
#endif /*USE_LOADBALANCE*/
END IF
#endif /*PARTICLES*/

DO iStage=2,nRKStages
  tStage=time+dt*RK_c(iStage)
#ifdef PARTICLES
  ! deposition
  IF (time.GE.DelayTime) THEN
#if USE_LOADBALANCE
    CALL LBStartTime(tLBStart)
#endif /*USE_LOADBALANCE*/
#if USE_LOADBALANCE
    CALL LBSplitTime(LB_INTERPOLATION,tLBStart)
#endif /*USE_LOADBALANCE*/
#if USE_MPI
    CALL MPIParticleSend()
#endif /*USE_MPI*/
#if USE_LOADBALANCE
    CALL LBPauseTime(LB_PARTCOMM,tLBStart)
#endif /*USE_LOADBALANCE*/

#if USE_MPI
    CALL MPIParticleRecv()
#endif /*USE_MPI*/
#if USE_LOADBALANCE
    CALL LBSplitTime(LB_PARTCOMM,tLBStart)
#endif /*USE_LOADBALANCE*/
    CALL InterpolateFieldToParticle()
    IF(DoInterpolation) CALL CalcPartRHS()
#if USE_LOADBALANCE
    CALL LBPauseTime(LB_INTERPOLATION,tLBStart)
#endif /*USE_LOADBALANCE*/

    CALL Deposition()
  END IF
  CALL CountPartsPerElem(ResetNumberOfParticles=.FALSE.) !for scaling of tParts of LB !why not rigth after "tStage=time+dt*RK_c(iStage)"?!
#endif /*PARTICLES*/

  ! field solver
  CALL DGTimeDerivative_weakForm(time,tStage,0,doSource=.TRUE.)
#if USE_LOADBALANCE
  CALL LBStartTime(tLBStart)
#endif /*USE_LOADBALANCE*/
  IF(DoPML) THEN
    CALL CalcPMLSource()
    CALL PMLTimeDerivative()
  END IF
#if USE_LOADBALANCE
  CALL LBSplitTime(LB_PML,tLBStart)
#endif /*USE_LOADBALANCE*/
  CALL DivCleaningDamping()
#ifdef PP_POIS
  CALL DGTimeDerivative_weakForm_Pois(time,tStage,0)
  CALL DivCleaningDamping_Pois()
#endif



  ! performe RK steps
  ! field step
  Ut_temp = Ut - Ut_temp*RK_a(iStage)
  U = U + Ut_temp*b_dt(iStage)
#if USE_LOADBALANCE
  CALL LBPauseTime(LB_DG,tLBStart)
#endif /*USE_LOADBALANCE*/

#ifdef PP_POIS
  Phit_temp = Phit - Phit_temp*RK_a(iStage)
  Phi = Phi + Phit_temp*b_dt(iStage)
  CALL EvalGradient()
#endif

  !PML auxiliary variables
#if USE_LOADBALANCE
  CALL LBStartTime(tLBStart)
#endif /*USE_LOADBALANCE*/
  IF(DoPML)THEN
    U2t_temp = U2t - U2t_temp*RK_a(iStage)
    U2 = U2 + U2t_temp*b_dt(iStage)
  END IF
#if USE_LOADBALANCE
  CALL LBPauseTime(LB_PML,tLBStart)
#endif /*USE_LOADBALANCE*/

#ifdef PARTICLES
  ! particle step
  IF (time.GE.DelayTime) THEN
#if USE_LOADBALANCE
    CALL LBStartTime(tLBStart)
#endif /*USE_LOADBALANCE*/
    LastPartPos(1:3,1:PDM%ParticleVecLength)=PartState(1:3,1:PDM%ParticleVecLength)
    PEM%LastGlobalElemID(1:PDM%ParticleVecLength)=PEM%GlobalElemID(1:PDM%ParticleVecLength)
    DO iPart=1,PDM%ParticleVecLength
      IF (PDM%ParticleInside(iPart)) THEN
        Pt_temp(1:3,iPart) = PartState(4:6,iPart) - RK_a(iStage) * Pt_temp(1:3,iPart)
        PartState(1:3,iPart) = PartState(1:3,iPart) + Pt_temp(1:3,iPart)*b_dt(iStage)
        ! Don't push the velocity component of neutral particles!
        IF(isPushParticle(iPart))THEN
          Pt_temp(4:6,iPart) =        Pt(1:3,iPart) - RK_a(iStage) * Pt_temp(4:6,iPart)
          PartState(4:6,iPart) = PartState(4:6,iPart) + Pt_temp(4:6,iPart)*b_dt(iStage)
        END IF
      END IF ! PDM%ParticleInside(iPart)
    END DO ! iPart=1,PDM%ParticleVecLength
#if USE_LOADBALANCE
    CALL LBSplitTime(LB_PUSH,tLBStart)
#endif /*USE_LOADBALANCE*/
#if USE_MPI
    CALL IRecvNbofParticles()
#endif /*USE_MPI*/
#if USE_LOADBALANCE
    CALL LBSplitTime(LB_PARTCOMM,tLBStart)
#endif /*USE_LOADBALANCE*/
    IF(MeasureTrackTime) CALL CPU_TIME(TimeStart)
    CALL PerformTracking()
    IF(MeasureTrackTime) THEN
      CALL CPU_TIME(TimeEnd)
      tTracking=tTracking+TimeEnd-TimeStart
    END IF
#if USE_LOADBALANCE
    CALL LBSplitTime(LB_TRACK,tLBStart)
#endif /*USE_LOADBALANCE*/
#if USE_MPI
    CALL SendNbOfParticles()
#endif /*USE_MPI*/
#if USE_LOADBALANCE
    CALL LBPauseTime(LB_PARTCOMM,tLBStart)
#endif /*USE_LOADBALANCE*/
  END IF
#endif /*PARTICLES*/

END DO

#ifdef PARTICLES
IF (time.GE.DelayTime) THEN
#if USE_LOADBALANCE
    CALL LBStartTime(tLBStart)
#endif /*USE_LOADBALANCE*/
  IF(MeasureTrackTime) CALL CPU_TIME(TimeStart)
  CALL ParticleInserting()
  IF(MeasureTrackTime) THEN
    CALL CPU_TIME(TimeEnd)
    tLocalization=tLocalization+TimeEnd-TimeStart
  END IF
#if USE_LOADBALANCE
  CALL LBSplitTime(LB_EMISSION,tLBStart)
#endif /*USE_LOADBALANCE*/
#if USE_MPI
  CALL MPIParticleSend()
  CALL MPIParticleRecv()
  PartMPIExchange%nMPIParticles=0
#endif /*USE_MPI*/
#if USE_LOADBALANCE
  CALL LBPauseTime(LB_PARTCOMM,tLBStart)
#endif /*USE_LOADBALANCE*/
END IF

IF (doParticleMerge) THEN
  IF (.NOT.(useDSMC)) THEN
#if USE_LOADBALANCE
    CALL LBStartTime(tLBStart)
#endif /*USE_LOADBALANCE*/
    ALLOCATE(PEM%pStart(1:PP_nElems)           , &
             PEM%pNumber(1:PP_nElems)          , &
             PEM%pNext(1:PDM%maxParticleNumber), &
             PEM%pEnd(1:PP_nElems) )
#if USE_LOADBALANCE
    CALL LBPauseTime(LB_SPLITMERGE,tLBStart)
#endif /*USE_LOADBALANCE*/
  END IF
END IF

IF ((time.GE.DelayTime).OR.(time.EQ.0)) CALL UpdateNextFreePosition()

IF (doParticleMerge) THEN
  CALL StartParticleMerge()
  IF (.NOT.(useDSMC)) THEN
    DEALLOCATE(PEM%pStart , &
               PEM%pNumber, &
               PEM%pNext  , &
               PEM%pEnd   )
  END IF
  CALL UpdateNextFreePosition()
END IF

IF (useDSMC) THEN
  IF (time.GE.DelayTime) THEN

    CALL DSMC_main()
#if USE_LOADBALANCE
    CALL LBStartTime(tLBStart)
#endif /*USE_LOADBALANCE*/
    PartState(4:6,1:PDM%ParticleVecLength) = PartState(4:6,1:PDM%ParticleVecLength) + DSMC_RHS(1:3,1:PDM%ParticleVecLength)
#if USE_LOADBALANCE
    CALL LBPauseTime(LB_DSMC,tLBStart)
#endif /*USE_LOADBALANCE*/
  END IF
END IF
#endif /*PARTICLES*/

END SUBROUTINE TimeStepByLSERK


END MODULE MOD_TimeStep
#endif