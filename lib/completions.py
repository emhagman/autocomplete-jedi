#!/usr/bin/python

import jedi
import sys

source = sys.argv[1]
start = sys.argv[2]
length = sys.argv[3]
path = sys.argv[4]


# print them
script = jedi.Script(source, int(start), int(length), path)
completions = script.completions()
for c in completions:
    print "%s:::%s:::%s" % (c.name, c.complete, c.type)
