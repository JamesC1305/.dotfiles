#!/usr/bin/env python3
"""Transport Firecracker editor jobs through the checkout's devtool container."""

import argparse
import fcntl
import hashlib
import json
import os
from pathlib import Path
import platform
import shlex
import shutil
import signal
import subprocess
from concurrent.futures import ThreadPoolExecutor
import sys
import tempfile
import time
import uuid


def container_path(path, root):
    return "/firecracker/" + str(Path(path).relative_to(root))


def alive(pid):
    try:
        os.kill(pid, 0)
        return True
    except ProcessLookupError:
        return False


def fix_permissions(cid, state, cargo_only=False):
    paths = ["/firecracker/build/cargo_target"]
    if not cargo_only:
        paths.append("/firecracker/build/.nvim-devtool")
    return subprocess.run(
        [
            "docker",
            "exec",
            cid,
            "chown",
            "-f",
            "-R",
            f"{os.getuid()}:{os.getgid()}",
            *paths,
        ],
        stdout=subprocess.DEVNULL,
        stderr=subprocess.PIPE,
        timeout=60,
    )


def stop(state, expected=None):
    cid_file = state / "container"
    if not cid_file.exists():
        return
    cid = cid_file.read_text().strip()
    if expected is not None and cid != expected:
        return
    try:
        remote = "/firecracker/build/.nvim-devtool/" + state.name
        subprocess.run(
            [
                "docker",
                "exec",
                cid,
                "python3",
                remote + "/transport.py",
                "quiesce",
                "--state",
                remote,
            ],
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
            timeout=15,
        )
        fix_permissions(cid, state)
    finally:
        subprocess.run(
            ["docker", "stop", "--time", "8", cid],
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
            timeout=15,
        )
        cid_file.unlink(missing_ok=True)


def keep(args):
    state = Path(args.state)
    remote = container_path(state, args.root)
    command = "exec python3 " + shlex.join(
        [remote + "/transport.py", "serve", "--state", remote]
    )
    with (state / "container.log").open("a") as log:
        child = subprocess.Popen(
            [str(Path(args.root) / "tools/devtool"), "sh", command],
            stdin=subprocess.DEVNULL,
            stdout=log,
            stderr=log,
        )
        cid = None
        try:
            while child.poll() is None and alive(args.owner):
                if cid is None and (state / "container").exists():
                    cid = (state / "container").read_text().strip()
                time.sleep(0.5)
        finally:
            if cid is not None:
                stop(state, expected=cid)
            try:
                child.wait(timeout=15)
            except subprocess.TimeoutExpired:
                child.terminate()
                child.wait(timeout=5)


def ensure(args):
    state = Path(args.state)
    state.mkdir(parents=True, exist_ok=True)
    # Concurrent test and debugger requests must not create two keepers.
    with (state / "startup.lock").open("w") as lock:
        fcntl.flock(lock, fcntl.LOCK_EX)
        cid_file = state / "container"
        if cid_file.exists():
            cid = cid_file.read_text().strip()
            check = subprocess.run(
                ["docker", "inspect", "-f", "{{.State.Running}}", cid],
                capture_output=True,
                text=True,
                timeout=10,
            )
            if check.returncode == 0 and check.stdout.strip() == "true":
                return cid
            cid_file.unlink()
        shutil.copyfile(__file__, state / "transport.py")
        runner = Path(args.runner)
        shutil.copyfile(runner / "neotest.py", state / "neotest.py")
        shutil.copytree(
            runner / "neotest_python",
            state / "neotest_python",
            dirs_exist_ok=True,
            ignore=shutil.ignore_patterns("__pycache__"),
        )
        (state / "stopping").unlink(missing_ok=True)
        with (state / "keeper.log").open("a") as log:
            keeper = subprocess.Popen(
                [
                    sys.executable,
                    __file__,
                    "keep",
                    "--root",
                    args.root,
                    "--state",
                    args.state,
                    "--owner",
                    str(args.owner),
                ],
                stdin=subprocess.DEVNULL,
                stdout=log,
                stderr=log,
                start_new_session=True,
            )
        deadline = time.monotonic() + 30
        while time.monotonic() < deadline:
            if cid_file.exists():
                return cid_file.read_text().strip()
            if keeper.poll() is not None:
                break
            time.sleep(0.1)
        raise RuntimeError(
            "devtool container did not start; see " + str(state / "container.log")
        )


def serve(args):
    state = Path(args.state)
    cid = Path("/etc/hostname").read_text().strip()
    temporary = state / "container.tmp"
    temporary.write_text(cid)
    temporary.replace(state / "container")
    while True:
        time.sleep(3600)


def terminate_group(group):
    try:
        # SIGINT lets pytest run fixture teardown before escalation.
        os.killpg(group, signal.SIGINT)
        deadline = time.monotonic() + 5
        while time.monotonic() < deadline:
            os.killpg(group, 0)
            time.sleep(0.1)
        os.killpg(group, signal.SIGTERM)
        time.sleep(1)
        os.killpg(group, signal.SIGKILL)
    except ProcessLookupError:
        pass


def quiesce(args):
    state = Path(args.state)
    with (state / "jobs.lock").open("w") as lock:
        fcntl.flock(lock, fcntl.LOCK_EX)
        (state / "stopping").touch()
        groups = []
        for pidfile in state.glob("*.pid"):
            try:
                groups.append(int(pidfile.read_text()))
            except FileNotFoundError:
                pass
    with ThreadPoolExecutor() as pool:
        list(pool.map(terminate_group, groups))


def inside(args):
    pidfile = Path(args.pidfile)
    argv = args.command[1:] if args.command[:1] == ["--"] else args.command
    with (pidfile.parent / "jobs.lock").open("w") as lock:
        fcntl.flock(lock, fcntl.LOCK_EX)
        if (pidfile.parent / "stopping").exists():
            raise RuntimeError("devtool container is stopping")
        child = subprocess.Popen(argv, start_new_session=True)
        pidfile.write_text(str(child.pid))
    try:
        return child.wait()
    finally:
        terminate_group(child.pid)
        pidfile.unlink(missing_ok=True)


def kill_run(args):
    pidfile = Path(args.pidfile)
    if pidfile.exists():
        terminate_group(int(pidfile.read_text()))


def execute(args):
    state = Path(args.state)
    cid = ensure(args)
    remote = container_path(state, args.root)
    pidfile = remote + "/" + uuid.uuid4().hex + ".pid"
    argv = args.command[1:] if args.command[:1] == ["--"] else args.command
    cmd = ["docker", "exec", "-i", "-w", args.cwd]
    for name, value in json.loads(args.env).items():
        cmd += ["-e", name + "=" + str(value)]
    cmd += [
        cid,
        "python3",
        remote + "/transport.py",
        "inside",
        "--pidfile",
        pidfile,
        "--",
        *argv,
    ]
    kill = [
        "docker",
        "exec",
        cid,
        "python3",
        remote + "/transport.py",
        "kill",
        "--pidfile",
        pidfile,
    ]
    child = subprocess.Popen(cmd)
    interrupted = False

    def cancel(_signum, _frame):
        nonlocal interrupted
        if not interrupted:
            interrupted = True
            subprocess.run(
                kill, timeout=10, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL
            )
            child.terminate()

    for sig in (signal.SIGTERM, signal.SIGINT, signal.SIGHUP):
        signal.signal(sig, cancel)
    code = 1
    try:
        code = child.wait()
    finally:
        if interrupted:
            subprocess.run(
                kill, timeout=10, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL
            )
        if argv and Path(argv[0]).name == "cargo":
            repair = fix_permissions(cid, state, cargo_only=True)
            if repair.returncode:
                sys.stderr.buffer.write(repair.stderr)
                if code == 0:
                    code = repair.returncode
    return 130 if interrupted else code


def prepare_debugpy(args):
    # Cache by Python ABI, machine, and requested version, not Neovim PID.
    key = hashlib.sha256(
        (args.package + sys.version + platform.machine()).encode()
    ).hexdigest()[:16]
    base = Path("/firecracker/build/.nvim-devtool/python")
    base.mkdir(parents=True, exist_ok=True)
    target = base / key
    with (base / (key + ".lock")).open("w") as lock:
        fcntl.flock(lock, fcntl.LOCK_EX)
        if not (target / "debugpy/__init__.py").exists():
            temporary = Path(tempfile.mkdtemp(prefix=key + "-", dir=base))
            try:
                subprocess.run(
                    [
                        sys.executable,
                        "-m",
                        "pip",
                        "install",
                        "--disable-pip-version-check",
                        "--target",
                        str(temporary),
                        args.package,
                    ],
                    check=True,
                    stdout=sys.stderr,
                )
                temporary.replace(target)
            finally:
                if temporary.exists():
                    shutil.rmtree(temporary)
    print(target)


def pytest_entry(args):
    state = Path(args.state)
    # Serialise preparation/runs: test.sh refreshes shared /srv artifacts.
    with open("/srv/nvim-pytest.lock", "w") as lock:
        fcntl.flock(lock, fcntl.LOCK_EX)
        # FD 3 is reserved for DAP stdout below; retain the lock on another FD.
        lock_fd = fcntl.fcntl(lock.fileno(), fcntl.F_DUPFD, 10)
        os.set_inheritable(lock_fd, True)
    selection = Path("/firecracker/build/current_artifacts")
    identity = selection.read_text().strip() if selection.exists() else "<no artifacts>"
    marker = Path("/srv/nvim-artifacts-ready")
    reuse = (
        marker.exists()
        and marker.read_text() == identity
        and Path("/srv/test_artifacts").is_dir()
    )
    bindir = state / ("pytest-debug" if args.debug else "pytest-run")
    bindir.mkdir(exist_ok=True)
    shim = bindir / "pytest"
    python_args = (
        ["python3", "-m", "debugpy.adapter"]
        if args.debug
        else ["python3", str(state / "neotest.py")]
    )
    # Reaching pytest means test.sh completed artifact preparation successfully.
    shim.write_text(
        "#!/bin/sh\nprintf %s "
        + shlex.quote(identity)
        + " > "
        + str(marker)
        + "\nexec "
        + shlex.join(python_args)
        + ' "$@" >&3\n'
    )
    shim.chmod(0o755)
    env = dict(os.environ, PATH=str(bindir) + os.pathsep + os.environ["PATH"])
    if reuse:
        env["FC_TEST_SKIP_ARTIFACT_COPY"] = "1"
    if args.python_path:
        env["PYTHONPATH"] = args.python_path + os.pathsep + env.get("PYTHONPATH", "")
    command = args.command[1:] if args.command[:1] == ["--"] else args.command
    os.execvpe(
        "bash",
        [
            "bash",
            "-c",
            'exec 3>&1; exec bash /firecracker/tools/test.sh "$@" >&2',
            "devtool-pytest",
            *command,
        ],
        env,
    )


def main():
    p = argparse.ArgumentParser()
    p.add_argument(
        "action",
        choices=[
            "ensure",
            "keep",
            "serve",
            "exec",
            "inside",
            "kill",
            "stop",
            "pytest",
            "prepare-debugpy",
            "quiesce",
        ],
    )
    p.add_argument("--root")
    p.add_argument("--state")
    p.add_argument("--runner")
    p.add_argument("--owner", type=int)
    p.add_argument("--pidfile")
    p.add_argument("--cwd", default="/firecracker")
    p.add_argument("--env", default="{}")
    p.add_argument("--debug", action="store_true")
    p.add_argument("--python-path")
    p.add_argument("--package", default="debugpy")
    args, args.command = p.parse_known_args()
    if args.action == "stop":
        stop(Path(args.state))
    elif args.action == "ensure":
        print(ensure(args))
    else:
        return {
            "keep": keep,
            "serve": serve,
            "exec": execute,
            "inside": inside,
            "kill": kill_run,
            "pytest": pytest_entry,
            "prepare-debugpy": prepare_debugpy,
            "quiesce": quiesce,
        }[args.action](args)


if __name__ == "__main__":
    try:
        sys.exit(main() or 0)
    except Exception as exc:
        print("devtool editor transport: " + str(exc), file=sys.stderr)
        sys.exit(1)
