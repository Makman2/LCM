from collections import defaultdict
import csv
from functools import partial
from operator import itemgetter
import sys


listdefaultdict = partial(defaultdict, list)


def all_elements_equal(iterator):
    iterator = iter(iterator)
    try:
        first = next(iterator)
        return all(first == rest for rest in iterator)
    except StopIteration:
        return True


def mean(iterator):
    count = 0
    summed = 0

    for elem in iterator:
        count += 1
        summed += elem

    return summed / count


def main():
    files = {'nF': 'calibration_nF.csv',
             'microF': 'calibration_microF.csv',
             'mF': 'calibration_mF.csv'}

    data = defaultdict(listdefaultdict)
    # Collect calibration data from CSV files.
    for domain, file in files.items():
        with open(file, newline='') as csvfile:
            # cid is the ID of one specific capacitor used.
            reader = csv.reader(csvfile)
            for cid, capacitance, real_capacitance in reader:
                data[domain][cid].append(
                    (float(capacitance), float(real_capacitance)))

    q = {}
    # Calculate calibration values using means.
    for domain, domain_data in data.items():
        # Check that the desired capacitance does not change for the same
        # capacitor id.
        for cid, capacities in domain_data.items():
            if not all_elements_equal(real_capacitance
                                      for capacitance, real_capacitance
                                      in capacities):
                print("DATA FAILURE - Inequality in desired capacitance found "
                      "for CID {}.".format(cid), file=sys.stderr)
                return 1

        # Get the (real_capacitance, mean_measured_capacitance) pairs.
        capacitors_means = list(
            (domain_data[cid][0][1], mean(capacitance
                                          for capacitance, real_capacitance
                                          in capacities))
            for cid, capacities in domain_data.items())

        # Calculate correction factor q. We assume that the real capacitance is
        # the target capacitance of the capacitor written on it.
        # q = C_real / C_measured
        q[domain] = mean(c_real / c_measured
                         for c_real, c_measured in capacitors_means)

    # Print stuff.
    print()

    print('Files used:')
    for file in sorted(files.values()):
        print('-', file)

    print()

    tablerow_formatstring = '{:8} {:<25}'
    head = tablerow_formatstring.format('domain', 'q')

    print(head)
    print('-' * len(head))

    # Sort by domain string for better readable output.
    sorted_q = sorted(q.items(), key=itemgetter(0))
    for domain, calibration_value in sorted_q:
        print(tablerow_formatstring.format(domain, calibration_value))

    print()


if __name__ == '__main__':
    sys.exit(main())
