from math import ceil, log2
import sys

from float24 import bin_to_int


digits = 2
relative_precision = 0.05
label = 'float24printtable'


def print_table():
    needed_precision = -ceil(log2(relative_precision**digits))

    combinations = int(2**needed_precision)
    tablesize = digits * 2**needed_precision
    print('; {} most significant bits required.'.format(needed_precision))
    print('; This table requires {} bytes.'.format(tablesize))

    print('{}:'.format(label))

    digit_list = []
    for x in range(2**needed_precision):
        xbin = bin(x)[2:]
        # Pad with zeros if necessary.
        xbin = '0' * (needed_precision - len(xbin)) + xbin
        db = ('{:.' + str(digits) + 'f}').format(
            round(bin_to_int('0.' + xbin), digits))[2:]

        digit_list.append(db)

    # Convert trailing zero values to '9999...', as we accidentally round over
    # which would result into an absolute error of 1!
    first_nines = next(i
                       for i, elem in
                       enumerate(reversed(digit_list)) if elem != '0' * digits)

    if first_nines != 0:
        digit_list = digit_list[:-first_nines] + ['9' * digits] * first_nines

    # Assemble lines
    for db in digit_list:
        print(' ' * 4 + '.db "{}"'.format(db))


def main():
    print_table()


if __name__ == '__main__':
    sys.exit(main())
