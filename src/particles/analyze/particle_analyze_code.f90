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

MODULE MOD_Particle_Analyze_Code
! IMPLICIT VARIABLE HANDLING
IMPLICIT NONE
#if defined(PARTICLES) && defined(CODE_ANALYZE)
PRIVATE
!-----------------------------------------------------------------------------------------------------------------------------------
! GLOBAL VARIABLES
!-----------------------------------------------------------------------------------------------------------------------------------
! Private Part ---------------------------------------------------------------------------------------------------------------------
! Public Part ----------------------------------------------------------------------------------------------------------------------
PUBLIC :: WriteParticleTrackingDataAnalytic 
PUBLIC :: CalcAnalyticalParticleState
PUBLIC :: AnalyticParticleMovement
!===================================================================================================================================

CONTAINS

!===================================================================================================================================
!> Calculate the analytical position and velocity depending on the pre-defined function
!===================================================================================================================================
SUBROUTINE CalcAnalyticalParticleState(t,PartStateAnalytic,alpha_out,theta_out)
! MODULES
USE MOD_Globals
USE MOD_Globals_Vars          ,ONLY: PI
USE MOD_Preproc
USE MOD_PICInterpolation_Vars ,ONLY: AnalyticInterpolationType,AnalyticInterpolationSubType,AnalyticInterpolationP
USE MOD_PICInterpolation_Vars ,ONLY: AnalyticInterpolationPhase
USE MOD_TimeDisc_Vars         ,ONLY: TEnd
USE MOD_PARTICLE_Vars         ,ONLY: PartSpecies,Species
! IMPLICIT VARIABLE HANDLING
IMPLICIT NONE
!----------------------------------------------------------------------------------------------------------------------------------
! INPUT VARIABLES
REAL,INTENT(IN)               :: t                        !< simulation time
!----------------------------------------------------------------------------------------------------------------------------------
! OUTPUT VARIABLES
REAL,INTENT(OUT)              :: PartStateAnalytic(1:6)   !< analytic position and velocity
REAL,INTENT(OUT),OPTIONAL     :: alpha_out                    !< dimensionless parameter: alpha_out = q*B_0*l / (m*v_perpendicular)
REAL,INTENT(OUT),OPTIONAL     :: theta_out                    !< angle
!----------------------------------------------------------------------------------------------------------------------------------
! LOCAL VARIABLES
!REAL    :: p
REAL    :: gamma_0
REAL    :: phi_0
REAL    :: Theta
REAL    :: beta
!===================================================================================================================================
PartStateAnalytic=0. ! default

ASSOCIATE( iPart => 1 )
  ! Select analytical solution depending on the type of the selected (analytic) interpolation
  SELECT CASE(AnalyticInterpolationType)
  ! 0: const. magnetostatic field: B = B_z = (/ 0 , 0 , 1 T /) = const.
  CASE(0)
    ASSOCIATE( B_0    => 1.0                                    ,& ! [T] cons. magnetic field
               v_perp => 1.0                                    ,& ! [m/s] perpendicular velocity (to guiding center)
               m      => Species(PartSpecies(iPart))%MassIC     ,& ! [kg] particle mass
               q      => Species(PartSpecies(iPart))%ChargeIC   ,& ! [C] particle charge
               phi    => AnalyticInterpolationPhase             )  ! [rad] phase shift
      ASSOCIATE( omega_c => ABS(q)*B_0/m )
        ASSOCIATE( r_c => v_perp/omega_c )
          PartStateAnalytic(1) = COS(omega_c*t + phi)*r_c
          PartStateAnalytic(2) = SIN(omega_c*t + phi)*r_c
          PartStateAnalytic(3) = 0.
          PartStateAnalytic(4) = -SIN(omega_c*t + phi)*v_perp
          PartStateAnalytic(5) =  COS(omega_c*t + phi)*v_perp
          PartStateAnalytic(6) = 0.
        END ASSOCIATE
      END ASSOCIATE
    END ASSOCIATE
  ! 1: magnetostatic field: B = B_z = (/ 0 , 0 , B_0 * EXP(x/l) /) = const.
  CASE(1)
    SELECT CASE(AnalyticInterpolationSubType)
    CASE(1,2)
      ASSOCIATE( p       => AnalyticInterpolationP , &
                 Theta_0 => -PI/2.0                     , &
                 t       => t - TEnd/2. )
                 !t       => t )
        ! gamma
        gamma_0 = SQRT(ABS(p*p - 1.))

        ! angle
        Theta   = -2.*ATAN( SQRT((1.+p)/(1.-p)) * TANH(0.5*gamma_0*t) ) + Theta_0

        ! x-pos
        PartStateAnalytic(1) = LOG(-SIN(Theta) + p )

        ! y-pos
        PartStateAnalytic(2) = p*t + Theta - Theta_0
      END ASSOCIATE
    CASE(3)
      ASSOCIATE( p       => AnalyticInterpolationP , &
                 Theta_0 => -PI/2.0                      &
                  )
        ! gamma
        gamma_0 = SQRT(ABS(p*p - 1.))

        ! angle
        Theta   = -2.*ATAN( SQRT((p+1.)/(p-1.)) * TAN(0.5*gamma_0*t) ) -2.*PI*REAL(NINT((gamma_0*t)/(2.*PI))) + Theta_0

        ! x-pos
        PartStateAnalytic(1) = LOG(-SIN(Theta) + p )

        ! y-pos
        PartStateAnalytic(2) = p*t + Theta - Theta_0
      END ASSOCIATE
    CASE(11,21) ! old version of CASE(1,2)
      ASSOCIATE( p       => AnalyticInterpolationP , &
            Theta_0 => 0.d0 ) !0.785398163397448d0    )
        beta = ACOS(p)
        !beta = ASIN(-p)
        ! phase shift
        phi_0   = ATANH( (1./TAN(beta/2.)) * TAN(Theta_0/2.) )
        ! angle
        Theta   = -2.*ATANH( TAN(beta/2.) * TANH(0.5*t*SIN(beta)-phi_0) )
        Theta   = -2.*ATANH( TAN(beta/2.) * TANH(0.5*SIN(beta*t)-phi_0) )
        ! x-pos
        PartStateAnalytic(1) = LOG((COS(Theta)-p)/(COS(Theta_0)-p))
        ! y-pos
        PartStateAnalytic(2) = p*t - (Theta-Theta_0)
      END ASSOCIATE
    CASE(31) ! old version of CASE(3)
      ASSOCIATE( p       => AnalyticInterpolationP , &
                 Theta_0 => 0.d0                   )
        gamma_0 = SQRT(p*p-1.)
        ! phase shift
        phi_0   = ATAN( (gamma_0/(p-1.)) * TAN(Theta_0/2.) )
        ! angle
        Theta   = 2.*ATAN( SQRT((p-1)/(p+1)) * TAN(0.5*gamma_0*t - phi_0) ) + 2*Pi*REAL(NINT((t*gamma_0)/(2*Pi) - phi_0/Pi))
        ! x-pos
        PartStateAnalytic(1) = LOG((COS(Theta)-p)/(COS(Theta_0)-p))
        ! y-pos
        PartStateAnalytic(2) = p*t - (Theta-Theta_0)
      END ASSOCIATE
    END SELECT

    SELECT CASE(AnalyticInterpolationSubType)
    CASE(1,2,3)
      ! Set analytic velocity
      PartStateAnalytic(4) = COS(Theta)
      PartStateAnalytic(5) = SIN(Theta)
      PartStateAnalytic(6) = 0.
    CASE(11,21,31)
      ! Set analytic velocity
      PartStateAnalytic(4) = SIN(Theta)
      PartStateAnalytic(5) = COS(Theta)
      PartStateAnalytic(6) = 0.
    END SELECT

    ! Optional output variables
    IF(PRESENT(alpha_out))THEN
      ASSOCIATE( dot_theta => SIN(Theta) - AnalyticInterpolationP )
        ASSOCIATE( alpha_0 => -dot_theta / EXP(PartStateAnalytic(1)) )
          alpha_out = alpha_0
          WRITE (*,*) "alpha_out =", alpha_out
        END ASSOCIATE
      END ASSOCIATE
    END IF
    IF(PRESENT(theta_out))THEN
      theta_out = Theta
      WRITE (*,*) "theta_out =", theta_out
    END IF
  ! 2: const. electromagnetic field: B = B_z = (/ 0 , 0 , (x^2+y^2)^0.5 /) = const.
  !                                  E = 1e-2/(x^2+y^2)^(3/2) * (/ x , y , 0. /)
  CASE(2)
    ! missing ...
  END SELECT
END ASSOCIATE

END SUBROUTINE CalcAnalyticalParticleState


!===================================================================================================================================
!> Calculates "running" L_2 norms
!> running means: use the old L_2 error from the previous iteration in order to determine the L_2 error over time (simulation time)
!>
!> -------------------------------------------------------------------------
!> OLD METHOD: assuming constant timestep (ignoring the total time tEnd -> Delta t = tEnd / Niter)
!> L_2(t) = SQRT( ( L_2(t-1)^2 * (iter-1) + delta(t)^2 ) / iter )
!>
!> -------------------------------------------------------------------------
!> NEW METHOD: assuming variable timestep
!> L_2(t) = SQRT(  L_2(t-1)^2   +   (t - t_old) * delta(t)^2  )
!>
!> t     : simulation time
!> t_old : simulation time of the last iteration
!> L_2   : error norm
!> delta : difference numerical to analytical solution
!> iter  : simulation iteration counter
!===================================================================================================================================
SUBROUTINE CalcErrorParticle(t,iter,PartStateAnalytic)
! MODULES
USE MOD_PICInterpolation_Vars ,ONLY: L_2_Error_Part,L_2_Error_Part_time
USE MOD_Particle_Vars         ,ONLY: PartState, PDM
! OLD METHOD: considering TEnd:
! USE MOD_TimeDisc_Vars         ,ONLY: TEnd
! IMPLICIT VARIABLE HANDLING
IMPLICIT NONE
!----------------------------------------------------------------------------------------------------------------------------------
! INPUT VARIABLES
INTEGER(KIND=8),INTENT(IN)    :: iter                     !< simulation iteration counter
REAL,INTENT(IN)               :: t                        !< simulation time
REAL,INTENT(INOUT)            :: PartStateAnalytic(1:6)   !< analytic position and velocity
!----------------------------------------------------------------------------------------------------------------------------------
! OUTPUT VARIABLES
!----------------------------------------------------------------------------------------------------------------------------------
! LOCAL VARIABLES
INTEGER                       :: iPart,iPartState
!===================================================================================================================================
! Get analytic particle position
CALL CalcAnalyticalParticleState(t,PartStateAnalytic)

! Depending on the iteration counter, set the L_2 error (re-use the value in the next loop)
IF(iter.LT.1)THEN ! first iteration
  L_2_Error_Part(1:6) = 0.
  L_2_Error_Part_time = 0.
ELSE
  DO iPart=1,PDM%ParticleVecLength
    IF (PDM%ParticleInside(iPart)) THEN
      DO iPartState = 1, 6
        ! OLD METHOD: original
        ! L_2_Error_Part(iPartState) = SQRT( ( (L_2_Error_Part(iPartState))**2*REAL(iter-1) + &
        !                               (PartStateAnalytic(iPartState)-PartState(iPartState,iPart))**2 )/ REAL(iter))

        ! OLD METHOD: considering TEnd
        ! L_2_Error_Part(iPartState) = SQRT( Tend * ( (L_2_Error_Part(iPartState))**2*REAL(iter-1) + &
        !                               (PartStateAnalytic(iPartState)-PartState(iPartState,iPart))**2 ) &
        !                      / REAL(iter))

        ! NEW METHOD: considering variable time step
        L_2_Error_Part(iPartState) = SQRT(  (L_2_Error_Part(iPartState))**2 + &
                                   (t-L_2_Error_Part_time)*(PartStateAnalytic(iPartState)-PartState(iPartState,iPart))**2 )
      END DO ! iPartState = 1, 6
      L_2_Error_Part_time = t
    ELSE
      L_2_Error_Part(1:6) = -1.0
    END IF
  END DO
END IF

END SUBROUTINE CalcErrorParticle


!===================================================================================================================================
!> Calculate the analytical position and velocity depending on the pre-defined function
!===================================================================================================================================
SUBROUTINE AnalyticParticleMovement(time,iter)
! MODULES
USE MOD_Globals
USE MOD_Preproc
USE MOD_Analyze_Vars           ,ONLY: OutputErrorNorms
USE MOD_Particle_Analyze_Vars  ,ONLY: TrackParticlePosition
USE MOD_PICInterpolation_Vars  ,ONLY: L_2_Error_Part
USE MOD_Particle_MPI_Vars      ,ONLY: PartMPI
! IMPLICIT VARIABLE HANDLING
IMPLICIT NONE
!----------------------------------------------------------------------------------------------------------------------------------
! INPUT VARIABLES
REAL,INTENT(IN)               :: time                        !< simulation time
INTEGER(KIND=8),INTENT(IN)    :: iter                        !< iteration
!----------------------------------------------------------------------------------------------------------------------------------
! OUTPUT VARIABLES
!----------------------------------------------------------------------------------------------------------------------------------
! LOCAL VARIABLES
REAL                          :: PartStateAnalytic(1:6)   !< analytic position and velocity
CHARACTER(LEN=40)             :: formatStr
!===================================================================================================================================

CALL CalcErrorParticle(time,iter,PartStateAnalytic)
IF(PartMPI%MPIRoot.AND.OutputErrorNorms) THEN
  WRITE(UNIT_StdOut,'(A13,ES16.7)')' Sim time  : ',time
  WRITE(formatStr,'(A5,I1,A7)')'(A13,',6,'ES16.7)'
  WRITE(UNIT_StdOut,formatStr)' L2_Part   : ',L_2_Error_Part
  OutputErrorNorms=.FALSE.
END IF
IF(TrackParticlePosition) CALL WriteParticleTrackingDataAnalytic(time,iter,PartStateAnalytic) ! new function

END SUBROUTINE AnalyticParticleMovement


!----------------------------------------------------------------------------------------------------------------------------------!
!> Write analytic particle info to ParticlePositionAnalytic.csv file
!> time, pos, velocity
!----------------------------------------------------------------------------------------------------------------------------------!
SUBROUTINE WriteParticleTrackingDataAnalytic(time,iter,PartStateAnalytic)
!----------------------------------------------------------------------------------------------------------------------------------!
! MODULES                                                                                                                          !
!----------------------------------------------------------------------------------------------------------------------------------!
USE MOD_Globals               ,ONLY: MPIRoot,FILEEXISTS,unit_stdout
USE MOD_Restart_Vars          ,ONLY: DoRestart
USE MOD_Globals               ,ONLY: abort
USE MOD_PICInterpolation_Vars ,ONLY: L_2_Error_Part
!----------------------------------------------------------------------------------------------------------------------------------!
IMPLICIT NONE
! INPUT / OUTPUT VARIABLES
REAL,INTENT(IN)                  :: time
INTEGER(KIND=8),INTENT(IN)       :: iter
REAL(KIND=8),INTENT(IN)          :: PartStateAnalytic(1:6)
!-----------------------------------------------------------------------------------------------------------------------------------
! LOCAL VARIABLES
CHARACTER(LEN=28),PARAMETER              :: outfile='ParticlePositionAnalytic.csv'
INTEGER                                  :: ioUnit,I
CHARACTER(LEN=150)                       :: formatStr
INTEGER,PARAMETER                        :: nOutputVar=13
CHARACTER(LEN=255),DIMENSION(nOutputVar) :: StrVarNames(nOutputVar)=(/ CHARACTER(LEN=255) :: &
    '001-time',     &
    'PartPosX_Analytic', &
    'PartPosY_Analytic', &
    'PartPosZ_Analytic', &
    'PartVelX_Analytic', &
    'PartVelY_Analytic', &
    'PartVelZ_Analytic', &
    'L2_PartPosX'      , &
    'L2_PartPosY'      , &
    'L2_PartPosZ'      , &
    'L2_PartVelX'      , &
    'L2_PartVelY'      , &
    'L2_PartVelZ'        &
    /)
CHARACTER(LEN=255),DIMENSION(nOutputVar) :: tmpStr ! needed because PerformAnalyze is called multiple times at the beginning
CHARACTER(LEN=1000)                      :: tmpStr2
CHARACTER(LEN=1),PARAMETER               :: delimiter=","
LOGICAL                                  :: FileExist,CreateFile
!===================================================================================================================================
! only the root shall write this file
IF(.NOT.MPIRoot)RETURN

! check if file is to be created
CreateFile=.TRUE.
IF(iter.GT.0)CreateFile=.FALSE.                             ! don't create new file if this is not the first iteration
IF((DoRestart).AND.(FILEEXISTS(outfile)))CreateFile=.FALSE. ! don't create new file if this is a restart and the file already exists
!                                                           ! assume continued simulation and old load balance data is still needed

! check if new file with header is to be created
INQUIRE(FILE = outfile, EXIST=FileExist)
IF(.NOT.FileExist)CreateFile=.TRUE.                         ! if no file exists, create one

! create file with header
IF(CreateFile) THEN
  OPEN(NEWUNIT=ioUnit,FILE=TRIM(outfile),STATUS="UNKNOWN")
  tmpStr=""
  DO I=1,nOutputVar
    WRITE(tmpStr(I),'(A)')delimiter//'"'//TRIM(StrVarNames(I))//'"'
  END DO
  WRITE(formatStr,'(A1)')'('
  DO I=1,nOutputVar
    IF(I.EQ.nOutputVar)THEN ! skip writing "," and the end of the line
      WRITE(formatStr,'(A,A1,I2)')TRIM(formatStr),'A',LEN_TRIM(tmpStr(I))
    ELSE
      WRITE(formatStr,'(A,A1,I2,A1)')TRIM(formatStr),'A',LEN_TRIM(tmpStr(I)),','
    END IF
  END DO

  WRITE(formatStr,'(A,A1)')TRIM(formatStr),')' ! finish the format
  WRITE(tmpStr2,formatStr)tmpStr               ! use the format and write the header names to a temporary string
  tmpStr2(1:1) = " "                           ! remove possible relimiter at the beginning (e.g. a comma)
  WRITE(ioUnit,'(A)')TRIM(ADJUSTL(tmpStr2))    ! clip away the front and rear white spaces of the temporary string

  CLOSE(ioUnit)
END IF

! Print info to file
IF(FILEEXISTS(outfile))THEN
  OPEN(NEWUNIT=ioUnit,FILE=TRIM(outfile),POSITION="APPEND",STATUS="OLD")
  WRITE(formatStr,'(A2,I2,A14,A1)')'(',nOutputVar,CSVFORMAT,')'
  WRITE(tmpStr2,formatStr)&
      " ",time, &                           ! time
      delimiter,PartStateAnalytic(1), &     ! PartPosX analytic solution
      delimiter,PartStateAnalytic(2), &     ! PartPosY analytic solution
      delimiter,PartStateAnalytic(3), &     ! PartPosZ analytic solution
      delimiter,PartStateAnalytic(4), &     ! PartVelX analytic solution
      delimiter,PartStateAnalytic(5), &     ! PartVelY analytic solution
      delimiter,PartStateAnalytic(6), &     ! PartVelZ analytic solution
      delimiter,L_2_Error_Part(1), &     ! L2 error for PartPosX solution
      delimiter,L_2_Error_Part(2), &     ! L2 error for PartPosY solution
      delimiter,L_2_Error_Part(3), &     ! L2 error for PartPosZ solution
      delimiter,L_2_Error_Part(4), &     ! L2 error for PartVelX solution
      delimiter,L_2_Error_Part(5), &     ! L2 error for PartVelY solution
      delimiter,L_2_Error_Part(6)        ! L2 error for PartVelZ solution
  WRITE(ioUnit,'(A)')TRIM(ADJUSTL(tmpStr2)) ! clip away the front and rear white spaces of the data line
  CLOSE(ioUnit)
ELSE
  SWRITE(UNIT_StdOut,'(A)')TRIM(outfile)//" does not exist. Cannot write particle tracking (analytic) info!"
END IF

END SUBROUTINE WriteParticleTrackingDataAnalytic
  

#endif /*defined(PARTICLES) && defined(CODE_ANALYZE)*/
END MODULE MOD_Particle_Analyze_Code