This jobscript generator creates job scripts and input files for inversions
of FR BSM model with gauge and scalar fields.

The jobscript generation is driven by the executable shell script

```generate_jobs.sh``` 

which takes a parameter file as input. The FR BSM
model couples SU(3) gauge fields, two flavours of SU(3)-charged quark fields
and a doublet of complex scalar fields (represented by four real scalars).
Hence, inversions require at least one gauge field and one scalar field,
but likely multiple scalar fields are required for each gauge configuration.

The job generation operates on a collection of gauge configurations and a
collection of scalar configurations. The python script ```scalar_combinator.py``` 
is used internally to generate a unique sample of scalar configurations
for each gauge configuration. Alternatively, the same sample of scalar
configurations can be used for all gauge configurations. Other modes are
currently not available (such as stepping through the scalar field
collection in the direction of molecular dynamics time in that sector, rather than
randomly).

Currently, the generator is only suitable for the PBS batch scheduler,
although it can rather easily be adapted. One job scrill per gauge field
configuration will be generated.

The parameter file specifies the following options:

```
# a name for the job to be generated -> ends up in the job script as a job identifier
name='inversion'
# starting gauge configuration
conf_start=0
# last gauge configuration to be used
conf_end=0
# step between gauge configurations
conf_step=0
# number of scalars per gauge configuration
npergauge=0
# use the same set of scalars for all gauge configurations
resuse_scalars=0
# full path to the directory containing the scalar fields
scalars_dir='.'
# full path to the directory contining the gauge fields
gauges_dir='.'
# directory (will be created if it doesn't exist) where the jobscript and input
# files should be deposited
jdir='.'
# seed for the random number generator used to sample the scalar field collection
scalar_rng_seed=123456
# seed for the tmLQCD random number generator, important for stochastic sources
tmlqcd_rng_seed=123456
# full path and filename to the template job script for the jobs
jscr='jscr.template'
# full path and filename to the template tmLQCD input file for the jobs
ifile='template.input
# full path to the tmLQCD invert executable
executable="path_to/invert"
```

As can be seen above, a template input file for tmLQCD must be prepared.
The job script generator will replace the following capitalised strings:

``` 
# seed for the tmLQCD random number generator  ( -> tmlqcd_rng_seed)
seed = SEED
# configuration number to be processed ( one of conf_start...conf_step...conf_end ) 
InitialStoreCounter = NSTORE
# number of scalar fields per gauge configuration ( -> npergauge)
npergauge = NPERGAUGE
```

Similarly a template job script must be provided which will be subjected
to the following replacements of the capitalised strings

NAME, EXEC, JDIR

```
# job name ( -> name + further specifiers )
#PBS -N NAME
date > NAME.log

# tmLQCD invert executable
efile=EXEC

# job working directory
cd JDIR
```

The jobscript generator would thus be run like

```
./generate_jobs.sh $path_to_params/paramfile.params
```

.

--------------------------
May 2016, Bartosz Kostrzewa

