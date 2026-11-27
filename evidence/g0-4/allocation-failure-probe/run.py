import os
import resource
import subprocess
import sys

resource.setrlimit(resource.RLIMIT_CORE, (0, 0))
exe = sys.argv[1]
for name, options, count in [('cold', {}, 27), ('warm', {'G04_WARM': '1'}, 16)]:
    env = dict(os.environ)
    env.pop("G04_WARM", None)
    env.update(options)
    baseline = subprocess.run([exe], env=env, capture_output=True, text=True, check=True)
    expected_rows = 1 if name == 'cold' else 2
    expected = f'result=Ok({expected_rows}) calls={count}'
    if baseline.stdout.splitlines()[0] != expected:
        raise RuntimeError(f'{name}: unexpected baseline {baseline.stdout!r}')
    print(name, baseline.stdout.strip(), flush=True)
    for index in range(count):
        result = subprocess.run([exe, str(index)], env=env, capture_output=True, text=True)
        if index < 5:
            if result.returncode != 0 or 'result=Err("allocation failed")' not in result.stdout:
                raise RuntimeError(f'{name} {index}: unexpected {result.returncode} {result.stdout!r} {result.stderr!r}')
        elif result.returncode != -6 or 'memory allocation of ' not in result.stderr:
            raise RuntimeError(f'{name} {index}: unexpected {result.returncode} {result.stdout!r} {result.stderr!r}')
        print(name, index, 'status', result.returncode, 'result', result.stdout.splitlines()[:1], 'stderr', result.stderr.splitlines()[:1], flush=True)
