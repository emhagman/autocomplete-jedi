#!/usr/bin/python

import jedi
import sys

source = sys.argv[1]
start = sys.argv[2]
length = sys.argv[3]


# print them
script = jedi.Script(source, int(start), int(length), '')
completions = script.completions()
for c in completions:
    print "%s:::%s" % (c.complete, c.name)
