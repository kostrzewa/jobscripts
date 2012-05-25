#!/bin/sh
#
#(otherwise the default shell would be used)
#$ -S /bin/sh
#
#(the running time for this job)
#$ -l h_cpu=00:01:00
#
#(stderr and stdout are merged together to stdout) 
#$ -j y
#
#(send mail on job's end and abort)
#$ -m bae
#$ -pe multicore 2
# change to scratch directory
cd $TMPDIR
/usr/lib64/openmpi/1.4-icc/bin/mpirun -np 2 /afs/ifh.de/user/k/kostrzew/code/tmLQCD.kost/build_hybrid/hmc_tm -f $HOME/code/tmLQCD.kost/build_hybrid/sample-hmc0.input

