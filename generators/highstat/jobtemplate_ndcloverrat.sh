#!/bin/sh
#
#(otherwise the default shell would be used)
#$ -S /bin/sh
#
#(the running time for this job)
#$ -l h_rt=H_RT
#$ -l s_rt=S_RT
#$ -l h_vmem=3G
#
#(stderr and stdout are merged together to stdout) 
#$ -j y
# the default output directory is in the home folder, we don't want that!
#$ -o /dev/null
#
#(send mail on job's end and abort)
#$ -m bae
# queue name and number of cores
#$ -pe QUEUE NCORES
#$ -P etmc

# number of mpi processes
NPROCS=NP
# basename, e.g. hmc0
BASENAME=BN
# e.g. openmp_noreduct
ADDON=AN
# e.g. highstatX
SUBDIR=SD
# "s" for start, "c" for continue
STATE=ST
# numerical counter for number of continue script
# if STATE=c
NCONT=NC

PENAME=QUEUE

ODIR=OD
EFILE=EF
IFILE=IF
ITOPDIR=ITD

if [[ ${STATE} == "s" ]]; then
  if [[ ! -d ${ODIR} ]]; then
    mkdir -p ${ODIR}
  fi
fi

if [[ ! -d ${ODIR} ]]
then
  echo "output directory ${ODIR} could not be found! Aborting!"
  exit 111
fi

cd ${ODIR}

case ${ADDON} in
  *MPI*)
    # special rules apply for pax9
    if [[ "$PENAME" == "pax9" ]]; then
      export BINDING="--cpus-per-proc 1 --map-by ppr:16:node"
    else
      export BINDING="--cpus-per-proc 1 --map-by ppr:8:node"
    fi
  ;;
  *hybrid*) 
    if [[ "$PENAME" == "pax9" ]]; then
      export BINDING="--cpus-per-proc 4 --map-by ppr:2:socket"
    else
      export BINDING="--cpus-per-proc 4 --map-by ppr:1:socket"
    fi
  ;;
  *openmp*)
    export BINDING="--cpus-per-proc 8 --map-by ppr:1:node"
  ;;
esac

# initialize all environment variables related to ICC
. /opt/intel/2013/bin/iccvars.sh intel64

MPIRUN="/usr/lib64/openmpi-intel/bin/mpirun -x LD_LIBRARY_PATH -wd ${ODIR} -np ${NPROCS} ${BINDING}"
case ${ADDON} in
  *MPI*) export MPIPREFIX=${MPIRUN};;
  *mpi*) export MPIPREFIX=${MPIRUN};;
  *hybrid*) 
    export KMP_AFFINITY="compact,granularity=fine"
    export MPIPREFIX="${MPIRUN} -x KMP_AFFINITY"
  ;;
  *openmp*) 
    export MPIPREFIX=""
    export KMP_AFFINITY="compact,granularity=fine"
  ;;
esac

cp ${IFILE} ${ODIR}

${MPIPREFIX} ${EFILE} -f ${IFILE} &> ${ODIR}/out.${STATE}${NCONT}_${BASENAME}_${ADDON}.${JOB_ID}.out
