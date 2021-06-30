#!/bin/bash
#PBS -l select=1:ncpus=${NCPUS}:mpiprocs=${NCPUS}
#PBS -l place=scatter:exc1
#PBS -o run_ppmap.log
#PBS -e run_ppmap.err
#PBS -N run_ppmap.name
#PBS -l walltime=72:00:00
#PBS -q workq
####PBS -P run_ppmap.name


# latest intel compilers, mkl and intel-mpi

module purge
module load compiler/intel

ulimit -s unlimited
ulimit -c 0

start="$(date +%s)"
echo Running PPMAP with OMP_NUM_THREADS=${NCPUS}
export OMP_NUM_THREADS=${NCPUS}
${code}/ppmap   <field name>   <first field #>   <last field #> 
echo PPMAP finished

