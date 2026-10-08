import re
import unittest
from pathlib import Path
ROOT = Path(__file__).resolve().parents[2]
class BackupContractTests(unittest.TestCase):
    def test_every_persisted_scalar_has_a_codable_export_and_restore_assignment(self):
        records = (ROOT / 'ASCEND/App/BackupRecords.swift').read_text(encoding='utf-8')
        relations = {'WorkoutSession', 'WorkoutExercise', 'WorkoutSet', 'Exercise', 'DailyObjective', 'DailyObjectiveCompletion', 'DailyEvaluation', 'ELOHistoryEntry'}
        for file in (ROOT / 'ASCEND/Core/Persistence').glob('*Models.swift'):
            source = file.read_text(encoding='utf-8')
            for name, body in re.findall(r'@Model final class (\w+) \{(.*?)(?=\n@Model|\Z)', source, re.S):
                if name == 'MuscleState': continue # derived, deliberately rebuilt
                match = re.search(r'struct Backup' + name + r':.*?\n\}(?=\n|\Z)', records, re.S)
                self.assertIsNotNone(match, name)
                dto = match.group()
                for field, kind in re.findall(r'\bvar (\w+): ([^\n]+)', body.split('    init(')[0]):
                    if '{' in kind: continue # computed property, not stored data
                    kind = kind.split('=')[0].split('//')[0].strip()
                    if kind.rstrip('?') in relations or kind.startswith('[') and kind[1:-1] in relations: continue
                    self.assertRegex(dto, r'var ' + field + r':', name + '.' + field)
                    self.assertIn(field + ' = source.' + field, dto, name + '.' + field + ' export')
                    self.assertIn('model.' + field + ' = ' + field, dto, name + '.' + field + ' restore')
        declarations = re.findall(r'^    var \w+: (.*)$', records, re.M)
        self.assertFalse(any(kind.rstrip('?') in relations for kind in declarations), 'Backup must contain IDs, never live SwiftData models')
if __name__ == '__main__': unittest.main()
