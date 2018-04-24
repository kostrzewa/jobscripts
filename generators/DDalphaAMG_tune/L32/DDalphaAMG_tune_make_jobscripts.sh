nodes=(4 8 16 32)
levels=(3)
iters=(5)
mucoarse=(2.0 3.0 4.0 5.0 6.0 7.0 8.0 9.0 10.0 11.0 12.0)
nvecs=(16 24)
conf=/marconi_work/Pra13_3304/Confs/NF2_TMCLOVER/cA2a.60.32/conf.0500

for nds in ${nodes[@]}; do
  nrzprocs=4
  nryprocs=4

  mgby=4
  mgbz=4
  mgbt=4
  if [ ${nds} -ge 8 ]; then
    mgbt=2
  fi
  if [ ${nds} -ge 16 ]; then
    mgbz=2
    nrzprocs=8
  fi
  if [ ${nds} -ge 32 ]; then
    mgby=2
    nryprocs=8
  fi
  
  for iter in ${iters[@]}; do
    for lvl in ${levels[@]}; do
      for nvec in ${nvecs[@]}; do
        for muc in ${mucoarse[@]}; do
          wdir=$(pwd)/nds${nds}_iters${iter}_nlevel${lvl}_nvec${nvec}_mucoarse${muc}
          if [ ! -d ${wdir} ]; then
            mkdir ${wdir}
            mkdir ${wdir}/outputs
          fi
          ln -s ${conf} ${wdir}
        
          ifile=${wdir}/invert.input
          cp invert.input.template ${ifile}
          sed -i "s/MUCOARSE/${muc}/g" ${ifile}
          sed -i "s/NVEC/${nvec}/g" ${ifile}
          sed -i "s/NLEVEL/${lvl}/g" ${ifile}
          sed -i "s/ITERS/${iter}/g" ${ifile}
          sed -i "s/MGBT/${mgbt}/g" ${ifile}
          sed -i "s/MGBY/${mgby}/g" ${ifile}
          sed -i "s/MGBZ/${mgbz}/g" ${ifile}
          sed -i "s/NRZPROCS/${nrzprocs}/g" ${ifile}
          sed -i "s/NRYPROCS/${nryprocs}/g" ${ifile}
        
          jfile=${wdir}/job.nds${nds}_iters${iter}_nlevel${lvl}_nvec${nvec}_mucoarse${muc}.sh
          cp job.DDalphaAMG.scan.template ${jfile}
          sed -i "s@WDIR@${wdir}@g" ${jfile}
          sed -i "s/MUCOARSE/${muc}/g" ${jfile}
          sed -i "s/NVEC/${nvec}/g" ${jfile}
          sed -i "s/NLEVEL/${lvl}/g" ${jfile}
          sed -i "s/ITERS/${iter}/g" ${jfile}
          sed -i "s/NODES/${nds}/g" ${jfile}
        done
      done
    done
  done
done
