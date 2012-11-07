#!/bin/bash

REFTFILE="../runtimes_csw.csv"

REFSAMPLES="refhmc0 refhmc1 refhmc2 refhmc3 refhmc_ndclover refhmc_nosplit_ndclover refhmc_nocsw_ndclover \
         refhmc_nosplit_nocsw_ndclover refhmc_cloverdet refhmc_tmcloverdet refhmc_check_ndclover_tmcloverdet\
         refhmc_check_ndclover_nocsw_tmcloverdet refhmc_tmcloverdetratio"

SAMPLES="hmc0 hmc1 hmc2 hmc3 hmc_ndclover hmc_nosplit_ndclover hmc_nocsw_ndclover \
         hmc_nosplit_nocsw_ndclover hmc_cloverdet hmc_tmcloverdet hmc_check_ndclover_tmcloverdet\
         hmc_check_ndclover_nocsw_tmcloverdet hmc_tmcloverdetratio"

# skip the headers in the files
readrefheaderflag=0
readheaderflag=0

while read refname ${REFSAMPLES}; do
  if [[ readrefheaderflag -eq 0 ]]; then
    let readrefheaderflag=1
    continue
  fi

  let readheaderflag=0
  while read name ${SAMPLES}; do
    if [[ readheaderflag -eq 0 ]]; then
      let readheaderflag=1
      continue
    fi

    if [[ $refname = $name ]]; then
      for i in ${SAMPLES}; do
        j="ref"${i}
        if [[ -z ${!i} ]]; then
          echo "The $name run of sample $i has an empty time measurement. The set is probably not complete!"
          continue
        fi
        if [[ `echo "scale=6;out=0;r=${!i}/${!j};if(r>1.05) out=1;out" | bc` -eq 1 ]]; then
          echo "The $name run of sample $i took longer than the reference time: ${!i} > ${!j} !"
        fi
      done
    fi
  done < ${1}
done < ${REFTFILE}
