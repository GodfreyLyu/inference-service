# Inference service

An independently installable generic LLM service. It owns the Ollama process,
model revision, resource limits, scheduling, execution and cancellation. The API
accepts generic role/content messages; it has no review, user, database or Kafka
fields. The protocol package lives in [contracts/](contracts/README.md) and has its
own version and wheel release.

The read-only extraction source is recorded in [MIGRATION.md](docs/MIGRATION.md).
No sibling checkout, frontend, GPU or model is required for the ordinary checks.

## Install and check

Use Python 3.12 (runtime supports 3.12 through 3.15), Apache Thrift **0.25.0**,
JDK 11+ and Maven 3.9+. Commands run from this project root. Create this project's
own environment; do not share the backend interpreter.

```bash
python3.12 -m venv .venv
```

```bash
.venv/bin/python scripts/bootstrap.py
```

Bootstrap installs fully pinned third-party dependencies, builds the contract and
service wheels, and installs both normally with `--no-deps`. It does not use
editable installs. Build isolation obtains the setuptools build tool specified by
the packages; application dependencies are fixed in `requirements*.lock`.

```bash
.venv/bin/python scripts/check.py --java
```

This checks lint/format, byte-for-byte Python/Java generation, unit tests, real
Thrift TCP functional tests, native child lifecycle and Java interoperability.
Maven builds the examples in `contracts/target/`. Set `MAVEN` to an alternate
Maven executable if it is not on PATH. `scripts/install_thrift.sh` builds the
exact compiler on Linux (requires bison, cmake, flex, g++ and make); the archive
SHA256 is checked before building.

For separate test scopes:

```bash
.venv/bin/python -m pytest -m 'not functional and not real_model'
```

```bash
RUN_JAVA_INTEROP=1 .venv/bin/python -m pytest -m functional
```

The functional tests use actual generated Thrift clients/processors and TCP;
execution uses a controlled model double. Adapter tests mock Ollama HTTP, and
lifecycle tests launch real disposable native child processes. These checks do
not validate model quality, GPU drivers, production HA or real model loading.
The restart test kills/replaces a real service process and verifies instance fencing.

## Start and stop

Ollama 0.24.0+ must be available on PATH for host execution. The service launches
its own child and fails if the configured native port is occupied. No global
Ollama daemon is contacted. Install the pinned model separately or explicitly
enable pulling; never replace a mismatched revision.

```bash
cp .env.example .env
```

For CPU development set `REQUIRE_GPU=false` in `.env`; the default remains
GPU-required. Set `OLLAMA_PORT` to a free loopback port if an existing daemon uses
11434, and `OLLAMA_MODELS` to your model directory if needed. Configuration
settings are validated by `src/llm_service/config.py`; the example lists policy
and limits. Application configuration and runtime data are ignored by Git.

```bash
.venv/bin/llm-service
```

Use Ctrl-C or SIGTERM to drain. The process rejects new work, cancels queued
requests, terminates/reaps its owned Ollama process group, joins the generation
worker and closes listeners. Default shutdown budget is 20 seconds; deployment
termination grace must exceed it. Health endpoints are `/live` and `/ready` on
11435; Thrift is 9091 and native HTTP remains loopback-only on 11434.

A generic Python client can make a real generation against an already running
instance (this prints the synthetic prompt's result):

```bash
.venv/bin/python scripts/thrift_demo.py --host 127.0.0.1 --port 9091 --prompt 'Translate Hello to French.'
```

The Java example has no service implementation dependency:

```bash
.venv/bin/python scripts/java_thrift.py --compile-only
```

```bash
.venv/bin/python scripts/java_thrift.py --host 127.0.0.1 --port 9091
```

Opt-in hardware verification requires an already running service with the pinned
model and full GPU residency. It performs real inference and is separate from
ordinary tests:

```bash
.venv/bin/python -m llm_service.verify --host 127.0.0.1 --port 9091
```

## Build and local deployment

```bash
.venv/bin/python -m build --wheel --outdir dist .
```

```bash
.venv/bin/python -m build --wheel --outdir dist contracts
```

The service and contract wheels have independent versions. Only publish a new
contract version when releasing a new artifact; do not replace an existing
version or release asset. Backend uses the fixed released artifact described in
[contracts/README.md](contracts/README.md), never this implementation package.

The image preserves the source Fedora ARM64/Ollama/Mesa krunkit stack and accepts
this project root as its complete context:

```bash
docker build --platform linux/arm64 -t inference-service:local .
```

Without `.env` or shell overrides, Compose selects CPU development and allows a
missing pinned model to be pulled. A copied `.env.example` takes precedence for
these values: explicitly set `REQUIRE_GPU=false` for CPU and
`MODEL_PULL_IF_MISSING=true` to allow downloads. Compose binds published ports to
loopback, persists models in its own named volume, and applies memory, CPU, process
and shutdown limits. It does not attach any existing cluster or data.

```bash
docker compose up -d --build
```

```bash
docker compose logs -f inference
```

```bash
docker compose down
```

`down` preserves the model volume. The image is ARM64/krunkit-specific, not a
portable x86 production image. GPU access in a krunkit VM requires the appropriate
render node/device permissions; CPU testing does not establish GPU readiness.

[deploy/inference.yaml](deploy/inference.yaml) is a single-instance Kubernetes
starting template, not an applied deployment. Supply your own model PVC, immutable
image digest, render-node permissions and namespace. It uses Recreate strategy:
clients must send start/get/cancel to the same instance endpoint. One active native
generation is enforced; increasing replicas without durable affinity/routing is
unsupported. Probe, resource, persistence and graceful-exit settings are explicit.

The v1 Thrift wire protocol has no native TLS/auth. Keep it on a private trusted
network; production requires an authenticated TLS proxy or service mesh. The
optional [mTLS policy example](deploy/mtls.example.yaml) provides configuration
entry points for strict mTLS and worker service-account authorization in an
existing Istio mesh. It has not been applied or verified against your cluster.
Never expose raw Thrift or native Ollama publicly. Existing Minikube/Argo releases
remain unchanged.

## Execution and recovery

Only one native generation runs, with a bounded pending queue and retained result
registry. RPC connection timeouts do not cancel execution. A caller must persist
`instance_id` and `request_id` before submission and reconcile uncertain responses
with `getGeneration`; it must not blindly create a new request. Cancellation
returns CANCELLING while native shutdown/recovery is unresolved; only a terminal
snapshot confirms completion. The service fails closed if exit cannot be proven.

Registry/results are in memory. Restart creates a new instance UUID and loses
old results; `instance_changed` and `not_found` cannot prove the old operation did
not run. Terminal results are retained for their advertised TTL (600 seconds by
default), then lookup can fail. Operators must reconcile unknown work with the
calling application's durable state. Do not reuse an expired request ID to retry
an uncertain operation. See [the complete compatibility contract](contracts/README.md).

## IDEA

Open **this directory** as its own IDEA project with the Python plugin. Choose
an existing interpreter at `.venv/bin/python` in Python SDK settings. Shared
[.run/](.run/) configurations use `$PROJECT_DIR$` and this interpreter for service,
unit tests, functional tests and generation checks. Configure JDK/Maven and
Thrift PATH for Java/generation checks. Open `review-backend` separately; do not
make the parent folder a combined project. No GUI settings were performed during
migration and no personal `.idea/workspace.xml` is committed.

## Verification record

See [docs/VERIFICATION.md](docs/VERIFICATION.md) for actual checks and boundaries.
GitHub Actions builds and tests this repository alone; it never checks out backend.
