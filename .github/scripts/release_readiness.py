import os
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
AUDIT_PATH = ROOT / 'assessment' / '01-audit.md'
DECISION_PATH = ROOT / 'assessment' / '03-release-decision.md'
PLACEHOLDERS = {'', 'none', 'tbd', 'n/a', 'not accepted', 'pending'}


def field_value(text, label):
    prefix = f'**{label}:**'
    for line in text.splitlines():
        if line.startswith(prefix):
            return line[len(prefix):].strip()
    return ''


def acceptance_rows(text):
    rows = {}
    in_section = False
    for line in text.splitlines():
        if line == '## P0/P1 Risk Acceptance':
            in_section = True
            continue
        if in_section and line.startswith('## '):
            break
        if not in_section:
            continue
        if not line.strip().startswith('|'):
            continue
        cells = [cell.strip() for cell in line.strip().strip('|').split('|')]
        if len(cells) != 4 or cells[0].lower() == 'finding id' or set(cells[0]) == {'-'}:
            continue
        rows[cells[0].upper()] = {
            'disposition': cells[1],
            'owner': cells[2],
            'rationale': cells[3],
        }
    return rows


def finding_from_heading(line):
    if not (line.startswith('### P0 ') or line.startswith('### P1 ')):
        return None

    id_start = line.find('[')
    id_end = line.find(']', id_start + 1)
    if id_start < 0 or id_end <= id_start:
        return {
            'severity': line[4:6],
            'finding_id': None,
            'status': '',
        }

    return {
        'severity': line[4:6],
        'finding_id': line[id_start + 1:id_end],
        'status': '',
    }


def record_unresolved(findings, finding):
    if finding and not finding['status'].lower().startswith('fixed'):
        findings.append((finding['severity'], finding['finding_id']))


def unresolved_high_findings(audit):
    unresolved = []
    current = None

    for line in audit.splitlines():
        heading_finding = finding_from_heading(line)
        if heading_finding:
            record_unresolved(unresolved, current)
            current = heading_finding
        elif current and line.startswith('**Status:**'):
            current['status'] = line[len('**Status:**'):].strip()

    record_unresolved(unresolved, current)
    return unresolved


def release_blockers(audit, decision, quality_result):
    blockers = []

    if quality_result != 'success':
        blockers.append(f'quality-gate result is {quality_result!r}, not success')

    decision_value = field_value(decision, 'Decision').split('—', 1)[0].strip().upper()
    if decision_value != 'APPROVED':
        blockers.append(f'release decision is {decision_value or "missing"}')

    accountable_owner = field_value(decision, 'Accountable owner')
    if accountable_owner.lower() in PLACEHOLDERS:
        blockers.append('accountable release owner is missing or TBD')

    rows = acceptance_rows(decision)
    for severity, finding_id in unresolved_high_findings(audit):
        if not finding_id:
            blockers.append(f'{severity} finding has no stable ID for release review')
            continue
        row = rows.get(finding_id.upper())
        if not row:
            blockers.append(f'{severity} {finding_id} has no risk-acceptance row')
            continue
        if row['disposition'].lower() != 'accepted':
            blockers.append(f'{severity} {finding_id} is unresolved and not explicitly accepted')
        if row['owner'].lower() in PLACEHOLDERS:
            blockers.append(f'{severity} {finding_id} has no named acceptance owner')
        if row['rationale'].lower() in PLACEHOLDERS:
            blockers.append(f'{severity} {finding_id} has no acceptance rationale')

    return blockers


def main():
    tag = os.environ.get('GITHUB_REF_NAME', 'local candidate')
    quality_result = os.environ.get('QUALITY_GATE_RESULT', 'not provided')
    audit = AUDIT_PATH.read_text()
    decision = DECISION_PATH.read_text()
    blockers = release_blockers(audit, decision, quality_result)

    if blockers:
        print(f'BLOCKED: {tag} is not releasable.')
        for blocker in blockers:
            print(f'- {blocker}')
        return 1

    print(f'RELEASABLE: {tag} passed quality checks and documented risk review.')
    return 0


if __name__ == '__main__':
    sys.exit(main())