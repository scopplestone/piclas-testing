MODULE MOD_VolInt
!===================================================================================================================================
! Containes the different DG volume integrals
! Computes the volume integral contribution based on U and updates Ut
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
INTERFACE VolInt
  MODULE PROCEDURE VolInt_weakForm
END INTERFACE

PUBLIC::VolInt
!===================================================================================================================================


CONTAINS



SUBROUTINE VolInt_weakForm(Ut,dofirstElems)
!===================================================================================================================================
! Computes the volume integral of the weak DG form a la Kopriva
! Attention 1: 1/J(i,j,k) is not yet accounted for
! Attention 2: ut is initialized and is updated with the volume flux derivatives
!===================================================================================================================================
! MODULES
USE MOD_DG_Vars,ONLY:D_hat,D_hat_T
USE MOD_Mesh_Vars,ONLY:Metrics_fTilde,Metrics_gTilde,Metrics_hTilde
USE MOD_PreProc
USE MOD_Flux,ONLY:EvalFlux3D                                         ! computes volume fluxes in local coordinates
! IMPLICIT VARIABLE HANDLING
IMPLICIT NONE
!-----------------------------------------------------------------------------------------------------------------------------------
! INPUT VARIABLES
!-----------------------------------------------------------------------------------------------------------------------------------
! OUTPUT VARIABLES
REAL,INTENT(INOUT)                                  :: Ut(PP_nVar,0:PP_N,0:PP_N,0:PP_N,1:PP_nElems)
LOGICAL,INTENT(IN)                                  :: dofirstElems
! Adds volume contribution to time derivative Ut contained in MOD_DG_Vars (=aufschmutzen!)
!-----------------------------------------------------------------------------------------------------------------------------------
! LOCAL VARIABLES
REAL,DIMENSION(PP_nVar,0:PP_N,0:PP_N,0:PP_N)      :: f,g,h                ! volume fluxes at all Gauss points
REAL,DIMENSION(PP_nVar)                           :: fTilde,gTilde,hTilde ! auxiliary variables needed to store the fluxes at one GP
INTEGER                                           :: i,j,k,iElem
INTEGER                                           :: l                    ! row index for matrix vector product
INTEGER                                           :: firstElemID, lastElemID
!===================================================================================================================================

IF(dofirstElems)THEN
  firstElemID = 1
  lastElemID  = PP_nElems/2+1
ELSE ! second half of elements
  firstElemID = PP_nElems/2+2
  lastElemID  = PP_nElems
END IF

DO iElem=firstElemID,lastElemID
!DO iElem=1,PP_nElems
  ! Cut out the local DG solution for a grid cell iElem and all Gauss points from the global field
  ! Compute for all Gauss point values the Cartesian flux components
  CALL EvalFlux3D(iElem,f,g,h)
  DO k=0,PP_N
    DO j=0,PP_N
      DO i=0,PP_N
        fTilde=f(:,i,j,k)
        gTilde=g(:,i,j,k)
        hTilde=h(:,i,j,k)
        ! Compute the transformed fluxes with the metric terms
        ! Attention 1: we store the transformed fluxes in f,g,h again
        f(:,i,j,k) = fTilde(:)*Metrics_fTilde(1,i,j,k,iElem) + &
                     gTilde(:)*Metrics_fTilde(2,i,j,k,iElem) + &
                     hTilde(:)*Metrics_fTilde(3,i,j,k,iElem)
        g(:,i,j,k) = fTilde(:)*Metrics_gTilde(1,i,j,k,iElem) + &
                     gTilde(:)*Metrics_gTilde(2,i,j,k,iElem) + &
                     hTilde(:)*Metrics_gTilde(3,i,j,k,iElem)
        h(:,i,j,k) = fTilde(:)*Metrics_hTilde(1,i,j,k,iElem) + &
                     gTilde(:)*Metrics_hTilde(2,i,j,k,iElem) + &
                     hTilde(:)*Metrics_hTilde(3,i,j,k,iElem)
      END DO ! i
    END DO ! j
  END DO ! k
  DO l=0,PP_N
    DO k=0,PP_N
      DO j=0,PP_N
        DO i=0,PP_N
          ! Update the time derivative with the spatial derivatives of the transformed fluxes
          Ut(:,i,j,k,iElem) = Ut(:,i,j,k,iElem) + D_hat(i,l)*f(:,l,j,k) + &
                                                  D_hat(j,l)*g(:,i,l,k) + &
                                                  D_hat(k,l)*h(:,i,j,l)
        END DO !i
      END DO ! j
    END DO ! k
  END DO ! l

  !CALL VolInt_Metrics(f,g,h,Metrics_fTilde(:,:,:,:,iElem),&
  !                          Metrics_gTilde(:,:,:,:,iElem),&
  !                          Metrics_hTilde(:,:,:,:,iElem))
  !DO k=0,PP_N
  !  DO j=0,PP_N
  !    DO i=0,PP_N
  !      Ut(:,i,j,k,iElem) = D_Hat_T(0,i)*f(:,0,j,k) + &
  !                          D_Hat_T(0,j)*g(:,i,0,k) + &
  !                          D_Hat_T(0,k)*h(:,i,j,0)
  !      DO l=1,PP_N
  !        ! Update the time derivative with the spatial derivatives of the transformed fluxes
  !        Ut(:,i,j,k,iElem) = Ut(:,i,j,k,iElem) + D_Hat_T(l,i)*f(:,l,j,k) + &
  !                                                D_Hat_T(l,j)*g(:,i,l,k) + &
  !                                                D_Hat_T(l,k)*h(:,i,j,l)
  !      END DO ! l
  !    END DO !i
  !  END DO ! j
  !END DO ! k
END DO ! iElem
END SUBROUTINE VolInt_weakForm


SUBROUTINE VolInt_Metrics(f,g,h,Mf,Mg,Mh)
!===================================================================================================================================
! Compute the tranformed states for all conservative variables
!===================================================================================================================================
! MODULES
USE MOD_PreProc
USE MOD_DG_Vars,ONLY:nTotal_vol
! IMPLICIT VARIABLE HANDLING
IMPLICIT NONE
!-----------------------------------------------------------------------------------------------------------------------------------
! INPUT VARIABLES
REAL,DIMENSION(3,nTotal_Vol),INTENT(IN)          :: Mf,Mg,Mh             ! Metrics
!-----------------------------------------------------------------------------------------------------------------------------------
! OUTPUT VARIABLES
REAL,DIMENSION(PP_nVar,nTotal_vol),INTENT(INOUT) :: f,g,h                ! volume fluxes at all Gauss points
!-----------------------------------------------------------------------------------------------------------------------------------
! LOCAL VARIABLES
INTEGER                                        :: i
REAL,DIMENSION(PP_nVar)                        :: fTilde,gTilde,hTilde ! auxiliary variables needed to store the fluxes at one GP
!===================================================================================================================================
DO i=1,nTotal_Vol
  fTilde=f(:,i)
  gTilde=g(:,i)
  hTilde=h(:,i)
  ! Compute the transformed fluxes with the metric terms
  ! Attention 1: we store the transformed fluxes in f,g,h again
  f(:,i) = fTilde*Mf(1,i) + &
           gTilde*Mf(2,i) + &
           hTilde*Mf(3,i)
  g(:,i) = fTilde*Mg(1,i) + &
           gTilde*Mg(2,i) + &
           hTilde*Mg(3,i)
  h(:,i) = fTilde*Mh(1,i) + &
           gTilde*Mh(2,i) + &
           hTilde*Mh(3,i)
END DO ! i
END SUBROUTINE VolInt_Metrics

END MODULE MOD_VolInt
