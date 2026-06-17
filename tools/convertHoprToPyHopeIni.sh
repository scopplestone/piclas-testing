#!/bin/bash
# Script for changing all hopr.ini file in the cwd and below from the old HOPR format input to the new PyHOPE parameter format
# Creation date: 2025-10-15

_display_changes () {
  echo -e "Changes performed by this script that convert a HOPR .ini file into a PyHOPE .ini file:\n"
  OUTPUT="HOPR .ini:PyHOPE .ini:Description\n"
  OUTPUT=${OUTPUT}"-----:----:-----\n"
  OUTPUT=${OUTPUT}"DebugVisu=T:DebugVisu=F:changed functionality now envokes the interactive gmsh GUI\n"
  OUTPUT=${OUTPUT}"generateFEMconnectivity:doFEMConnect:renamed variable\n"
  OUTPUT=${OUTPUT}"MeshPostDeform=1:MeshPostDeform=cylinder:changed variable datatype from integer to string\n"
  OUTPUT=${OUTPUT}"MeshPostDeform=2:MeshPostDeform=sphere:changed variable datatype from integer to string\n"
  OUTPUT=${OUTPUT}"postscalemesh:[REMOVED]:variable no longer exists in pyhope\n"
  OUTPUT=${OUTPUT}"meshTemplate:[REMOVED]:variable no longer exists in pyhope\n"
  OUTPUT=${OUTPUT}"SpaceQuandt:[REMOVED]:variable no longer exists in pyhope\n"
  OUTPUT=${OUTPUT}"MeshDim:[REMOVED]:variable no longer exists in pyhope\n"
  OUTPUT=${OUTPUT}"lowerZ_BC:[REMOVED]:variable no longer exists in pyhope\n"
  OUTPUT=${OUTPUT}"upperZ_BC:[REMOVED]:variable no longer exists in pyhope\n"
  OUTPUT=${OUTPUT}"logging:[REMOVED]:variable no longer exists in pyhope\n"
  OUTPUT=${OUTPUT}"Mode=2:Mode=external:changed variable value from 2 to 3 or 'external'\n"
  OUTPUT=${OUTPUT}"Mode=5:Mode=external:changed variable value from 5 to 3 or 'external'\n"
  OUTPUT=${OUTPUT}"Mode=11:Mode=internal:changed variable value from 11 to 1 or 'external'\n"
  OUTPUT=${OUTPUT}"zLength:MeshExtrudeLength:renamed variable\n"
  OUTPUT=${OUTPUT}"nElemsZ:MeshExtrudeElems:renamed variable\n"
  OUTPUT=${OUTPUT}"sfc_type:MeshSortingSFC:renamed variable\n"
  echo -e ${OUTPUT} | column -s : -t -o$'\t\t'
  echo ""
}

# Check command line arguments
for ARG in "$@"; do
  if [ "${ARG}" == "--help" ] || [ ${ARG} == "-h" ]; then
    echo "This scripts searches recursively in the current directory for hopr*.ini and externals.ini files"
    echo "and changed specific flags/settings from old (hopr) to new (pyhope) compatibility."
    echo ""
    echo "Input arguments:"
    echo ""
    echo "  --help/-h            Print this help information. No other arguments are allowed."
    echo ""
    echo "Usage example:"
    echo ""
    echo "  cd ~/piclas/regressioncheck"
    echo "  ~/piclas/tools/convertHoprToPyHopeIni.sh"
    echo ""
    echo "or simply run the script within the directory, where the hopr*.ini file is"
    echo ""
    echo "  cd ~/piclas/regressioncheck/CHE_poisson/SurfFlux_ThermionicEmission_Schottky"
    echo -e "  ~/piclas/tools/convertHoprToPyHopeIni.sh\n"
    _display_changes
    exit 0
  fi
  echo "ERROR: This script takes no input arguments except '--help'"
  exit 1
done


if test -t 1; then # if terminal
  NbrOfColors=$(which tput > /dev/null && tput colors) # supports color
  if test -n "$NbrOfColors" && test $NbrOfColors -ge 8; then
    NC="$(tput sgr0)"
    RED="$(tput setaf 1)"
    GREEN="$(tput setaf 2)"
    YELLOW="$(tput setaf 3)"
  fi
fi

# Check if there are any files to process
NbrOfHoprFiles=$(find ./ -type f -name "hopr.ini" | wc -l)
NbrOfExternalsFiles=$(find ./ -type f -name "externals.ini" | wc -l)

# Output info on the number of found files
if [[ ${NbrOfHoprFiles} -gt 0 ]] || [[ ${NbrOfExternalsFiles} -gt 0 ]]; then
  _display_changes
  echo "Found ${NbrOfHoprFiles} hopr.ini and ${NbrOfExternalsFiles} externals.ini files, which will be processed"
else
  echo "Found no hopr.ini and no externals.ini files in cwd or below. Exit."
  exit 0
fi

# Process hopr.ini files
if [[ ${NbrOfHoprFiles} -gt 0 ]]; then
  # Deactivate all DebugVisu=T lines
  find ./ -type f -name "hopr*.ini" -exec sed -i '/[Dd]ebug[Vv]isu.*=\s*[tT]/s/[tT]/F/' {} \;

  # Replace "generateFEMconnectivity = T" with "doFEMConnect = T"
  find ./ -type f -name "hopr*.ini" -exec sed -i 's/generateFEMconnectivity/doFEMConnect/' {} \;

  # Rename value for key MeshPostDeform from 1 to cylinder
  find ./ -type f -name "hopr*.ini" -exec sed -i '/MeshPostDeform.*=\s*1/s/1/cylinder/' {} \;

  # Rename value for key MeshPostDeform from 2 to sphere
  find ./ -type f -name "hopr*.ini" -exec sed -i '/MeshPostDeform.*=\s*2/s/2/sphere/' {} \;

  # Remove all lines with the following strings as these variables no longer exist in pyhope
  # - postScaleMesh
  # - meshTemplate
  # - SpaceQuandt
  # - MeshDim
  # - lowerZ_BC
  # - upperZ_BC
  find ./ -type f -name "hopr*.ini" -exec sed -i '/postscalemesh\|meshTemplate\|SpaceQuandt\|MeshDim\|lowerZ_BC\|upperZ_BC\|logging/Id' {} \;

  # Rename all mesh modes with external meshes (2, 5) to "Mode = external"
  find ./ -type f -name "hopr*.ini" -exec sed -i '/Mode.*=\s*[25].*/s/[25].*/external/' {} \;

  # Rename mesh "Mode = 11" with  "Mode = internal"
  find ./ -type f -name "hopr*.ini" -exec sed -i '/Mode.*=\s*11.*/s/11.*/internal/' {} \;

  # Rename mesh "zLength" to "MeshExtrudeLength"
  find ./ -type f -name "hopr*.ini" -exec sed -i 's/zLength/MeshExtrudeLength/' {} \;

  # Rename mesh "nElemsZ" to "MeshExtrudeElems"
  find ./ -type f -name "hopr*.ini" -exec sed -i 's/nElemsZ/MeshExtrudeElems/' {} \;

  # Rename mesh "sfc_type" to "MeshSortingSFC"
  find ./ -type f -name "hopr*.ini" -exec sed -i 's/sfc_type/MeshSortingSFC/' {} \;
fi

# Process externals.ini files
if [[ ${NbrOfExternalsFiles} -gt 0 ]]; then
  # Rename executable hopr to pyhope
  find ./ -type f -name "externals.ini" -exec sed -i '/externalbinary.*=\s*/s/\.\/bin\/hopr/pyhope    /' {} \;
  find ./ -type f -name "externals.ini" -exec sed -i '/externalbinary.*=\s*/s/\.\/hopr\/build\/bin\/hopr/pyhope    /' {} \;
fi