DEBUG=1

base="etascan_L24"
kappas="0.130 0.132"
confs="1041 1091 1141 1191"
etas="0 1 m1.1 m1.15 m1.2 m2.2 m2.3 m2.4"
  

ofile=iters_${base}.dat
echo "kappa eta conf iters res" > ${ofile}
for kappa in ${kappas}; do
  for conf in ${confs}; do
    for eta in ${etas}; do
      valeta=$( echo $eta | sed 's/m/-/g' )
      dirname=$( printf "%s_%s_Kap%s" $base $eta $kappa )
      filename=$( printf "%s/%s/%s_%s.log" $dirname $conf $dirname $conf )
      # this produces a bash array
      iters=( $( grep "Inversion done" ${filename} | grep iterations | awk '{print $5 }' ) )
      # the true residual is decorated with an exclamation mark...
      residues=( $( grep "Inversion done" ${filename} | grep iterations | awk '{print $10 }' | sed 's/!//g' ) )
      if [ $DEBUG -eq 1 ]; then
        echo dirname = $dirname
        echo filename = $filename
        echo
      fi
      for i in $( seq 0 $(( ${#iters[@]} - 1 )) ); do
        echo $kappa $valeta $conf ${iters[i]} ${residues[i]}  >> ${ofile}
      done
    done
  done
  echo ${ofile}
done
