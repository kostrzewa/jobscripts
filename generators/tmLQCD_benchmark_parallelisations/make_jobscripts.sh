#!/bin/bash

Ls=(24 32 48 64)
Nnds=(8 16 32 36 64 72)
Ntpn=(1 2 4 8 16 32 64)
Ntpt=(1 2 3 4 6 8 12 16 24 32 64 128 256)

gcd() {
  a=$1
  b=$2

  while [ $b -ne 0 ]; do
    t=$b
    b=$(( $a % $b ))
    a=$t
  done

  echo $a
}

for L in ${Ls[@]}; do
  for nds in ${Nnds[@]}; do
    for tpn in ${Ntpn[@]}; do
      nx=1
      ny=1
      nz=1
      nt=1

      nmpi=$(( $tpn * $nds ))

      # we have 34 tiles with 2 cores each available for compute tasks
      # for practicality reasons, we will idle 2 tiles and work with 64 cores
      # per node only
      # the 32 remaining tiles are arranged in a 2D mesh network (roughly),
      # so we want to make sure that we can parallelize the two innermost
      # directions (Y and Z) on the card, whether this is done via threads
      # or processes is immaterial
      # we want to ensure that at least two lattice sites remain in each direction
      # but one could imagine replacing the "2" below by "3", "4", "6" or "8"
      # depending on the lattice size and other requirements
      ny=$( gcd $(( $L / 2 )) $tpn )
      nz=$( gcd $(( $L / 2 )) $(( $tpn / $ny )) )

      # T and X directions will be parallelized across the nodes
      # note: T = 2L, factor drops out
      nt=$( gcd $(( 2 * $L / 2 )) $nds )
      nx=$( gcd $(( $L / 2 )) $(( $nds / $nt )) )

      # if the algorithm above has chosen the number of processes in Y much larger than  
      # the number of processes in Z, exchange a factor of two, if possible
      if [ $ny -gt $(( 2 * $nz )) -a $(( $ny % 2 )) -eq 0 ]; then
        ny=$(( $ny / 2 ))
        nz=$(( $nz * 2 ))
      fi
     
      # if the algorithm above has chosen the number of processes in T much larger than  
      # the number of processes in X, exchange a factor of two, if possible
      if [ $nt -gt $(( 4 * $nx )) -a $(( $nt % 2 )) -eq 0 ]; then
        nt=$(( $nt / 2 ))
        nx=$(( $nx * 2 ))
      fi

      if [ $(( $ny * $nz )) -lt $tpn ]; then
        echo "unable to find on-node parallelisation for L=$L, tpn=$tpn"
        continue
      fi

      if [ $(( $nt * $nx )) -lt $nds ]; then
        echo "unable to find inter-node parallelisation for L=$L, nds=$nds"
        continue
      fi
      
      echo L=$L nds=$nds tpn=$tpn nt=$nt nx=$nx ny=$ny nz=$nz 
      
      for tpt in ${Ntpt[@]}; do
        cupn=$(( $tpn * $tpt ))        
        # we want to check up to 256 compute units per node, no more than that
        # we also want to run with no fewer than 32 compute units per node
        if [ $cupn -gt 256 -o $cupn -lt 32 ]; then 
          continue 
        fi

        wdir=$( printf /marconi_work/INF17_lqcd123_0/KNL_benchmarks/tmLQCD/normal/L%02d_nds%03d_tpn%02d_tpt%03d $L $nds $tpn $tpt )
        jfile=benchmark.$( printf L%02d_nds%03d_tpn%02d_tpt%03d $L $nds $tpn $tpt ).sh
        mkdir $wdir

        if [ -f ${wdir}/benchmark.input ]; then
          rm $wdir/benchmark.input
        fi
        cp benchmark.input.template $wdir/benchmark.input
        sed -i "s/Ls/${L}/g" $wdir/benchmark.input
        sed -i "s/Ts/$(( 2 * $L))/g" $wdir/benchmark.input
        sed -i "s/NTHREADS/${tpt}/g" $wdir/benchmark.input
        sed -i "s/NX/${nx}/g" $wdir/benchmark.input
        sed -i "s/NY/${ny}/g" $wdir/benchmark.input
        sed -i "s/NZ/${nz}/g" $wdir/benchmark.input

        if [ -f $wdir/${jfile} ]; then
          rm $wdir/${jfile}
        fi
        cp benchmark.job.template $wdir/${jfile}
        sed -i "s/LLL/${L}/g" $wdir/${jfile}
        sed -i "s/NDS/${nds}/g" $wdir/${jfile}
        sed -i "s/TPN/${tpn}/g" $wdir/$jfile
        sed -i "s/TPT/${tpt}/g" $wdir/$jfile
        sed -i "s@WDIR@${wdir}@g" $wdir/$jfile

      done
        
    done
  done
done



