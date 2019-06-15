#!/bin/bash

ens_id=cA211b.40.24
gauge_path=/hiskp4/gauges/nf211/${ens_id}/conf

if [ ! -f masses.py ]; then
  echo "masses.py could not be found!"
  exit 1
fi

# masses.py produces a sequence of 2*kappa*mu values and propagator labels
#   2*kappa*mu_1 label_1 2*kappa*mu_2 label_2 ...
# it starts with the light quark mass and then produces pairs of "strange"
# quark masses around 0.0185 with appropriate mass shifts
masses=( $(./masses.py) )

conf_start=4
conf_step=4
conf_end=1320

ts_rng_seed=22402448

Nt=48
nts=12
dts=$(( $Nt / $nts ))

echo "cid src_ts" > src_timeslices.dat

for cid in $( seq ${conf_start} ${conf_step} ${conf_end} ); do
  echo $cid

  c4=$(printf %04d ${cid})
  if [ ! -d ${c4} ]; then
    mkdir ${c4}
  fi

  # job script
  job_file=${c4}/job_${c4}.cmd
  cp templates/job.cmd.template ${job_file}
  sed -i "s/=ENS=/${ens_id}/g" ${job_file}
  sed -i "s/=NSTORE=/${c4}/g" ${job_file}

  # set up beginning of input file for tmLQCD interface
  invert_file=${c4}/invert.input
  cp templates/invert.header.template ${invert_file}
  sed -i "s/=NSTORE=/${cid}/g" ${invert_file}
  sed -i "s@=GAUGEPATH=@${gauge_path}@g" ${invert_file}

  # propagator and correlator definitions
  def_file=${c4}/definitions.yaml
  cp templates/definitions.header.template ${def_file}
  for mu_idx in $( seq 0 2 $(( ${#masses[@]} - 1 )) ); do
    kappa2mu=${masses[${mu_idx}]}

    # for each mass we need to add an operator to the tmLQCD
    # interface input file
    cat templates/operator_CLOVER.template >> ${invert_file}
    sed -i "s/=TWOKAPPAMU=/${masses[$mu_idx]}/g" ${invert_file}

    # time slice propagator definition for this quark mass
    cat templates/TimeSlicePropagator.template >> ${def_file}
    # this is the "idx" of the operator in the the tmLQCD
    # input file, starting at 0 
    sed -i "s/=SOLVER_ID=/$(( ${mu_idx} / 2 ))/g" ${def_file}
    sed -i "s/=ID=/${masses[$(( ${mu_idx} + 1 ))]}/g" ${def_file}
    
    # pion (for the first mass) and kaon (for all subsequent masses)
    cat templates/OetMesonTwoPointFunction.template >> ${def_file}
    sed -i "s/=TWOPT_ID=/${masses[$(( ${mu_idx} + 1 ))]}+-g-${masses[1]}-g/g" ${def_file}
    sed -i "s/=FWD_FLAV=/${masses[1]}/g" ${def_file}
    sed -i "s/=BWD_FLAV=/${masses[$(( ${mu_idx} + 1 ))]}/g" ${def_file}

    # for the strange quark masses, we can also compute the "charged" eta meson
    if [ ${mu_idx} -gt 0 ]; then
      # "charged" eta meson
      cat templates/OetMesonTwoPointFunction.template >> ${def_file}
      sed -i "s/=TWOPT_ID=/${masses[$(( ${mu_idx} + 1 ))]}+-g-${masses[$(( ${mu_idx} + 1 ))]}-g/g" ${def_file}
      sed -i "s/=FWD_FLAV=/${masses[$(( ${mu_idx} + 1 ))]}/g" ${def_file}
      sed -i "s/=BWD_FLAV=/${masses[$(( ${mu_idx} + 1 ))]}/g" ${def_file}
    fi

  done # mu_idx

  # input file for CVC which defines the source locations and the
  # seed for the RNG
  # note that a single seed is used for the entire replica as
  # it is XOR'ed with the configuration number
  cvc_file=${c4}/cpff.input
  cp templates/cpff.input.template ${cvc_file}
  # we will use ${ts_rng_seed} also in the cvc input file, this is absolutely no problem
  sed -i "s/=SEED=/${ts_rng_seed}/g" ${cvc_file}

  # obtain a random time slice for the first source
  ts1=$(./rng.py --seed ${ts_rng_seed} --cid ${cid} --Nt ${Nt})
  echo ts1=$ts1
  src_ts=( ${ts1} )
  # all other source time slices are at maximal uniform separation
  # from this starting time slice
  for i in $(seq 1 $(( $nts -1 )) ); do
    new_ts=$(( (${ts1} + ${i}*${dts}) % ${Nt} ))
    src_ts+=( ${new_ts} )
  done
  for i in $(seq 0 $(( $nts - 1 )) ); do
    echo $cid ${src_ts[${i}]} >> src_timeslices.dat
    echo "source_coords = ${src_ts[${i}]},0,0,0" >> ${cvc_file}
  done

done # cid
