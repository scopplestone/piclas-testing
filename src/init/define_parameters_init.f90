#include "boltzplatz.h"

MODULE MOD_Define_Parameters_Init
!===================================================================================================================================
! Initialization of all defined parameters
!===================================================================================================================================

PUBLIC:: InitDefineParameters
!===================================================================================================================================

CONTAINS

SUBROUTINE InitDefineParameters() 
!----------------------------------------------------------------------------------------------------------------------------------!
! Calls all parameter definition routines
!----------------------------------------------------------------------------------------------------------------------------------!
! MODULES                                                                                                                          !
USE MOD_Globals
USE MOD_ReadInTools      ,ONLY: prms
USE MOD_MPI              ,ONLY: DefineParametersMPI
USE MOD_IO_HDF5          ,ONLY: DefineParametersIO
USE MOD_Interpolation    ,ONLY: DefineParametersInterpolation
USE MOD_Output           ,ONLY: DefineParametersOutput
USE MOD_Restart          ,ONLY: DefineParametersRestart
#if defined(ROS) || defined(IMPA)
USE MOD_LinearSolver     ,ONLY: DefineParametersLinearSolver
#endif
USE MOD_LoadBalance      ,ONLY: DefineParametersLoadBalance
USE MOD_Analyze          ,ONLY: DefineParametersAnalyze
USE MOD_RecordPoints     ,ONLY: DefineParametersRecordPoints
USE MOD_TimeDisc         ,ONLY: DefineParametersTimedisc
USE MOD_Mesh             ,ONLY: DefineparametersMesh
USE MOD_Equation         ,ONLY: DefineParametersEquation
#ifndef PP_HDG
USE MOD_PML              ,ONLY: DefineParametersPML
#endif /*PP_HDG*/
#if USE_QDS_DG
USE MOD_QDS              ,ONLY: DefineParametersQDS
#endif
#ifdef PP_HDG
USE MOD_HDG              ,ONLY: DefineParametersHDG
#endif /*PP_HDG*/
USE MOD_Dielectric       ,ONLY: DefineParametersDielectric
USE MOD_Filter           ,ONLY: DefineParametersFilter
USE MOD_Boltzplatz_Init  ,ONLY: DefineParametersBoltzplatz
#ifdef PARTICLES
USE MOD_ParticleInit     ,ONLY: DefineParametersParticles
USE MOD_Particle_Mesh    ,ONLY: DefineparametersParticleMesh
USE MOD_Particle_Analyze ,ONLY: DefineParametersParticleAnalyze
USE MOD_TTMInit          ,ONLY: DefineParametersTTM
USE MOD_PICInit          ,ONLY: DefineParametersPIC
USE MOD_Part_Emission    ,ONLY: DefineParametersParticleEmission
USE MOD_DSMC_Init        ,ONLY: DefineParametersDSMC
USE MOD_LD_Init          ,ONLY: DefineParametersLD
USE MOD_SurfaceModel_Init,ONLY: DefineParametersSurfModel
USE MOD_SurfaceModel_Analyze,ONLY: DefineParametersSurfModelAnalyze
#endif
!----------------------------------------------------------------------------------------------------------------------------------!
! Insert modules here
!----------------------------------------------------------------------------------------------------------------------------------!
IMPLICIT NONE
! INPUT / OUTPUT VARIABLES 
!-----------------------------------------------------------------------------------------------------------------------------------
! LOCAL VARIABLES
!===================================================================================================================================

SWRITE(UNIT_stdOut,'(132("="))')
SWRITE(UNIT_stdOut,'(A)') ' DEFINING PARAMETERS ...'
SWRITE(UNIT_stdOut,'(132("="))')

CALL DefineParametersMPI()
CALL DefineParametersIO()
CALL DefineParametersLoadBalance()
CALL DefineParametersInterpolation()
CALL DefineParametersRestart()
#if defined(ROS) || defined(IMPA)
CALL DefineParametersLinearSolver()
#endif
CALL DefineParametersOutput()
CALL DefineParametersBoltzplatz()
CALL DefineParametersTimedisc()
CALL DefineParametersMesh()
CALL DefineParametersEquation()
#ifndef PP_HDG
CALL DefineParametersPML()
#endif /*PP_HDG*/
#if USE_QDS_DG
CALL DefineParametersQDS()
#endif
#ifdef PP_HDG
CALL DefineParametersHDG()
#endif /*PP_HDG*/
CALL DefineParametersDielectric()
CALL DefineParametersFilter()
CALL DefineParametersAnalyze()
CALL DefineParametersRecordPoints()
#ifdef PARTICLES
CALL DefineParametersParticles()
CALL DefineParametersParticleMesh()
CALL DefineParametersParticleAnalyze()
CALL DefineParametersTTM()
CALL DefineParametersPIC()
CALL DefineParametersParticleEmission()
CALL DefineParametersDSMC()
CALL DefineParametersLD()
CALL DefineParametersSurfModel()
CALL DefineParametersSurfModelAnalyze()
#endif

SWRITE(UNIT_stdOut,'(132("="))')
SWRITE(UNIT_stdOut,'(A,I0,A)') ' DEFINING PARAMETERS DONE! --> ',prms%count_entries(),' UNIQUE PARAMETERS DEFINED'
SWRITE(UNIT_stdOut,'(132("="))')


END SUBROUTINE InitDefineParameters

END MODULE MOD_Define_Parameters_Init