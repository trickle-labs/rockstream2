import subprocess
import sys
import time
import unittest
from types import SimpleNamespace

from silo_smoke import expect_negative, wait_for_ready


class ReadinessTests(unittest.TestCase):
    def run_child(self, code, timeout):
        process = subprocess.Popen(
            [sys.executable, "-c", code], stdout=subprocess.PIPE, stderr=subprocess.PIPE
        )
        try:
            started = time.monotonic()
            line, stderr = wait_for_ready(process, timeout)
            return line, stderr, time.monotonic() - started
        finally:
            process.kill()
            process.communicate(timeout=5)

    def test_partial_stdout_obeys_deadline(self):
        line, _, elapsed = self.run_child(
            "import sys,time; sys.stdout.write('REA'); sys.stdout.flush(); time.sleep(5)",
            0.25,
        )
        self.assertIsNone(line)
        self.assertLess(elapsed, 2)

    def test_stderr_is_drained_before_ready(self):
        line, stderr, _ = self.run_child(
            "import sys,time; sys.stderr.write('x' * 262144); sys.stderr.flush(); "
            "sys.stdout.write('READY\\n'); sys.stdout.flush(); time.sleep(5)",
            5,
        )
        self.assertEqual(line, b"READY\n")
        self.assertTrue(stderr)
        self.assertLessEqual(len(stderr), 65536)


class NegativeControlTests(unittest.TestCase):
    def test_unrelated_assertion_is_not_the_expected_fault(self):
        marker = b"negative-control: double-apply count mismatch"
        with self.assertRaises(AssertionError):
            expect_negative(SimpleNamespace(returncode=1, stderr=b"assertion failed in setup"), marker, "control")
        expect_negative(SimpleNamespace(returncode=1, stderr=marker), marker, "control")
        with self.assertRaises(AssertionError):
            expect_negative(SimpleNamespace(returncode=0, stderr=marker), marker, "control")


if __name__ == "__main__":
    unittest.main()
