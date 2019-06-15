#!/usr/bin/python
import math

kappa=0.1400645
mu_l=0.0053

# the stange quark massses that we have used in the PLNG and flavour_singlet projects
# are: 0.0176 0.0220 0.0264
mu_s=0.0220
shift=0.0044
# let's be more agressive and use sqrt(1/2)
delta_s=math.sqrt(1.0/2.0)
signs=[+1.0, -1.0]

print( 2*kappa*mu_l )
print( "u" )
print( 2*kappa*mu_s )
print( "sp{0:.10f}".format( mu_s ) )

for power in range(0,5):
    for sign in signs: 
        mu_s_shifted=mu_s + sign*shift*delta_s**power
        print( 2*kappa*mu_s_shifted )
        print( "sp{0:.10f}".format( mu_s_shifted ) )

