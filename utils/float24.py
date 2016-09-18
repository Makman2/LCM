def bin_to_int(x):
    """
    Extension to ``int(x, 2)`` which also allows to convert from fixed point
    notation.

    >>> bin_to_int('1.1')
    1.5
    >>> bin_to_int('10.111')
    2.875
    >>> bin_to_int('111')
    7

    :param x: The binary string.
    :return:  The number represented by ``x``.
    """
    if x.startswith('0b'):
        x = x[2:]

    dot_pos = x.find('.')
    if dot_pos == -1:
        result = int(x, 2)
        return result
    else:
        result = int(x[:dot_pos], 2)
        fact = 1
        for letter in x[dot_pos+1:]:
            fact <<= 1
            result += int(letter) / fact
        return result


def float24_to_real(x):
    """
    Converts a float24 (in integer format) to a real float.

    >>> float24_to_int(0b010000000000000000000000)
    2.0
    >>> float24_to_int(0xC30400)
    -16.25

    :param x: The float24 to convert.
    :return:  The real number.
    """
    b = bin(x)[2:]
    # Pad with zeros
    b = "0" * (24 - len(b)) + b
    sign = (-1) ** int(b[0])
    exponent = int(b[1:8], 2) - 63
    frac = bin_to_int("1." + b[8:])
    return sign * 2**exponent * frac


def to_float24(x):
    """
    Converts any number (as close as possible) to a float24.

    >>> to_float24(0)
    0
    >>> hex(to_float24(1))
    '0x3f0000'
    >>> hex(to_float24(3.75))
    '0x40e000'

    :param x: The number to convert.
    :return:  The float24.
    """
    if x == 0:
        return 0

    # Calculate sign bit.
    if x < 0:
        s = '1'
        x *= -1
    else:
        s = '0'

    shifts = 0
    if x >= 1:
        # Divide by 2 until less 2.
        while x >= 2:
            x /= 2
            shifts += 1
    else:
        # Multiply with 2 until 1.
        while x < 1:
            x *= 2
            shifts -= 1

    # Compute exponent.
    e = bin(shifts + 63)[2:]
    e = "0" * (7 - len(e)) + e

    # Subtract implicit '1'.
    x -= 1

    # Approximate x now as close as possible.
    digits = ''
    factor = 1
    for i in range(16):  # 16 because our fraction is that long.
        factor /= 2

        if factor <= x:
            digits += '1'
            x -= factor
        else:
            digits += '0'

    return int(s + e + digits, 2)
