#!/usr/bin/env python
"""Write docs/oracles/data/mcd43c3.toml from the records of the MCD43C3 extract, and parse it back.

Usage: mcd43c3_manifest.py --data DIR --repo REPO --corrected YYYY-MM-DD --residual X

Reads DIR/rules.json, DIR/manifest.jsonl, DIR/excluded.jsonl, DIR/climatology.jsonl and DIR/replaced_months.json,
and the recipes under REPO/oracles/recipes for their sha256. --corrected and --residual are the date and the
largest residual set to zero that mcd43c3_window_correction.py printed. Refuses unless excluded.jsonl is exactly
the reduced granules dated outside the window and replaced_months.json exists. Writes one [[granule]] per
granule in the window, one [[excluded_granule]] per removed granule and one [[climatology]] per climatology file,
then parses the file and checks those counts.
"""
import argparse, datetime as dt, hashlib, json, os, sys, tomllib

ap = argparse.ArgumentParser()
ap.add_argument('--data', required=True); ap.add_argument('--repo', required=True)
ap.add_argument('--residual', required=True); ap.add_argument('--corrected', required=True)
a = ap.parse_args()
data, repo = os.path.abspath(a.data), os.path.abspath(a.repo)


def sha(p):
    h = hashlib.sha256()
    with open(p, 'rb') as f:
        for c in iter(lambda: f.read(1 << 22), b''): h.update(c)
    return h.hexdigest()


def refuse(msg):
    print('REFUSED:', msg); sys.exit(1)


q = json.dumps
rules = json.load(open(os.path.join(data, 'rules.json')))
lo, hi = (dt.date.fromisoformat(x) for x in rules['window'])
nominal = lambda n: dt.datetime.strptime(n.split('.')[1][1:], '%Y%j').date()
recs = [json.loads(l) for l in open(os.path.join(data, 'manifest.jsonl'))]
excl = [json.loads(l) for l in open(os.path.join(data, 'excluded.jsonl'))]
clim = [json.loads(l) for l in open(os.path.join(data, 'climatology.jsonl'))]
replaced_path = os.path.join(data, 'replaced_months.json')
if not os.path.exists(replaced_path): refuse(replaced_path + ' is absent')
replaced = json.load(open(replaced_path))
inside = [r for r in recs if lo <= nominal(r['granule']) <= hi]
if {r['granule'] for r in recs} - {r['granule'] for r in inside} != {r['granule'] for r in excl}:
    refuse('excluded.jsonl is not the set of reduced granules dated outside the window')
days = {lo + dt.timedelta(i) for i in range((hi - lo).days + 1)}
missing = sorted(days - {nominal(r['granule']) for r in inside})
recipe = lambda n: os.path.join(repo, 'oracles', 'recipes', n)

L = []
w = L.append
w('# MCD43C3 v061: MODIS BRDF/albedo, daily, 0.05 degree CMG, reduced to a monthly climatology of black-sky and white-sky albedo, all-valid and snow-free')
w('')
w('id = "mcd43c3"')
w('title = "MODIS/Terra+Aqua BRDF/Albedo Model Parameters Daily L3 Global 0.05Deg CMG V061"')
w('publisher = "NASA LP DAAC"')
w('doi = "10.5067/MODIS/MCD43C3.061"')
w('source = "https://data.lpdaac.earthdatacloud.nasa.gov/lp-prod-protected/MCD43C3.061/"')
w(f'window = [{lo.isoformat()}, {hi.isoformat()}]')
w('fetched = 2026-09-12  # the last granule of the first reduction; the first was reduced on 2026-09-08')
w('local_path = "oracles/data/mcd43c3"  # untracked extract')
w('recipe = "oracles/recipes/mcd43c3_reduce.py"')
w(f'recipe_sha256 = {q(sha(recipe("mcd43c3_reduce.py")))}')
w('first_reduction_sha256 = "0e58357decc531bafbcadc21d83c13d74d79af55d5b1b2339353b5a807dcb15b"  # mcd43c3_reduce.py at a144b59')
for field, n in (('correction', 'mcd43c3_window_correction.py'), ('replace_months', 'mcd43c3_replace_months.py'),
                 ('count_ceiling', 'mcd43c3_count_ceiling.py'), ('climatology_recipe', 'mcd43c3_climatology.py'),
                 ('manifest_recipe', 'mcd43c3_manifest.py')):
    w(f'{field} = "oracles/recipes/{n}"')
    w(f'{field}_sha256 = {q(sha(recipe(n)))}')
w('oracles = ["earth.modis_albedo_by_class"]')
w('anchors = ["M7"]')
w('')
w('[reduction]')
w('rules_file = "rules.json"')
w(f'rules_sha256 = {q(sha(os.path.join(data, "rules.json")))}')
w(f'all_variant = {q(rules["all_variant"])}')
w(f'snowfree_variant = {q(rules["snowfree_variant"])}')
w(f'declared_before_first_granule = {str(rules["declared_before_first_granule"]).lower()}')
w('granule_in_window = "the nominal date, the AYYYYDDD field of the granule name, lies in window"')
w('month = "the calendar month of the nominal date"')
w('valid_value = "raw value in 0 to 32766, 32767 the fill, scaled by 0.001; Albedo_Quality 255 and Percent_Snow 255 the fill"')
w('fine_grid = "0.05 degree CMG, 3600 rows from 90 N by 7200 columns from 180 W: BSA and WSA shortwave, vis and nir, and Percent_Snow"')
w('coarse_grid = "0.25 degree, 720 by 1440: BSA and WSA Band1 to Band7, the sum and count of valid 0.05 degree cells over each 5 by 5 block"')
w('accumulators = "<variant>_<kind>_<band>_sum.mm (float32) and <variant>_<kind>_<band>_cnt.mm (uint16), snowpct_sum.mm and snowpct_cnt.mm, 12 months each"')
w('climatology = "climatology_<name>.npz for each accumulator pair: mean (float32, sum over count, NaN where the count is zero) and count (uint16)"')
w('count_ceiling = "no cell count above the granules dated in its month, 25 times that on the 0.25 degree bands"')
w('raw_granules_retained = false')
w(f'granules_in_window = {len(inside)}')
w(f'days_without_a_granule = [{", ".join(d.isoformat() for d in missing)}]  # the temporal search returned no granule for these dates')
w('')
w('[window_correction]')
w(f'corrected = {a.corrected}')
w(f'granules_removed = {len(excl)}')
w(f'months = {q(sorted({nominal(r["granule"]).month for r in excl}))}')
w('rule = "each granule refetched by name with its recorded bytes and sha256, reduced again to its recorded QA histogram and snow-free fraction, and its sums and counts subtracted; a sum whose count reaches zero is set to zero"')
w(f'largest_residual_set_to_zero = {a.residual}')
w('')
w('[replaced_months]')
w(f'months = {q(replaced["months"])}')
w(f'granules = {replaced["granules"]}')
w('rule = "every accumulator slot of these months copied from a reduction of the same granules from zero by the batch-committing recipe, after the first reduction counted a granule in each twice in part"')
w(f'source_manifest_sha256 = {q(replaced["source_manifest_sha256"])}')
w(f'source_rules_sha256 = {q(replaced["source_rules_sha256"])}')
w('')
w('# Every file of the climatology.')
for c in clim:
    w('[[climatology]]')
    w(f'name = {q(c["name"])}'); w(f'file = {q(c["file"])}'); w(f'shape = {q(c["shape"])}')
    w(f'bytes = {c["bytes"]}'); w(f'sha256 = {q(c["sha256"])}'); w('')
w('# Every source granule reduced into the extract, so it can be traced to bytes and regenerated.')
for r in inside:
    w('[[granule]]'); w(f'name = {q(r["granule"])}'); w(f'date = {r["date"]}'); w(f'bytes = {r["bytes"]}'); w(f'sha256 = {q(r["sha256"])}'); w('')
w('# Every granule the temporal search returned outside the window, reduced and then removed by the correction.')
for r in excl:
    w('[[excluded_granule]]'); w(f'name = {q(r["granule"])}'); w(f'date = {r["date"]}'); w(f'bytes = {r["bytes"]}'); w(f'sha256 = {q(r["sha256"])}'); w('')

out = os.path.join(repo, 'docs', 'oracles', 'data', 'mcd43c3.toml')
open(out, 'w').write('\n'.join(L).rstrip('\n') + '\n')
t = tomllib.load(open(out, 'rb'))
assert len(t['granule']) == len(inside) and len(t['excluded_granule']) == len(excl) and len(t['climatology']) == len(clim)
print(out, 'granules', len(inside), 'excluded', len(excl), 'climatology files', len(clim), 'days without a granule', [d.isoformat() for d in missing])
