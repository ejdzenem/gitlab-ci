#!/usr/bin/python3

import argparse

from packaging.version import Version
from sys import exit

description="""
Script compares version1 with version2. If the version1 is less than version2,
then script exits with exit code 0, otherwise it exits with exit code 1. It is
useful for comparing versions between two environments.

Versioning scheme follows Python's PEP440 specification.
More at https://www.python.org/dev/peps/pep-0440/

Script is using Python's module named packaging.
More at https://pypi.org/project/packaging/

  $ pip install packaging

exit codes:
  0     If version1 is less than version2.
  1     If version1 is higher or equals version2.
  2     If any input value does not comply with PEP440 recommendation or other
        unxepected error.
"""

parser = argparse.ArgumentParser(description=description, formatter_class=argparse.RawTextHelpFormatter)
parser.add_argument("version1", type=Version, help="the first version number")
parser.add_argument("version2", type=Version, help="the second version number")
parser.add_argument("-v", "--verbose", action="store_true", help="print output message")
args = parser.parse_args()

if args.version1 < args.version2:
    if args.verbose:
        print("{} is lower version than {}, exit 0".format(args.version1, args.version2))
else:
    if args.verbose:
        print("{} is higher version than {}, exit 1".format(args.version1, args.version2))
    exit(1)
