"""Install locked development tools and normal wheels in this Python environment."""

import os
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def run(*args):
    subprocess.run([sys.executable, *args], cwd=ROOT, check=True)


def main():
    os.chdir(ROOT)
    run("-m", "pip", "install", "-r", "requirements-dev.lock")
    run("-m", "build", "--wheel", "--outdir", "dist", "contracts")
    run("-m", "build", "--wheel", "--outdir", "dist", ".")
    run(
        "-m",
        "pip",
        "install",
        "--no-deps",
        "--force-reinstall",
        "dist/local_llm_contract-1.0.0-py3-none-any.whl",
        "dist/local_ollama_llm_service-1.0.0-py3-none-any.whl",
    )


if __name__ == "__main__":
    main()
