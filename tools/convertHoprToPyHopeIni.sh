#!/bin/bash
# Script for changing all hopr.ini file in the cwd and below from the old HOPR format input to the new PyHOPE parameter format

if test -t 1; then # if terminal
  NbrOfColors=$(which tput > /dev/null && tput colors) # supports color
  if test -n "$NbrOfColors" && test $NbrOfColors -ge 8; then
    NC="$(tput sgr0)"
    RED="$(tput setaf 1)"
    GREEN="$(tput setaf 2)"
    YELLOW="$(tput setaf 3)"
  fi
fi

NbrOfHoprFiles=$(find ./ -type f -name "hopr.ini" | wc -l)

if [[ ${NbrOfHoprFiles} -gt 0 ]]; then
  echo "Found ${NbrOfHoprFiles} hopr.ini files, which will be processed"
else
  echo "Found no hopr.ini files in cwd or below. Exit."
  exit 0
fi

# Deactivate all DebugVisu=T lines
find ./ -type f -name "hopr.ini" -exec sed -i '/[Dd]ebug[Vv]isu.*=\s*[tT]/s/[tT]/F/' {} \;

# Replace "generateFEMconnectivity = T" with "doFEMConnect = T"
find ./ -type f -name "hopr.ini" -exec sed -i 's/generateFEMconnectivity/doFEMConnect/' {} \;

# Rename value for key MeshPostDeform from 1 to cylinder
find ./ -type f -name "hopr.ini" -exec sed -i '/MeshPostDeform.*=\s*1/s/1/cylinder/' {} \;

# Rename value for key MeshPostDeform from 2 to sphere
find ./ -type f -name "hopr.ini" -exec sed -i '/MeshPostDeform.*=\s*2/s/2/sphere/' {} \;