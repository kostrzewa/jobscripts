#!/bin/bash
#SBATCH --nodes=4
#SBATCH --ntasks-per-node=6
#SBATCH --cpus-per-task=4
#SBATCH --time=00:59:00
#SBATCH --output=D30_=L=.%j
#SBATCH --error=D30_=L=.%j

export OMP_NUM_THREADS=${SLURM_CPUS_PER_TASK}
export LD_LIBRARY_PATH=${LD_LIBRARY_PATH}:/homec/hbn28/hbn282/code/petsc/arch-linux2-c-opt/lib/:/homec/hbn28/hbn282/code/slepc/arch-linux2-c-opt/lib/

module r

date
srun --exclusive -n ${SLURM_NTASKS} --cpu_bind=sockets ./ev_largest -log_summary =L=
#srun --exclusive -n ${SLURM_NTASKS} --cpu_bind=sockets ./ev_ts -log_summary =L=
date
