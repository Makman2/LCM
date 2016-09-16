# LCM

Software written in assembly for a custom made capacitance measuring board.

## Conventions

As the codebase is written in assembly (sadly), some conventions need to be
defined to simplify and unify special cases.

### General

- 8bit Return values reside in r16 (if not mentioned else). Pointer values
  reside in Z (if not mentioned else).
- Multiple return values are allowed (but shall be documented explicitly!).
- Labels:
  - If it's a function entry point: Arbitrary name
  - If it's a branch/jump destination:
    `_<asm-filename>_<function-name>_<some-random-qualifier>`

### Headers

- File-ending: `.asm` (As headers need to contain the code and no external
  referencing is allowed due to the AVR assembly dialect)
- Include guards shall be used with following naming convention:
  ```
  .ifndef LCM_SUBDIRECTORY_FILENAME
  .def LCM_SUBDIRECTORY_FILENAME

  ; code ...

  .endif
  ```

### Numerics

- Little-Endianness: AVR uses Little-Endian too.
- Little-Endianness for registers: If there's no explicitly mentioned
  exception, lower register numbers have less numeric significance than higher
  register numbers.

### Objects

Sometimes `struct` or `class` are quite useful regarding their working
principle. In this case following implementation details are specified:

- An object is a bunch of values stored in memory (either heap or stack).
- The object origin/start-address begins at the lowest address.
- Constructors and destructors have following naming convention:
  ```
  <object-name>_create
  <object-name>_destroy
  ```
- If documentation of an object states that it's "primitive", then no
  destructor exists. "Primitive" means that an object does not need explicit
  destruction handling, so just deallocating the occupied memory or abandoning
  the object suffices.
- Member functions have following naming convention:
  ```
  <object-name>_<name-of-the-function>
  ```
- Constructors, destructors and member functions accept always the pointer to
  the object inside the `Z` register (`r31:30`). The `Z` register needs to be
  restored back to the old value when done!
