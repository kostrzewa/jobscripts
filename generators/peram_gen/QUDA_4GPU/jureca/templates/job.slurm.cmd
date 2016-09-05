#!/bin/bash -x
#SBATCH --job-name=JOBNAME                                                                                                                                                                                     
#SBATCH --mail-type=ALL
#SBATCH --mail-user=bartosz.kostrzewa@desy.de
#SBATCH --nodes=1
#SBATCH --ntasks-per-node=4
#SBATCH --cpus-per-task=12
#SBATCH --output=outputs/out.JOBNAME.%j
#SBATCH --error=outputs/out.JOBNAME.%j
#SBATCH --time=06:00:00
#SBATCH --partition=gpus
#SBATCH --gres=gpu:4

module restore nvidia

rundir=RUNDIR
exe=EXEC
outfile=OUTFILE
infile=INFILE

cd ${rundir}
date > ${outfile}
QUDA_RESOURCE_PATH=${HOME}/misc/jureca/quda_resources/develop-serial OMP_NUM_THREADS=12 srun ${exe} -LapHsin ${infile} | tee -a ${outfile}
date >> ${outfile}

wait
