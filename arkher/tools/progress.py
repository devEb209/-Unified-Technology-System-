#!/usr/bin/env python3
"""Progress over explicit brief entries, never source-file counts or invented 10K items.

Partial implementation earns COVERAGE, not COMPLETION. No arbitrary 50% weights.
The 10K/100K formal targets remain independent and uncertified.
"""
from pathlib import Path
from collections import Counter
import hashlib
import json
import re

ROOT = Path(__file__).resolve().parents[2]
BRIEF_BLOB = '9f628f98e103d1fedea1a7c418ecb50ecdf21fcf'
NPC_ALIASES = {'perception':'NPC Perception','memory':'NPC Memory','goals':'NPC Goals','needs':'NPC Needs','personality':'NPC Personality','emotions':'NPC Emotion','decision making':'NPC Decision System','planning':'NPC Planning','learning':'NPC Learning','adaptation':'NPC Adaptation','relationships':'NPC Relationship System','routines':'NPC Routine'}


def extract(data):
    if hashlib.sha1(f'blob {len(data)}\0'.encode() + data).hexdigest() != BRIEF_BLOB:
        raise ValueError('Brief changed: review scope explicitly before changing the denominator')
    active, family, reference_list = False, None, False
    entries, seen, families = [], set(), {}
    for number, line in enumerate(data.decode('utf-8').splitlines(), 1):
        text = line.strip()
        if text.startswith('PARTE II '): active = True; continue
        if text.startswith('PARTE III '): break
        if not active: continue
        header = re.match(r'^([A-Z])\s+—\s+(.+)$', text)
        if header:
            family = header[1]; families[family] = header[2]; reference_list = False; continue
        if not family or not text or text == '---': continue
        if family == 'G' and text == 'Criar:': reference_list = False; continue
        if family == 'G' and text == 'Criar uma família própria inspirada nas capacidades modernas de:': reference_list = True; continue
        if reference_list: continue  # DLSS/FSR/etc. are references, not implementations to copy.
        if re.search(r'\d[.,\d]*\s*[–−]\s*\d', text): continue
        if text.startswith(('Sistemas ', 'Criar', 'Integrar', 'NPCs devem', 'Exemplos', 'Esta categoria',
                            'ARKHER não', 'E milhares', '+ ', 'centenas', 'milhares')) or text.endswith(':'): continue
        if text.startswith('- '): name = text[2:]
        elif re.match(r'^\d+\. ', text): name = re.sub(r'^\d+\. ', '', text)
        elif len(text) < 85 and not text.endswith('.') and not text.startswith(('A seguinte', 'Cada família')): name = text
        else: continue
        name = name.strip().rstrip(';').rstrip('.')
        original_name = name
        if family == 'K': name = NPC_ALIASES.get(name, name)
        key = family + '/' + name
        if key.casefold() in seen:
            next(entry for entry in entries if entry['id'].casefold() == key.casefold())['sourceMentions'].append({'line': number, 'name': original_name})
            continue
        seen.add(key.casefold())
        entries.append({'id': key, 'family': family, 'name': name, 'sourceLine': number, 'sourceMentions': [{'line': number, 'name': original_name}], 'status': 'not_implemented'})
    assert set(families) == set('ABCDEFGHIJKLMNOPQRSTUVWXYZ') and len(entries) >= 800
    return entries, families


def main():
    data = (ROOT / 'ARKHER STUDIOS👑').read_bytes()
    entries, families = extract(data)
    by_id = {entry['id']: entry for entry in entries}
    evidence = json.loads((ROOT / 'arkher/progress/evidence.json').read_text())
    tests = json.loads((ROOT / 'build/arkher/tests.json').read_text())
    assert tests['failed'] == 0
    names = set(tests['tests'])
    for group in evidence:
        assert group['status'] == 'partial', 'Complete status requires a separate end-to-end certification process'
        for path in group['files']:
            if not (ROOT / path).is_file(): raise ValueError('Missing source evidence: ' + path)
        for name in group['tests']:
            if name not in names: raise ValueError('Evidence test was not executed successfully: ' + name)
        for identifier in group['entries']:
            if identifier not in by_id: raise ValueError('Not an explicit brief entry: ' + identifier)
            entry = by_id[identifier]
            if entry['status'] != 'not_implemented': raise ValueError('Duplicate evidence mapping: ' + identifier)
            entry.update(status='partial', scope=group['scope'], sourceFiles=group['files'], tests=group['tests'])
    statuses = Counter(entry['status'] for entry in entries)
    total = len(entries); covered = total - statuses['not_implemented']
    family_reports = []
    for key, title in families.items():
        subset = [entry for entry in entries if entry['family'] == key]
        count = sum(entry['status'] != 'not_implemented' for entry in subset)
        family_reports.append({'id': key, 'name': title, 'entries': len(subset), 'withPartialCode': count,
                               'withoutImplementation': len(subset)-count, 'completeValidated': 0})
    report = {
        'product': 'ARKHER', 'generation': 1, 'version': '1.0.0-dev.2',
        'briefBlob': BRIEF_BLOB, 'denominator': 'explicit named catalogue entries in Part II, by family; not distinct systems or effort',
        'method': 'Exact duplicates and explicit NPC terminology aliases inside a family consolidated; all source mentions preserved; technology inspiration names excluded. Partial items earn coverage only, never fractional completion.',
        'explicitEntries': total, 'sourceMentions': sum(len(entry['sourceMentions']) for entry in entries), 'partialWithEvidence': covered, 'withoutImplementation': total-covered,
        'codeCoveragePercent': round(covered/total*100, 2),
        'withoutImplementationPercent': round((total-covered)/total*100, 2),
        'completeValidated': 0, 'validatedCompletionPercent': 0,
        'remainingCompletionOrValidationPercent': 100,
        'formalTargets': {'realSystemsMinimum': 10000, 'completeFeaturesMinimum': 100000,
                          'certifiedSystems': None, 'certifiedFeatures': None, 'status': 'NOT_CERTIFIED'},
        'effortRemainingPercent': None,
        'warning': 'Coverage is NOT V1 completion. Unexpanded requirements and formal 10K/100K targets prevent an exact overall completion/effort percentage. No hardware or Studio validation is claimed.',
        'families': family_reports, 'entries': entries,
    }
    destination = ROOT / 'arkher/progress/REPORT.json'
    destination.write_text(json.dumps(report, ensure_ascii=False, indent=2) + '\n')
    lines = ["# ARKHER — progresso rastreável da V1", '',
        f"Fonte: blob `{BRIEF_BLOB}`. Versão de desenvolvimento: `1.0.0-dev.2`.", '',
        f"- **{covered}/{total} entradas ({report['codeCoveragePercent']:.2f}%) têm código parcial com evidência rastreada.**",
        f"- **{total-covered}/{total} ({report['withoutImplementationPercent']:.2f}%) ainda estão sem implementação rastreada.**",
        '- **0% certificados como completos ponta a ponta**: a validação em Roblox Studio/dispositivos continua pendente.',
        '- **100% ainda exigem conclusão e/ou validação final. Isso NÃO significa 0% de código funcionando.**',
        '- Alvos de **10.000 sistemas / 100.000 funcionalidades**: não certificados; não equivalem às entradas nomeadas abaixo.',
        '- Percentual de esforço restante: **não estimado**. Cobertura não é tempo, esforço, qualidade nem conclusão global.', '',
        '## Método', '',
        'Cada entrada explícita da Parte II do prompt é rastreada por família, nome e linha. Duplicatas exatas e aliases explícitos de terminologia NPC dentro da mesma família são consolidados, preservando todas as linhas de origem; referências como DLSS/FSR não viram sistemas nossos. Nomes repetidos em contextos/famílias diferentes permanecem como exigências de integração, **não como sistemas distintos para atingir 10K**.', '',
        'Um item parcial não recebe 50%, 90% ou outro peso arbitrário. Só conta como cobertura em andamento. A lista mantém também os mínimos numéricos e os requisitos ainda não decompostos. Não há garantia de viabilidade de cada tecnologia; não há retirada silenciosa de escopo.', '',
        '| Família | Entradas | Código parcial | Sem implementação | Concluídas/validadas |',
        '|---|---:|---:|---:|---:|']
    for family in family_reports:
        lines.append(f"| {family['id']} — {family['name']} | {family['entries']} | {family['withPartialCode']} | {family['withoutImplementation']} | 0 |")
    lines += ['', 'A evidência por item está em `REPORT.json` e as correspondências revisáveis em `evidence.json`.',
              'Todos os pendentes continuam no escopo da **V1**, não foram deslocados para a V2.', '']
    (ROOT / 'arkher/progress/README.md').write_text('\n'.join(lines), encoding='utf-8')
    summary = '\n'.join(lines[:13])
    # A static in-product read-only report; not a counter derived from filenames or helpers.
    literal = json.dumps(summary, ensure_ascii=False)
    (ROOT / 'arkher/src/Core/Progress.luau').write_text('-- Generated by tools/progress.py; do not hand-edit percentages.\nreturn {\n'
        + f'  total={total}, partial={covered}, pending={total-covered}, coverage={report["codeCoveragePercent"]}, completeValidated=0,\n'
        + '  explanation=' + literal + ',\n}\n', encoding='utf-8')
    print(json.dumps({key: report[key] for key in ['explicitEntries','partialWithEvidence','withoutImplementation',
          'codeCoveragePercent','withoutImplementationPercent','validatedCompletionPercent','effortRemainingPercent']}, indent=2))


if __name__ == '__main__':
    main()
