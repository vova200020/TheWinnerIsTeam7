import fitz, re, json, sys
PDF = r'notes/temp_notes/ASD-STE100_ISSUE9.pdf'
OUT = sys.argv[1]
d = fitz.open(PDF)
POS  = re.compile(r'\((n|v|adj|adv|prep|conj|pron|art|TN|TV)\)')
INFL = re.compile(r"^\(?[A-Z][A-Z\-' ]*[,)]?$")
rows, pages, skipped = [], 0, []
for i in range(len(d)):
    p = d[i]; txt = p.get_text()
    if 'Part 2 - Dictionary' not in txt or 'Approved meaning' not in txt: continue
    if 'Guide to the dictionary' in txt: continue
    spans = []
    for b in p.get_text('dict')['blocks']:
        if b['type'] != 0: continue
        for l in b['lines']:
            for s in l['spans']:
                t = s['text'].strip()
                if t: spans.append((round(s['bbox'][0],1), round(s['bbox'][1],1), t))
    # per-page column detection from the table header row
    hdr = {t: x for x, y, t in spans if t in ('Word', 'Approved meaning/', 'STE EXAMPLE', 'Non-STE example')}
    if 'Word' not in hdr or 'Approved meaning/' not in hdr:
        skipped.append(i+1); continue
    c1, c2 = hdr['Word'], hdr['Approved meaning/']
    c3 = hdr.get('STE EXAMPLE', c2 + (c2 - c1) * 1.2)
    pages += 1
    col1 = sorted((y, t) for x, y, t in spans
                  if c1-6 <= x < c2-6 and 60 < y < 715
                  and not t.startswith(('Word', '(part of speech', 'Approved meaning')) and t != 'ALTERNATIVES')
    col2 = sorted((y, t) for x, y, t in spans
                  if c2-6 <= x < c3-6 and 60 < y < 715
                  and not t.startswith(('Approved meaning',)) and t != 'ALTERNATIVES')
    ents = []
    for y, t in col1:
        if ents and (not POS.search(ents[-1][1]) or INFL.match(t)):
            ents[-1][1] = (ents[-1][1] + ' ' + t).strip()
        else:
            ents.append([y, t])
    for k, (y, name) in enumerate(ents):
        y_hi = ents[k+1][0] - 2 if k+1 < len(ents) else 9999
        alt = ' '.join(t for yy, t in col2 if y - 4 <= yy < y_hi)
        head = re.sub(r'\s*\(.*$', '', name).strip().rstrip(',')
        rows.append({'p': i+1, 'entry': name, 'head': head, 'approved': head.isupper(), 'col2': alt.strip()})
a = sum(1 for r in rows if r['approved'])
print(f'word-list pages={pages}  entries={len(rows)}  approved={a}  not_approved={len(rows)-a}')
print(f'spec: 875 approved / 1274 not approved = 2149 total; skipped pages (no header row): {len(skipped)}')
json.dump(rows, open(OUT, 'w', encoding='utf-8'), indent=0, ensure_ascii=False)
