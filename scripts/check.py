"""Run this repository's checks without another checkout or a model."""

import argparse
import os
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def run(*args, env=None):
    subprocess.run([sys.executable, *args], cwd=ROOT, env=env, check=True)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--java", action="store_true", help="Require JDK11+ and Maven3.9+")
    args = parser.parse_args()
    run("-m", "ruff", "check", "src", "tests", "scripts")
    run("-m", "ruff", "format", "--check", "src", "tests", "scripts")
    run("scripts/generate_thrift.py", "--check")
    environment = os.environ.copy()
    if args.java:
        environment["RUN_JAVA_INTEROP"] = "1"
    run("-m", "pytest", env=environment)


if __name__ == "__main__":
    main()
