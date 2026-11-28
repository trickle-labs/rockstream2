#!/usr/bin/env python3
"""Local, disposable Silo conditional-write smoke test; not provider qualification."""

import concurrent.futures
import http.client
import json
import os
import selectors
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


def expect_negative(result, marker, label):
    if result.returncode == 0 or marker not in result.stderr:
        raise AssertionError(f"{label}: {result.stderr!r}")


def wait_for_ready(process, timeout):
    deadline = time.monotonic() + timeout
    stdout = bytearray()
    stderr = bytearray()
    with selectors.DefaultSelector() as selector:
        selector.register(process.stdout, selectors.EVENT_READ, stdout)
        selector.register(process.stderr, selectors.EVENT_READ, stderr)
        while selector.get_map():
            remaining = deadline - time.monotonic()
            if remaining <= 0:
                break
            events = selector.select(remaining)
            if not events:
                break
            for key, _ in events:
                chunk = os.read(key.fd, 4096)
                if not chunk:
                    selector.unregister(key.fileobj)
                    continue
                key.data.extend(chunk)
                if key.data is stderr and len(stderr) > 65536:
                    del stderr[:-65536]
                if key.data is stdout:
                    if b"\n" in stdout:
                        return bytes(stdout.split(b"\n", 1)[0] + b"\n"), bytes(stderr)
                    if len(stdout) > 65536:
                        return None, bytes(stderr)
    return None, bytes(stderr)


def slate_recovery(binary):
    def kill_at_ready(mode, prefix):
        process = subprocess.Popen([binary, mode, prefix], stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        line = None
        stderr = b""
        try:
            line, stderr = wait_for_ready(process, 60)
        finally:
            process.kill()
            _, remaining_stderr = process.communicate(timeout=10)
            stderr += remaining_stderr
        if line != b"READY\n":
            raise RuntimeError(f"{mode} failed to reach its crash boundary: {line!r} {stderr!r}")
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
    expect_negative(mutant, b"negative-control: double-apply count mismatch", "double-apply negative control was not detected")
    kill_at_ready("publish-corrupt", "corrupt-delta")
    corrupt = recover("corrupt-delta")
    if corrupt.returncode == 0 or b"delta digest mismatch" not in corrupt.stderr:
        raise AssertionError(f"corrupt committed delta was not rejected: {corrupt.stderr!r}")
    kill_at_ready("publish", "checkpoint-registration")
    kill_at_ready("apply-and-wait", "checkpoint-registration")
    result = recover("checkpoint-registration", "checkpoint")
    expect((result.returncode, result.stdout), (0, b"CHECKPOINTED\n"), f"checkpoint: {result.stderr!r}")
    for prefix in ("split-good", "split-bad"):
        kill_at_ready("publish", prefix)
        kill_at_ready("split-apply", prefix)
    result = recover("split-good", "takeover")
    expect((result.returncode, result.stdout), (0, b"RECOVERED\n"), f"split takeover: {result.stderr!r}")
    mutant = recover("split-bad", "takeover-bad")
    expect_negative(mutant, b"negative-control: dirty takeover count mismatch", "dirty-instance negative control was not detected")
    comparison = recover("w1g", "w1g")
    if comparison.returncode != 0 or not comparison.stdout.startswith(b"W1G-COMPARED "):
        raise AssertionError(f"W1-G layouts failed: {comparison.stdout!r} {comparison.stderr!r}")
    print(comparison.stdout.decode().strip())
    group = recover("group", "group")
    expect((group.returncode, group.stdout), (0, b"GROUP-COMMIT\n"), f"group commit: {group.stderr!r}")
    kill_at_ready("w1g-crash", "w1g-crash")
    recovered = recover("w1g-crash", "w1g-recover")
    expect((recovered.returncode, recovered.stdout), (0, b"W1G-RECOVERED\n"), f"W1-G checkpoint recovery: {recovered.stderr!r}")
    kill_at_ready("w1g-crash", "w1g-crash-bad")
    mutant = recover("w1g-crash-bad", "w1g-recover-bad")
    expect_negative(mutant, b"negative-control: dirty checkpoint baseline mismatch", "W1-G dirty-instance negative control was not detected")
    for prefix in ("history-crash", "history-crash-bad"):
        kill_at_ready("w1g-root-crash", prefix)
    recovered = recover("history-crash", "w1g-history-recover")
    expect((recovered.returncode, recovered.stdout), (0, b"HISTORY-RECOVERED\n"), f"history recovery: {recovered.stderr!r}")
    mutant = recover("history-crash-bad", "w1g-history-bad")
    expect_negative(mutant, b"negative-control: missing history replay", "history replay negative control was not detected")
    metrics = recover("synthetic", "synthetic")
    if metrics.returncode != 0 or metrics.stdout.count(b"SYNTHETIC layout=") != 2:
        raise AssertionError(f"synthetic experiment failed: {metrics.stdout!r} {metrics.stderr!r}")
    print(metrics.stdout.decode().strip())


def main():
    started = False
    try:
        subprocess.run(["docker", "run", "-d", "--rm", "--name", NAME,
                        "-p", f"127.0.0.1:{PORT}:9000", "-e", f"MINIO_ROOT_USER={USER}",
                        "-e", f"MINIO_ROOT_PASSWORD={PASSWORD}", IMAGE, "server", "/data"],
                       check=True, stdout=subprocess.DEVNULL)
        started = True
        for attempt in range(30):
            try:
                connection = http.client.HTTPConnection("127.0.0.1", PORT, timeout=1)
                connection.request("GET", "/minio/health/cluster")
                response = connection.getresponse()
                ready = response.status == 200
                connection.close()
                if ready:
                    break
            except OSError:
                pass
            time.sleep(1)
        else:
            raise RuntimeError("Silo cluster did not become ready after 30 attempts")

        bucket = request("PUT")
        expect(bucket[0], 200, f"create bucket: {bucket[2]!r}")
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
