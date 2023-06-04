#!/bin/bash  -i
mpirun -np 8 piclas parameter.ini

#By default, aliases are not available in shell scripts — for instance, in non-interactive shells. However, we can enable them using the shell option:
#shopt -s expand_aliases
source $HOME/.boltzplatz_aliases
#. $HOME/.boltzplatz_aliases --source-only

#2vtk 1
#2vtk 18

# minus 1 because bash
2vtk 0
2vtk 17
