"""Exercise dependency policy against Cargo's real optional-feature graph."""
import os
import shutil
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parent.parent


class DependencyPolicy(unittest.TestCase):
    def test_optional_workspace_edge_is_rejected(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            for name in ('w1g-oracle', 'other'):
                (root / name / 'src').mkdir(parents=True)
                (root / name / 'src' / 'lib.rs').write_text('')
            shutil.copyfile(ROOT / 'rust-toolchain.toml', root / 'rust-toolchain.toml')
            (root / 'Cargo.toml').write_text('[workspace]\nresolver="2"\nmembers=["w1g-oracle","other"]\n')
            (root / 'w1g-oracle' / 'Cargo.toml').write_text(
                '[package]\nname="w1g-oracle"\nversion="0.1.0"\nedition="2024"\n'
                '[dependencies]\nother={path="../other",optional=true}\n')
            (root / 'other' / 'Cargo.toml').write_text(
                '[package]\nname="other"\nversion="0.1.0"\nedition="2024"\n')
            env = dict(os.environ, CARGO_NET_OFFLINE='true')
            subprocess.run(['cargo', 'generate-lockfile', '--offline'], cwd=root,
                           check=True, capture_output=True, env=env)
            checker = (ROOT / 'scripts' / 'check-dependencies.py').read_text()
            checker = checker.replace('{"w1g-oracle": set()}',
                                      '{"w1g-oracle": set(), "other": set()}')
            script = root / 'check-dependencies.py'
            script.write_text(checker)
            result = subprocess.run([sys.executable, script], cwd=root, env=env,
                                    capture_output=True, text=True, check=False)
            self.assertNotEqual(result.returncode, 0, result.stdout)
            self.assertIn('disallowed or unregistered workspace dependency', result.stderr)

    def test_repository_local_nonmember_dependency_is_rejected(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            for name in ('w1g-oracle', 'outside'):
                (root / name / 'src').mkdir(parents=True)
                (root / name / 'src' / 'lib.rs').write_text('')
            shutil.copyfile(ROOT / 'rust-toolchain.toml', root / 'rust-toolchain.toml')
            (root / 'Cargo.toml').write_text('[workspace]\nresolver="2"\nmembers=["w1g-oracle"]\nexclude=["outside"]\n')
            (root / 'w1g-oracle' / 'Cargo.toml').write_text(
                '[package]\nname="w1g-oracle"\nversion="0.1.0"\nedition="2024"\n'
                '[dependencies]\noutside={path="../outside"}\n')
            (root / 'outside' / 'Cargo.toml').write_text(
                '[package]\nname="outside"\nversion="0.1.0"\nedition="2024"\n')
            env = dict(os.environ, CARGO_NET_OFFLINE='true')
            subprocess.run(['cargo', 'generate-lockfile', '--offline'], cwd=root,
                           check=True, capture_output=True, env=env)
            result = subprocess.run([sys.executable, ROOT / 'scripts' / 'check-dependencies.py'],
                                    cwd=root, env=env, capture_output=True, text=True, check=False)
            self.assertNotEqual(result.returncode, 0, result.stdout)
            self.assertIn('path dependency is not a workspace member', result.stderr)

    def test_external_path_dependency_is_rejected(self):
        with tempfile.TemporaryDirectory() as tmp:
            parent = Path(tmp)
            root, outside = parent / 'repository', parent / 'external'
            for path in (root / 'w1g-oracle', outside):
                (path / 'src').mkdir(parents=True)
                (path / 'src' / 'lib.rs').write_text('')
            shutil.copyfile(ROOT / 'rust-toolchain.toml', root / 'rust-toolchain.toml')
            (root / 'Cargo.toml').write_text('[workspace]\nresolver="2"\nmembers=["w1g-oracle"]\n')
            (root / 'w1g-oracle' / 'Cargo.toml').write_text(
                '[package]\nname="w1g-oracle"\nversion="0.1.0"\nedition="2024"\n'
                '[dependencies]\nexternal={path="../../external"}\n')
            (outside / 'Cargo.toml').write_text(
                '[package]\nname="external"\nversion="0.1.0"\nedition="2024"\n')
            env = dict(os.environ, CARGO_NET_OFFLINE='true')
            subprocess.run(['cargo', 'generate-lockfile', '--offline'], cwd=root,
                           check=True, capture_output=True, env=env)
            result = subprocess.run([sys.executable, ROOT / 'scripts' / 'check-dependencies.py'],
                                    cwd=root, env=env, capture_output=True, text=True, check=False)
            self.assertNotEqual(result.returncode, 0, result.stdout)
            self.assertIn('path dependency is not a workspace member', result.stderr)


if __name__ == '__main__':
    unittest.main()
