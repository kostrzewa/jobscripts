nds=(64 128)
lvls=(2 3)
iters=(3 4 5)
mucoarse=(4.0 4.5 5.0 5.5 6.0 6.5 7.0 7.5 8.0 8.5 9.0 9.5 10.0 10.5 11.0 11.5 12.0)
nvecs=(16 20 24 28 32)

test_run=0

nmeas=2

base_ofile=timings.dat
base_mfile=missing.dat

dt=$(date)

for nd in ${nds[@]}; do
  ofile=nds${nd}_${base_ofile}
  mfile=nds${nd}_${base_mfile}
  echo "# $dt" > $ofile
  echo "nds setupiter lvl nvec mucoarse setuptime setupcgrid solvetime solvecgrid solvefiter solveciter" >> $ofile
  echo "# $dt" > $mfile
  
  for iter in ${iters[@]}; do
    for lvl in ${lvls[@]}; do
      for nvec in ${nvecs[@]}; do
        for muc in ${mucoarse[@]}; do
          job=nds${nd}_iters${iter}_nlevel${lvl}_nvec${nvec}_mucoarse${muc}
          wdir=$(pwd)/${job}
          sfile=$wdir/outputs/${job}.64.L64.DDalphaAMG.test.out
          if [ ! -f $sfile ]; then
            echo $wdir >> $mfile
            continue
          else
            echo $sfile
          fi
          setuptime=$(grep "setup ran" $sfile | awk '{print $5}')
          setupcgrid=$(grep "setup ran" $sfile | awk '{print $7}' | sed 's/(//g')
          if [ -z ${setuptime} ]; then
            if [ $test_run -eq 1 ]; then
              exit 1
            fi
            echo $wdir >> $mfile
            continue
          fi
          
          temp=( $(grep "Solving time" $sfile | awk '{print $3}') )
          solvetime=0
          for num in ${temp[@]}; do
            solvetime=$( echo "scale=2; $solvetime + $num" | bc -l )
          done
          solvetime=$( echo "scale=2; $solvetime / $nmeas" | bc -l )
  
          temp=( $(grep "Solving time" $sfile | awk '{print $5}' | sed 's/(//g') )
          solvecgrid=0
          for num in ${temp[@]}; do
            solvecgrid=$( echo "scale=2; $solvecgrid + $num" | bc -l )
          done
          solvecgrid=$( echo "scale=2; $solvecgrid / $nmeas" | bc -l )

          temp=( $(grep "Total iterations on fine grid" $sfile | awk '{print $6}') )
          solvefiter=0
          for num in ${temp[@]}; do
            solvefiter=$( echo "scale=2; $solvefiter + $num" | bc -l )
          done
          solvefiter=$( echo "scale=2; $solvefiter / $nmeas" | bc -l )
          
          temp=( $(grep "Total iterations on coarse grids" $sfile | awk '{print $6}') )
          solveciter=0
          for num in ${temp[@]}; do
            solveciter=$( echo "scale=2; $solveciter + $num" | bc -l )
          done
          solveciter=$( echo "scale=2; $solveciter / $nmeas" | bc -l )

          echo "$nd $iter $lvl $nvec $muc $setuptime $setupcgrid $solvetime $solvecgrid $solvefiter $solveciter" >> $ofile
  
          if [ $test_run -eq 1 ]; then
            exit 0
          fi
        done
      done
    done
  done
done
