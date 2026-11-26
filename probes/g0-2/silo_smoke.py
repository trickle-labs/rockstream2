#!/usr/bin/env python3
"""Local, disposable Silo conditional-write smoke test; not provider qualification."""

import concurrent.futures
import http.client
import json
import select
import subprocess
import sys
import time
import uuid

IMAGE = "pgsty/silo@sha256:c20d112390b9a9ce8c11b8af95ad35bcaa62f4759663c09c936cd8d2b511f329"
USER = "rockstream-local"
PASSWORD = "rockstream-local-test-only"
NAME = "rockstream-g0-2-" + uuid.uuid4().hex[:12]
PORT = 19020
BASE = f"http://127.0.0.1:{PORT}/g0-probe"


def request(method, path="", value=None, condition=None):
    command = ["curl", "--silent", "--show-error", "--max-time", "10", "--http1.1",
               "--aws-sigv4", "aws:amz:us-east-1:s3", "--user", f"{USER}:{PASSWORD}",
               "--request", method, "--include"]
    if condition:
        command += ["--header", condition]
    if value is not None:
        command += ["--data-binary", value]
    started = time.monotonic()
    output = subprocess.check_output(command + [BASE + path])
    elapsed_ms = (time.monotonic() - started) * 1000
    headers, body = output.split(b"\r\n\r\n", 1)
    lines = headers.decode("iso-8859-1").split("\r\n")
    status = int(lines[0].split()[1])
    fields = dict(line.split(": ", 1) for line in lines[1:] if ": " in line)
    return status, fields.get("ETag"), body, round(elapsed_ms, 3)


def expect(actual, expected, label):
    if actual != expected:
        raise AssertionError(f"{label}: expected {expected!r}, got {actual!r}")


def slate_recovery(binary):
    def kill_at_ready(mode, prefix):
        process = subprocess.Popen([binary, mode, prefix], stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        try:
            if not select.select([process.stdout], [], [], 60)[0]:
                raise RuntimeError(f"{mode} did not reach its crash boundary")
            line = process.stdout.readline()
            if line != b"READY\n":
                raise RuntimeError(f"{mode} failed before crash boundary: {line!r} {process.stderr.read()!r}")
        finally:
            process.kill()
            process.communicate(timeout=10)
        expect(process.returncode, -9, f"{mode} SIGKILL")

    def recover(prefix, mode="recover"):
        return subprocess.run([binary, mode, prefix], capture_output=True, timeout=60)

    kill_at_ready("publish", "crash-after-publish")
    result = recover("crash-after-publish")
    expect((result.returncode, result.stdout), (0, b"RECOVERED\n"), f"post-publish recovery: {result.stderr!r}")
    kill_at_ready("publish", "crash-after-apply")
    kill_at_ready("apply-and-wait", "crash-after-apply")
    result = recover("crash-after-apply")
    expect((result.returncode, result.stdout), (0, b"RECOVERED\n"), f"post-apply recovery: {result.stderr!r}")
    mutant = recover("crash-after-apply", "recover-reapply")
    if mutant.returncode == 0 or b"assertion" not in mutant.stderr:
        raise AssertionError(f"double-apply negative control was not detected: {mutant.stderr!r}")


def main():
    started = False
    try:
        subprocess.run(["docker", "run", "-d", "--rm", "--name", NAME,
                        "-p", f"127.0.0.1:{PORT}:9000", "-e", f"MINIO_ROOT_USER={USER}",
                        "-e", f"MINIO_ROOT_PASSWORD={PASSWORD}", IMAGE, "server", "/data"],
                       check=True, stdout=subprocess.DEVNULL)
        started = True
        for attempt in range(100):
            try:
                connection = http.client.HTTPConnection("127.0.0.1", PORT, timeout=1)
                connection.request("GET", "/minio/health/ready")
                response = connection.getresponse()
                ready = response.status == 200
                connection.close()
                if ready:
                    break
            except OSError:
                pass
            time.sleep(0.1)
        else:
            raise RuntimeError("Silo did not become ready within 10 seconds")

        expect(request("PUT")[0], 200, "create bucket")
        first = request("PUT", "/root", "first", "If-None-Match: *")
        expect(first[0], 200, "create-if-absent")
        expect(request("PUT", "/root", "duplicate", "If-None-Match: *")[0], 412, "duplicate create")
        expect(request("GET", "/root")[2], b"first", "read after create")
        second = request("PUT", "/root", "second", f"If-Match: {first[1]}")
        expect(second[0], 200, "matching update")
        expect(request("PUT", "/root", "stale", f"If-Match: {first[1]}")[0], 412, "stale update")
        expect(request("GET", "/root")[2], b"second", "read after update")
        with concurrent.futures.ThreadPoolExecutor(max_workers=2) as pool:
            writes = list(pool.map(lambda value: request("PUT", "/root", value, f"If-Match: {second[1]}"),
                                   ["racer-a", "racer-b"]))
        expect(sorted(result[0] for result in writes), [200, 412], "concurrent expected-parent updates")
        current = request("GET", "/root")
        if current[2] not in (b"racer-a", b"racer-b"):
            raise AssertionError(f"unexpected winning value: {current[2]!r}")
        expect(current[1], next(result[1] for result in writes if result[0] == 200), "current version")
        if len(sys.argv) == 2:
            slate_recovery(sys.argv[1])
        elif len(sys.argv) > 2:
            raise ValueError("usage: silo_smoke.py [slate-probe-binary]")
        print(json.dumps({"result": "pass", "image": IMAGE,
                          "slatedb_recovery": "pass" if len(sys.argv) == 2 else "not run",
                          "scope": "local smoke only; not G0.2 qualification",
                          "sample_ms": {"create": first[3], "matching_update": second[3],
                                        "concurrent_updates": [r[3] for r in writes], "read": current[3]}}, indent=2))
    finally:
        if started:
            subprocess.run(["docker", "stop", NAME], check=True, stdout=subprocess.DEVNULL)


if __name__ == "__main__":
    main()
