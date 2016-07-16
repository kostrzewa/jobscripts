if [ -z "${1}" -o -z "${2}" -o -z "${3}" ]; then
 echo "usage: ./submit.sh <start> <step> <no> [-co]"
 echo "[-co] contraction only"
 exit 1
fi

start=${1}
step=${2}
no=${3}

prefix=Z_extend

if [ -z "$( ls ${prefix}* )" ]; then
  touch ${prefix}_0000
fi

for i in $( seq ${start} ${step} $(( ${start} + (${no}-1)*${step} )) ); do 
  i4=$( printf %04d $i )
  cp contraction.job.cmd.template contraction.job.${i4}.cmd
  sed -i "s/GCONF/${i4}/g" contraction.job.${i4}.cmd
  jobid=""
  if [ -z "${4}" ]; then
    jobid=$( sbatch job.${i4}.cmd | awk '{print $NF}' )
    sbatch --dependency=afterok:${jobid} contraction.job.${i4}.cmd
  else
    sbatch contraction.job.${i4}.cmd
  fi
  mv ${prefix}_* ${prefix}_${i4}
done
