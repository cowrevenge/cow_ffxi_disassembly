import csv, re
BS=chr(92)
rows=list(csv.reader(open('tables_strings.csv', encoding='utf-8', errors='replace')))
pat=re.compile(r'^C:'+BS+BS+'dev'+BS+BS+r'.+')
out=set()
for r in rows[1:]:
    for f in r:
        f=f.replace('"','')
        if BS*2 in f or f.startswith('C:'+BS):
            m=pat.match(f.replace(BS,BS)) 
            cand=f.strip()
            if cand.startswith('C:'+BS+'dev'): out.add(cand)
for p in sorted(out): print("  ",p)
print("unique:",len(out))
