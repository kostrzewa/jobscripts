#PBS -N jobname
#PBS -l walltime=10:00:00,mem=52gb
#PBS -l nodes=1:ppn=8:gpus=4:exclusive_process
#PBS -M bartosz.kostrzewa@desy.de
#PBS -m abe
#PBS -j oe

exe=/hadron/bartek/code/peram_gen_QUDA_4GPU/main/main

cd blahblah
mpirun.openmpi -x OMP_NUM_THREADS=2 -np 4 -npersocket 2 \
${exe} -LapHsin ./INFILE &> ./OUTFILE
chmod 664 *
