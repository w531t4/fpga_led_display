import sys

target = sys.argv[1]
size = sys.argv[2]
with open(target, 'w') as f:
    for each in range(0, int(size)):
        f.write("00\n")