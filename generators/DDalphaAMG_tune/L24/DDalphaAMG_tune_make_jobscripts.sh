nodes=(1 2 3)
levels=(3)
iters=(5)
mucoarse=(2.0 3.0 4.0 5.0 6.0 7.0 8.0 9.0 10.0 11.0 12.0)
nvecs=(16 24)
conf=/marconi_work/Pra13_3304/Confs/NF2_TMCLOVER/cA2a.30.24/conf.0500

for nds in ${nodes[@]}; do
  mgbt=6
  if [ ${nds} -eq 3 ]; then
    mgbt=4
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
