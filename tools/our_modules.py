import csv, collections, sys
BS = chr(92)
mods = collections.defaultdict(set)
rows = list(csv.reader(open('tables_strings.csv', encoding='utf-8', errors='replace')))
marker = 'dancer' + BS + 'modules' + BS          # after CSV unescaping there is a single backslash
seen_paths = 0
for r in rows:
    for field in r:
        idx = field.find(marker)
        if idx < 0:
            continue
        rest = field[idx + len(marker):]
        pieces = rest.split(BS)          # e.g. ['sqMotion', 'src', 'sqmoKey.c']
        if len(pieces) >= 3 and pieces[-1].endswith('.c'):
            mods[pieces[0]].add(pieces[-1])
            seen_paths += 1
for mod in sorted(mods):
    print("  %-12s %2d files : %s" % (mod, len(mods[mod]), ', '.join(sorted(mods[mod]))))
print("OUR-BUILD dancer modules:", len(mods), "| source-file paths:", seen_paths)
