"""Gate checks must still reject bad fixtures when Python optimization is enabled."""
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parent.parent


class OptimizedChecks(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name)
        shutil.copytree(ROOT / 'scripts', self.root / 'scripts')
        shutil.copytree(ROOT / 'fixtures' / 'w1g', self.root / 'fixtures' / 'w1g')

    def run_check(self, name):
        env = dict(os.environ, PYTHONOPTIMIZE='1')
        return subprocess.run([sys.executable, self.root / 'scripts' / name],
                              text=True, capture_output=True, env=env, check=False)

    def edit_fixture(self, old, new):
        path = self.root / 'fixtures' / 'w1g' / 'transactions.csv'
        text = path.read_text()
        self.assertIn(old, text)
        path.write_text(text.replace(old, new))

    def test_cross_term_rejects_wrong_complete_cut_under_optimization(self):
        self.edit_fixture('0,order,1,101,1,1000', '0,order,1,101,1,1001')
        result = self.run_check('check-cross-term.py')
        self.assertNotEqual(result.returncode, 0, result.stdout)
        self.assertIn('batch result disagrees with frozen cut 2', result.stderr)

    def test_donor_negative_weight_mutant_is_rejected(self):
        path = self.root / 'scripts' / 'check-cross-term.py'
        source = path.read_text()
        self.assertIn('if key == right_key:', source)
        path.write_text(source.replace('if key == right_key:', 'if key == right_key and lw > 0:'))
        result = self.run_check('check-cross-term.py')
        self.assertNotEqual(result.returncode, 0, result.stdout)
        self.assertIn('donor retraction mismatch', result.stderr)

    def test_postgres_rejects_invalid_weight_under_optimization(self):
        self.edit_fixture('0,order,1,101,1,1000', '0,order,9,101,1,1000')
        result = self.run_check('check-postgres.py')
        self.assertNotEqual(result.returncode, 0, result.stdout)
        self.assertIn('invalid fixture weight', result.stderr)

    def test_postgres_rejects_untrusted_region_under_optimization(self):
        self.edit_fixture('0,customer,1,1,North,', '0,customer,1,1,invalid,')
        result = self.run_check('check-postgres.py')
        self.assertNotEqual(result.returncode, 0, result.stdout)
        self.assertIn('invalid fixture region', result.stderr)

    def test_postgres_rejects_unknown_table_under_optimization(self):
        self.edit_fixture('0,order,1,101,1,1000', '0,unknown,1,101,1,1000')
        result = self.run_check('check-postgres.py')
        self.assertNotEqual(result.returncode, 0, result.stdout)
        self.assertIn('invalid fixture table', result.stderr)

    def test_postgres_rejects_untrusted_expected_region_under_optimization(self):
        path = self.root / 'fixtures' / 'w1g' / 'expected.csv'
        path.write_text(path.read_text().replace('North', "North';invalid"))
        result = self.run_check('check-postgres.py')
        self.assertNotEqual(result.returncode, 0, result.stdout)
        self.assertIn('invalid expected region', result.stderr)

    def test_postgres_rejects_unchecked_epochs_and_cuts(self):
        # An accepting psql stub proves validation, rather than connection failure,
        # rejects rows outside the frozen workload before database execution.
        binary = self.root / 'bin'
        binary.mkdir()
        psql = binary / 'psql'
        psql.write_text('#!/bin/sh\nexit 0\n')
        psql.chmod(0o755)
        env = dict(os.environ, PYTHONOPTIMIZE='1', PATH=str(binary) + os.pathsep + os.environ.get('PATH', ''))
        for name, row, error in (
            ('transactions.csv', '-1,order,1,105,1,1\n', 'invalid fixture epoch'),
            ('transactions.csv', '4,order,1,105,1,1\n', 'invalid fixture epoch'),
            ('expected.csv', '-1,North,1,1\n', 'invalid expected cut'),
            ('expected.csv', '5,North,1,1\n', 'invalid expected cut'),
        ):
            with self.subTest(row=row):
                path = self.root / 'fixtures' / 'w1g' / name
                original = path.read_text()
                path.write_text(original + row)
                try:
                    result = subprocess.run([sys.executable, self.root / 'scripts' / 'check-postgres.py'],
                                            text=True, capture_output=True, env=env, check=False)
                    self.assertNotEqual(result.returncode, 0, result.stdout)
                    self.assertIn(error, result.stderr)
                finally:
                    path.write_text(original)


if __name__ == '__main__':
    unittest.main()
