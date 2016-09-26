from enum import Enum
from math import log

from float24 import to_float24


DOMAIN = Enum('Domain', 'F mF microF nF pF')
DOMAIN_MAP = {DOMAIN.F: 1,
              DOMAIN.mF: 10**-3,
              DOMAIN.microF: 10**-6,
              DOMAIN.nF: 10**-9,
              DOMAIN.pF: 10**-12}

#===============================================================================

# These are the resistances used (in Ohm). The leftmost one is the first one
# enabled when using the turn-switch.
R = [0.5, 1000, 360000]
# These are the domains we show on the display. This allows numeric tuning for
# capacitance calculation.
measuring_domains = [DOMAIN.mF, DOMAIN.microF, DOMAIN.nF]

# Frequency of the timer in Hz. If no prescaling is used, this is the same like
# the CPU clock.
f = 16 * 10**6

# The connected capacitance charging voltage (in V).
V_charge = 5
# The voltage drop over the load mosfet (when loading capacitance, in V).
V_mosfet = 0.7
# The comparator threshold voltage (in V).
V_comparator_threshold = 1.23

# Correction factors.
correction_factors = [0.20771273621062544,
                      1.2042984670282875,
                      1.0953768519337752]

#===============================================================================

pins = ['PB0', 'PB1', 'PB2']

# From the formula
#
#   t = n * deltaT = -RC * log(1 - V_comparator_threshold/V_load) / q
#   --> C = - deltaT * n / (R * log(...)) * q
#
# (deltaT = 1 / f, n: Timer-cycles elapsed, q: correction factor)
#
# Some values can be precomputed:
#
#   kappa = - deltaT / (R * log(...)) * q = -q / (f * R * k)
#   (deltaT = 1 / f, k = log(...))
#
# So we get:
#
# C = kappa * n
#
# To optimize for measuring domine, we define
#
# C = [DOMAIN] = zeta * n, zeta = kappa / domain

V_load = V_charge - V_mosfet
k = log(1 - V_comparator_threshold / V_load)
kappas = list(-q / (f * r * k) for q, r in zip(correction_factors, R))
zetas =  list(kappa / DOMAIN_MAP[domain]
              for kappa, domain in zip(kappas, measuring_domains))

# Print stuff.
print()

print('Clock frequency (f): {}Hz'.format(f))
print('Charging voltage (V_charge): {}V'.format(V_charge))
print('Voltage drop at load MOSFET (V_mosfet): {}V'.format(V_mosfet))
print('Analog Comparator threshold (V_comparator_threshold): {}V'.format(
          V_comparator_threshold))
print()

tablerow_formatstring = '{:4} {:8} {:15} {:<10} {:<25} {:<25} {:10}'

head = tablerow_formatstring.format('PIN', 'R', 'Domain', 'q', 'kappa', 'zeta',
                                    'to_float24(zeta)')
print(head)
print('-' * len(head))

for pin, r, domain, q, kappa, zeta in zip(pins, R, measuring_domains,
                                          correction_factors, kappas, zetas):
    print(tablerow_formatstring.format(
        pin, r, domain, round(q, 5), kappa, zeta, hex(to_float24(zeta))))

print()
