#include "boltzplatz.h"

MODULE MOD_Equation
!===================================================================================================================================
! Add comments please!
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
INTERFACE InitEquation
  MODULE PROCEDURE InitEquation
END INTERFACE
INTERFACE ExactFunc
  MODULE PROCEDURE ExactFunc 
END INTERFACE
INTERFACE CalcSource
  MODULE PROCEDURE CalcSource
END INTERFACE
INTERFACE DivCleaningDamping
  MODULE PROCEDURE DivCleaningDamping
END INTERFACE
PUBLIC::InitEquation,ExactFunc,CalcSource,FinalizeEquation,DivCleaningDamping
!===================================================================================================================================

PUBLIC::DefineParametersEquation
CONTAINS

!==================================================================================================================================
!> Define parameters for equation
!==================================================================================================================================
SUBROUTINE DefineParametersEquation()
! MODULES
USE MOD_Globals
USE MOD_ReadInTools ,ONLY: prms
IMPLICIT NONE
!==================================================================================================================================
CALL prms%SetSection("Equation")

CALL prms%CreateRealOption(     'c_corr'           , 'TODO-DEFINE-PARAMETER\n'//&
                                                     'Multiplied with c0 results in the velocity of '//&
                                                     'introduced artificial correcting waves (HDC)' , '1.')
CALL prms%CreateRealOption(     'c0'               , 'TODO-DEFINE-PARAMETER\n'//&
                                                     'Velocity of light (in vacuum)' , '1.')
CALL prms%CreateRealOption(     'eps'              , 'TODO-DEFINE-PARAMETER\n'//&
                                                     'Electric constant (vacuum permittivity)' , '1.')
CALL prms%CreateRealOption(     'mu'               , 'TODO-DEFINE-PARAMETER\n'//&
                                                     'Magnetic constant (vacuum permeability = 4πE−7H/m)' &
                                                   , '1.')
CALL prms%CreateRealOption(     'fDamping'         , 'TODO-DEFINE-PARAMETER\n'//&
                                                     'Apply the damping factor also to PML source terms\n'//&
                                                     'but only to PML variables for Phi_E and Phi_B to prevent charge-related\n'//&
                                                     'instabilities (accumulation of divergence compensation over \n'//&
                                                     'timeU2 = U2 * fDamping' , '0.999')
CALL prms%CreateLogicalOption(  'ParabolicDamping' , 'TODO-DEFINE-PARAMETER' , '.FALSE.')
CALL prms%CreateLogicalOption(  'CentralFlux'      , 'TODO-DEFINE-PARAMETER\n'//&
                                                     'Flag for central or upwind flux' , '.FALSE.')
CALL prms%CreateIntOption(      'IniExactFunc'     , 'TODO-DEFINE-PARAMETER\n'//&
                                                     'Define exact function necessary for '//&
                                                     'linear scalar advection')

CALL prms%CreateLogicalOption(  'DoExactFlux'      , 'TODO-DEFINE-PARAMETER\n'//&
                                                     'Switch emission to flux superposition at'//&
                                                     ' certain positions' , '.FALSE.')
CALL prms%CreateRealArrayOption('xDipole'          , 'TODO-DEFINE-PARAMETER\n'//&
                                                     'Base point of electromagnetic dipole', '0. , 0. , 0.')
CALL prms%CreateRealOption(     'omega'            , 'TODO-DEFINE-PARAMETER\n'//&
                                                     '2*pi*f (f=100 MHz default)' , '6.28318e8')
CALL prms%CreateRealOption(     'tPulse'           , 'TODO-DEFINE-PARAMETER\n'//&
                                                     'Half length of pulse' , '30e-9')

CALL prms%CreateRealOption(     'TEFrequency'      , 'TODO-DEFINE-PARAMETER\n'//&
                                                     'Frequency of TE wave' , '35e9')
CALL prms%CreateRealOption(     'TEScale'          , 'TODO-DEFINE-PARAMETER\n'//&
                                                     'Scaling of input TE-wave strength' , '1.')
CALL prms%CreateLogicalOption(  'TEPolarization'   , 'TODO-DEFINE-PARAMETER\n'//&
                                                     'Linear or circular polarized' , '.TRUE.')
CALL prms%CreateIntOption(      'TERotation'       , 'TODO-DEFINE-PARAMETER\n'//&
                                                     'Left or right rotating TE wave', '1')
CALL prms%CreateLogicalOption(  'TEPulse'          , 'TODO-DEFINE-PARAMETER\n'//&
                                                     'Flag for pulsed or continuous wave' , '.FALSE.')
CALL prms%CreateIntArrayOption( 'TEMode'           , 'TODO-DEFINE-PARAMETER\n'//&
                                                     'Input of TE_n,m mode', '1 , 1')
CALL prms%CreateRealOption(     'TERadius'         , 'TODO-DEFINE-PARAMETER\n'//&
                                                     'Radius of Input TE wave, if wave is '//&
                                                     ' inserted over a plane' , '0.0')

CALL prms%CreateRealOption(     'WaveLength'       , 'TODO-DEFINE-PARAMETER' , '1.')
CALL prms%CreateRealArrayOption('WaveVector'       , 'TODO-DEFINE-PARAMETER', '0. , 0. , 1.')
CALL prms%CreateRealArrayOption('WaveBasePoint'    , 'TODO-DEFINE-PARAMETER', '0.5 , 0.5 , 0.')
CALL prms%CreateRealOption(     'I_0'              , 'TODO-DEFINE-PARAMETER\n'//&
                                                     'Max. intensity' , '1.')
CALL prms%CreateRealOption(     'sigma_t'          , 'TODO-DEFINE-PARAMETER\n'//&
                                                     'Can be used instead of tFWHM (time For Full '//&
                                                     'Wave Half Maximum)' , '0.')
CALL prms%CreateRealOption(     'tFWHM'            , 'TODO-DEFINE-PARAMETER\n'//&
                                                     'Time For Full Wave Half Maximum' , '0.')
CALL prms%CreateRealOption(     'Beam_a0'          , 'TODO-DEFINE-PARAMETER\n'//&
                                                     'Value to scale max. electric field' , '-1.0')
CALL prms%CreateRealOption(     'omega_0'          , 'TODO-DEFINE-PARAMETER\n'//&
                                                     'Spot size and inv of spot size' , '1.0')
CALL prms%CreateStringOption(   'BCStateFile'      , 'TODO-DEFINE-PARAMETER\n'//&
                                                     'Boundary Condition State File', 'no file found')
CALL prms%CreateIntOption(      'AlphaShape'       , 'TODO-DEFINE-PARAMETER', '2')
CALL prms%CreateRealOption(     'r_cutoff'         , 'TODO-DEFINE-PARAMETER\n'//&
                                                     'Modified for curved and shape-function influence'//&
                                                     ' (c*dt*SafetyFactor+r_cutoff)' , '1.0')

CALL prms%CreateIntOption(      'FluxDir'          , 'TODO-DEFINE-PARAMETER\n'//&
                                                     'Flux direction', '-1')
CALL prms%CreateIntOption(      'ExactFluxDir'     , 'TODO-DEFINE-PARAMETER\n'//&
                                                     'Flux direction for ExactFlux', '3')
CALL prms%CreateRealOption(     'ExactFluxPosition', 'TODO-DEFINE-PARAMETER\n'//&
                                                     'x,y, or z-position of interface')

END SUBROUTINE DefineParametersEquation

SUBROUTINE InitEquation()
!===================================================================================================================================
! Get the constant advection velocity vector from the ini file 
!===================================================================================================================================
! MODULES
USE MOD_Globals
USE MOD_Globals_Vars,            ONLY:PI,ElectronMass,ElectronCharge
USE MOD_ReadInTools
#ifdef PARTICLES
USE MOD_Interpolation_Vars,      ONLY:InterpolationInitIsDone
#endif
USE MOD_Equation_Vars 
USE MOD_TimeDisc_Vars,           ONLY:TEnd
USE MOD_Mesh_Vars,               ONLY:BoundaryType,nBCs,BC
USE MOD_Globals_Vars,            ONLY:EpsMach
USE MOD_Mesh_Vars,               ONLY:xyzMinMax,nSides,nBCSides
USE MOD_Mesh,                    ONLY:GetMeshMinMaxBoundaries
USE MOD_Utils,                   ONLY:RootsOfBesselFunctions
! IMPLICIT VARIABLE HANDLING
 IMPLICIT NONE
!-----------------------------------------------------------------------------------------------------------------------------------
! INPUT VARIABLES
!-----------------------------------------------------------------------------------------------------------------------------------
! OUTPUT VARIABLES
!-----------------------------------------------------------------------------------------------------------------------------------
! LOCAL VARIABLES
REAL                             :: c_test
INTEGER                          :: nRefStates,iBC,ntmp,iRefState
INTEGER,ALLOCATABLE              :: RefStates(:)
LOGICAL                          :: isNew
REAL                             :: PulseCenter
REAL,ALLOCATABLE                 :: nRoots(:)
LOGICAL                          :: DoSide(1:nSides)
INTEGER                          :: locType,locState,iSide
!===================================================================================================================================
! Read the maximum number of time steps MaxIter and the end time TEnd from ini file
TEnd=GetReal('TEnd') ! must be read in here due to DSMC_init
IF(EquationInitIsDone)THEN
#ifdef PARTICLES
  IF(InterpolationInitIsDone)THEN
    SWRITE(*,*) "InitMaxwell not ready to be called or already called."
    RETURN
  END IF
#else
  SWRITE(*,*) "InitMaxwell not ready to be called or already called."
  RETURN
#endif /*PARTICLES*/
END IF

SWRITE(UNIT_StdOut,'(132("-"))')
SWRITE(UNIT_stdOut,'(A)') ' INIT MAXWELL ...' 

! Read correction velocity
c_corr             = GETREAL('c_corr','1.')
c                  = GETREAL('c0','1.')
eps0               = GETREAL('eps','1.')
mu0                = GETREAL('mu','1.')
smu0               = 1./mu0
fDamping           = GETREAL('fDamping','0.999')
DoParabolicDamping = GETLOGICAL('ParabolicDamping','.FALSE.')
CentralFlux        = GETLOGICAL('CentralFlux','.FALSE.')
!scr            = 1./ GETREAL('c_r','0.18')  !constant for damping

c_test = 1./SQRT(eps0*mu0)
IF(.NOT.ALMOSTEQUALRELATIVE(c_test,c,10E-8))THEN
  SWRITE(*,*) "ERROR: c does not equal 1/sqrt(eps*mu)!"
  SWRITE(*,*) "c:", c
  SWRITE(*,*) "mu:", mu0
  SWRITE(*,*) "eps:", eps0
  SWRITE(*,*) "1/sqrt(eps*mu):", c_test
  CALL abort(&
      __STAMP__&
      ,' Speed of light coefficients does not match!')
END IF

c2     = c*c 
c_inv  = 1./c
c2_inv = 1./c2

c_corr2   = c_corr*c_corr
c_corr_c  = c_corr*c 
c_corr_c2 = c_corr*c2
eta_c     = (c_corr-1.)*c

! Read in boundary parameters
IniExactFunc = GETINT('IniExactFunc')
nRefStates=nBCs+1
nTmp=0
ALLOCATE(RefStates(nRefStates))
RefStates=0
IF(IniExactFunc.GT.0) THEN
  RefStates(1)=IniExactFunc
  nTmp=1
END IF
DO iBC=1,nBCs
  IF(BoundaryType(iBC,BC_STATE).GT.0)THEN
    isNew=.TRUE.
    ! check if boundarytype already exists
    DO iRefState=1,nTmp
      IF(BoundaryType(iBC,BC_STATE).EQ.RefStates(iRefState)) isNew=.FALSE.
    END DO
    IF(isNew)THEN
      nTmp=nTmp+1
      RefStates(ntmp)=BoundaryType(iBC,BC_STATE)
    END IF
  END IF
END DO
IF(nTmp.GT.0) DoExactFlux = GETLOGICAL('DoExactFlux','.FALSE.')
IF(DoExactFlux) CALL InitExactFlux()
DO iRefState=1,nTmp
  SELECT CASE(RefStates(iRefState))
  CASE(4,41)
    xDipole(1:3)       = GETREALARRAY('xDipole',3,'0.,0.,0.') ! dipole base point
    DipoleOmega        = GETREAL('omega','6.28318E08')        ! f=100 MHz default
    tPulse             = GETREAL('tPulse','30e-9')            ! half length of pulse
  CASE(5)
    TEFrequency        = GETREAL('TEFrequency','35e9') 
    TEScale            = GETREAL('TEScale','1.') 
    TEPolarization     = GETLOGICAL('TEPolarization','.TRUE.') 
    TERotation         = GETINT('TERotation','1') 
    TEPulse            = GETLOGICAL('TEPulse','.FALSE.')
    TEMode             = GETINTARRAY('TEMode',2,'1,1')
    ! compute required roots
    ALLOCATE(nRoots(1:TEMode(2)))
    CALL RootsOfBesselFunctions(TEMode(1),TEMode(2),0,nRoots)
    TEModeRoot=nRoots(TEMode(2))
    DEALLOCATE(nRoots)
    ! check if it is a BC condition
    DO iBC=1,nBCs
      IF(BoundaryType(iBC,BC_STATE).EQ.5)THEN
        DoSide=.FALSE.
        DO iSide=1,nBCSides
          locType =BoundaryType(BC(iSide),BC_TYPE)
          locState=BoundaryType(BC(iSide),BC_STATE)
          IF(locState.EQ.5)THEN
            DoSide(iSide)=.TRUE.
          END IF ! locState.EQ.BCIn
        END DO
        ! call function to get radius
        CALL GetWaveGuideRadius(DoSide)
      END IF
    END DO
    IF((TERotation.NE.-1).AND.(TERotation.NE.1))THEN
      CALL abort(&
    __STAMP__&
    ,' TERotation has to be +-1 for right and left rotating TE modes.')
    END IF
    IF(TERadius.LT.0.0)THEN ! not set
      TERadius=GETREAL('TERadius','0.0')
      SWRITE(UNIT_StdOut,*) ' TERadius not determined automatically. Set waveguide radius to ', TERadius
    END IF

    ! display cut-off freequncy for this mode
    SWRITE(UNIT_stdOut,'(A,I5,A1,I5,A,E25.14E3,A)')&
           '  Cut-off frequency in circular waveguide for TE_[',1,',',0,'] is ',1.8412*c/(2*PI*TERadius),' Hz (lowest mode)'
    SWRITE(UNIT_stdOut,'(A,I5,A1,I5,A,E25.14E3,A)')&
           '  Cut-off frequency in circular waveguide for TE_[',TEMode(1),',',TEMode(2),'] is ',(TEModeRoot/TERadius)*c/(2*PI),&
           ' Hz (chosen mode)'
  CASE(12,14,15,16)
    ! planar wave input
    WaveLength     = GETREAL('WaveLength','1.') ! f=100 MHz default
    WaveVector(1:3)= GETREALARRAY('WaveVector',3,'0.,0.,1.')
    WaveVector=UNITVECTOR(WaveVector)
    BeamWaveNumber=2.*PI/WaveLength
    BeamOmegaW=BeamWaveNumber*c

    ! construct perpendicular electric field
    IF(ABS(WaveVector(3)).LT.EpsMach)THEN
      E_0=(/ -WaveVector(2)-WaveVector(3)  , WaveVector(1) ,WaveVector(1) /)
    ELSE
      IF(ALMOSTEQUAL(ABS(WaveVector(3)),1.))THEN ! wave vector in z-dir -> E_0 in x-dir!
        E_0=(/1.0, 0.0, 0.0 /) ! test fixed direction
      ELSE
        E_0=(/ WaveVector(3) , WaveVector(3) , -WaveVector(1)-WaveVector(2) /)
      END IF
    END IF
    ! normalize E-field
    E_0=UNITVECTOR(E_0)

    IF(RefStates(iRefState).EQ.12)EXIT
    ! ONLY FOR CASE(14,15,16)
    ! -------------------------------------------------------------------
    ! spatial Gaussian beam, only in x,y or z direction
    ! additional tFWHM is a temporal gauss
    ! note:
    ! 14: Gaussian pulse is initialized IN the domain
    ! 15: Gaussian pulse is a boundary condition, HENCE tDelayTime is used
    WaveBasePoint =GETREALARRAY('WaveBasePoint',3,'0.5 , 0.5 , 0.')
    I_0     = GETREAL ('I_0','1.')
    sigma_t = GETREAL ('sigma_t','0.')
    tFWHM   = GETREAL ('tFWHM','0.')
    IF((sigma_t.GT.0).AND.(tFWHM.EQ.0))THEN
      tFWHM=2.*SQRT(2.*LOG(2.))*sigma_t
    ELSE IF((sigma_t.EQ.0).AND.(tFWHM.GT.0))THEN
      sigma_t=tFWHM/(2.*SQRT(2.*LOG(2.)))
    ELSE
      CALL abort(&
      __STAMP__&
      ,' Input of pulse length is wrong.')
    END IF
    ! in 15: scaling by a_0 or intensity
    Beam_a0 = GETREAL ('Beam_a0','-1.0')
    ! decide if pulse maxima is scaled by intensity or a_0 parameter
    BeamEta=2.*SQRT(mu0/eps0)
    IF(Beam_a0.LE.0.0)THEN
      Beam_a0 = 0.0
      BeamAmpFac=SQRT(BeamEta*I_0)
    ELSE
      BeamAmpFac=Beam_a0*2*PI*ElectronMass*c2/(ElectronCharge*Wavelength)
    END IF
    omega_0 = GETREAL ('omega_0','1.')
    omega_0_2inv =2.0/(omega_0**2)
    somega_0_2 =1.0/(omega_0**2)
  
    IF(ALMOSTEQUAL(ABS(WaveVector(1)),1.))THEN ! wave in x-direction
      BeamIdir1=2
      BeamIdir2=3
      BeamIdir3=1
    ELSE IF(ALMOSTEQUAL(ABS(WaveVector(2)),1.))THEN ! wave in y-direction
      BeamIdir1=1
      BeamIdir2=3
      BeamIdir3=2
    ELSE IF(ALMOSTEQUAL(ABS(WaveVector(3)),1.))THEN! wave in z-direction
      BeamIdir1=1
      BeamIdir2=2
      BeamIdir3=3
    ELSE
      CALL abort(&
      __STAMP__&
      ,'RefStates CASE(14,15,16): wave vector currently only in x,y,z!')
    END IF

    ! determine active time for time-dependent BC: save computational time for BC -> or possible switch to SM BC?
    !    SWRITE(UNIT_StdOut,'(a3,a30,a3,a33,a3,a7,a3)')' | ',TRIM(ParameterName),' | ', output,' | ',TRIM(DefMsg),' | '
    
    SELECT CASE(RefStates(iRefState))
    CASE(15,16) ! pure BC or mixed IC+BC
      IF(RefStates(iRefState).EQ.15)THEN
        tActive = 8*sigma_t
      ELSE
        SWRITE(UNIT_StdOut,'(a3,a30,a3,E33.14E3,a3,a7,a3)')' | ','tActive (old for BC=16)',&
                                                           ' | ', 3*ABS(WaveBasePoint(BeamIdir3))*c_inv,' | ','CALCUL.',' | '
        ! get xyzMinMax
        CALL GetMeshMinMaxBoundaries()
        PulseCenter = WaveBasePoint(BeamIdir3) - (xyzMinMax(2*BeamIdir3)+xyzMinMax(2*BeamIdir3-1))/2
        IF((PulseCenter*WaveVector(BeamIdir3)).LT.0.0)THEN ! wave vector and base point are pointing in opposite direction
          tActive = (3./2.)*c_inv*(ABS(PulseCenter)+ABS((xyzMinMax(2*BeamIdir3)-xyzMinMax(2*BeamIdir3-1))/2))
        ELSE
          tActive = (1./2.)*c_inv*(ABS(PulseCenter)+ABS((xyzMinMax(2*BeamIdir3)-xyzMinMax(2*BeamIdir3-1))/2))
        END IF
      END IF
      SWRITE(UNIT_StdOut,'(a3,a30,a3,E33.14E3,a3,a7,a3)')' | ','tActive (laser pulse time)',&
                                                         ' | ', tActive,' | ','CALCUL.',' | '
    END SELECT
!stop
  END SELECT
END DO

DEALLOCATE(RefStates)

BCStateFile=GETSTR('BCStateFile','no file found')
!WRITE(DefBCState,'(I3,A,I3,A,I3,A,I3,A,I3,A,I3)') &
!  IniExactFunc,',',IniExactFunc,',',IniExactFunc,',',IniExactFunc,',',IniExactFunc,',',IniExactFunc
!IF(BCType_in(1) .EQ. -999)THEN
!  BCType = GETINTARRAY('BoundaryType',6)
!ELSE
!  BCType=BCType_in
!  SWRITE(UNIT_stdOut,*)'|                   BoundaryType | -> Already read in CreateMPICart!'

!END IF
!BCState   = GETINTARRAY('BoundaryState',6,TRIM(DefBCState))
!BoundaryCondition(:,1) = BCType
!BoundaryCondition(:,2) = BCState
! Read exponent for shape function
alpha_shape = GETINT('AlphaShape','2')
rCutoff     = GETREAL('r_cutoff','1.')
! Compute factor for shape function
ShapeFuncPrefix = 1./(2. * beta(1.5, REAL(alpha_shape) + 1.) * REAL(alpha_shape) + 2. * beta(1.5, REAL(alpha_shape) + 1.)) &
                * (REAL(alpha_shape) + 1.)/(PI*(rCutoff**3))
            
EquationInitIsDone=.TRUE.
SWRITE(UNIT_stdOut,'(A)')' INIT MAXWELL DONE!'
SWRITE(UNIT_StdOut,'(132("-"))')
END SUBROUTINE InitEquation



SUBROUTINE ExactFunc(ExactFunction,t,tDeriv,x,resu) 
!===================================================================================================================================
! Specifies all the initial conditions. The state in conservative variables is returned.
!===================================================================================================================================
! MODULES
USE MOD_Globals
USE MOD_Globals_Vars,            ONLY:PI
USE MOD_Equation_Vars,           ONLY:c,c2,eps0,WaveVector,c_inv,WaveBasePoint&
                                     , sigma_t, E_0,BeamIdir1,BeamIdir2,BeamIdir3,BeamWaveNumber &
                                     ,BeamOmegaW, BeamAmpFac,TEScale,TERotation,TEPulse,TEFrequency,TEPolarization,omega_0,&
                                      TERadius,somega_0_2,xDipole,tActive,TEModeRoot
USE MOD_Equation_Vars,           ONLY:TEMode
USE MOD_TimeDisc_Vars,    ONLY: dt
! IMPLICIT VARIABLE HANDLING
IMPLICIT NONE
!-----------------------------------------------------------------------------------------------------------------------------------
! INPUT VARIABLES
REAL,INTENT(IN)                 :: t
INTEGER,INTENT(IN)              :: tDeriv           ! determines the time derivative of the function
REAL,INTENT(IN)                 :: x(3)              
INTEGER,INTENT(IN)              :: ExactFunction    ! determines the exact function
!-----------------------------------------------------------------------------------------------------------------------------------
! OUTPUT VARIABLES
REAL,INTENT(OUT)                :: Resu(PP_nVar)    ! state in conservative variables
!-----------------------------------------------------------------------------------------------------------------------------------
! LOCAL VARIABLES 
REAL                            :: Resu_t(PP_nVar),Resu_tt(PP_nVar) ! state in conservative variables
REAL                            :: Frequency,Amplitude,Omega
REAL                            :: Cent(3),r,r2,zlen
REAL                            :: a, b, d, l, m, nn, B0            ! aux. Variables for Resonator-Example
REAL                            :: gamma,Psi,GradPsiX,GradPsiY     !     -"-
REAL                            :: xrel(3), theta, Etheta          ! aux. Variables for Dipole
REAL,PARAMETER                  :: Q=1, dD=1, omegaD=6.28318E8     ! aux. Constants for Dipole
REAL                            :: cos1,sin1,b1,b2                     ! aux. Variables for Gyrotron
REAL                            :: eps,phi,z                       ! aux. Variables for Gyrotron
REAL                            :: Er,Br,Ephi,Bphi,Bz,Ez           ! aux. Variables for Gyrotron
!REAL, PARAMETER                 :: B0G=1.0,g=3236.706462           ! aux. Constants for Gyrotron
!REAL, PARAMETER                 :: k0=3562.936537,h=1489.378411    ! aux. Constants for Gyrotron
!REAL, PARAMETER                 :: omegaG=3.562936537e+3           ! aux. Constants for Gyrotron
REAL                            :: SqrtN
REAL                            :: omegaG,g,h,B0G
REAL                            :: Bess_mG_R_R_inv,r_inv
REAL                            :: Bess_mG_R,Bess_mGM_R,Bess_mGP_R,costz,sintz,sin2,cos2,costz2,sintz2,dBess_mG_R
INTEGER                         :: MG,nG
REAL                            :: spatialWindow,tShift,tShiftBC!> electromagnetic wave shaping vars
REAL                            :: timeFac,temporalWindow
!INTEGER, PARAMETER              :: mG=34,nG=19                     ! aux. Constants for Gyrotron
REAL                            :: kz
!===================================================================================================================================
Cent=x
SELECT CASE (ExactFunction)
CASE(0) ! Particles
  Resu=0.
CASE(1) ! Constant 
  Resu(1:3)=1.
  resu(4:6)=c_inv*resu(1:3)
  Resu(7:8)=0.
  Resu_t=0.
  Resu_tt=0.
CASE(2) ! Coaxial Waveguide
  Frequency=1.
  Amplitude=1.
  zlen=2.5
  r=0.5
  r2=(x(1)*x(1)+x(2)*x(2))/r
  omega=Frequency*2.*Pi/zlen ! shift beruecksichtigen
  resu   =0.
  resu(1)=( x(1))*sin(omega*(x(3)-c*t))/r2
  resu(2)=( x(2))*sin(omega*(x(3)-c*t))/r2
  resu(4)=(-x(2))*sin(omega*(x(3)-c*t))/(r2*c)
  resu(5)=( x(1))*sin(omega*(x(3)-c*t))/(r2*c) 

  Resu_t=0.
  resu_t(1)=-omega*c*( x(1))*cos(omega*(x(3)-c*t))/r2
  resu_t(2)=-omega*c*( x(2))*cos(omega*(x(3)-c*t))/r2
  resu_t(4)=-omega*c*(-x(2))*cos(omega*(x(3)-c*t))/(r2*c)
  resu_t(5)=-omega*c*( x(1))*cos(omega*(x(3)-c*t))/(r2*c) 
  Resu_tt=0.
  resu_tt(1)=-(omega*c)**2*( x(1))*sin(omega*(x(3)-c*t))/r2
  resu_tt(2)=-(omega*c)**2*( x(2))*sin(omega*(x(3)-c*t))/r2
  resu_tt(4)=-(omega*c)**2*(-x(2))*sin(omega*(x(3)-c*t))/(r2*c)
  resu_tt(5)=-(omega*c)**2*( x(1))*sin(omega*(x(3)-c*t))/(r2*c) 
CASE(3) ! Resonator
  !special initial values
  !geometric perameters
  a=1.5; b=1.0; d=3.0
  !time parameters
  l=5.; m=4.; nn=3.; B0=1.
  IF(a.eq.0)THEN
    CALL abort(&
      __STAMP__&
      ,' Parameter a of resonator is zero!')
  END IF
  IF(b.eq.0)THEN
    CALL abort(&
      __STAMP__&
      ,' Parameter b of resonator is zero!')
  END IF
  IF(d.eq.0)THEN
    CALL abort(&
      __STAMP__&
      ,' Parameter d of resonator is zero!')
  END IF
  omega = Pi*c*sqrt((m/a)**2+(nn/b)**2+(l/d)**2)
  gamma = sqrt((omega/c)**2-(l*pi/d)**2)
  IF(gamma.eq.0)THEN
    CALL abort(&
    __STAMP__&
    ,' gamma is computed to zero!')
  END IF
  Psi      =   B0          * cos((m*pi/a)*x(1)) * cos((nn*pi/b)*x(2))
  GradPsiX = -(B0*(m*pi/a) * sin((m*pi/a)*x(1)) * cos((nn*pi/b)*x(2)))
  GradPsiY = -(B0*(nn*pi/b) * cos((m*pi/a)*x(1)) * sin((nn*pi/b)*x(2)))

  resu(1)= (-omega/gamma**2) * sin((l*pi/d)*x(3)) *(-GradPsiY)* sin(omega*t)
  resu(2)= (-omega/gamma**2) * sin((l*pi/d)*x(3)) *  GradPsiX * sin(omega*t)
  resu(3)= 0.0
  resu(4)=(1/gamma**2)*(l*pi/d) * cos((l*pi/d)*x(3)) * GradPsiX * cos(omega*t)
  resu(5)=(1/gamma**2)*(l*pi/d) * cos((l*pi/d)*x(3)) * GradPsiY * cos(omega*t)
  resu(6)= Psi                  * sin((l*pi/d)*x(3))            * cos(omega*t)
  resu(7)=0.
  resu(8)=0.

CASE(4) ! Dipole
  resu(1:8) = 0.
  !RETURN
  eps=1e-10
  xrel    = x - xDipole
  r = SQRT(DOT_PRODUCT(xrel,xrel))
  IF (r.LT.eps) RETURN
  IF (xrel(3).GT.eps) THEN
    theta = ATAN(SQRT(xrel(1)**2+xrel(2)**2)/xrel(3))
  ELSE IF (xrel(3).LT.(-eps)) THEN
    theta = ATAN(SQRT(xrel(1)**2+xrel(2)**2)/xrel(3)) + pi
  ELSE
    theta = 0.5*pi
  END IF
  phi = ATAN2(xrel(2),xrel(1))
  !IF (xrel(1).GT.eps)      THEN  ! <-------------- OLD stuff, simply replaced with ATAN2() ... but not validated 
  !  phi = ATAN(xrel(2)/xrel(1))
  !ELSE IF (xrel(1).LT.eps) THEN ! THIS DIVIDES BY ZERO ?!
  !  phi = ATAN(xrel(2)/xrel(1)) + pi
  !ELSE IF (xrel(2).GT.eps) THEN
  !  phi = 0.5*pi
  !ELSE IF (xrel(2).LT.eps) THEN
  !  phi = 1.5*pi
  !ELSE
  !  phi = 0.0                                                                                     ! Vorsicht: phi ist hier undef!
  !END IF

  Er = 2.*cos(theta)*Q*dD/(4.*pi*eps0) * ( 1./r**3*sin(omegaD*t-omegaD*r/c) + (omegaD/(c*r**2)*cos(omegaD*t-omegaD*r/c) ) )
  Etheta = sin(theta)*Q*dD/(4.*pi*eps0) * ( (1./r**3-omegaD**2/(c**2*r))*sin(omegaD*t-omegaD*r/c) &
          + (omegaD/(c*r**2)*cos(omegaD*t-omegaD* r/c) ) ) 
  Bphi = 1/(c2*eps0)*omegaD*sin(theta)*Q*dD/(4.*pi) &
       * ( - omegaD/(c*r)*sin(omegaD*t-omegaD*r/c) + 1./r**2*cos(omegaD*t-omegaD*r/c) )
  IF (ABS(phi).GT.eps) THEN 
    resu(1)= sin(theta)*cos(phi)*Er + cos(theta)*cos(phi)*Etheta 
    resu(2)= sin(theta)*sin(phi)*Er + cos(theta)*sin(phi)*Etheta
    resu(3)= cos(theta)         *Er - sin(theta)         *Etheta
    resu(4)=-sin(phi)*Bphi
    resu(5)= cos(phi)*Bphi
    resu(6)= 0.0 
  ELSE
    resu(3)= cos(theta)         *Er - sin(theta)         *Etheta
  END IF
  
CASE(5) ! Initialization of TE waves in a circular waveguide
  ! Book: Springer
  ! Elektromagnetische Feldtheorie fuer Ingenieure und Physicker
  ! p. 500ff
  ! polarization: 
  ! false - linear polarization
  ! true  - cirular polarization
  r=SQRT(x(1)**2+x(2)**2)
  ! if a DOF is located in the origin, prevent division by zero ..
  phi = ATAN2(X(2),X(1))
  z=x(3)
  omegaG=2*PI*TEFrequency ! angular frequency

  ! TE_mG,nG
  mG=TEMode(1) ! azimuthal wave number
  nG=TEMode(2) ! radial wave number

  SqrtN=TEModeRoot/TERadius ! (7.412)
  ! axial wave number
  ! 1/c^2 omegaG^2 - kz^2=mu^2/ro^2
  kz=(omegaG*c_inv)**2-SqrtN**2 ! (7.413)
  IF(kz.LT.0)THEN
    SWRITE(UNIT_stdOut,'(A,E25.14E3)')'(omegaG*c_inv)**2 = ',(omegaG*c_inv)**2
    SWRITE(UNIT_stdOut,'(A,E25.14E3)')'SqrtN**2          = ',SqrtN**2
    SWRITE(UNIT_stdOut,'(A)')'  Maybe frequency too small?'
    CALL abort(&
        __STAMP__&
        ,'kz=SQRT((omegaG*c_inv)**2-SqrtN**2), but the argument in negative!')
  END IF
  kz=SQRT(kz)
  ! precompute coefficients
  Bess_mG_R  = BESSEL_JN(mG  ,r*SqrtN)
  Bess_mGM_R = BESSEL_JN(mG-1,r*SqrtN)
  Bess_mGP_R = BESSEL_JN(mG+1,r*SqrtN)
  dBess_mG_R = 0.5*(Bess_mGM_R-Bess_mGP_R)
  COSTZ      = COS(kz*z-omegaG*t)
  SINTZ      = SIN(kz*z-omegaG*t)
  sin1       = SIN(REAL(mG)*phi)
  cos1       = COS(REAL(mG)*phi)
  ! barrier for small radii
  IF(r/TERadius.LT.1e-4)THEN
    SELECT CASE(mG)
    CASE(0) ! arbitary
      Bess_mG_R_R_inv=1e6
    CASE(1)
      Bess_mG_R_R_inv=0.5
    CASE DEFAULT
      Bess_mG_R_R_inv=0.
    END SELECT
  ELSE
    r_inv=1./r
    Bess_mG_R_R_inv=Bess_mG_R*r_inv
  END IF
  IF(.NOT.TEPolarization)THEN ! no polarization, e.g. linear polarization along the a-axis
    ! electric field
    Er   =  omegaG*REAL(mG)* Bess_mG_R_R_inv*sin1*SINTZ
    Ephi =  omegaG*SqrtN*dBess_mG_R*cos1*SINTZ
    Ez   =  0.
    ! magnetic field
    Br   = -kz*SqrtN*dBess_mG_R*cos1*SINTZ
    Bphi =  kz*REAL(mG)*Bess_mG_R_R_inv*sin1*SINTZ
    Bz   =  (SqrtN**2)*Bess_mG_R*cos1*COSTZ
  ELSE ! cirular polarization
    ! polarisation if superposition of two fields
    ! circular polarisation requires an additional temporal shift
    ! a) perpendicular shift of TE mode, rotation of 90 degree
    sin2       = SIN(REAL(mG)*phi+0.5*PI)
    cos2       = COS(REAL(mG)*phi+0.5*PI)
    IF(TERotation.EQ.1)THEN ! shift for left or right rotating fields
      COSTZ2     = COS(kz*z-omegaG*t-0.5*PI)
      SINTZ2     = SIN(kz*z-omegaG*t-0.5*PI)
    ELSE
      COSTZ2     = COS(kz*z-omegaG*t+0.5*PI)
      SINTZ2     = SIN(kz*z-omegaG*t+0.5*PI)
    END IF
    ! electric field
    Er   =  omegaG*REAL(mG)* Bess_mG_R_R_inv*(sin1*SINTZ+sin2*SINTZ2)
    Ephi =  omegaG*SqrtN*dBess_mG_R*(cos1*SINTZ+cos2*SINTZ2)
    Ez   =  0.
    ! magnetic field
    Br   = -kz*SqrtN*dBess_mG_R*(cos1*SINTZ+cos2*SINTZ2)
    Bphi =  kz*REAL(mG)*Bess_mG_R_R_inv*(sin1*SINTZ+sin2*SINTZ2)
    ! caution: does we have to modify the z entry? yes
    Bz   =  (SqrtN**2)*Bess_mG_R*(cos1*COSTZ+cos2*COSTZ2)
  END IF

  resu(1)= COS(phi)*Er - SIN(phi)*Ephi
  resu(2)= SIN(phi)*Er + COS(phi)*Ephi
  resu(3)= 0.0
  resu(4)= COS(phi)*Br - SIN(phi)*Bphi
  resu(5)= SIN(phi)*Br + COS(phi)*Bphi
  resu(6)= Bz
  resu(1:5)=resu(1:5)
  resu( 6 )=resu( 6 )
  resu(1:6)=TEScale*resu(1:6)
  resu(7)= 0.0
  resu(8)= 0.0
  IF(TEPulse)THEN
    sigma_t=4.*(2.*PI)/omegaG/(2.*SQRT(2.*LOG(2.)))
    tShift=t-4.*sigma_t
    temporalWindow=EXP(-0.5*(tshift/sigma_t)**2)
    IF (t.LE.34*sigma_t) THEN
      resu(1:8)=resu(1:8)*temporalWindow
    ELSE
      resu(1:8)=0.
    END IF
  END IF

CASE(7) ! Manufactured Solution
  resu(:)=0
  resu(1)=SIN(2*pi*(x(1)-t))
  resu_t(:)=0
  resu_t(1)=-2*pi*COS(2*pi*(x(1)-t))
  resu_tt(:)=0
  resu_tt(1)=-4*pi*pi*resu(1)

CASE(10) !issautier 3D test case with source (Stock et al., divcorr paper), domain [0;1]^3!!!
  resu(:)=0.
  resu(1)=x(1)*SIN(Pi*x(2))*SIN(Pi*x(3)) !*SIN(t)
  resu(2)=x(2)*SIN(Pi*x(3))*SIN(Pi*x(1)) !*SIN(t)
  resu(3)=x(3)*SIN(Pi*x(1))*SIN(Pi*x(2)) !*SIN(t)
  resu(4)=pi*SIN(Pi*x(1))*(x(3)*COS(Pi*x(2))-x(2)*COS(Pi*x(3))) !*(COS(t)-1)
  resu(5)=pi*SIN(Pi*x(2))*(x(1)*COS(Pi*x(3))-x(3)*COS(Pi*x(1))) !*(COS(t)-1)
  resu(6)=pi*SIN(Pi*x(3))*(x(2)*COS(Pi*x(1))-x(1)*COS(Pi*x(2))) !*(COS(t)-1)

  resu_t(:)=0.
  resu_t(1)= COS(t)*resu(1)
  resu_t(2)= COS(t)*resu(2)
  resu_t(3)= COS(t)*resu(3)
  resu_t(4)=-SIN(t)*resu(4)
  resu_t(5)=-SIN(t)*resu(5)
  resu_t(6)=-SIN(t)*resu(6)
  resu_tt=0.
  resu_tt(1)=-SIN(t)*resu(1)
  resu_tt(2)=-SIN(t)*resu(2)
  resu_tt(3)=-SIN(t)*resu(3)
  resu_tt(4)=-COS(t)*resu(4)
  resu_tt(5)=-COS(t)*resu(5)
  resu_tt(6)=-COS(t)*resu(6)

  resu(1)=     SIN(t)*resu(1)
  resu(2)=     SIN(t)*resu(2)
  resu(3)=     SIN(t)*resu(3)
  resu(4)=(COS(t)-1.)*resu(4)
  resu(5)=(COS(t)-1.)*resu(5)
  resu(6)=(COS(t)-1.)*resu(6)

CASE(12) ! planar wave test case
  resu(1:3)=E_0*cos(BeamWaveNumber*DOT_PRODUCT(WaveVector,x)-BeamOmegaW*t)
  resu(4:6)=c_inv*CROSS(WaveVector,resu(1:3))
  resu(7:8)=0.

CASE(14) ! 1 of 3: Gauss-shape with perfect focus (w(z)=w_0): initial condition (IC)
         ! spatial gauss beam, still planar wave scaled by intensity spatial and temporal filer are defined according to 
         ! Thiele 2016: "Modelling laser matter interaction with tightly focused laser pules in electromagnetic codes"
         ! beam insert is done by a paraxial assumption focus is at basepoint
         ! intensity * Gaussian filter in transversal and longitudinal direction
  spatialWindow = EXP(    -((x(BeamIdir1)-WaveBasePoint(BeamIdir1))**2+                        & ! <------ NEW formulation 
                            (x(BeamIdir2)-WaveBasePoint(BeamIdir2))**2)/((  omega_0  )**2)     & ! <------ NEW formulation 
                          -((x(BeamIdir3)-WaveBasePoint(BeamIdir3))**2)/((2*sigma_t*c)**2)  )    ! <------ NEW formulation 
  !spatialWindow = EXP(    -0.5*((x(BeamIdir1)-WaveBasePoint(BeamIdir1))**2+                  &
                            !(x(BeamIdir2)-WaveBasePoint(BeamIdir2))**2)*omega_0_2inv     &
                       !-0.25*(x(BeamIdir3)-WaveBasePoint(BeamIdir3))**2/((sigma_t*c)**2)  )
  ! build final coefficients
  timeFac=COS(BeamWaveNumber*DOT_PRODUCT(WaveVector,x-WaveBasePoint)-BeamOmegaW*(t-ABS(WaveBasePoint(BeamIdir3))/c))
  resu(1:3)=BeamAmpFac*spatialWindow*E_0*timeFac
  resu(4:6)=c_inv*CROSS( WaveVector,resu(1:3)) 
  resu(7:8)=0.
CASE(15) ! 2 of 3: Gauß-shape with perfect focus (w(z)=w_0): boundary condition (BC)
         ! spatial gauss beam, still planar wave scaled by intensity spatial and temporal filer are defined according to 
         ! Thiele 2016: "Modelling laser matter interaction with tightly focused laser pules in electromagnetic codes"
         ! beam insert is done by a paraxial assumption focus is at basepoint and should be on BC
  !IF (t.GT.8*sigma_t) THEN ! pulse has passesd -> return 
  IF(t.GT.tActive)THEN ! pulse has passesd -> return
    resu(1:8)=0.
  ELSE
    tShift=t-4*sigma_t
    ! intensity * Gaussian filter in transversal and longitudinal direction
    spatialWindow = EXP(-((x(BeamIdir1)-WaveBasePoint(BeamIdir1))**2+&                                   ! <------ NEW formulation
                          (x(BeamIdir2)-WaveBasePoint(BeamIdir2))**2)*somega_0_2) ! (x^2+y^2)/(w_0^2)    ! <------ NEW formulation
    !spatialWindow = EXP(-((x(BeamIdir1)-WaveBasePoint(BeamIdir1))**2+&               ! <------- OLD formulation
                          !(x(BeamIdir2)-WaveBasePoint(BeamIdir2))**2)*omega_0_2inv)  ! <------- OLD formulation
    ! build final coefficients
    !WaveBasePoint(BeamIdir3)=0.  ! was set to zero, why?
    ! pulse displacement is arbitrarily set to 4 (no beam initially in domain)
    timeFac =COS(BeamWaveNumber*DOT_PRODUCT(WaveVector,x-WaveBasePoint)-BeamOmegaW*tShift)
    ! temporal window
    !temporalWindow=EXP(-(tShift/sigma_t)**2)     ! <------ NEW formulation
    temporalWindow=EXP(-0.25*(tShift/sigma_t)**2) ! <------ NEW formulation: test #3
    !temporalWindow=EXP(-0.5*(tShift/sigma_t)**2) ! <------- OLD formulation
    resu(1:3)=BeamAmpFac*spatialWindow*E_0*timeFac*temporalWindow
    resu(4:6)=c_inv*CROSS( WaveVector,resu(1:3)) 
    resu(7:8)=0.
  END IF
CASE(16) ! 3 of 3: Gauß-shape with perfect focus (w(z)=w_0): initial & boundary condition (BC)
         ! spatial gauss beam, still planar wave scaled by intensity spatial and temporal filer are defined according to 
         ! Thiele 2016: "Modelling laser matter interaction with tightly focused laser pules in electromagnetic codes"
         ! beam insert is done by a paraxial assumption focus is at basepoint and should be on BC
  !IF(t.GT.3*ABS(WaveBasePoint(BeamIdir3))/c)THEN ! pulse has passesd -> return 
  IF(t.GT.tActive)THEN ! pulse has passesd -> return
    resu(1:8)=0.
  ELSE
    ! IC (t=0) or BC (t>0)
    tShift=t-ABS(WaveBasePoint(BeamIdir3))/c ! substitution: shift to wave base point position
    IF(t.LT.dt)THEN ! initial condiction: IC
      spatialWindow = EXP(    -((x(BeamIdir1)-WaveBasePoint(BeamIdir1))**2+                      & ! <------ NEW formulation 
                                (x(BeamIdir2)-WaveBasePoint(BeamIdir2))**2)/((  omega_0  )**2)   & ! <------ NEW formulation 
                              -((x(BeamIdir3)-WaveBasePoint(BeamIdir3))**2)/((2*sigma_t*c)**2)  )  ! <------ NEW formulation 
      !spatialWindow = EXP(    -((x(BeamIdir1)-WaveBasePoint(BeamIdir1))**2+                  & <------- OLD formulation
      !                          (x(BeamIdir2)-WaveBasePoint(BeamIdir2))**2)*omega_0_2inv     & <------- OLD formulation
      !                     -0.5*(x(BeamIdir3)-WaveBasePoint(BeamIdir3))**2/((sigma_t*c)**2)  ) <------- OLD formulation
      timeFac=COS(BeamWaveNumber*DOT_PRODUCT(WaveVector,x-WaveBasePoint)-BeamOmegaW*tShift)
      resu(1:3)=BeamAmpFac*spatialWindow*E_0*timeFac
    ELSE ! boundary condiction: BC
      tShiftBC=t+(WaveBasePoint(BeamIdir3)-x(3))/c ! shift to wave base point position
      ! intensity * Gaussian filter in transversal and longitudinal direction
    spatialWindow = EXP(-((x(BeamIdir1)-WaveBasePoint(BeamIdir1))**2+&                                   ! <------ NEW formulation
                          (x(BeamIdir2)-WaveBasePoint(BeamIdir2))**2)*somega_0_2) ! (x^2+y^2)/(w_0^2)    ! <------ NEW formulation
     !spatialWindow = EXP(-((x(BeamIdir1)-WaveBasePoint(BeamIdir1))**2+&               ! <------- OLD formulation
                           !(x(BeamIdir2)-WaveBasePoint(BeamIdir2))**2)*omega_0_2inv)  ! <------- OLD formulation
     !spatialWindow = EXP(-((x(BeamIdir1)-WaveBasePoint(BeamIdir1))**2+&
                           !(x(BeamIdir2)-WaveBasePoint(BeamIdir2))**2)*omega_0_2inv)
      timeFac =COS(BeamWaveNumber*DOT_PRODUCT(WaveVector,x-WaveBasePoint)-BeamOmegaW*tShift)
      temporalWindow=EXP(-0.25*(tShiftBC/sigma_t)**2) ! <------ NEW formulation: test #3
     !temporalWindow=EXP( -0.5*(tShiftBC/sigma_t)**2) ! <------- OLD formulation
      resu(1:3)=BeamAmpFac*spatialWindow*E_0*timeFac*temporalWindow
    END IF
    resu(4:6)=c_inv*CROSS(WaveVector,resu(1:3)) 
    resu(7:8)=0.
  END IF
CASE(50,51)            ! Initialization and BC Gyrotron - including derivatives
  eps=1e-10
  mG =34
  IF ((ExactFunction.EQ.51).AND.(x(3).GT.eps)) RETURN
  r=SQRT(x(1)**2+x(2)**2)
  phi = ATAN2(x(2),x(1))
 !    IF (x(1).GT.eps)      THEN ! <-------------- OLD stuff, simply replaced with ATAN2() ... but not validated
 !      phi = ATAN(x(2)/x(1))
 !    ELSE IF (x(1).LT.(-eps)) THEN
 !      phi = ATAN(x(2)/x(1)) + pi
 !    ELSE IF (x(2).GT.eps) THEN
 !      phi = 0.5*pi
 !    ELSE IF (x(2).LT.(-eps)) THEN
 !      phi = 1.5*pi
 !    ELSE
 !      phi = 0.0         ! Vorsicht: phi ist hier undef!
 !    END IF
  z = x(3)
  a = h*z+mG*phi
  b0 = BESSEL_JN(mG,REAL(g*r))
  b1 = BESSEL_JN(mG-1,REAL(g*r))
  b2 = BESSEL_JN(mG+1,REAL(g*r))
  SELECT CASE(MOD(tDeriv,4))
    CASE(0)
      cos1  =  omegaG**tDeriv * cos(a-omegaG*t)
      sin1  =  omegaG**tDeriv * sin(a-omegaG*t)
    CASE(1)
      cos1  =  omegaG**tDeriv * sin(a-omegaG*t)
      sin1  = -omegaG**tDeriv * cos(a-omegaG*t)
    CASE(2)
      cos1  = -omegaG**tDeriv * cos(a-omegaG*t)
      sin1  = -omegaG**tDeriv * sin(a-omegaG*t)
    CASE(3)
      cos1  = -omegaG**tDeriv * sin(a-omegaG*t)
      sin1  =  omegaG**tDeriv * cos(a-omegaG*t)
    CASE DEFAULT
      cos1  = 0.0
      sin1  = 0.0
      CALL abort(&
          __STAMP__&
          ,'What is that weired tDeriv you gave me?',999,999.)
  END SELECT

  Er  =-B0G*mG*omegaG/(r*g**2)*b0     *cos1
  Ephi= B0G*omegaG/h      *0.5*(b1-b2)*sin1
  Br  =-B0G*h/g           *0.5*(b1-b2)*sin1
  Bphi=-B0G*mG*h/(r*g**2)     *b0     *cos1
  Bz  = B0G                   *b0     *cos1
  resu(1)= cos(phi)*Er - sin(phi)*Ephi
  resu(2)= sin(phi)*Er + cos(phi)*Ephi
  resu(3)= 0.0
  resu(4)= cos(phi)*Br - sin(phi)*Bphi
  resu(5)= sin(phi)*Br + cos(phi)*Bphi
  resu(6)= Bz
  resu(7)= 0.0
  resu(8)= 0.0

CASE(41) ! pulsed Dipole
  resu = 0.0
  RETURN
CASE(100) ! QDS
  resu = 0.0
  RETURN
CASE DEFAULT
  SWRITE(*,*)'Exact function not specified. ExactFunction = ',ExactFunction
END SELECT ! ExactFunction

# if (PP_TimeDiscMethod==1)
! For O3 RK, the boundary condition has to be adjusted
! Works only for O3 RK!!
SELECT CASE(tDeriv)
CASE(0)
  ! resu = g(t)
CASE(1)
  ! resu = g(t) + dt/3*g'(t)
  Resu=Resu + dt/3.*Resu_t
CASE(2)
  ! resu = g(t) + 3/4 dt g'(t) +5/16 dt^2 g''(t)
  Resu=Resu + 0.75*dt*Resu_t+5./16.*dt*dt*Resu_tt
CASE DEFAULT
  ! Stop, works only for 3 Stage O3 LS RK
  CALL abort(&
      __STAMP__&
      ,'Exactfuntion works only for 3 Stage O3 LS RK!',999,999.)
END SELECT
#endif
END SUBROUTINE ExactFunc


SUBROUTINE CalcSource(t,coeff,Ut)
!===================================================================================================================================
! Specifies all the initial conditions. The state in conservative variables is returned.
!===================================================================================================================================
! MODULES
USE MOD_Globals,           ONLY: abort
USE MOD_Globals_Vars,      ONLY: PI
USE MOD_PreProc
USE MOD_Equation_Vars,     ONLY: eps0,c_corr,IniExactFunc, DipoleOmega,tPulse,xDipole
#ifdef PARTICLES
USE MOD_PICDepo_Vars,      ONLY: PartSource,DoDeposition
USE MOD_Dielectric_Vars,   ONLY: DoDielectric,isDielectricElem,ElemToDielectric,DielectricEps,ElemToDielectric!DielectricEpsR_inv
#if IMPA
USE MOD_LinearSolver_Vars, ONLY:ExplicitPartSource
#endif
#endif /*PARTICLES*/
USE MOD_Mesh_Vars,         ONLY: Elem_xGP                  ! for shape function: xyz position of the Gauss points
#if defined(LSERK) || defined(IMPA) || defined(ROS)
USE MOD_Equation_Vars,     ONLY: DoParabolicDamping,fDamping
USE MOD_TimeDisc_Vars,     ONLY: sdtCFLOne!, RK_B, iStage  
USE MOD_DG_Vars,           ONLY: U
#endif /*LSERK*/
! IMPLICIT VARIABLE HANDLING
IMPLICIT NONE
!-----------------------------------------------------------------------------------------------------------------------------------
! INPUT VARIABLES
REAL,INTENT(IN)                 :: t,coeff
!-----------------------------------------------------------------------------------------------------------------------------------
! OUTPUT VARIABLES
REAL,INTENT(INOUT)              :: Ut(1:PP_nVar,0:PP_N,0:PP_N,0:PP_N,1:PP_nElems)
!-----------------------------------------------------------------------------------------------------------------------------------
! LOCAL VARIABLES 
INTEGER                         :: i,j,k,iElem
REAL                            :: eps0inv, x(1:3)
REAL                            :: r                                                 ! for Dipole
REAL,PARAMETER                  :: Q=1, d=1    ! for Dipole
#ifdef PARTICLES
REAL                            :: PartSourceLoc(1:4)
#endif
!===================================================================================================================================
eps0inv = 1./eps0
#ifdef PARTICLES
IF(DoDeposition)THEN
  IF(DoDielectric)THEN
    DO iElem=1,PP_nElems
      IF(isDielectricElem(iElem)) THEN ! 1.) PML version - PML element
        DO k=0,PP_N; DO j=0,PP_N; DO i=0,PP_N 
#if IMPA
          PartSourceLoc=PartSource(:,i,j,k,iElem)+ExplicitPartSource(:,i,j,k,iElem)
#else
          PartSourceLoc=PartSource(:,i,j,k,iElem)
#endif
          !  Get PartSource from Particles
          !Ut(1:3,i,j,k,iElem) = Ut(1:3,i,j,k,iElem) - eps0inv *coeff* PartSource(1:3,i,j,k,iElem) * DielectricEpsR_inv
          !Ut(  8,i,j,k,iElem) = Ut(  8,i,j,k,iElem) + eps0inv *coeff* PartSource(  4,i,j,k,iElem) * c_corr * DielectricEpsR_inv
          Ut(1:3,i,j,k,iElem) = Ut(1:3,i,j,k,iElem) - eps0inv *coeff* PartSourceloc(1:3) &
                                                      / DielectricEps(i,j,k,ElemToDielectric(iElem)) ! only use x
          Ut(  8,i,j,k,iElem) = Ut(  8,i,j,k,iElem) + eps0inv *coeff* PartSourceloc( 4 ) * c_corr &
                                                      / DielectricEps(i,j,k,ElemToDielectric(iElem)) ! only use x
        END DO; END DO; END DO
      ELSE
        DO k=0,PP_N; DO j=0,PP_N; DO i=0,PP_N 
#if IMPA
          PartSourceLoc=PartSource(:,i,j,k,iElem)+ExplicitPartSource(:,i,j,k,iElem)
#else
          PartSourceLoc=PartSource(:,i,j,k,iElem)
#endif
          !  Get PartSource from Particles
          Ut(1:3,i,j,k,iElem) = Ut(1:3,i,j,k,iElem) - eps0inv *coeff* PartSourceloc(1:3)
          Ut(  8,i,j,k,iElem) = Ut(  8,i,j,k,iElem) + eps0inv *coeff* PartSourceloc( 4 ) * c_corr 
        END DO; END DO; END DO
      END IF
    END DO
  ELSE
    DO iElem=1,PP_nElems
      DO k=0,PP_N; DO j=0,PP_N; DO i=0,PP_N 
#if IMPA
        PartSourceLoc=PartSource(:,i,j,k,iElem)+ExplicitPartSource(:,i,j,k,iElem)
#else
        PartSourceLoc=PartSource(:,i,j,k,iElem)
#endif
        !  Get PartSource from Particles
        Ut(1:3,i,j,k,iElem) = Ut(1:3,i,j,k,iElem) - eps0inv *coeff* PartSourceloc(1:3)
        Ut(  8,i,j,k,iElem) = Ut(  8,i,j,k,iElem) + eps0inv *coeff* PartSourceloc( 4 ) * c_corr 
      END DO; END DO; END DO
    END DO
  END IF
END IF
#endif /*PARTICLES*/
SELECT CASE (IniExactFunc)
CASE(0) ! Particles
  ! empty, nothing to do
CASE(1) ! Constant          - no sources
CASE(2) ! Coaxial Waveguide - no sources
CASE(3) ! Resonator         - no sources
CASE(4) ! Dipole
  DO iElem=1,PP_nElems
    DO k=0,PP_N; DO j=0,PP_N; DO i=0,PP_N 
      r = SQRT(DOT_PRODUCT(Elem_xGP(:,i,j,k,iElem)-xDipole,Elem_xGP(:,i,j,k,iElem)-xDipole))
      IF (shapefunc(r) .GT. 0 ) THEN
        Ut(3,i,j,k,iElem) = Ut(3,i,j,k,iElem) - (shapefunc(r)) *coeff* Q*d*DipoleOmega * COS(DipoleOmega*t) * eps0inv
    ! dipole should be neutral
        Ut(8,i,j,k,iElem) = Ut(8,i,j,k,iElem) + (shapefunc(r)) *coeff* c_corr*Q*d*SIN(DipoleOmega*t) * eps0inv
      END IF
    END DO; END DO; END DO
  END DO
CASE(5) ! TE_34,19 Mode     - no sources
CASE(7) ! Manufactured Solution
  DO iElem=1,PP_nElems
    DO k=0,PP_N; DO j=0,PP_N; DO i=0,PP_N 
      Ut(1,i,j,k,iElem) =Ut(1,i,j,k,iElem) - coeff*2*pi*COS(2*pi*(Elem_xGP(1,i,j,k,iElem)-t)) * eps0inv
      Ut(8,i,j,k,iElem) =Ut(8,i,j,k,iElem) + coeff*2*pi*COS(2*pi*(Elem_xGP(1,i,j,k,iElem)-t)) * c_corr * eps0inv
    END DO; END DO; END DO
  END DO
CASE(10) !issautier 3D test case with source (Stock et al., divcorr paper), domain [0;1]^3!!!
  DO iElem=1,PP_nElems
    DO k=0,PP_N; DO j=0,PP_N; DO i=0,PP_N  
      x(:)=Elem_xGP(:,i,j,k,iElem)
      Ut(1,i,j,k,iElem) =Ut(1,i,j,k,iElem) + coeff*(COS(t)- (COS(t)-1.)*2*pi*pi)*x(1)*SIN(Pi*x(2))*SIN(Pi*x(3))
      Ut(2,i,j,k,iElem) =Ut(2,i,j,k,iElem) + coeff*(COS(t)- (COS(t)-1.)*2*pi*pi)*x(2)*SIN(Pi*x(3))*SIN(Pi*x(1))
      Ut(3,i,j,k,iElem) =Ut(3,i,j,k,iElem) + coeff*(COS(t)- (COS(t)-1.)*2*pi*pi)*x(3)*SIN(Pi*x(1))*SIN(Pi*x(2))
      Ut(1,i,j,k,iElem) =Ut(1,i,j,k,iElem) - coeff*(COS(t)-1.)*pi*COS(Pi*x(1))*(SIN(Pi*x(2))+SIN(Pi*x(3)))
      Ut(2,i,j,k,iElem) =Ut(2,i,j,k,iElem) - coeff*(COS(t)-1.)*pi*COS(Pi*x(2))*(SIN(Pi*x(3))+SIN(Pi*x(1)))
      Ut(3,i,j,k,iElem) =Ut(3,i,j,k,iElem) - coeff*(COS(t)-1.)*pi*COS(Pi*x(3))*(SIN(Pi*x(1))+SIN(Pi*x(2)))
      Ut(8,i,j,k,iElem) =Ut(8,i,j,k,iElem) + coeff*c_corr*SIN(t)*( SIN(pi*x(2))*SIN(pi*x(3)) &
                                                            +SIN(pi*x(3))*SIN(pi*x(1)) &
                                                            +SIN(pi*x(1))*SIN(pi*x(2)) )
    END DO; END DO; END DO
  END DO

CASE(12) ! plane wave
CASE(14) ! gauss pulse, spatial -> IC
CASE(15) ! gauss pulse, temporal -> BC
CASE(16) ! gauss pulse, temporal -> IC+BC

CASE(41) ! Dipole via temporal Gausspuls
!t0=TEnd/5, w=t0/4 ! for pulsed Dipole (t0=offset and w=width of pulse)
!TEnd=30.E-9 -> short pulse for 100ns runtime
IF(1.EQ.2)THEN ! new formulation with divergence correction considered
  DO iElem=1,PP_nElems
    DO k=0,PP_N; DO j=0,PP_N; DO i=0,PP_N 
      Ut(1,i,j,k,iElem) =Ut(1,i,j,k,iElem) - coeff*2*pi*COS(2*pi*(Elem_xGP(1,i,j,k,iElem)-t)) * eps0inv
      Ut(8,i,j,k,iElem) =Ut(8,i,j,k,iElem) + coeff*2*pi*COS(2*pi*(Elem_xGP(1,i,j,k,iElem)-t)) * c_corr * eps0inv
    END DO; END DO; END DO
  END DO
ELSE ! old/original formulation
  DO iElem=1,PP_nElems; DO k=0,PP_N; DO j=0,PP_N; DO i=0,PP_N 
    IF (t.LE.2*tPulse) THEN
      r = SQRT(DOT_PRODUCT(Elem_xGP(:,i,j,k,iElem)-xDipole,Elem_xGP(:,i,j,k,iElem)-xDipole))
      IF (shapefunc(r) .GT. 0 ) THEN
        Ut(3,i,j,k,iElem) = Ut(3,i,j,k,iElem) - ((shapefunc(r))*Q*d*COS(DipoleOmega*t)*eps0inv)*&
                            EXP(-(t-tPulse/5)**2/(2*(tPulse/(4*5))**2))
      END IF
    END IF
  END DO; END DO; END DO; END DO
END IF
CASE(50,51) ! TE_34,19 Mode - no sources
CASE DEFAULT
  CALL abort(&
      __STAMP__&
      ,'Exactfunction not specified! IniExactFunc = ',IntInfoOpt=IniExactFunc)
END SELECT ! ExactFunction

#if defined(LSERK) ||  defined(ROS) || defined(IMPA)
IF(DoParabolicDamping)THEN
  !Ut(7:8,:,:,:,:) = Ut(7:8,:,:,:,:) - (1.0-fDamping)*sdtCFLOne/RK_b(iStage)*U(7:8,:,:,:,:)
  Ut(7:8,:,:,:,:) = Ut(7:8,:,:,:,:) - (1.0-fDamping)*sdtCFLOne*U(7:8,:,:,:,:)
END IF
#endif /*LSERK*/

!source fo divcorr damping!
!Ut(7:8,:,:,:,:)=Ut(7:8,:,:,:,:)-(c_corr*scr)*U(7:8,:,:,:,:)
END SUBROUTINE CalcSource


SUBROUTINE DivCleaningDamping()
!===================================================================================================================================
! Specifies all the initial conditions. The state in conservative variables is returned.
!===================================================================================================================================
! MODULES
USE MOD_Globals
USE MOD_PreProc
USE MOD_DG_Vars,       ONLY : U
USE MOD_Equation_Vars, ONLY : fDamping,DoParabolicDamping
! IMPLICIT VARIABLE HANDLING
IMPLICIT NONE
!-----------------------------------------------------------------------------------------------------------------------------------
! INPUT VARIABLES
!-----------------------------------------------------------------------------------------------------------------------------------
! OUTPUT VARIABLES
!-----------------------------------------------------------------------------------------------------------------------------------
! LOCAL VARIABLES 
INTEGER                         :: i,j,k,iElem
!===================================================================================================================================
IF(DoParabolicDamping) RETURN
DO iElem=1,PP_nElems
  DO k=0,PP_N; DO j=0,PP_N; DO i=0,PP_N 
    !  Get source from Particles
    U(7:8,i,j,k,iElem) = U(7:8,i,j,k,iElem) * fDamping
  END DO; END DO; END DO
END DO
END SUBROUTINE DivCleaningDamping

FUNCTION shapefunc(r)
!===================================================================================================================================
! Implementation of (possibly several different) shapefunctions 
!===================================================================================================================================
! MODULES
  USE MOD_Equation_Vars, ONLY : shapeFuncPrefix, alpha_shape, rCutoff
! IMPLICIT VARIABLE HANDLING
    IMPLICIT NONE
!-----------------------------------------------------------------------------------------------------------------------------------
! INPUT VARIABLES
    REAL                 :: r         ! radius / distance to center
!-----------------------------------------------------------------------------------------------------------------------------------
! OUTPUT VARIABLES
    REAL                 :: shapefunc ! sort of a weight for the source
!-----------------------------------------------------------------------------------------------------------------------------------
! LOCAL VARIABLES 
!===================================================================================================================================
   IF (r.GE.rCutoff) THEN
     shapefunc = 0.0
   ELSE
     shapefunc = ShapeFuncPrefix *(1-(r/rCutoff)**2)**alpha_shape
   END IF
END FUNCTION shapefunc

FUNCTION beta(z,w)                                                                                                
   IMPLICIT NONE
   REAL beta, w, z                                                                                                  
   beta = GAMMA(z)*GAMMA(w)/GAMMA(z+w)                                                                    
END FUNCTION beta 


SUBROUTINE GetWaveGuideRadius(DoSide) 
!===================================================================================================================================
! routine to find the maximum radius of a  wave-guide at a given BC plane
! radius computation requires interpolation points on the surface, hence
! an additional change-basis is required to map Gauss to Gauss-Lobatto points 
!===================================================================================================================================
! MODULES                                                                                                                          !
!----------------------------------------------------------------------------------------------------------------------------------!
USE MOD_Globals
USE MOD_PreProc
USE MOD_Mesh_Vars    ,  ONLY:nSides,Face_xGP
USE MOD_Equation_Vars,  ONLY:TERadius
#if (PP_NodeType==1)
USE MOD_ChangeBasis,    ONLY:ChangeBasis2D
USE MOD_Basis,          ONLY:LegGaussLobNodesAndWeights
USE MOD_Basis,          ONLY:BarycentricWeights,InitializeVandermonde
USE MOD_Interpolation_Vars, ONLY:xGP,wBary
#endif
!----------------------------------------------------------------------------------------------------------------------------------!
! IMPLICIT VARIABLE HANDLING
IMPLICIT NONE
! INPUT VARIABLES 
LOGICAL,INTENT(IN)      :: DoSide(1:nSides)
!----------------------------------------------------------------------------------------------------------------------------------!
! OUTPUT VARIABLES
!-----------------------------------------------------------------------------------------------------------------------------------
! LOCAL VARIABLES
REAL                    :: Radius
INTEGER                 :: iSide,p,q
#if (PP_NodeType==1)
REAL                    :: xGP_tmp(0:PP_N),wBary_tmp(0:PP_N),wGP_tmp(0:PP_N)
REAL                    :: Vdm_PolN_GL(0:PP_N,0:PP_N)
#endif
REAL                    :: Face_xGL(1:2,0:PP_N,0:PP_N)
!===================================================================================================================================

#if (PP_NodeType==1)
! get Vandermonde, change from Gauss or Gauss-Lobatto Points to Gauss-Lobatto-Points
! radius requires GL-points
CALL LegGaussLobNodesAndWeights(PP_N,xGP_tmp,wGP_tmp)
CALL BarycentricWeights(PP_N,xGP_tmp,wBary_tmp)
!CALL InitializeVandermonde(PP_N,PP_N,wBary_tmp,xGP,xGP_tmp,Vdm_PolN_GL)
CALL InitializeVandermonde(PP_N,PP_N,wBary,xGP,xGP_tmp,Vdm_PolN_GL)
#endif

TERadius=0.
Radius   =0.
DO iSide=1,nSides
  IF(.NOT.DoSide(iSide)) CYCLE
#if (PP_NodeType==1)
  CALL ChangeBasis2D(2,PP_N,PP_N,Vdm_PolN_GL,Face_xGP(1:2,:,:,iSide),Face_xGL)
#else
  Face_xGL(1:2,:,:)=Face_xGP(1:2,:,:,iSide)
#endif
  DO q=0,PP_N
    DO p=0,PP_N
      Radius=SQRT(Face_xGL(1,p,q)**2+Face_xGL(2,p,q)**2)
      TERadius=MAX(Radius,TERadius)
    END DO ! p
  END DO ! q
END DO

#ifdef MPI
CALL MPI_ALLREDUCE(MPI_IN_PLACE,TERadius,1,MPI_DOUBLE_PRECISION,MPI_MAX,MPI_COMM_WORLD,iError)
#endif /*MPI*/

SWRITE(UNIT_StdOut,*) ' Found waveguide radius of ', TERadius

END SUBROUTINE GetWaveGuideRadius


SUBROUTINE InitExactFlux()
!===================================================================================================================================
! Get the constant advection velocity vector from the ini file 
!===================================================================================================================================
! MODULES
USE MOD_PreProc
USE MOD_Globals,         ONLY:abort,UNIT_stdOut,mpiroot,iError
#ifdef MPI
USE MOD_Globals,         ONLY:MPI_COMM_WORLD,MPI_SUM,MPI_INTEGER
#endif
USE MOD_Mesh_Vars,       ONLY:nElems,ElemToSide,SideToElem,lastMPISide_MINE
USE MOD_Interfaces,      ONLY:FindElementInRegion,FindInterfacesInRegion,CountAndCreateMappings
USE MOD_Equation_Vars,   ONLY:ExactFluxDir,ExactFluxPosition,isExactFluxInterFace
USE MOD_ReadInTools,     ONLY:GETREAL,GETINT
! IMPLICIT VARIABLE HANDLING
 IMPLICIT NONE
!-----------------------------------------------------------------------------------------------------------------------------------
! INPUT VARIABLES
!-----------------------------------------------------------------------------------------------------------------------------------
! OUTPUT VARIABLES
!-----------------------------------------------------------------------------------------------------------------------------------
! LOCAL VARIABLES
LOGICAL,ALLOCATABLE :: isExactFluxElem(:)     ! true if iElem is an element located within the ExactFlux region
LOGICAL,ALLOCATABLE :: isExactFluxFace(:)     ! true if iFace is a Face located wihtin or on the boarder (interface) of the
!                                             ! ExactFlux region
INTEGER,ALLOCATABLE :: ExactFluxToElem(:),ExactFluxToFace(:),ExactFluxInterToFace(:) ! mapping to total element/face list
INTEGER,ALLOCATABLE :: ElemToExactFlux(:),FaceToExactFlux(:),FaceToExactFluxInter(:) ! mapping to ExactFlux element/face list
REAL                :: InterFaceRegion(6)
INTEGER             :: nExactFluxElems,nExactFluxFaces,nExactFluxInterFaces
INTEGER             :: iElem,iSide,SideID,nExactFluxMasterInterFaces,sumExactFluxMasterInterFaces
!===================================================================================================================================
! get x,y, or z-position of interface
ExactFluxDir = GETINT('FluxDir','-1') 
IF(ExactFluxDir.EQ.-1)THEN
  ExactFluxDir = GETINT('ExactFluxDir','3')
END IF
ExactFluxPosition    = GETREAL('ExactFluxPosition') ! initialize empty to force abort when values is not supplied
! set interface region, where one of the bounding box sides coinsides with the ExactFluxPosition in direction of ExactFluxDir
SELECT CASE(ABS(ExactFluxDir))
CASE(1) ! x
  InterFaceRegion(1:6)=(/-HUGE(1.),ExactFluxPosition,-HUGE(1.),HUGE(1.),-HUGE(1.),HUGE(1.)/)
CASE(2) ! y
  InterFaceRegion(1:6)=(/-HUGE(1.),HUGE(1.),-HUGE(1.),ExactFluxPosition,-HUGE(1.),HUGE(1.)/)
CASE(3) ! z
  InterFaceRegion(1:6)=(/-HUGE(1.),HUGE(1.),-HUGE(1.),HUGE(1.),-HUGE(1.),ExactFluxPosition/)
CASE DEFAULT
  CALL abort(&
      __STAMP__&
      ,' Unknown exact flux direction: ExactFluxDir=',ExactFluxDir)
END SELECT

! set all elements lower/higher than the ExactFluxPosition to True/False for interface determination
CALL FindElementInRegion(isExactFluxElem,InterFaceRegion,ElementIsInside=.FALSE.,DoRadius=.FALSE.,Radius=-1.,DisplayInfo=.FALSE.)

! find all faces in the ExactFlux region
CALL FindInterfacesInRegion(isExactFluxFace,isExactFluxInterFace,isExactFluxElem)

nExactFluxMasterInterFaces=0
DO iElem=1,nElems ! loop over all local elems
  DO iSide=1,6    ! loop over all local sides
    IF(ElemToSide(E2S_FLIP,iSide,iElem).EQ.0)THEN ! only master sides
      SideID=ElemToSide(E2S_SIDE_ID,iSide,iElem)
      IF(isExactFluxInterFace(SideID))THEN
        nExactFluxMasterInterFaces=nExactFluxMasterInterFaces+1
      END IF
    END IF
  END DO
END DO

#ifdef MPI
  sumExactFluxMasterInterFaces=0
  CALL MPI_REDUCE(nExactFluxMasterInterFaces , sumExactFluxMasterInterFaces , 1 , MPI_INTEGER, MPI_SUM,0, MPI_COMM_WORLD, IERROR)
#else
  sumExactFluxMasterInterFaces=nExactFluxMasterInterFaces
#endif /* MPI */
SWRITE(UNIT_StdOut,'(A8,I10,A)') '  Found ',sumExactFluxMasterInterFaces,' interfaces for ExactFlux.'

IF(mpiroot)THEN
  IF(sumExactFluxMasterInterFaces.LE.0)THEN
    CALL abort(&
        __STAMP__&
        ,' [sumExactFluxMasterInterFaces.LE.0]: using ExactFlux but no interfaces found: sumExactFlux=',sumExactFluxMasterInterFaces)
  END IF
END IF


nExactFluxMasterInterFaces=0
DO iSide=1,lastMPISide_MINE ! nSides
  IF(SideToElem(S2E_ELEM_ID,iSide).EQ.-1) CYCLE
  IF(isExactFluxInterFace(SideID))THEN ! if an interface is encountered
    nExactFluxMasterInterFaces=nExactFluxMasterInterFaces+1
  END IF
END DO

#ifdef MPI
  sumExactFluxMasterInterFaces=0
  CALL MPI_REDUCE(nExactFluxMasterInterFaces , sumExactFluxMasterInterFaces , 1 , MPI_INTEGER, MPI_SUM,0, MPI_COMM_WORLD, IERROR)
#else
  sumExactFluxMasterInterFaces=nExactFluxMasterInterFaces
#endif /* MPI */
SWRITE(UNIT_StdOut,'(A8,I10,A)') '  Found ',sumExactFluxMasterInterFaces,' interfaces for ExactFlux. <<<<<< DEBUG this'







! Get number of ExactFlux Elems, Faces and Interfaces. Create Mappngs ExactFlux <-> physical region
CALL CountAndCreateMappings('ExactFlux',&
                            isExactFluxElem,isExactFluxFace,isExactFluxInterFace,&
                            nExactFluxElems,nExactFluxFaces, nExactFluxInterFaces,&
                            ElemToExactFlux,ExactFluxToElem,& ! these two are allocated
                            FaceToExactFlux,ExactFluxToFace,& ! these two are allocated
                            FaceToExactFluxInter,ExactFluxInterToFace) ! these two are allocated

! compute the outer radius of the mode in the cylindrical waveguide
CALL GetWaveGuideRadius(isExactFluxInterFace)

! Deallocate the vectors (must be deallocated because the used routine 'CountAndCreateMappings' requires INTENT,IN and ALLOCATABLE)
SDEALLOCATE(isExactFluxElem)
SDEALLOCATE(isExactFluxFace)
SDEALLOCATE(ExactFluxToElem)
SDEALLOCATE(ExactFluxToFace)
SDEALLOCATE(ExactFluxInterToFace)
SDEALLOCATE(ElemToExactFlux)
SDEALLOCATE(FaceToExactFlux)
SDEALLOCATE(FaceToExactFluxInter)
!CALL MPI_BARRIER(MPI_COMM_WORLD, iError)
!stop
END SUBROUTINE InitExactFlux


SUBROUTINE FinalizeEquation()
!===================================================================================================================================
! Get the constant advection velocity vector from the ini file
!===================================================================================================================================
! MODULES
USE MOD_Equation_Vars,ONLY:EquationInitIsDone,isExactFluxInterFace
! IMPLICIT VARIABLE HANDLING
IMPLICIT NONE
!-----------------------------------------------------------------------------------------------------------------------------------
! INPUT VARIABLES
!-----------------------------------------------------------------------------------------------------------------------------------
! OUTPUT VARIABLES
!-----------------------------------------------------------------------------------------------------------------------------------
! LOCAL VARIABLES
!===================================================================================================================================
EquationInitIsDone = .FALSE.
SDEALLOCATE(isExactFluxInterFace)
END SUBROUTINE FinalizeEquation

END MODULE MOD_Equation

