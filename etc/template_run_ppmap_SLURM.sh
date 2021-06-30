#!/bin/bash --login
#SBATCH --job-name=run_ppmap.name
#SBATCH -o run_ppmap.log
#SBATCH -e run_ppmap.err
#SBATCH -t 3-00:00
#SBATCH -p compute
#SBATCH -n ${NCPUS}
#SBATCH --exclusive

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

