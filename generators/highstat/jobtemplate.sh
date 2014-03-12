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
#
# redirect stdout and stderr to /dev/null
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

# write stdout and stderr into tmp dir, will be copied to output at the end
exec > ${TMPDIR}/stdout.txt.${JOB_ID} 2> ${TMPDIR}/stderr.txt.${JOB_ID}

case ${BASENAME} in
  *mpihmc211*)
    cp ${ITOPDIR}/roots_mpihmc211.dat ${ODIR}
  ;;
  *hmc2*)
    cp ${ITOPDIR}/normierungLocal.dat ${ODIR}
    cp ${ITOPDIR}/Square_root_BR_roots.dat ${ODIR}
  ;;
  *ndclover*)
    cp ${ITOPDIR}/clover_roots.dat ${ODIR}
    cp ${ITOPDIR}/clover_roots_2.dat ${ODIR}
    cp ${ITOPDIR}/clover_roots_problematic.dat ${ODIR}
  ;;  
esac 

case ${ADDON} in
  *MPI*)
    export NPN=8
    export BINDING="-cpus-per-proc 1 -npersocket 4 -bycore -bind-to-core"
  ;;
  *hybrid*) 
    export NPN=2
    export BINDING="-cpus-per-proc 4 -npersocket 1 -bysocket -bind-to-socket"
  ;;
  *openmp*)
    export NPN=1
esac

MPIRUN="/usr/lib64/openmpi-intel/bin/mpirun -wd ${ODIR} -np ${NPROCS} -npernode ${NPN} ${BINDING}"
case ${ADDON} in
  *MPI*) export MPIPREFIX=${MPIRUN};;
  *mpi*) export MPIPREFIX=${MPIRUN};;
  *hybrid*) 
    export MPIPREFIX=${MPIRUN}
    eval `modulecmd sh add intel.2013`
    source /usr/local/bin/intel-setup-2013.sh intel64
  ;;
  *openmp*) 
    export MPIPREFIX=${MPIRUN}
    eval `modulecmd sh add intel.2013`
    source /usr/local/bin/intel-setup-2013.sh intel64
  ;;
esac

cp ${IFILE} ${ODIR}

/usr/bin/time -p ${MPIPREFIX} ${EFILE} -f ${IFILE} > ${ODIR}/hmcout.${JOB_ID}.out

cp ${TMPDIR}/std* ${ODIR}
