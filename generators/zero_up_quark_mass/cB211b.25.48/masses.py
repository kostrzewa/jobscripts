#!/usr/bin/python
import math

kappa=0.1394267
mu_l=0.0025
mu_s=0.0185
shift=0.0037
delta_s=math.sqrt(2.0/3.0)
signs=[+1.0, -1.0]

print( 2*kappa*mu_l )
print( "u" )
print( 2*kappa*mu_s )
print( "sp{0:.10f}".format( mu_s ) )

for power in range(0,8):
    for sign in signs: 
        mu_s_shifted=mu_s + sign*shift*delta_s**power
        print( 2*kappa*mu_s_shifted )
        print( "sp{0:.10f}".format( mu_s_shifted ) )

