!==================================================================================================================================
! Copyright (c) 2015-2019 Wladimir Reschke
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

MODULE MOD_SurfaceModel_Init
!===================================================================================================================================
!> Module for initialization of surface models
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
PUBLIC :: DefineParametersSurfModel
PUBLIC :: InitSurfaceModel
PUBLIC :: FinalizeSurfaceModel
!===================================================================================================================================

CONTAINS

!==================================================================================================================================
!> Define parameters for surface model
!==================================================================================================================================
SUBROUTINE DefineParametersSurfModel()
! MODULES
USE MOD_ReadInTools ,ONLY: prms
IMPLICIT NONE
!==================================================================================================================================
CALL prms%SetSection("SurfaceModel")

CALL prms%CreateIntOption( 'Part-Species[$]-PartBound[$]-ResultSpec','Resulting recombination species (one of nSpecies)',&
                           '-1', numberedmulti=.TRUE.)
CALL prms%CreateRealOption('Part-SurfaceModel-SEE-Te','Bulk electron temperature for SEE model by Morozov2004 in Kelvin (default corresponds to 50 eV)',&
                           '5.80226250308285e5')

END SUBROUTINE DefineParametersSurfModel


SUBROUTINE InitSurfaceModel()
!===================================================================================================================================
!> Initialize surface model variables
!===================================================================================================================================
! MODULES
USE MOD_Globals_Vars           ,ONLY: Kelvin2eV
USE MOD_Particle_Vars          ,ONLY: nSpecies
USE MOD_ReadInTools            ,ONLY: GETINT,GETREAL
USE MOD_Particle_Boundary_Vars ,ONLY: nPartBound,PartBound
USE MOD_SurfaceModel_Vars      ,ONLY: SurfModResultSpec,SurfModEnergyDistribution,SurfModSEEelectronTemp
!-----------------------------------------------------------------------------------------------------------------------------------
! IMPLICIT VARIABLE HANDLING
IMPLICIT NONE
!-----------------------------------------------------------------------------------------------------------------------------------
! INPUT VARIABLES
!-----------------------------------------------------------------------------------------------------------------------------------
! OUTPUT VARIABLES
!-----------------------------------------------------------------------------------------------------------------------------------
! LOCAL VARIABLES
CHARACTER(32) :: hilf, hilf2
INTEGER       :: iSpec, iPartBound
LOGICAL       :: ReadSurfModSEEelectronTemp
!===================================================================================================================================
IF (.NOT.(ANY(PartBound%Reactive))) RETURN

ReadSurfModSEEelectronTemp = .FALSE. ! Initialize

ALLOCATE(SurfModResultSpec(1:nPartBound,1:nSpecies))
SurfModResultSpec = 0
ALLOCATE(SurfModEnergyDistribution(1:nPartBound))
SurfModEnergyDistribution = ''
! initialize model specific variables
DO iSpec = 1,nSpecies
  WRITE(UNIT=hilf,FMT='(I0)') iSpec
  DO iPartBound=1,nPartBound
    IF(.NOT.PartBound%Reactive(iPartBound)) CYCLE
    WRITE(UNIT=hilf2,FMT='(I0)') iPartBound
    hilf2=TRIM(hilf)//'-PartBound'//TRIM(hilf2)
    SELECT CASE(PartBound%SurfaceModel(iPartBound))
!-----------------------------------------------------------------------------------------------------------------------------------
    CASE(5,6,7,8)
      ! 5: SEE by Levko2015
      ! 6: SEE by Pagonakis2016 (originally from Harrower1956)
      ! 7: SEE-I (bombarding electrons are removed, Ar+ on different materials is considered for SEE)
      ! 8: SEE-E (bombarding electrons are reflected, e- on dielectric materials is considered for SEE and three different outcomes)
!-----------------------------------------------------------------------------------------------------------------------------------
      SurfModResultSpec(iPartBound,iSpec) = GETINT('Part-Species'//TRIM(hilf2)//'-ResultSpec')
      IF(PartBound%SurfaceModel(iPartBound).EQ.8)THEN
        SurfModEnergyDistribution = 'Morozov2004'
        ReadSurfModSEEelectronTemp = .TRUE.
      ELSE
        SurfModEnergyDistribution = 'deltadistribution'
      END IF ! PartBound%SurfaceModel(iPartBound).EQ.8
!-----------------------------------------------------------------------------------------------------------------------------------
    END SELECT
!-----------------------------------------------------------------------------------------------------------------------------------
  END DO
END DO


! If SEE model by Morozov is used, read the additional parameter for the electron bulk temperature
IF(ReadSurfModSEEelectronTemp)THEN
  SurfModSEEelectronTemp = GETREAL('Part-SurfaceModel-SEE-Te') ! default is 50 eV = 5.80226250308285e5 K
  SurfModSEEelectronTemp = SurfModSEEelectronTemp*Kelvin2eV    ! convert to eV to be used in the code
END IF ! ReadSurfModSEEelectronTemp

END SUBROUTINE InitSurfaceModel


SUBROUTINE FinalizeSurfaceModel()
!===================================================================================================================================
!> Deallocate surface model vars
!===================================================================================================================================
! MODULES
USE MOD_SurfaceModel_Vars
USE MOD_SurfaceModel_Analyze_Vars
! IMPLICIT VARIABLE HANDLING
IMPLICIT NONE
!-----------------------------------------------------------------------------------------------------------------------------------
! INPUT VARIABLES
!-----------------------------------------------------------------------------------------------------------------------------------
! OUTPUT VARIABLES
!-----------------------------------------------------------------------------------------------------------------------------------
! LOCAL VARIABLES
!===================================================================================================================================
SurfModelAnalyzeInitIsDone=.FALSE.

SDEALLOCATE(SurfModResultSpec)

! === Surface Analyze Vars
SDEALLOCATE(SurfAnalyzeCount)
SDEALLOCATE(SurfAnalyzeNumOfAds)
SDEALLOCATE(SurfAnalyzeNumOfDes)
IF(CalcBoundaryParticleOutput)THEN
  SDEALLOCATE(BPO%RealPartOut)
  SDEALLOCATE(BPO%PartBoundaries)
  SDEALLOCATE(BPO%BCIDToBPOBCID)
  SDEALLOCATE(BPO%Species)
  SDEALLOCATE(BPO%SpecIDToBPOSpecID)
END IF ! CalcBoundaryParticleOutput

END SUBROUTINE FinalizeSurfaceModel

END MODULE MOD_SurfaceModel_Init
