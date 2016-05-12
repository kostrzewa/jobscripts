#PBS -N NAME
#PBS -l walltime=48:00:00,mem=15gb
#PBS -M bartosz.kostrzewa@desy.de
#PBS -l nodes=lcpunode01:ppn=32
#PBS -j oe

efile=EXEC

#PBS_TASKNUM=1
#PBS_NUM_PPN=32

export OMP_NUM_THREADS=32

cd JDIR

date > NAME.log

KMP_AFFINITY=compact ${efile} -v | tee -a NAME.log

date >> NAME.log

