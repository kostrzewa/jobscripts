#!/bin/bash
#PBS -S /bin/bash
#PBS -N time_clov_noqdp
#PBS -l nodes=24:ppn=24
#PBS -l walltime=00:59:00
#PBS -j oe

set -e
set -u

module swap PrgEnv-cray PrgEnv-intel
module load gcc/6.3.0
module load intel/17.0.2.174
module load perftools-base

module list

set -x

wdir=$PBS_O_WORKDIR/24nodes
odir=$PBS_O_WORKDIR/24nodes

if [ ! -d $wdir ]; then
  mkdir -p $wdir
fi

cd $wdir

# Geometry Setup

latsize=( 24 24 24 96 )
geometry=( 1 1 2 24 )

addon=.by4

# Start
export OMP_NUM_THREADS=12

prog=$HOME/local/xc40/Chroma-Richardson-CG/local-icc/bin/time_clov_noqdp

iters=500

for order in 0 1; do
  for eager in 0 1; do
    for async in 0 1; do
      if [ ${eager} -eq 1 ]; then
        export MPICH_GNI_MAX_EAGER_MSG_SIZE=131072
        addon=${addon}.eager
      else
        export MPICH_GNI_MAX_EAGER_MSG_SIZE=8192
      fi

      export MPICH_NEMESIS_ASYNC_PROGRESS=${async}
      if [ ${async} -eq 1 ]; then
        export MPICH_MAX_THREAD_SAFETY=multiple
        addon=${addon}.async
      else
        export MPICH_MAX_THREAD_SAFETY=single
      fi

      if [ ${order} -eq 1 ]; then
        grid_order -R  \
            -g ${geometry[2]},${geometry[3]} -c 2 \
            > MPICH_RANK_ORDER
        
        cat MPICH_RANK_ORDER
        export MPICH_RANK_REORDER_METHOD=3
        addon=${addon}.opt_grid_order
      else
        export MPICH_RANK_REORDER_METHOD=1
      fi

      for prec in d f; do
        for kernel in dslash mmat cg bicgstab; do
          ofile=${kernel}_prec-${prec}_latsize${latsize[0]}-${latsize[1]}-${latsize[2]}-${latsize[3]}_geom${geometry[0]}-${geometry[1]}-${geometry[2]}-${geometry[3]}${addon}.log
         
          echo ${ofile} > ${ofile}
      
          aprun -j 1 -n $((geometry[0] * geometry[1] * geometry[2] * geometry[3])) -N 2 -d 12 \
              -cc depth \
              $prog \
              -${kernel} \
              -compress12 \
              -soalen 4 \
              -prec ${prec} \
              -i ${iters} \
              -x ${latsize[0]} \
              -y ${latsize[1]} \
              -z ${latsize[2]} \
              -t ${latsize[3]} \
              -c 12 -sy 1 -sz 1 -geom ${geometry[@]} \
              -by 4 -bz 4 -pxy 0 -pxyz 0 -minct 1 | tee -a ${ofile}
        done
      done
    done
  done
done

