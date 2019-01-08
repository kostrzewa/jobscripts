#!/bin/bash -x                                                                                                                                               
#SBATCH --time=12:00:00
#SBATCH --mem=82G
#SBATCH --nodes=125

#SBATCH --cpus-per-task=48
#SBATCH --partition=skl_usr_prod
#SBATCH --ntasks-per-node=1
#SBATCH --exclusive
#SBATCH --qos=skl_qos_bprod

#SBATCH --job-name=qphix_block_benchmark
#SBATCH --account=INF18_lqcd123_1
#SBATCH --mail-type=ALL
#SBATCH --mail-user=bartosz_kostrzewa@fastmail.com
#SBATCH --output=outputs/out.%x.%J.out
#SBATCH --error=outputs/err.%x.%J.err

module purge
module load env-skl/1.0
module load intel/pe-xe-2018--binary intelmpi/2018--binary mkl/2018--binary

RUNDIR=/marconi_work/INF18_lqcd123/bartek/tests/qphix_80c160_blocks
ODIR=${RUNDIR}/outputs

if [ ! -d ${ODIR} ]; then
  mkdir -p ${ODIR}
  mkdir ${ODIR}
fi

cd ${RUNDIR}

export I_MPI_JOB_RESPECT_PROCESS_PLACEMENT=disable
export HFI_NO_CPUAFFINITY=1

export I_MPI_HYDRA_ENV=all
export I_MPI_FABRICS=shm:tmi
export I_MPI_PIN=1

## at debug level 4, Intel MPI outputs task pinning layout
## which can be used to confirm that desired layout has been
## obtained
export I_MPI_DEBUG=4

## pin tasks to regions of 3 cores (hyperthreading is disabled on A3)
export I_MPI_PIN_DOMAIN=3
export OMP_NUM_THREADS=3

## verbose will output thread pinning, can and should be disabled in
## production because DDalphaAMG and tmLQCD will use different numbers
## of threads, resulting in LOTS of output every time the
## numbers are changed...
export KMP_AFFINITY="balanced,granularity=fine"

ofile=qphix_scan.dat

arch_arr=( "avx2" "skylake" )
by_arr=( 1 2 4 8 )
bz_arr=( 1 2 4 8 )
padxy_arr=( 0 1 )
padxyz_arr=( 0 1 )

njobs=$(( ${#arch_arr[@]} *
          ${#by_arr[@]} *
          ${#bz_arr[@]} *
          ${#padxy_arr[@]} *
          ${#padxyz_arr[@]} ))

njob=0

datfile=qphix_scan.dat
echo "arch by bz padxy padxyz tts" > ${datfile}

for arch in "avx2" "skylake" "skl_soalen4"; do
  EXE=/marconi_work/INF18_lqcd123/bartek/build/${arch}/tmLQCD_cC211_06_80_production/invert
  if [ "${arch}" = "skl_soalen4" ]; then
    EXE=/marconi_work/INF18_lqcd123/bartek/build/skylake/tmLQCD_cC211_06_80_production_soalen4/invert
  fi
  for by in 1 2 4 8; do
    for bz in 1 2 4 8; do
      for padxy in 0 1; do
        for padxyz in 0 1; do
          njob=$(( ${njob} + 1 ))

          idstring=arch-${arch}_by${by}_bz${bz}_padxy${padxy}_padxyz${padxyz}
          ifile=${idstring}.input
          cp input.template ${ifile}
          sed -i "s/_BY_/${by}/g" ${ifile}
          sed -i "s/_BZ_/${bz}/g" ${ifile}
          sed -i "s/_PADXY_/${padxy}/g" ${ifile}
          sed -i "s/_PADXYZ_/${padxyz}/g" ${ifile}
          
          ofile=outputs/${idstring}.out
          echo "Job ${njob} out of ${njobs}" | tee -a ${ofile}
          echo "arch=${arch} by=${by} bz=${bz} padxy=${padxy} padxyz=${padxyz}" | tee -a ${ofile}
          tts_arr=( $( mpirun -n $(( 125 * 16 )) -ppn 16 $EXE -f ${ifile} 2>&1 | \
            tee -a ${ofile} | grep "Inversion done" | grep sec | awk '{print $4}') )
          
          for tts in ${tts_arr[@]}; do
            echo ${arch} ${by} ${bz} ${padxy} ${padxyz} ${tts} | tee -a ${datfile}
          done

        done # padxyz
      done # padxy
    done # bz
  done # by
done # arch
