#!/bin/bash
# Script for changing all hopr.ini file in the cwd and below from the old HOPR format input to the new PyHOPE parameter format
# Creation date: 2025-10-15

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
  echo "Found ${NbrOfHoprFiles} hopr.ini and ${NbrOfExternalsFiles} externals.ini files, which will be processed"
else
  echo "Found no hopr.ini and no externals.ini files in cwd or below. Exit."
  exit 0
fi

# Process hopr.ini files
if [[ ${NbrOfHoprFiles} -gt 0 ]]; then
  # Deactivate all DebugVisu=T lines
  find ./ -type f -name "hopr.ini" -exec sed -i '/[Dd]ebug[Vv]isu.*=\s*[tT]/s/[tT]/F/' {} \;

  # Replace "generateFEMconnectivity = T" with "doFEMConnect = T"
  find ./ -type f -name "hopr.ini" -exec sed -i 's/generateFEMconnectivity/doFEMConnect/' {} \;

  # Rename value for key MeshPostDeform from 1 to cylinder
  find ./ -type f -name "hopr.ini" -exec sed -i '/MeshPostDeform.*=\s*1/s/1/cylinder/' {} \;

  # Rename value for key MeshPostDeform from 2 to sphere
  find ./ -type f -name "hopr.ini" -exec sed -i '/MeshPostDeform.*=\s*2/s/2/sphere/' {} \;
fi

# Process externals.ini files
if [[ ${NbrOfExternalsFiles} -gt 0 ]]; then
  # Rename executable hopr to pyhope
  find ./ -type f -name "externals.ini" -exec sed -i '/externalbinary.*=\s*/s/\.\/bin\/hopr/pyhope    /' {} \;
  find ./ -type f -name "externals.ini" -exec sed -i '/externalbinary.*=\s*/s/\.\/hopr\/build\/bin\/hopr/pyhope    /' {} \;
fi