#!/bin/bash 

start="$(date +%s)"
echo Running PPMAP with OMP_NUM_THREADS=$NCPUS
export OMP_NUM_THREADS=$NCPUS
${code}  <field name>   <first field #>   <last field #>
echo PPMAP finished
