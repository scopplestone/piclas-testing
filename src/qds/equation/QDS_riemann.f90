#include "boltzplatz.h"

MODULE MOD_QDS_Riemann
!===================================================================================================================================
!> Contains the routines to
!> - determine the riemann flux for QDS DG method
!===================================================================================================================================
! MODULES
!USE MOD_io_HDF5
! IMPLICIT VARIABLE HANDLING
IMPLICIT NONE
PRIVATE
!-----------------------------------------------------------------------------------------------------------------------------------
! GLOBAL VARIABLES 
!-----------------------------------------------------------------------------------------------------------------------------------
! Private Part ---------------------------------------------------------------------------------------------------------------------
! Public Part ----------------------------------------------------------------------------------------------------------------------
INTERFACE RiemannQDS
  MODULE PROCEDURE RiemannQDS
END INTERFACE

PUBLIC::RiemannQDS
!===================================================================================================================================
CONTAINS
SUBROUTINE RiemannQDS(F,U_L,U_R,nv)
!===================================================================================================================================
! Computes the numerical flux
! Conservative States are rotated into normal direction in this routine and are NOT backrotatet: don't use it after this routine!!
!===================================================================================================================================
! MODULES
USE MOD_PreProc ! PP_N
USE MOD_QDS_DG_Vars,     ONLY:QDSnVar!,QDSMaxVelo
! IMPLICIT VARIABLE HANDLING
IMPLICIT NONE
!-----------------------------------------------------------------------------------------------------------------------------------
! INPUT VARIABLES
REAL,DIMENSION(QDSnVar,0:PP_N,0:PP_N),INTENT(IN) :: U_L,U_R
REAL,INTENT(IN)                                  :: nv(3,0:PP_N,0:PP_N)
!-----------------------------------------------------------------------------------------------------------------------------------
! OUTPUT VARIABLES
REAL,INTENT(OUT)                                 :: F(QDSnVar,0:PP_N,0:PP_N)
!-----------------------------------------------------------------------------------------------------------------------------------
! INPUT / OUTPUT VARIABLES
!-----------------------------------------------------------------------------------------------------------------------------------
! LOCAL VARIABLES 
INTEGER                                          :: p,q, iVar,I
REAL                                             :: velocompL, velocompR,LambdaMax
!===================================================================================================================================
!Lax-Friedrich
DO iVar=0,7
  I=iVar*5
  DO q=0,PP_N; DO p=0,PP_N 
    IF(U_L(1+I,p,q).GT.0.0)THEN
      velocompL = U_L(2+I,p,q)/U_L(1+I,p,q)*nv(1,p,q) + &
                  U_L(3+I,p,q)/U_L(1+I,p,q)*nv(2,p,q) + &
                  U_L(4+I,p,q)/U_L(1+I,p,q)*nv(3,p,q)
    ELSE
      velocompL = 0.0
    END IF
    IF(U_R(1+I,p,q).GT.0.0)THEN
      velocompR = U_R(2+I,p,q)/U_R(1+I,p,q)*nv(1,p,q) + &
                  U_R(3+I,p,q)/U_R(1+I,p,q)*nv(2,p,q) + &
                  U_R(4+I,p,q)/U_R(1+I,p,q)*nv(3,p,q)
    ELSE
      velocompR = 0.0
    END IF
    !IF (ABS(velocompL).GT.ABS(velocompR)) THEN
      !LambdaMax = ABS(velocompL)
    !ELSE
      !LambdaMax = ABS(velocompR)
    !END IF
    LambdaMax = MERGE(ABS(velocompL),ABS(velocompR),ABS(velocompL).GT.ABS(velocompR))
    !LambdaMax=QDSMaxVelo


!    Lambda_L = 0.5 * (LambdaMax + ABS(LambdaMax))
!    Lambda_R = 0.5 * (LambdaMax - ABS(LambdaMax))
!    F(1 + iVar*5,p,q) =  (Lambda_L * U_L(1 + iVar*5,p,q) + Lambda_R * U_R(1 + iVar*5,p,q)) 
!    F(2 + iVar*5,p,q) =  (Lambda_L * U_L(2 + iVar*5,p,q) + Lambda_R * U_R(2 + iVar*5,p,q))
!    F(3 + iVar*5,p,q) =  (Lambda_L * U_L(3 + iVar*5,p,q) + Lambda_R * U_R(3 + iVar*5,p,q))
!    F(4 + iVar*5,p,q) =  (Lambda_L * U_L(4 + iVar*5,p,q) + Lambda_R * U_R(4 + iVar*5,p,q))
!    F(5 + iVar*5,p,q) =  (Lambda_L * U_L(5 + iVar*5,p,q) + Lambda_R * U_R(5 + iVar*5,p,q)) 
    


     F(1+I,p,q) =   0.5*(velocompL* U_L(1+I,p,q) + velocompR* U_R(1+I,p,q)) &
                  - 0.5*LambdaMax *(U_R(1+I,p,q) -            U_L(1+I,p,q))

     F(2+I,p,q) =   0.5*(velocompL* U_L(2+I,p,q) + velocompR* U_R(2+I,p,q)) &
                  - 0.5*LambdaMax *(U_R(2+I,p,q) -            U_L(2+I,p,q))

     F(3+I,p,q) =   0.5*(velocompL* U_L(3+I,p,q) + velocompR* U_R(3+I,p,q)) &
                  - 0.5*LambdaMax *(U_R(3+I,p,q) -            U_L(3+I,p,q))

     F(4+I,p,q) =   0.5*(velocompL* U_L(4+I,p,q) + velocompR* U_R(4+I,p,q)) &
                  - 0.5*LambdaMax *(U_R(4+I,p,q) -            U_L(4+I,p,q))

     F(5+I,p,q) =   0.5*(velocompL* U_L(5+I,p,q) + velocompR* U_R(5+I,p,q)) &
                  - 0.5*LambdaMax *(U_R(5+I,p,q) -            U_L(5+I,p,q))

!     F(1 + iVar*5,p,q) = 0.5*(velocompL* U_L(1 + iVar*5,p,q) + velocompR* U_R(1 + iVar*5,p,q))
!     F(2 + iVar*5,p,q) = 0.5*(velocompL* U_L(2 + iVar*5,p,q) + velocompR* U_R(2 + iVar*5,p,q))
!     F(3 + iVar*5,p,q) = 0.5*(velocompL* U_L(3 + iVar*5,p,q) + velocompR* U_R(3 + iVar*5,p,q))
!     F(4 + iVar*5,p,q) = 0.5*(velocompL* U_L(4 + iVar*5,p,q) + velocompR* U_R(4 + iVar*5,p,q))
!     F(5 + iVar*5,p,q) = 0.5*(velocompL* U_L(5 + iVar*5,p,q) + velocompR* U_R(5 + iVar*5,p,q))

     
!    LambdaMax = MAX(ABS(velocompL), ABS(velocompR))
!    F(1 + iVar*5,p,q) =  0.5*(velocompL * U_L(1 + iVar*5,p,q) +velocompR * U_R(1 + iVar*5,p,q) &
!          + LambdaMax *(U_L(1 + iVar*5,p,q) -  U_R(1 + iVar*5,p,q)))
!    F(2 + iVar*5,p,q) =  0.5*(velocompL * U_L(2 + iVar*5,p,q) +velocompR * U_R(2 + iVar*5,p,q) &
!          + LambdaMax *(U_L(2 + iVar*5,p,q) -  U_R(2 + iVar*5,p,q)))
!    F(3 + iVar*5,p,q) =  0.5*(velocompL * U_L(3 + iVar*5,p,q) +velocompR * U_R(3 + iVar*5,p,q) &
!          + LambdaMax *(U_L(3 + iVar*5,p,q) -  U_R(3 + iVar*5,p,q)))
!    F(4 + iVar*5,p,q) =  0.5*(velocompL * U_L(4 + iVar*5,p,q) +velocompR * U_R(4 + iVar*5,p,q) &
!          + LambdaMax *(U_L(4 + iVar*5,p,q) -  U_R(4 + iVar*5,p,q)))
!    F(5 + iVar*5,p,q) =  0.5*(velocompL * U_L(5 + iVar*5,p,q) +velocompR * U_R(5 + iVar*5,p,q) &
!          + LambdaMax *(U_L(5 + iVar*5,p,q) -  U_R(5 + iVar*5,p,q)))
  END DO; END DO
END DO


END SUBROUTINE RiemannQDS


END MODULE MOD_QDS_Riemann
