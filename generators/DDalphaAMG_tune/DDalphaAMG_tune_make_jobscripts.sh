nodes=(64 128)
levels=(2 3)
iters=(3 4 5)
mucoarse=(4.0 4.5 5.0 5.5 6.0 6.5 7.0 7.5 8.0 8.5 9.0 9.5 10.0 10.5 11.0 11.5 12.0)
nvecs=(16 20 24 28 32)
conf=/marconi_work/INF17_lqcd123_0/KNL_benchmarks/DDalphaAMG_L64/conf.0200

for nds in ${nodes[@]}; do
  mgbt=4
  if [ ${nds} -eq 128 ]; then
    mgbt=2
  fi
  for iter in ${iters[@]}; do
    for lvl in ${levels[@]}; do
      for nvec in ${nvecs[@]}; do
        for muc in ${mucoarse[@]}; do
          wdir=$(pwd)/nds${nds}_iters${iter}_nlevel${lvl}_nvec${nvec}_mucoarse${muc}
          if [ ! -d ${wdir} ]; then
            mkdir ${wdir}
            mkdir ${wdir}/outputs
            ln -s ${conf} ${wdir}/conf.0200
          fi
        
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
