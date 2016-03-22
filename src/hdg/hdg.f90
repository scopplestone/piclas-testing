#include "boltzplatz.h"

MODULE MOD_HDG
!===================================================================================================================================
! Module for the HDG method 
!===================================================================================================================================
! MODULES
! IMPLICIT VARIABLE HANDLING
IMPLICIT NONE
PRIVATE
!-----------------------------------------------------------------------------------------------------------------------------------
INTERFACE InitHDG
  MODULE PROCEDURE InitHDG
END INTERFACE

!INTERFACE HDG
!  MODULE PROCEDURE HDG
!END INTERFACE

INTERFACE FinalizeHDG
  MODULE PROCEDURE FinalizeHDG
END INTERFACE

PUBLIC :: InitHDG,FinalizeHDG
PUBLIC :: HDG, RestartHDG
!===================================================================================================================================

CONTAINS

SUBROUTINE InitHDG()
!===================================================================================================================================
! Initialize variables of the HDG module
!===================================================================================================================================
! MODULES
USE MOD_Globals
USE MOD_PreProc
USE MOD_HDG_Vars
USE MOD_Interpolation_Vars ,ONLY: xGP,wGP,L_minus,L_plus
USE MOD_Basis              ,ONLY: PolynomialDerivativeMatrix
USE MOD_Interpolation_Vars ,ONLY: wGP
USE MOD_Elem_Mat           ,ONLY: Elem_Mat,BuildPrecond
USE MOD_ReadInTools        ,ONLY: GETLOGICAL,GETREAL,GETINT
USE MOD_Mesh_Vars          ,ONLY: sJ,nBCSides,nSides,SurfElem,SideToElem
USE MOD_Mesh_Vars          ,ONLY: BoundaryType,nBCSides,nSides,BC
USE MOD_Particle_Mesh_Vars, ONLY: GEO,NbrOfRegions
USE MOD_Particle_Vars      ,ONLY :RegionElectronRef
USE MOD_Equation_Vars      ,ONLY:eps0
USE MOD_Restart_Vars,    ONLY:DoRestart
! IMPLICIT VARIABLE HANDLING
IMPLICIT NONE
!-----------------------------------------------------------------------------------------------------------------------------------
! INPUT VARIABLES
!-----------------------------------------------------------------------------------------------------------------------------------
! OUTPUT VARIABLES
!-----------------------------------------------------------------------------------------------------------------------------------
! LOCAL VARIABLES
INTEGER :: i,j,k,p,q,r,iElem,jElem,SideID
INTEGER :: BCType,BCstate,RegionID
REAL    :: D(0:PP_N,0:PP_N)
!===================================================================================================================================
IF(HDGInitIsDone)THEN
   SWRITE(*,*) "InitHDG already called."
   RETURN
END IF
SWRITE(UNIT_StdOut,'(132("-"))')
SWRITE(UNIT_stdOut,'(A)') ' INIT HDG...'

nGP_vol =(PP_N+1)**3
nGP_face=(PP_N+1)**2
IF (NbrOfRegions .GT. 0) THEN !Regions only used for Boltzmann Electrons so far -> non-linear HDG-sources!
  nonlinear = .true.
  NonLinSolver=GETINT('NonLinSolver','1')
  
  IF (NonLinSolver.EQ.1) THEN
    NewtonExactApprox = GETLOGICAL('NewtonExactSourceDeriv','false')
    AdaptIterNewton=GETINT('AdaptIterNewton','0')
    AdaptIterNewtonOld = AdaptIterNewton
    AdaptNewtonStartValue = GETLOGICAL('NewtonAdaptStartValue','false')
    IF (NewtonExactApprox) AdaptNewtonStartValue=.true.
    IF (DoRestart) AdaptNewtonStartValue=.false.
    ALLOCATE(NonlinVolumeFac(nGP_vol,PP_nElems))
    DO iElem=1,PP_nElems
      RegionID=GEO%ElemToRegion(iElem)
      DO k=0,PP_N; DO j=0,PP_N; DO i=0,PP_N
        r=k*(PP_N+1)**2+j*(PP_N+1) + i+1
        IF (AdaptNewtonStartValue) THEN
          NonlinVolumeFac(r,iElem)=0.0
        ELSE
          NonlinVolumeFac(r,iElem)=RegionElectronRef(1,RegionID) / (RegionElectronRef(3,RegionID)*eps0)
        END IF
      END DO; END DO; END DO !i,j,k
    END DO !iElem
  END IF

  RelaxFacNonlinear0=GETREAL('RelaxFacNonlinear','0.5')
  RelaxFacNonlinear=RelaxFacNonlinear0
  AdaptIterFixPoint0=GETINT('AdaptIterFixPoint','10')
  AdaptIterFixPoint=AdaptIterFixPoint0
  MaxIterFixPoint = GETINT('MaxIterFixPoint','10000')
  NormNonlinearDevLimit=GETREAL('NormNonlinearDevLimit','99999.')
  IF (NormNonlinearDevLimit .LT. 1.) THEN
    STOP 'NormNonlinearDevLimit should be .GE. 1'
  END IF
  EpsNonLinear=GETREAL('EpsNonLinear','1.0E-6')
ELSE
  nonlinear = .false.
END IF

!CG parameters
PrecondType=GETINT('PrecondType','2')
epsCG=GETREAL('epsCG','1.0E-6')
maxIterCG=GETINT('maxIterCG','500')

OnlyPostProc=GETLOGICAL('OnlyPostProc','.FALSE.')
ExactLambda=GETLOGICAL('ExactLambda','.FALSE.')

!boundary conditions
nDirichletBCsides=0
nNeumannBCsides  =0
DO SideID=1,nBCSides
  BCType =BoundaryType(BC(SideID),BC_TYPE)
  BCState=BoundaryType(BC(SideID),BC_STATE)
  SELECT CASE(BCType)
  CASE(2,4) !dirichlet
    nDirichletBCsides=nDirichletBCsides+1
  CASE(10,11) !Neumann, 
    nNeumannBCsides=nNeumannBCsides+1
  CASE DEFAULT ! unknown BCType
    CALL abort(__STAMP__,&
         ' unknown BC Type in hdg.f90!',BCType,999.)
  END SELECT ! BCType
END DO

IF(nDirichletBCsides.GT.0)ALLOCATE(DirichletBC(nDirichletBCsides))
IF(nNeumannBCsides  .GT.0)THEN
  ALLOCATE(NeumannBC(nNeumannBCsides))
  ALLOCATE(qn_face(PP_nVar, nGP_face,nNeumannBCsides))
END IF
#if (PP_nVar!=1)
  IF(nDirichletBCsides.GT.0)ALLOCATE(qn_face_MagStat(PP_nVar, nGP_face,nDirichletBCsides))
#endif
nDirichletBCsides=0
nNeumannBCsides  =0
DO SideID=1,nBCSides
  BCType =BoundaryType(BC(SideID),BC_TYPE)
  BCState=BoundaryType(BC(SideID),BC_STATE)
  SELECT CASE(BCType)
  CASE(2,4) !dirichlet
    nDirichletBCsides=nDirichletBCsides+1
    DirichletBC(nDirichletBCsides)=SideID
  CASE(10,11) !Neumann, 
    nNeumannBCsides=nNeumannBCsides+1
    NeumannBC(nNeumannBCsides)=SideID
  END SELECT ! BCType
END DO

!mappings
sideDir(  XI_MINUS)=1
sideDir(   XI_PLUS)=1
sideDir( ETA_MINUS)=2
sideDir(  ETA_PLUS)=2
sideDir(ZETA_MINUS)=3
sideDir( ZETA_PLUS)=3
pm(  XI_MINUS)=1
pm(   XI_PLUS)=2
pm( ETA_MINUS)=1
pm(  ETA_PLUS)=2
pm(ZETA_MINUS)=1
pm( ZETA_PLUS)=2

dirPm2iSide(1,1) = XI_MINUS
dirPm2iSide(2,1) = XI_PLUS
dirPm2iSide(1,2) = ETA_MINUS
dirPm2iSide(2,2) = ETA_PLUS
dirPm2iSide(1,3) = ZETA_MINUS
dirPm2iSide(2,3) = ZETA_PLUS

ALLOCATE(delta(0:PP_N,0:PP_N))
delta=0.
DO i=0,PP_N
  delta(i,i)=1.
END DO !i

ALLOCATE(LL_minus(0:PP_N,0:PP_N))
ALLOCATE(LL_plus( 0:PP_N,0:PP_N))
DO j=0,PP_N
  DO i=0,PP_N
    LL_minus(i,j) = L_minus(i)*L_minus(j)
    LL_plus(i,j)  = L_plus(i)*L_plus(j)
  END DO
END DO

ALLOCATE(Lomega_m(0:PP_N))
ALLOCATE(Lomega_p(0:PP_N))
! Compute a lifting matrix scaled by the Gaussian weights
Lomega_m = - L_minus/wGP
Lomega_p = + L_plus/wGP
ALLOCATE(Domega(0:PP_N,0:PP_N))
! Compute Differentiation matrix D for given Gausspoints (1D)
CALL PolynomialDerivativeMatrix(PP_N,xGP,D)
! Compute a Differentiation mtarix scaled by the Gaussian weigths
DO j=0,PP_N
  DO i=0,PP_N
    Domega(i,j) = wGP(i)/wGP(j)*D(i,j)
  END DO !r
END DO !s

ALLOCATE(InvDhat(nGP_vol,nGP_vol,PP_nElems))
ALLOCATE(wGP_vol(nGP_vol))
DO k=0,PP_N; DO j=0,PP_N; DO i=0,PP_N
  r=k*(PP_N+1)**2+j*(PP_N+1) + i+1
  wGP_vol(r)=wGP(i)*wGP(j)*wGP(k)
END DO; END DO; END DO !i,j,k

ALLOCATE(JwGP_vol(nGP_vol,PP_nElems))
DO iElem=1,PP_nElems
  DO k=0,PP_N; DO j=0,PP_N; DO i=0,PP_N
    r=k*(PP_N+1)**2+j*(PP_N+1) + i+1
    JwGP_vol(r,iElem)=wGP_vol(r)/sJ(i,j,k,iElem) !omega*J
  END DO; END DO; END DO !i,j,k
END DO !iElem


ALLOCATE(Ehat(nGP_face,nGP_vol,6,PP_nElems))
!side matrices
ALLOCATE(Smat(nGP_face,nGP_face,6,6,PP_nElems))


!stabilization parameter
ALLOCATE(Tau(PP_nElems))
DO iElem=1,PP_nElems
  Tau(iElem)=2./((SUM(JwGP_vol(:,iElem)))**(1./3.))  !1/h ~ 1/vol^(1/3) (volref=8)
END DO !iElem

CALL Elem_Mat()

ALLOCATE(Fdiag(nGP_face,nSides))
DO SideID=1,nSides
  DO q=0,PP_N; DO p=0,PP_N
      r=q*(PP_N+1)+p+1
      Fdiag(r,SideID)=SurfElem(p,q,SideID)*wGP(p)*wGP(q)
  END DO; END DO !p,q
  iElem= SideToElem(S2E_ELEM_ID,SideID)  
  jElem= SideToElem(S2E_NB_ELEM_ID,SideID)
  IF(jElem.EQ.-1)THEN
    Fdiag(:,SideID)=-Fdiag(:,SideID)*Tau(iElem) 
  ELSEIF(iElem.EQ.-1)THEN
    Fdiag(:,SideID)=-Fdiag(:,SideID)*Tau(jElem) 
  ELSE
    Fdiag(:,SideID)=-Fdiag(:,SideID)*(Tau(iElem)+Tau(jElem))
  END IF
END DO

CALL BuildPrecond()

ALLOCATE(lambda(PP_nVar,nGP_face,nSides))
lambda=0.
ALLOCATE(RHS_vol(PP_nVar, nGP_vol,PP_nElems))
RHS_vol=0.

HDGInitIsDone = .TRUE.
SWRITE(UNIT_stdOut,'(A)')' INIT HDG DONE!'
SWRITE(UNIT_StdOut,'(132("-"))')
END SUBROUTINE InitHDG


SUBROUTINE HDG(t,U_out,iter)
!===================================================================================================================================
!===================================================================================================================================
! MODULES
USE MOD_Globals
USE MOD_PreProc
USE MOD_HDG_Vars
! IMPLICIT VARIABLE HANDLING
IMPLICIT NONE
!-----------------------------------------------------------------------------------------------------------------------------------
! INPUT VARIABLES
REAL,INTENT(IN)     :: t !time
INTEGER(KIND=8),INTENT(IN)  :: iter
!-----------------------------------------------------------------------------------------------------------------------------------
! OUTPUT VARIABLES
REAL,INTENT(INOUT)  :: U_out(PP_nVar,nGP_vol,PP_nElems)
!-----------------------------------------------------------------------------------------------------------------------------------
! LOCAL VARIABLES
!===================================================================================================================================
IF(nonlinear) THEN
  IF (NonLinSolver.EQ.1) THEN
    CALL HDGNewton(t, U_out, iter)
  ELSE
    CALL HDGFixPoint(t,U_out)
  END IF
ELSE
  CALL HDGLinear(t,U_out)
END IF

END SUBROUTINE HDG


SUBROUTINE HDGFixPoint(t,U_out)
!===================================================================================================================================
!===================================================================================================================================
! MODULES
USE MOD_Globals
USE MOD_PreProc
USE MOD_HDG_Vars
USE MOD_Equation,          ONLY:CalcSourceHDG,ExactFunc
USE MOD_Equation_Vars,     ONLY:IniExactFunc
USE MOD_Equation_Vars,     ONLY:chitens_face
USE MOD_Mesh_Vars,         ONLY:Face_xGP,BCface_xGP,BoundaryType,nSides,BC!,Elem_xGP
USE MOD_Mesh_Vars,         ONLY:ElemToSide,NormVec,SurfElem
USE MOD_Interpolation_Vars,ONLY:wGP
USE MOD_Particle_Boundary_Vars     ,ONLY: PartBound
USE MOD_Elem_Mat          ,ONLY:PostProcessGradient
USE MOD_Restart_Vars      ,ONLY: DoRestart,RestartTime
#ifdef MPI
USE MOD_MPI_Vars
USE MOD_MPI,           ONLY:FinishExchangeMPIData,StartReceiveMPIData,StartSendMPIData
USE MOD_Mesh_Vars,     ONLY:nMPISides,nMPIsides_YOUR,nMPIsides_MINE
#endif /*MPI*/ 
#if (PP_nVar==1)
USE MOD_Equation_Vars,     ONLY:E
#elif (PP_nVar==3)
USE MOD_Equation_Vars,     ONLY:B
#else
USE MOD_Equation_Vars,     ONLY:E,B
#endif
! IMPLICIT VARIABLE HANDLING
IMPLICIT NONE
!-----------------------------------------------------------------------------------------------------------------------------------
! INPUT VARIABLES
REAL,INTENT(IN)     :: t !time
!-----------------------------------------------------------------------------------------------------------------------------------
! OUTPUT VARIABLES
REAL,INTENT(INOUT)  :: U_out(PP_nVar,nGP_vol,PP_nElems)
!-----------------------------------------------------------------------------------------------------------------------------------
! LOCAL VARIABLES
INTEGER :: i,j,k,r,p,q,iElem, iter, iVar
INTEGER :: BCsideID,BCType,BCstate,SideID,iLocSide
REAL    :: RHS_face(PP_nVar,nGP_face,nSides)
REAL    :: rtmp(nGP_vol),Norm_r2,Norm_r2_old
LOGICAL :: converged
REAL    :: lambda_old(PP_nVar, nGP_face,nSides) !,U_old(nGP_vol,PP_nElems)
#ifdef MPI
REAL    :: RHS_face_buf( PP_nVar,nGP_Face,nMPISides_MINE)
INTEGER :: startbuf,endbuf
#endif /*MPI*/ 
#if (PP_nVar!=1)
REAL    :: BTemp(3,3,nGP_vol,PP_nElems)
#endif
LOGICAL :: RelaxAdaptions, NormIsMonoDecr, UseLastNorm
!===================================================================================================================================
Norm_r2=0.
DO iVar = 1, PP_nVar
  !Dirichlet boundary conditions
  DO BCsideID=1,nDirichletBCSides
    SideID=DirichletBC(BCsideID)
    BCType =BoundaryType(BC(SideID),BC_TYPE)
    BCState=BoundaryType(BC(SideID),BC_STATE)
    SELECT CASE(BCType)
    CASE(2) ! exact BC = Dirichlet BC !!
      ! Determine the exact BC state
      DO q=0,PP_N; DO p=0,PP_N
        r=q*(PP_N+1) + p+1
        CALL ExactFunc(IniExactFunc,t,0,BCFace_xGP(:,p,q,SideID),lambda(iVar,r:r,SideID))
      END DO; END DO !p,q
    CASE(4) ! exact BC = Dirichlet BC !!
      ! SPECIAL BC: BCState specifies exactfunc to be used!!
      DO q=0,PP_N; DO p=0,PP_N
        r=q*(PP_N+1) + p+1
  !      CALL ExactFunc(BCstate,t,0,BCFace_xGP(:,p,q,SideID),lambda(r:r,SideID))
         IF (iVar.EQ.1) THEN
           lambda(iVar,r:r,SideID)=PartBound%Voltage(PartBound%MapToPartBC(BC(SideID)))
         ELSE
           lambda(iVar,r:r,SideID)= 0.0
         END IF
      END DO; END DO !p,q
    END SELECT ! BCType
  END DO !BCsideID=1,nDirichletBCSides

  !neumann BC
  DO BCsideID=1,nNeumannBCSides
    SideID=NeumannBC(BCsideID)
    BCType =BoundaryType(BC(SideID),BC_TYPE)
    BCState=BoundaryType(BC(SideID),BC_STATE)
    SELECT CASE(BCType)
    CASE(10) !neumann q=0
      DO q=0,PP_N; DO p=0,PP_N
        r=q*(PP_N+1) + p+1
        qn_face(iVar,r,BCSideID)= 0. !SUM((/0.,0.,0./)  &
                                !*MATMUL(chitens_face(:,:,p,q,SideID),NormVec(:,p,q,SideID)))*SurfElem(p,q,SideID)*wGP(p)*wGP(q)
      END DO; END DO !p,q
    CASE(11) !neumann q*n=1 !test
      DO q=0,PP_N; DO p=0,PP_N
        r=q*(PP_N+1) + p+1
        qn_face(iVar,r,BCSideID)=SUM((/1.,1.,1./)  &
                            *MATMUL(chitens_face(:,:,p,q,SideID),NormVec(:,p,q,SideID)))*SurfElem(p,q,SideID)*wGP(p)*wGP(q)
      END DO; END DO !p,q
    END SELECT ! BCType
  END DO !BCsideID=1,nNeumannBCSides
END DO


lambda_old=lambda
DO iVar=1, PP_nVar
  RelaxAdaptions=.FALSE.
  NormIsMonoDecr=.TRUE.
  UseLastNorm=.FALSE.
  converged =.false. 
  DO iter=1,MaxIterFixPoint

    !volume source (volume RHS of u system)
    SWRITE(*,*) '!!!!!!!!!!!!!!!!!', iter
  !  print*, U_out

    !calcsourcehdg has to be changed for PP_nVar>1!!!!!!!!!!!!!!!
    DO iElem=1,PP_nElems
      DO k=0,PP_N; DO j=0,PP_N; DO i=0,PP_N
        r=k*(PP_N+1)**2+j*(PP_N+1) + i+1
        CALL CalcSourceHDG(0.,i,j,k,iElem,RHS_vol(1:PP_nVar,r,iElem),U_out(1,r,iElem))
      END DO; END DO; END DO !i,j,k
      RHS_Vol(iVar,:,iElem)=-JwGP_vol(:,iElem)*RHS_vol(iVar,:,iElem)
    END DO !iElem 

    !replace lambda with exact function (debugging)
    !ExactFunc has to be changed for PP_nVar>1!!!!!!!!!!!!!!!!
    IF(onlyPostProc.OR.ExactLambda)THEN
      DO SideID=1,nSides
        DO q=0,PP_N; DO p=0,PP_N
          r=q*(PP_N+1) + p+1
          CALL ExactFunc(IniExactFunc,t,0,Face_xGP(:,p,q,SideID),lambda(:,r,SideID))
        END DO; END DO !p,q
      END DO
    END IF

    !prepare RHS_face ( RHS for lamdba system.)
    RHS_face(iVar,:,:)=0.
    DO iElem=1,PP_nElems
      !rtmp=MATMUL(InvDhat(:,:,iElem),-RHS_loc(:,iElem))
      CALL DSYMV('U',nGP_vol,1., InvDhat(:,:,iElem),nGP_vol, &
                                 -RHS_vol(iVar,:,iElem),1,0., &
                                 rtmp(:),1)
      DO iLocSide=1,6
        SideID=ElemToSide(E2S_SIDE_ID,iLocSide,iElem)
        CALL DGEMV('N',nGP_face,nGP_vol,1., &
                            Ehat(:,:,iLocSide,iElem), nGP_face, &
                            rtmp,1,1.,& !add to RHS_face 
                            RHS_face(iVar,:,SideID),1)  
      END DO
    END DO !iElem 

    !add Neumann
    DO BCsideID=1,nNeumannBCSides
      SideID=NeumannBC(BCsideID)
      RHS_face(iVar,:,SideID)=RHS_face(iVar,:,SideID)+qn_face(iVar,:,BCSideID)
    END DO

#ifdef MPI
  startbuf=nSides-nMPISides+1
  endbuf=nSides-nMPISides+nMPISides_MINE
  IF(nMPIsides_MINE.GT.0)RHS_face_buf(iVar,:,:)=RHS_face(iVar,:,startbuf:endbuf)
  CALL StartReceiveMPIData(1,RHS_face(iVar,:,:),1,nSides,RecRequest_U ,SendID=2) ! Receive MINE
  CALL StartSendMPIData(   1,RHS_face(iVar,:,:),1,nSides,SendRequest_U,SendID=2) ! Send YOUR
  CALL FinishExchangeMPIData(SendRequest_U,     RecRequest_U,SendID=2)           ! Send YOUR - receive MINE
  IF(nMPIsides_MINE.GT.0) RHS_face(iVar,:,startbuf:endbuf)=RHS_face(iVar,:,startbuf:endbuf)+RHS_face_buf(iVar,:,:)
  IF(nMPIsides_YOUR.GT.0) RHS_face(iVar,:,nSides-nMPIsides_YOUR+1:nSides)=0. !set send buffer to zero!
#endif /*MPI*/

  !muss noch geändert werden
    Norm_r2_old=Norm_r2
    CALL CheckNonLinRes(RHS_face(iVar,:,:),lambda(iVar,:,:),converged,Norm_r2)
    SWRITE(*,*) Norm_r2
  !  read*
  !  IF (converged) THEN
  !    WRITE(*,*) 'FixPoint Iteration converged in ',iter,' steps!'
  !  END IF


    ! SOLVE 
    CALL CG_solver(RHS_face(iVar,:,:),lambda(iVar,:,:))
    !POST PROCESSING

    IF (iter.GT.1) THEN
    !read*
      lambda(iVar,:,:)=(1.0-RelaxFacNonlinear)*lambda_old(iVar,:,:)+RelaxFacNonlinear*lambda(iVar,:,:)
    ELSE IF (   ( .NOT.DoRestart .AND. .NOT.ALMOSTEQUAL(t,0.)          ) &
       .OR.( DoRestart .AND. .NOT.ALMOSTEQUAL(t,RestartTime) )) THEN
    !read*
      lambda(iVar,:,:)=(1.0-RelaxFacNonlinear)*lambda_old(iVar,:,:)+RelaxFacNonlinear*lambda(iVar,:,:)
    END IF
    lambda_old(iVar,:,:)=lambda(iVar,:,:)

    !post processing:
    DO iElem=1,PP_nElems
      ! for post-proc
      DO iLocSide=1,6
        SideID=ElemToSide(E2S_SIDE_ID,iLocSide,iElem)
        CALL DGEMV('T',nGP_face,nGP_vol,1., &
                            Ehat(:,:,iLocSide,iElem), nGP_face, &
                            lambda(iVar,:,SideID),1,1.,& !add to RHS_face 
                            RHS_vol(iVar,:,iElem),1)  
      END DO
      !U_out(:,iElem)=MATMUL(InvDhat(:,:,iElem),-RHS_loc(:,iElem))
      CALL DSYMV('U',nGP_vol,1., InvDhat(:,:,iElem),nGP_vol, &
                                 -RHS_vol(iVar,:,iElem),1,0., &
                                 U_out(iVar,:,iElem),1)
    END DO !iElem 

  !muss noch angepasst werden für fall nVar>1
    IF (converged) THEN
      SWRITE(*,*) 'FixPoint Iteration has converged in ',iter,' steps...'
      IF(.NOT.RelaxAdaptions) THEN
        RelaxFacNonlinear=MIN(RelaxFacNonlinear*2.,1.)
        AdaptIterFixPoint=MAX(INT(AdaptIterFixPoint0*RelaxFacNonlinear0/RelaxFacNonlinear),3)
        SWRITE(*,*) 'WARNING: FixPoint relaxation has been changed to ',RelaxFacNonlinear
      END IF
  !    SWRITE(*,*)'Norm_r2: ',Norm_r2
      EXIT
    ELSE IF (MOD(iter,AdaptIterFixPoint).EQ.0 .OR. &
      (UseLastNorm .AND. Norm_r2/Norm_r2_old.GT.NormNonlinearDevLimit)) THEN
      IF (UseLastNorm .AND. Norm_r2/Norm_r2_old.GT.NormNonlinearDevLimit) NormIsMonoDecr=.FALSE.
      IF (UseLastNorm .AND. NormIsMonoDecr) THEN
        RelaxFacNonlinear=MIN(RelaxFacNonlinear*2.,1.)
      ELSE
        RelaxFacNonlinear=MAX(RelaxFacNonlinear/2.,1E-3) !min-value is arbitrary!!!
      END IF
      AdaptIterFixPoint=MAX(INT(AdaptIterFixPoint0*RelaxFacNonlinear0/RelaxFacNonlinear),3)
      RelaxAdaptions=.TRUE.
      NormIsMonoDecr=.TRUE.
      UseLastNorm=.FALSE.
      SWRITE(*,*) 'WARNING: FixPoint relaxation has been changed to ',RelaxFacNonlinear
  !    SWRITE(*,*)'Norm_r2: ',Norm_r2
    ELSE IF (iter.EQ.MaxIterFixPoint) THEN
      STOP 'FixPoint Iteration has NOT converged!'
  !    SWRITE(*,*)'Norm_r2: ',Norm_r2
    ELSE IF (UseLastNorm .AND. Norm_r2/Norm_r2_old.GT.0.999) THEN !limit is arbitrary!
      NormIsMonoDecr=.FALSE.
    ELSE
      UseLastNorm=.TRUE.
    END IF
  END DO
END DO

#if (PP_nVar==1)
  CALL PostProcessGradient(U_out(1,:,:),lambda(1,:,:),E)
#elif (PP_nVar==3)
  DO iVar=1, PP_nVar 
    CALL PostProcessGradient(U_out(iVar,:,:),lambda(iVar,:,:),BTemp(iVar,:,:,:))
  END DO
  DO k=0,PP_N; DO j=0,PP_N; DO i=0,PP_N
    r=k*(PP_N+1)**2+j*(PP_N+1) + i+1
    B(1,i,j,k,:) = BTemp(3,2,r,:) - BTemp(2,3,r,:)
    B(2,i,j,k,:) = BTemp(1,3,r,:) - BTemp(3,1,r,:)
    B(3,i,j,k,:) = BTemp(2,1,r,:) - BTemp(1,2,r,:)
  END DO; END DO; END DO !i,j,k
#else
  DO iVar=1, 3 
    CALL PostProcessGradient(U_out(iVar,:,:),lambda(iVar,:,:),BTemp(iVar,:,:,:))
  END DO
  DO k=0,PP_N; DO j=0,PP_N; DO i=0,PP_N
    r=k*(PP_N+1)**2+j*(PP_N+1) + i+1
    B(1,i,j,k,:) = BTemp(3,2,r,:) - BTemp(2,3,r,:)
    B(2,i,j,k,:) = BTemp(1,3,r,:) - BTemp(3,1,r,:)
    B(3,i,j,k,:) = BTemp(2,1,r,:) - BTemp(1,2,r,:)
  END DO; END DO; END DO !i,j,k
  CALL PostProcessGradient(U_out(4,:,:),lambda(4,:,:),E)
#endif

END SUBROUTINE HDGFixPoint


SUBROUTINE HDGLinear(t,U_out)
!===================================================================================================================================
!===================================================================================================================================
! MODULES
USE MOD_Globals
USE MOD_PreProc
USE MOD_HDG_Vars
USE MOD_Equation,          ONLY:CalcSourceHDG,ExactFunc
USE MOD_Equation_Vars,     ONLY:IniExactFunc
USE MOD_Equation_Vars,     ONLY:chitens_face
USE MOD_Mesh_Vars,         ONLY:Face_xGP,BCface_xGP,BoundaryType,nSides,BC!,Elem_xGP
USE MOD_Mesh_Vars,         ONLY:ElemToSide,NormVec,SurfElem
USE MOD_Interpolation_Vars,ONLY:wGP
USE MOD_Particle_Boundary_Vars     ,ONLY: PartBound
USE MOD_Elem_Mat          ,ONLY:PostProcessGradient
#ifdef MPI
USE MOD_MPI_Vars
USE MOD_MPI,           ONLY:FinishExchangeMPIData, StartReceiveMPIData,StartSendMPIData
USE MOD_Mesh_Vars,     ONLY:nMPISides,nMPIsides_YOUR,nMPIsides_MINE
#endif /*MPI*/ 
#if (PP_nVar==1)
USE MOD_Equation_Vars,     ONLY:E
#elif (PP_nVar==3)
USE MOD_Equation_Vars,     ONLY:B
#else
USE MOD_Equation_Vars,     ONLY:B, E
#endif
! IMPLICIT VARIABLE HANDLING
IMPLICIT NONE
!-----------------------------------------------------------------------------------------------------------------------------------
! INPUT VARIABLES
REAL,INTENT(IN)     :: t !time
!-----------------------------------------------------------------------------------------------------------------------------------
! OUTPUT VARIABLES
REAL,INTENT(INOUT)  :: U_out(PP_nVar,nGP_vol,PP_nElems)
!-----------------------------------------------------------------------------------------------------------------------------------
! LOCAL VARIABLES
INTEGER :: i,j,k,r,p,q,iElem, iVar!,iter
INTEGER :: BCsideID,BCType,BCstate,SideID,iLocSide
REAL    :: RHS_face(PP_nVar,nGP_face,nSides)
REAL    :: rtmp(nGP_vol)
!LOGICAL :: converged
#ifdef MPI
REAL    :: RHS_face_buf( PP_nVar,nGP_Face,nMPISides_MINE)
INTEGER :: startbuf,endbuf
#endif /*MPI*/ 
#if (PP_nVar!=1)
REAL    :: BTemp(3,3,nGP_vol,PP_nElems)
#endif
!===================================================================================================================================
DO iVar = 1, PP_nVar
  !Dirichlet boundary conditions
#if (PP_nVar!=1)
  IF (iVar.EQ.4) THEN
#endif
  DO BCsideID=1,nDirichletBCSides
    SideID=DirichletBC(BCsideID)
    BCType =BoundaryType(BC(SideID),BC_TYPE)
    BCState=BoundaryType(BC(SideID),BC_STATE)
    SELECT CASE(BCType)
    CASE(2) ! exact BC = Dirichlet BC !!
      ! Determine the exact BC state
      DO q=0,PP_N; DO p=0,PP_N
        r=q*(PP_N+1) + p+1
        CALL ExactFunc(IniExactFunc,t,0,BCFace_xGP(:,p,q,SideID),lambda(iVar,r:r,SideID))
      END DO; END DO !p,q
    CASE(4) ! exact BC = Dirichlet BC !!
      ! SPECIAL BC: BCState specifies exactfunc to be used!!
      DO q=0,PP_N; DO p=0,PP_N
        r=q*(PP_N+1) + p+1
  !      CALL ExactFunc(BCstate,t,0,BCFace_xGP(:,p,q,SideID),lambda(r:r,SideID))
       lambda(iVar,r:r,SideID)=PartBound%Voltage(PartBound%MapToPartBC(BC(SideID)))
      END DO; END DO !p,q
    END SELECT ! BCType
  END DO !BCsideID=1,nDirichletBCSides
#if (PP_nVar!=1)
  END IF
#endif

  !neumann BC
  DO BCsideID=1,nNeumannBCSides
    SideID=NeumannBC(BCsideID)
    BCType =BoundaryType(BC(SideID),BC_TYPE)
    BCState=BoundaryType(BC(SideID),BC_STATE)
    SELECT CASE(BCType)
    CASE(10) !neumann q=0
      DO q=0,PP_N; DO p=0,PP_N
        r=q*(PP_N+1) + p+1
        qn_face(iVar,r,BCSideID)= 0. !SUM((/0.,0.,0./)  &
                                !*MATMUL(chitens_face(:,:,p,q,SideID),NormVec(:,p,q,SideID)))*SurfElem(p,q,SideID)*wGP(p)*wGP(q)
      END DO; END DO !p,q
    CASE(11) !neumann q*n=1 !test
      DO q=0,PP_N; DO p=0,PP_N
        r=q*(PP_N+1) + p+1
        qn_face(iVar,r,BCSideID)=SUM((/1.,1.,1./)  &
                            *MATMUL(chitens_face(:,:,p,q,SideID),NormVec(:,p,q,SideID)))*SurfElem(p,q,SideID)*wGP(p)*wGP(q)
      END DO; END DO !p,q
    END SELECT ! BCType
  END DO !BCsideID=1,nNeumannBCSides

!for magnetostatic only neumann
#if (PP_nVar!=1) 
  IF (iVar.LT.4) THEN
    DO BCsideID=1,nDirichletBCSides
!      SideID=DirichletBC(BCsideID)
      DO q=0,PP_N; DO p=0,PP_N
        r=q*(PP_N+1) + p+1
        qn_face_MagStat(iVar,r,BCSideID)= 0.
      END DO; END DO !p,q
    END DO !BCsideID=1,nDirichletBCSides
  END IF
#endif

END DO

!volume source (volume RHS of u system)
DO iElem=1,PP_nElems
  DO k=0,PP_N; DO j=0,PP_N; DO i=0,PP_N
    r=k*(PP_N+1)**2+j*(PP_N+1) + i+1
    CALL CalcSourceHDG(0.,i,j,k,iElem,RHS_vol(1:PP_nVar,r,iElem))
  END DO; END DO; END DO !i,j,k    
  DO iVar = 1, PP_nVar
    RHS_Vol(iVar,:,iElem)=-JwGP_vol(:,iElem)*RHS_vol(iVar,:,iElem)
  END DO
END DO !iElem 

!replace lambda with exact function (debugging)
IF(onlyPostProc.OR.ExactLambda)THEN
  DO SideID=1,nSides
    DO q=0,PP_N; DO p=0,PP_N
      r=q*(PP_N+1) + p+1
      CALL ExactFunc(IniExactFunc,t,0,Face_xGP(:,p,q,SideID),lambda( 1:PP_nVar,r,SideID))
    END DO; END DO !p,q
  END DO
END IF

!prepare RHS_face ( RHS for lamdba system.)
DO iVar = 1, PP_nVar
  RHS_face(iVar,:,:)=0.
  DO iElem=1,PP_nElems
    !rtmp=MATMUL(InvDhat(:,:,iElem),-RHS_loc(:,iElem))
    CALL DSYMV('U',nGP_vol,1., InvDhat(:,:,iElem),nGP_vol, &
                               -RHS_vol(iVar,:,iElem),1,0., &
                               rtmp(:),1)

    DO iLocSide=1,6
      SideID=ElemToSide(E2S_SIDE_ID,iLocSide,iElem)
      CALL DGEMV('N',nGP_face,nGP_vol,1., &
                          Ehat(:,:,iLocSide,iElem), nGP_face, &
                          rtmp,1,1.,& !add to RHS_face 
                          RHS_face(iVar,:,SideID),1)  
    END DO
  END DO !iElem 
END DO

!add Neumann
DO BCsideID=1,nNeumannBCSides
  SideID=NeumannBC(BCsideID)
  RHS_face(:,:,SideID)=RHS_face(:,:,SideID)+qn_face(:,:,BCSideID)
END DO

#if (PP_nVar!=1) 
DO iVar = 1, PP_nVar
  IF (iVar.LT.4) THEN
    DO BCsideID=1,nDirichletBCSides
      SideID=DirichletBC(BCsideID)
      RHS_face(iVar,:,SideID)=RHS_face(iVar,:,SideID)+qn_face_MagStat(iVar,:,BCSideID)     
    END DO !BCsideID=1,nDirichletBCSides
  END IF
END DO
#endif


#ifdef MPI
  startbuf=nSides-nMPISides+1
  endbuf=nSides-nMPISides+nMPISides_MINE
  IF(nMPIsides_MINE.GT.0)RHS_face_buf=RHS_face(:,:,startbuf:endbuf)
  CALL StartReceiveMPIData(1,RHS_face,1,nSides,RecRequest_U ,SendID=2) ! Receive MINE
  CALL StartSendMPIData(   1,RHS_face,1,nSides,SendRequest_U,SendID=2) ! Send YOUR
  CALL FinishExchangeMPIData(SendRequest_U,     RecRequest_U,SendID=2) ! Send YOUR - receive MINE
  IF(nMPIsides_MINE.GT.0) RHS_face(:,:,startbuf:endbuf)=RHS_face(:,:,startbuf:endbuf)+RHS_face_buf
  IF(nMPIsides_YOUR.GT.0) RHS_face(:,:,nSides-nMPIsides_YOUR+1:nSides)=0. !set send buffer to zero!
#endif /*MPI*/

    ! SOLVE 
DO iVar=1, PP_nVar
  CALL CG_solver(RHS_face(iVar,:,:),lambda(iVar,:,:),iVar)
  !POST PROCESSING

  !post processing:
  DO iElem=1,PP_nElems
    ! for post-proc
    DO iLocSide=1,6
      SideID=ElemToSide(E2S_SIDE_ID,iLocSide,iElem)
      CALL DGEMV('T',nGP_face,nGP_vol,1., &
                          Ehat(:,:,iLocSide,iElem), nGP_face, &
                          lambda(iVar,:,SideID),1,1.,& !add to RHS_face 
                          RHS_vol(iVar,:,iElem),1)  
    END DO
    !U_out(:,iElem)=MATMUL(InvDhat(:,:,iElem),-RHS_loc(:,iElem))
    CALL DSYMV('U',nGP_vol,1., InvDhat(:,:,iElem),nGP_vol, &
                               -RHS_vol(iVar,:,iElem),1,0., &
                               U_out(iVar,:,iElem),1)
  END DO !iElem 
END DO

#if (PP_nVar==1)
  CALL PostProcessGradient(U_out(1,:,:),lambda(1,:,:),E)
#elif (PP_nVar==3)
  DO iVar=1, PP_nVar 
    CALL PostProcessGradient(U_out(iVar,:,:),lambda(iVar,:,:),BTemp(iVar,:,:,:))
  END DO
  DO k=0,PP_N; DO j=0,PP_N; DO i=0,PP_N
    r=k*(PP_N+1)**2+j*(PP_N+1) + i+1
    B(1,i,j,k,:) = BTemp(3,2,r,:) - BTemp(2,3,r,:)
    B(2,i,j,k,:) = BTemp(1,3,r,:) - BTemp(3,1,r,:)
    B(3,i,j,k,:) = BTemp(2,1,r,:) - BTemp(1,2,r,:)
  END DO; END DO; END DO !i,j,k
#else
  DO iVar=1, 3 
    CALL PostProcessGradient(U_out(iVar,:,:),lambda(iVar,:,:),BTemp(iVar,:,:,:))
  END DO
  DO k=0,PP_N; DO j=0,PP_N; DO i=0,PP_N
    r=k*(PP_N+1)**2+j*(PP_N+1) + i+1
    B(1,i,j,k,:) = BTemp(3,2,r,:) - BTemp(2,3,r,:)
    B(2,i,j,k,:) = BTemp(1,3,r,:) - BTemp(3,1,r,:)
    B(3,i,j,k,:) = BTemp(2,1,r,:) - BTemp(1,2,r,:)
  END DO; END DO; END DO !i,j,k
  CALL PostProcessGradient(U_out(4,:,:),lambda(4,:,:),E)
#endif

END SUBROUTINE HDGLinear


SUBROUTINE HDGNewton(t,U_out,td_iter)
!===================================================================================================================================
!===================================================================================================================================
! MODULES
USE MOD_Globals
USE MOD_PreProc
USE MOD_HDG_Vars
USE MOD_Equation,          ONLY:CalcSourceHDG,ExactFunc
USE MOD_Equation_Vars,     ONLY:IniExactFunc, eps0
USE MOD_Equation_Vars,     ONLY:chitens_face
USE MOD_Mesh_Vars,         ONLY:BCface_xGP,BoundaryType,nSides,BC!,Elem_xGP,Face_xGP
USE MOD_Mesh_Vars,         ONLY:ElemToSide,NormVec,SurfElem
USE MOD_Interpolation_Vars,ONLY:wGP
USE MOD_Particle_Vars     ,ONLY:  RegionElectronRef
USE MOD_Particle_Boundary_Vars     ,ONLY: PartBound
USE MOD_Particle_Mesh_Vars,ONLY : GEO
USE MOD_Elem_Mat          ,ONLY:PostProcessGradient, Elem_Mat,BuildPrecond
USE MOD_Restart_Vars      ,ONLY: DoRestart,RestartTime
#ifdef MPI
USE MOD_MPI_Vars
USE MOD_MPI,               ONLY:StartReceiveMPIData,StartSendMPIData,FinishExchangeMPIData
USE MOD_Mesh_Vars,         ONLY:nMPISides,nMPIsides_YOUR,nMPIsides_MINE
#endif /*MPI*/ 
#if (PP_nVar==1)
USE MOD_Equation_Vars,     ONLY:E
#endif
USE MOD_TimeDisc_Vars,     ONLY:IterDisplayStep,DoDisplayIter
! IMPLICIT VARIABLE HANDLING
IMPLICIT NONE
!-----------------------------------------------------------------------------------------------------------------------------------
! INPUT VARIABLES
REAL,INTENT(IN)     :: t !time
INTEGER(KIND=8),INTENT(IN)  :: td_iter
!-----------------------------------------------------------------------------------------------------------------------------------
! OUTPUT VARIABLES
REAL,INTENT(INOUT)  :: U_out(PP_nVar,nGP_vol,PP_nElems)
!-----------------------------------------------------------------------------------------------------------------------------------
! LOCAL VARIABLES
INTEGER :: i,j,k,r,p,q,iElem, iter,RegionID
INTEGER :: BCsideID,BCType,BCstate,SideID,iLocSide
REAL    :: RHS_face(PP_nVar,nGP_face,nSides)
REAL    :: rtmp(nGP_vol),Norm_r2!,Norm_r2_old
LOGICAL :: converged, beLinear
#ifdef MPI
REAL    :: RHS_face_buf( PP_nVar,nGP_Face,nMPISides_MINE)
INTEGER :: startbuf,endbuf
#endif /*MPI*/ 
#if (PP_nVar!=1)
REAL    :: BTemp(3,3,nGP_vol,PP_nElems)
#endif
!===================================================================================================================================
#if (PP_nVar!=1)
  WRITE(*,*) 'Nonlinear Newton solver only available with EQ-system Poisson!!'
  STOP
#endif
Norm_r2=0.

!Dirichlet boundary conditions
DO BCsideID=1,nDirichletBCSides
  SideID=DirichletBC(BCsideID)
  BCType =BoundaryType(BC(SideID),BC_TYPE)
  BCState=BoundaryType(BC(SideID),BC_STATE)
  SELECT CASE(BCType)
  CASE(2) ! exact BC = Dirichlet BC !!
    ! Determine the exact BC state
    DO q=0,PP_N; DO p=0,PP_N
      r=q*(PP_N+1) + p+1
      CALL ExactFunc(IniExactFunc,t,0,BCFace_xGP(:,p,q,SideID),lambda(PP_nVar,r:r,SideID))
    END DO; END DO !p,q
  CASE(4) ! exact BC = Dirichlet BC !!
    ! SPECIAL BC: BCState specifies exactfunc to be used!!
    DO q=0,PP_N; DO p=0,PP_N
      r=q*(PP_N+1) + p+1
      lambda(PP_nVar,r:r,SideID)= PartBound%Voltage(PartBound%MapToPartBC(BC(SideID)))
    END DO; END DO !p,q
  END SELECT ! BCType
END DO !BCsideID=1,nDirichletBCSides

!neumann BC
DO BCsideID=1,nNeumannBCSides
  SideID=NeumannBC(BCsideID)
  BCType =BoundaryType(BC(SideID),BC_TYPE)
  BCState=BoundaryType(BC(SideID),BC_STATE)
  SELECT CASE(BCType)
  CASE(10) !neumann q=0
    DO q=0,PP_N; DO p=0,PP_N
      r=q*(PP_N+1) + p+1
      qn_face(PP_nVar,r,BCSideID)= 0. 
    END DO; END DO !p,q
  CASE(11) !neumann q*n=1 !test
    DO q=0,PP_N; DO p=0,PP_N
      r=q*(PP_N+1) + p+1
      qn_face(PP_nVar,r,BCSideID)=SUM((/1.,1.,1./)  &
                          *MATMUL(chitens_face(:,:,p,q,SideID),NormVec(:,p,q,SideID)))*SurfElem(p,q,SideID)*wGP(p)*wGP(q)
    END DO; END DO !p,q
  END SELECT ! BCType
END DO !BCsideID=1,nNeumannBCSides


DO iElem=1,PP_nElems
  DO k=0,PP_N; DO j=0,PP_N; DO i=0,PP_N
    r=k*(PP_N+1)**2+j*(PP_N+1) + i+1
    CALL CalcSourceHDG(0.,i,j,k,iElem,RHS_vol(1:PP_nVar,r,iElem),U_out(1,r,iElem))
  END DO; END DO; END DO !i,j,k
  RHS_Vol(PP_nVar,:,iElem)=-JwGP_vol(:,iElem)*RHS_vol(PP_nVar,:,iElem)
END DO !iElem 

  !prepare RHS_face ( RHS for lamdba system.)
RHS_vol(PP_nVar,:,:)=RHS_vol(PP_nVar,:,:)+JwGP_vol(:,:)*U_out(PP_nVar,:,:)*NonlinVolumeFac(:,:)

RHS_face(PP_nVar,:,:) =0.
DO iElem=1,PP_nElems
  CALL DSYMV('U',nGP_vol,1., InvDhat(:,:,iElem),nGP_vol, &
                             -RHS_vol(PP_nVar,:,iElem),1,0., &
                             rtmp(:),1)
  DO iLocSide=1,6
    SideID=ElemToSide(E2S_SIDE_ID,iLocSide,iElem)
    CALL DGEMV('N',nGP_face,nGP_vol,1., &
                        Ehat(:,:,iLocSide,iElem), nGP_face, &
                        rtmp,1,1.,& !add to RHS_face 
                        RHS_face(PP_nVar,:,SideID),1)  
  END DO
END DO !iElem 


DO BCsideID=1,nNeumannBCSides
  SideID=NeumannBC(BCsideID)
  RHS_face(:,:,SideID)=RHS_face(:,:,SideID)+qn_face(:,:,BCSideID)
END DO

#ifdef MPI
  startbuf=nSides-nMPISides+1
  endbuf=nSides-nMPISides+nMPISides_MINE
  IF(nMPIsides_MINE.GT.0)RHS_face_buf=RHS_face(:,:,startbuf:endbuf)
  CALL StartReceiveMPIData(1,RHS_face,1,nSides,RecRequest_U ,SendID=2) ! Receive MINE
  CALL StartSendMPIData(   1,RHS_face,1,nSides,SendRequest_U,SendID=2) ! Send YOUR
  CALL FinishExchangeMPIData(SendRequest_U,     RecRequest_U,SendID=2) ! Send YOUR - receive MINE
  IF(nMPIsides_MINE.GT.0) RHS_face(:,:,startbuf:endbuf)=RHS_face(:,:,startbuf:endbuf)+RHS_face_buf
  IF(nMPIsides_YOUR.GT.0) RHS_face(:,:,nSides-nMPIsides_YOUR+1:nSides)=0. !set send buffer to zero!
#endif /*MPI*/

CALL CG_solver(RHS_face(PP_nVar,:,:),lambda(PP_nVar,:,:))

!post processing:
DO iElem=1,PP_nElems
  ! for post-proc
  DO iLocSide=1,6
    SideID=ElemToSide(E2S_SIDE_ID,iLocSide,iElem)
    CALL DGEMV('T',nGP_face,nGP_vol,1., &
                        Ehat(:,:,iLocSide,iElem), nGP_face, &
                        lambda(PP_nVar,:,SideID),1,1.,& !add to RHS_face 
                        RHS_vol(PP_nVar,:,iElem),1)  
  END DO
  CALL DSYMV('U',nGP_vol,1., InvDhat(:,:,iElem),nGP_vol, &
                             -RHS_vol(PP_nVar,:,iElem),1,0., &
                             U_out(PP_nVar,:,iElem),1)
END DO !iElem

IF(AdaptNewtonStartValue) THEN
  IF ((.NOT.DoRestart.AND.ALMOSTEQUAL(t,0.)).OR.(DoRestart.AND.ALMOSTEQUAL(t,RestartTime))) THEN
    DO iElem=1,PP_nElems
      RegionID=GEO%ElemToRegion(iElem)
      DO k=0,PP_N; DO j=0,PP_N; DO i=0,PP_N
        r=k*(PP_N+1)**2+j*(PP_N+1) + i+1     
        IF (NewtonExactApprox) THEN
          NonlinVolumeFac(r,iElem) = RegionElectronRef(1,RegionID)/ (RegionElectronRef(3,RegionID)*eps0) &         
                       * EXP( (U_out(1,r,iElem)-RegionElectronRef(2,RegionID)) / RegionElectronRef(3,RegionID) )
        ELSE
          NonlinVolumeFac(r,iElem)=RegionElectronRef(1,RegionID) / (RegionElectronRef(3,RegionID)*eps0)
        END IF
      END DO; END DO; END DO !i,j,k
    END DO !iElem
    CALL Elem_Mat()
    CALL BuildPrecond()
  END IF
END IF

converged =.false.
beLinear=.false.
AdaptIterNewton = AdaptIterNewtonOld
DO iter=1,MaxIterFixPoint

  IF (.NOT.beLinear) THEN
    IF ((iter.EQ.100).OR.(iter.GT.3*AdaptIterNewtonOld)) THEN
      IF(MPIroot) WRITE(*,*) 'The linear way, baby !!!!!!!!!!!!'
      DO iElem=1,PP_nElems
        RegionID=GEO%ElemToRegion(iElem)
        DO k=0,PP_N; DO j=0,PP_N; DO i=0,PP_N
          r=k*(PP_N+1)**2+j*(PP_N+1) + i+1
          NonlinVolumeFac(r,iElem)=RegionElectronRef(1,RegionID) / (RegionElectronRef(3,RegionID)*eps0)
        END DO; END DO; END DO !i,j,k
      END DO !iElem
      CALL Elem_Mat()
      CALL BuildPrecond()
      AdaptIterNewton = 0
      beLinear=.true.
    END IF
  END IF
  
  IF (AdaptIterNewton.GT.0) THEN
    IF (MOD(iter,AdaptIterNewton).EQ.0) THEN
      DO iElem=1,PP_nElems
        RegionID=GEO%ElemToRegion(iElem)
        DO k=0,PP_N; DO j=0,PP_N; DO i=0,PP_N
          r=k*(PP_N+1)**2+j*(PP_N+1) + i+1
          IF (NewtonExactApprox) THEN
            NonlinVolumeFac(r,iElem) = RegionElectronRef(1,RegionID)/ (RegionElectronRef(3,RegionID)*eps0) &         
                       * EXP( (U_out(1,r,iElem)-RegionElectronRef(2,RegionID)) / RegionElectronRef(3,RegionID) )
          ELSE
            NonlinVolumeFac(r,iElem)=RegionElectronRef(1,RegionID) / (RegionElectronRef(3,RegionID)*eps0)
          END IF
        END DO; END DO; END DO !i,j,k
      END DO !iElem
      CALL Elem_Mat()
      CALL BuildPrecond()
    END IF
  END IF
  !volume source (volume RHS of u system)
  !SWRITE(*,*) '!!!!!!!!!!!!!!!!!', iter

  DO iElem=1,PP_nElems
    DO k=0,PP_N; DO j=0,PP_N; DO i=0,PP_N
      r=k*(PP_N+1)**2+j*(PP_N+1) + i+1
      CALL CalcSourceHDG(0.,i,j,k,iElem,RHS_vol(1:PP_nVar,r,iElem),U_out(1,r,iElem))
    END DO; END DO; END DO !i,j,k
    RHS_Vol(PP_nVar,:,iElem)=-JwGP_vol(:,iElem)*RHS_vol(PP_nVar,:,iElem)
  END DO !iElem 

  !prepare RHS_face ( RHS for lamdba system.)
  RHS_vol(PP_nVar,:,:)=RHS_vol(PP_nVar,:,:)+JwGP_vol(:,:)*U_out(PP_nVar,:,:)*NonlinVolumeFac(:,:)

  RHS_face(PP_nVar,:,:) =0.
  DO iElem=1,PP_nElems
    CALL DSYMV('U',nGP_vol,1., InvDhat(:,:,iElem),nGP_vol, &
                               -RHS_vol(PP_nVar,:,iElem),1,0., &
                               rtmp(:),1)
    DO iLocSide=1,6
      SideID=ElemToSide(E2S_SIDE_ID,iLocSide,iElem)
      CALL DGEMV('N',nGP_face,nGP_vol,1., &
                          Ehat(:,:,iLocSide,iElem), nGP_face, &
                          rtmp,1,1.,& !add to RHS_face 
                          RHS_face(PP_nVar,:,SideID),1)  
    END DO
  END DO !iElem 

  !add Neumann
  DO BCsideID=1,nNeumannBCSides
    SideID=NeumannBC(BCsideID)
    RHS_face(:,:,SideID)=RHS_face(:,:,SideID)+qn_face(:,:,BCSideID)
  END DO


#ifdef MPI
  startbuf=nSides-nMPISides+1
  endbuf=nSides-nMPISides+nMPISides_MINE
  IF(nMPIsides_MINE.GT.0)RHS_face_buf=RHS_face(:,:,startbuf:endbuf)
  CALL StartReceiveMPIData(1,RHS_face,1,nSides,RecRequest_U ,SendID=2) ! Receive MINE
  CALL StartSendMPIData(   1,RHS_face,1,nSides,SendRequest_U,SendID=2) ! Send YOUR
  CALL FinishExchangeMPIData(SendRequest_U,     RecRequest_U,SendID=2) ! Send YOUR - receive MINE
  IF(nMPIsides_MINE.GT.0) RHS_face(:,:,startbuf:endbuf)=RHS_face(:,:,startbuf:endbuf)+RHS_face_buf
  IF(nMPIsides_YOUR.GT.0) RHS_face(:,:,nSides-nMPIsides_YOUR+1:nSides)=0. !set send buffer to zero!
#endif /*MPI*/

  ! SOLVE 
  CALL CheckNonLinRes(RHS_face(1,:,:),lambda(1,:,:),converged,Norm_r2)
  IF (converged) THEN
    IF(DoDisplayIter)THEN
      IF(MOD(td_iter,IterDisplayStep).EQ.0) THEN
        SWRITE(*,*) 'Newton Iteration has converged in ',iter,' steps...'
      END IF
    END IF
    EXIT
  ELSE IF (iter.EQ.MaxIterFixPoint) THEN
    STOP 'Newton Iteration has NOT converged!'
  !    SWRITE(*,*)'Norm_r2: ',Norm_r2
  END IF

  CALL CG_solver(RHS_face(PP_nVar,:,:),lambda(PP_nVar,:,:))   

  !post processing:
  DO iElem=1,PP_nElems
    ! for post-proc
    DO iLocSide=1,6
      SideID=ElemToSide(E2S_SIDE_ID,iLocSide,iElem)
      CALL DGEMV('T',nGP_face,nGP_vol,1., &
                          Ehat(:,:,iLocSide,iElem), nGP_face, &
                          lambda(PP_nVar,:,SideID),1,1.,& !add to RHS_face 
                          RHS_vol(PP_nVar,:,iElem),1)  
    END DO
    CALL DSYMV('U',nGP_vol,1., InvDhat(:,:,iElem),nGP_vol, &
                               -RHS_vol(PP_nVar,:,iElem),1,0., &
                               U_out(PP_nVar,:,iElem),1)
  END DO !iElem 
END DO

#if (PP_nVar==1)
CALL PostProcessGradient(U_out(PP_nVar,:,:),lambda(PP_nVar,:,:),E)
#endif

END SUBROUTINE HDGNewton

SUBROUTINE CheckNonLinRes(RHS,lambda, converged,Norm_R2)
!===================================================================================================================================
!   
!===================================================================================================================================
! MODULES
USE MOD_Globals
USE MOD_Preproc
USE MOD_HDG_Vars           ,ONLY: nGP_face
USE MOD_HDG_Vars           ,ONLY: EpsNonLinear
USE MOD_Mesh_Vars          ,ONLY: nSides,nMPISides_YOUR
! IMPLICIT VARIABLE HANDLING
IMPLICIT NONE
!-----------------------------------------------------------------------------------------------------------------------------------
! INPUT VARIABLES
REAL, INTENT(IN)    :: RHS(nGP_face*nSides)
!-----------------------------------------------------------------------------------------------------------------------------------
! OUTPUT VARIABLES
REAL, INTENT(INOUT) :: lambda(nGP_face*nSides)
LOGICAL, INTENT(INOUT) :: converged
REAL, INTENT(OUT) :: Norm_r2
!-----------------------------------------------------------------------------------------------------------------------------------
! LOCAL VARIABLES
REAL,DIMENSION(nGP_face*nSides) :: R 
INTEGER                         :: VecSize
!===================================================================================================================================
#ifdef MPI
! not use MPI_YOUR sides for vector_dot_product!!!
  VecSize=(nSides-nMPIsides_YOUR)*nGP_face
#else
  VecSize=nSides*nGP_face
#endif /*MPI*/
  CALL EvalResidual(RHS,lambda,R)

  CALL VectorDotProduct(VecSize,R(1:VecSize),R(1:VecSize),Norm_R2) !Z=V
!  print*, Norm_R2
!  read*
#ifdef MPI
  IF(MPIroot) converged=(Norm_R2.LT.EpsNonLinear**2)
  CALL MPI_BCAST(converged,1,MPI_LOGICAL,0,MPI_COMM_WORLD,iError)
#else
  converged=(Norm_R2.LT.EpsNonLinear**2)
#endif /*MPI*/
END SUBROUTINE CheckNonLinRes

SUBROUTINE CG_solver(RHS,lambda,iVar)
!===================================================================================================================================
!   
!===================================================================================================================================
! MODULES
USE MOD_Globals
USE MOD_Preproc
USE MOD_HDG_Vars           ,ONLY: nGP_face
USE MOD_HDG_Vars           ,ONLY: EpsCG,MaxIterCG,PrecondType
USE MOD_Mesh_Vars          ,ONLY: nSides,nMPISides_YOUR
! IMPLICIT VARIABLE HANDLING
IMPLICIT NONE
!-----------------------------------------------------------------------------------------------------------------------------------
! INPUT VARIABLES
REAL, INTENT(IN)    :: RHS(nGP_face*nSides)
!-----------------------------------------------------------------------------------------------------------------------------------
! OUTPUT VARIABLES
REAL, INTENT(INOUT) :: lambda(nGP_face*nSides)
INTEGER, INTENT(INOUT),OPTIONAL::iVar
!-----------------------------------------------------------------------------------------------------------------------------------
! LOCAL VARIABLES
REAL,DIMENSION(nGP_face*nSides) :: V,Z,R 
REAL                            :: AbortCrit2
REAL                            :: omega,rr,vz,rz1,rz2,Norm_r2
REAL                            :: timestartCG
INTEGER                         :: iter
INTEGER                         :: VecSize
LOGICAL                         :: converged
!===================================================================================================================================
!SWRITE(UNIT_StdOut,'(132("-"))')
!SWRITE(*,*)'CG solver start'
TimeStartCG=BOLTZPLATZTIME()
#ifdef MPI
! not use MPI_YOUR sides for vector_dot_product!!!
VecSize=(nSides-nMPIsides_YOUR)*nGP_face
#else
VecSize=nSides*nGP_face
#endif /*MPI*/
IF(PRESENT(iVar)) THEN
  CALL EvalResidual(RHS,lambda,R,iVar)
ELSE
  CALL EvalResidual(RHS,lambda,R)
END IF

CALL VectorDotProduct(VecSize,R(1:VecSize),R(1:VecSize),Norm_R2) !Z=V
#ifdef MPI
  IF(MPIroot) converged=(Norm_R2.LT.EpsCG**2)
  CALL MPI_BCAST(converged,1,MPI_LOGICAL,0,MPI_COMM_WORLD,iError)
#else
  converged=(Norm_R2.LT.EpsCG**2)
#endif /*MPI*/
IF(converged) THEN !converged
!  SWRITE(*,*)'CG not needed, residual already =0'
!  SWRITE(UNIT_StdOut,'(132("-"))')
  RETURN
END IF !converged
!AbortCrit2=Norm_R2*EpsCG**2
AbortCrit2=EpsCG**2

IF(PrecondType.NE.0) THEN
  CALL ApplyPrecond(R,V)
ELSE
  V(:)=R(:)
END IF
CALL VectorDotProduct(VecSize,R(1:VecSize),V(1:VecSize),rz1) !Z=V

! Conjugate Gradient
!IF(MPIroot) print*, '!!!!!!!!!!!!!!!!!!!!!!'
!IF(MPIroot) print*, iVar
DO iter=1,MaxIterCG
  ! matrix vector
  IF(PRESENT(iVar)) THEN
    CALL MatVec(V,Z, iVar)
  ELSE
    CALL MatVec(V,Z)
  END IF

  CALL VectorDotProduct(VecSize,V(1:VecSize),Z(1:VecSize),vz)

  omega=rz1/vz

  lambda=lambda+omega*V
  R=R-omega*Z
  CALL VectorDotProduct(VecSize,R(1:VecSize),R(1:VecSize),rr)
#ifdef MPI
  IF(MPIroot) converged=(rr.LT.AbortCrit2)
!  IF(MPIroot) print*, rr, AbortCrit2
  CALL MPI_BCAST(converged,1,MPI_LOGICAL,0,MPI_COMM_WORLD,iError)
#else
  converged=(rr.LT.AbortCrit2)
#endif /*MPI*/
  IF(converged) THEN !converged
!    TimeEndCG=BOLTZPLATZTIME()
!    SWRITE(UNIT_StdOut,'(A,X,I16)')   '#iterations        :',iter
!    SWRITE(UNIT_StdOut,'(A,X,ES16.7)')'RunTime         [s]:',(TimeEndCG-TimeStartCG)
!    SWRITE(UNIT_StdOut,'(A,X,ES16.7)')'RunTime/iter    [s]:', (TimeEndCG-TimeStartCG)/REAL(iter)
!    SWRITE(UNIT_StdOut,'(A,X,ES16.7)')'RunTime/iter/DOF[s]:',(TimeEndCG-TimeStartCG)/REAL(iter*PP_nElems*nGP_vol)
!    CALL EvalResidual(RHS,lambda,R)
!    CALL VectorDotProduct(VecSize,R(1:VecSize),R(1:VecSize),Norm_R2) !Z=V
!    SWRITE(UNIT_StdOut,'(A,X,ES16.7)')'Final Residual     :',SQRT(Norm_R2)
!    SWRITE(UNIT_StdOut,'(132("-"))')
    RETURN
  END IF !converged

  IF(PrecondType.NE.0) THEN
    CALL ApplyPrecond(R,Z)
  ELSE
    Z(:)=R(:)
  END IF
  CALL VectorDotProduct(VecSize,R(1:VecSize),Z(1:VecSize),rz2)
  V=Z+(rz2/rz1)*V
  rz1=rz2
END DO ! iter 
SWRITE(*,*)'CG sovler not converged in ',iter, 'iterations!!'
SWRITE(UNIT_StdOut,'(132("-"))')

END SUBROUTINE CG_solver


SUBROUTINE EvalResidual(RHS,lambda,R,iVar)
!===================================================================================================================================
!   
!===================================================================================================================================
! MODULES
USE MOD_Globals
USE MOD_HDG_Vars           ,ONLY: nGP_face,nDirichletBCSides,DirichletBC
USE MOD_Mesh_Vars          ,ONLY: nSides
! IMPLICIT VARIABLE HANDLING
IMPLICIT NONE
!-----------------------------------------------------------------------------------------------------------------------------------
! INPUT VARIABLES
REAL, INTENT(IN)    :: RHS(nGP_face,nSides)
REAL, INTENT(INOUT) :: lambda(nGP_face,nSides)
INTEGER, INTENT(INOUT),OPTIONAL::iVar
!-----------------------------------------------------------------------------------------------------------------------------------
! OUTPUT VARIABLES
REAL, INTENT(OUT)   :: R(nGP_face,nSides)
!-----------------------------------------------------------------------------------------------------------------------------------
! LOCAL VARIABLES
REAL                :: mv(nGP_face,nSides)
INTEGER             :: BCsideID
!===================================================================================================================================
IF(PRESENT(iVar)) THEN
  CALL MatVec(lambda,mv,iVar)
ELSE
  CALL MatVec(lambda,mv)
END IF
R=RHS-mv


!set mv on Dirichlet BC to zero!
#if (PP_nVar!=1)
IF (iVar.EQ.4) THEN
#endif
DO BCsideID=1,nDirichletBCSides
  R(:,DirichletBC(BCsideID))=0.
END DO ! SideID=1,nSides
#if (PP_nVar!=1)
END IF
#endif


END SUBROUTINE EvalResidual


SUBROUTINE MatVec(lambda, mv, iVar)
!===================================================================================================================================
! Performs matrix-vector multiplication for lambda system
!===================================================================================================================================
! MODULES
USE MOD_HDG_Vars           ,ONLY: Smat,Fdiag, nGP_face
USE MOD_HDG_Vars           ,ONLY: nDirichletBCSides,DirichletBC
USE MOD_Mesh_Vars          ,ONLY: nSides, SideToElem, ElemToSide
#ifdef MPI
USE MOD_MPI_Vars
USE MOD_MPI,           ONLY:StartReceiveMPIData,StartSendMPIData,FinishExchangeMPIData
USE MOD_Mesh_Vars,     ONLY:nMPISides,nMPIsides_YOUR,nMPIsides_MINE
#endif /*MPI*/ 
! IMPLICIT VARIABLE HANDLING
IMPLICIT NONE
!-----------------------------------------------------------------------------------------------------------------------------------
! INPUT VARIABLES
REAL,INTENT(INOUT) :: lambda(nGP_face, nSides)
!-----------------------------------------------------------------------------------------------------------------------------------
! OUTPUT VARIABLES
REAL,INTENT(INOUT) :: mv(nGP_face, nSides)
INTEGER, INTENT(INOUT),OPTIONAL::iVar
!-----------------------------------------------------------------------------------------------------------------------------------
! LOCAL VARIABLES
INTEGER :: firstSideID, lastSideID
INTEGER :: BCsideID,SideID, ElemID, locSideID
INTEGER :: jLocSide,jSideID(6)
#ifdef MPI
REAL    :: mvbuf(nGP_Face,nMPISides_MINE)
INTEGER :: startbuf,endbuf
#endif /*MPI*/ 
!===================================================================================================================================
#ifdef MPI
CALL StartReceiveMPIData(1,lambda,1,nSides, RecRequest_U,SendID=1) ! Receive MINE
CALL StartSendMPIData(   1,lambda,1,nSides,SendRequest_U,SendID=1) ! Send YOUR
#endif /*MPI*/


#ifdef MPI
firstSideID = 1
lastSideID = nSides-nMPIsides_YOUR
#else
firstSideID = 1
lastSideID = nSides
#endif /*MPI*/

mv=0.

DO SideID=firstSideID,lastSideID
  !master element
  locSideID = SideToElem(S2E_LOC_SIDE_ID,SideID)
  IF(locSideID.NE.-1)THEN
    ElemID    = SideToElem(S2E_ELEM_ID,SideID)  
    jSideID(:) = ElemToSide(E2S_SIDE_ID,:,ElemID)
    DO jLocSide = 1,6
      CALL DGEMV('N',nGP_face,nGP_face,1., &
                        Smat(:,:,jLocSide,locSideID,ElemID), nGP_face, &
                        lambda(:,SideID),1,1.,& !add to mv 
                        mv(:,jSideID(jLocSide)),1)  
    END DO !jLocSide 
  END IF !locSideID.NE.-1
  ! neighbour element
  locSideID = SideToElem(S2E_NB_LOC_SIDE_ID,SideID)
  IF(locSideID.NE.-1)THEN
    ElemID    = SideToElem(S2E_NB_ELEM_ID,SideID)
    jSideID(:)=ElemToSide(E2S_SIDE_ID,:,ElemID)
    DO jLocSide = 1,6
      CALL DGEMV('N',nGP_face,nGP_face,1., &
                        Smat(:,:,jLocSide,locSideID,ElemID), nGP_face, &
                        lambda(:,SideID),1,1.,& !add to mv 
                        mv(:,jSideID(jLocSide)),1)  
    END DO !jLocSide 
  END IF !locSideID.NE.-1
  !add mass matrix
  mv(:,SideID)=mv(:,SideID)-Fdiag(:,SideID)*lambda(:,SideID)
END DO ! SideID=1,nSides

#ifdef MPI
! Finish lambda communication 
CALL FinishExchangeMPIData(SendRequest_U,RecRequest_U,SendID=1) 

firstSideID=nSides-nMPIsides_YOUR+1
lastSideID =nSides
DO SideID=firstSideID,lastSideID
  !master element
  locSideID = SideToElem(S2E_LOC_SIDE_ID,SideID)
  IF(locSideID.NE.-1)THEN
    ElemID    = SideToElem(S2E_ELEM_ID,SideID)  
    jSideID(:) = ElemToSide(E2S_SIDE_ID,:,ElemID)
    DO jLocSide = 1,6
      CALL DGEMV('N',nGP_face,nGP_face,1., &
                        Smat(:,:,jLocSide,locSideID,ElemID), nGP_face, &
                        lambda(:,SideID),1,1.,& !add to mv 
                        mv(:,jSideID(jLocSide)),1)  
    END DO !jLocSide 
  END IF !locSideID.NE.-1
  ! neighbour element
  locSideID = SideToElem(S2E_NB_LOC_SIDE_ID,SideID)
  IF(locSideID.NE.-1)THEN
    ElemID    = SideToElem(S2E_NB_ELEM_ID,SideID)
    jSideID(:)=ElemToSide(E2S_SIDE_ID,:,ElemID)
    DO jLocSide = 1,6
      CALL DGEMV('N',nGP_face,nGP_face,1., &
                        Smat(:,:,jLocSide,locSideID,ElemID), nGP_face, &
                        lambda(:,SideID),1,1.,& !add to mv 
                        mv(:,jSideID(jLocSide)),1)
    END DO !jLocSide 
  END IF !locSideID.NE.-1
  !add mass matrix
  mv(:,SideID)=mv(:,SideID)-Fdiag(:,SideID)*lambda(:,SideID)
END DO ! SideID=1,nSides

#endif /*MPI*/



#ifdef MPI
startbuf=nSides-nMPISides+1
endbuf=nSides-nMPISides+nMPISides_MINE
IF(nMPIsides_MINE.GT.0)mvbuf=mv(:,startbuf:endbuf)
CALL StartReceiveMPIData(1,mv,1,nSides,RecRequest_U ,SendID=2)  ! Receive MINE
CALL StartSendMPIData(   1,mv,1,nSides,SendRequest_U,SendID=2)  ! Send YOUR
CALL FinishExchangeMPIData(SendRequest_U,RecRequest_U,SendID=2) ! Send YOUR - receive MINE
IF(nMPIsides_MINE.GT.0) mv(:,startbuf:endbuf)=mv(:,startbuf:endbuf)+mvbuf
IF(nMPIsides_YOUR.GT.0) mv(:,nSides-nMPIsides_YOUR+1:nSides)=0. !set send buffer to zero!
#endif /*MPI*/


#if (PP_nVar!=1)
IF (iVar.EQ.4) THEN
#endif
!set mv on Dirichlet BC to zero!
DO BCsideID=1,nDirichletBCSides
  mv(:,DirichletBC(BCsideID))=0.
END DO ! SideID=1,nSides
#if (PP_nVar!=1)
END IF
#endif


END SUBROUTINE MatVec


SUBROUTINE VectorDotProduct(dim1,A,B,Resu)
!===================================================================================================================================
! Computes Dot Product for vectors a and b: resu=a.b
!===================================================================================================================================
! MODULES
USE MOD_Globals
USE MOD_PreProc
! IMPLICIT VARIABLE HANDLING
IMPLICIT NONE
!-----------------------------------------------------------------------------------------------------------------------------------
! INPUT VARIABLES
INTEGER,INTENT(IN):: dim1
REAL,INTENT(IN)   :: A(dim1)
REAL,INTENT(IN)   :: B(dim1)
!-----------------------------------------------------------------------------------------------------------------------------------
! OUTPUT VARIABLES
REAL,INTENT(OUT)  :: Resu
!-----------------------------------------------------------------------------------------------------------------------------------
! LOCAL VARIABLES
INTEGER           :: i
!===================================================================================================================================

Resu=0.
DO i=1,dim1
  Resu=Resu + A(i)*B(i)
END DO

#ifdef MPI
  CALL MPI_ALLREDUCE(MPI_IN_PLACE,Resu,1,MPI_DOUBLE_PRECISION,MPI_SUM,MPI_COMM_WORLD,iError)
#endif

END SUBROUTINE VectorDotProduct


SUBROUTINE FinalizeHDG()
!===================================================================================================================================
! Finalizes variables necessary for hdg subroutines
!===================================================================================================================================
USE MOD_HDG_Vars
! IMPLICIT VARIABLE HANDLING
IMPLICIT NONE
!-----------------------------------------------------------------------------------------------------------------------------------
! OUTPUT VARIABLES
!-----------------------------------------------------------------------------------------------------------------------------------
! LOCAL VARIABLES
!===================================================================================================================================
HDGInitIsDone = .FALSE.
END SUBROUTINE FinalizeHDG



SUBROUTINE ApplyPrecond(R, V)
!===================================================================================================================================
! Apply the block-diagonal preconditioner for the lambda system
!===================================================================================================================================
! MODULES
USE MOD_HDG_Vars           ,ONLY: nGP_face, Precond, PrecondType,InvPrecondDiag
USE MOD_Mesh_Vars          ,ONLY: nSides
#ifdef MPI
USE MOD_MPI_Vars
USE MOD_MPI,           ONLY:StartReceiveMPIData,StartSendMPIData,FinishExchangeMPIData
USE MOD_Mesh_Vars,     ONLY:nMPIsides_YOUR
#endif /*MPI*/ 

! IMPLICIT VARIABLE HANDLING
IMPLICIT NONE
!-----------------------------------------------------------------------------------------------------------------------------------
! INPUT VARIABLES
REAL,INTENT(IN) :: R(nGP_face, nSides)
!-----------------------------------------------------------------------------------------------------------------------------------
! OUTPUT VARIABLES
REAL,INTENT(INOUT) :: V(nGP_face, nSides)
!-----------------------------------------------------------------------------------------------------------------------------------
! LOCAL VARIABLES
INTEGER :: firstSideID, lastSideID, SideID, igf
!===================================================================================================================================


firstSideID = 1
#ifdef MPI
lastSideID = nSides-nMPIsides_YOUR
#else
lastSideID = nSides
#endif /*MPI*/

SELECT CASE(PrecondType)
CASE(0)
  ! do nothing, should not be called
CASE(1) !apply side-block SPD Preconditioner matrix, already Cholesky decomposed
  DO SideID=firstSideID,lastSideID
    ! solve the preconditioner linear system
    call solveSPD(nGP_face,Precond(:,:,SideID),1,R(:,SideID), V(:,SideID))
  END DO ! SideID=1,nSides
CASE(2)
  DO SideID=firstSideID,lastSideID
    ! apply inverse of diagonal preconditioner
    DO igf = 1, nGP_face
      V(igf, SideID) = InvPrecondDiag(igf,SideID)*R(igf,SideID)
    END DO ! igf
  END DO ! SideID=1,nSides
END SELECT ! PrecondType


END SUBROUTINE ApplyPrecond



SUBROUTINE solveSPD(dimA,A,nRHS,RHS, X)
!===================================================================================================================================
! Solve a symmetrical positive definite linear system of dimension dims
!===================================================================================================================================
! MODULES

! IMPLICIT VARIABLE HANDLING
IMPLICIT NONE
!-----------------------------------------------------------------------------------------------------------------------------------
! INPUT VARIABLES
INTEGER,INTENT(IN):: dimA
REAL,INTENT(IN)   :: A(dimA, dimA)
INTEGER,INTENT(IN):: nRHS
REAL,INTENT(IN)   :: RHS(dimA,nRHS)
!-----------------------------------------------------------------------------------------------------------------------------------
! OUTPUT VARIABLES
REAL,INTENT(INOUT):: X(dimA,nRHS)
!-----------------------------------------------------------------------------------------------------------------------------------
! LOCAL VARIABLES
INTEGER           :: lapack_info
!===================================================================================================================================
X = RHS

CALL DPOTRS('U',dimA,nRHS,A,dimA,X,dimA,lapack_info)


!IF (lapack_info .NE. 0) THEN
!  STOP 'LAPACK ERROR IN SOLVE CHOLESKY!'
!END IF
END SUBROUTINE solveSPD



SUBROUTINE RestartHDG(U_out)
!===================================================================================================================================
!===================================================================================================================================
! MODULES
USE MOD_Globals
USE MOD_PreProc
USE MOD_HDG_Vars
USE MOD_Equation,          ONLY:CalcSourceHDG,ExactFunc
USE MOD_Elem_Mat          ,ONLY:PostProcessGradient
USE MOD_Basis              ,ONLY: getSPDInverse, GetInverse
#ifdef MPI
USE MOD_MPI_Vars
#endif /*MPI*/ 
#if (PP_nVar==1)
USE MOD_Equation_Vars,     ONLY:E
#elif (PP_nVar==3)
USE MOD_Equation_Vars,     ONLY:B
#else
USE MOD_Equation_Vars,     ONLY:B, E
#endif
! IMPLICIT VARIABLE HANDLING
IMPLICIT NONE
!-----------------------------------------------------------------------------------------------------------------------------------
REAL,INTENT(INOUT)  :: U_out(PP_nVar,nGP_vol,PP_nElems)
!-----------------------------------------------------------------------------------------------------------------------------------
! LOCAL VARIABLES
#ifdef MPI
#endif /*MPI*/ 
#if (PP_nVar!=1)
REAL    :: BTemp(3,3,nGP_vol,PP_nElems)
#endif
!===================================================================================================================================

#if (PP_nVar==1)
  CALL PostProcessGradient(U_out(1,:,:),lambda(1,:,:),E)
#elif (PP_nVar==3)
  DO iVar=1, PP_nVar 
    CALL PostProcessGradient(U_out(iVar,:,:),lambda(iVar,:,:),BTemp(iVar,:,:,:))
  END DO
  DO k=0,PP_N; DO j=0,PP_N; DO i=0,PP_N
    r=k*(PP_N+1)**2+j*(PP_N+1) + i+1
    B(1,i,j,k,:) = BTemp(3,2,r,:) - BTemp(2,3,r,:)
    B(2,i,j,k,:) = BTemp(1,3,r,:) - BTemp(3,1,r,:)
    B(3,i,j,k,:) = BTemp(2,1,r,:) - BTemp(1,2,r,:)
  END DO; END DO; END DO !i,j,k
#else
  DO iVar=1, 3 
    CALL PostProcessGradient(U_out(iVar,:,:),lambda(iVar,:,:),BTemp(iVar,:,:,:))
  END DO
  DO k=0,PP_N; DO j=0,PP_N; DO i=0,PP_N
    r=k*(PP_N+1)**2+j*(PP_N+1) + i+1
    B(1,i,j,k,:) = BTemp(3,2,r,:) - BTemp(2,3,r,:)
    B(2,i,j,k,:) = BTemp(1,3,r,:) - BTemp(3,1,r,:)
    B(3,i,j,k,:) = BTemp(2,1,r,:) - BTemp(1,2,r,:)
  END DO; END DO; END DO !i,j,k
  CALL PostProcessGradient(U_out(4,:,:),lambda(4,:,:),E)
#endif
END SUBROUTINE RestartHDG

END MODULE MOD_HDG