# Verification evidence

Recorded 2026-11-05 in the new standalone project. These are executed checks,
not claims about the original deployment or production readiness.

| Check | Actual result | Boundary |
| --- | --- | --- |
| Python 3.12 own `.venv`, fully pinned development dependencies | Installed successfully | No source venv copied. |
| Contract wheel v1.0.0 | Built; SHA256 `620efac1f6f81475e71e4a5d22c06090c6a4c028ed2a46bc1554ffb1a9c41d2f` | Exact initial release artifact; later local wheel ZIP timestamps can differ. |
| Contract generation | Python and Java byte-for-byte match `llm.thrift` with compiler0.25.0 | No protocol changes. |
| Service wheel | Built and installed normally with `--no-deps` | Both llm_service/llm_contract resolve from site-packages, not source paths. |
| Unit scope | 23 passed | Native adapter HTTP is mocked; lifecycle launches disposable real child processes. |
| Functional scope | 23 passed, including 4 Java interop cases | Real generated Thrift clients/processors over TCP, controlled model execution, real service-process kill/restart. No real GPU/model. |
| Combined gate | 46 passed; lint and format passed | Maven3.9.12 + JDK24 locally; CI config selects JDK11, not yet claimed locally. |
| Compose | `docker compose config --quiet` passed | Model-loading Compose runtime not started. |
| ARM64 image | `docker build --platform linux/arm64 -t inference-service:migration-verification .` passed | Fedora/Ollama/Mesa package pins retained. Docker Desktop build; package layer reused local cache. No krunkit/GPU execution. |

Built image manifest:
`sha256:febc209ab200d7321b6638a733d9c7d522f975be28aed727c07909f1a3e6aef7`.

The functional tests cover generic generation/query and shared ID idempotency,
conflicting IDs, concurrent duplicate submissions, single native slot and pending
limit, cancellation waiting for native exit, orphaned deadlines, TTL/retention,
lost TCP submission response, invalid messages/options, graceful shutdown,
malformed frames and unprovable native exit. The process restart case proves a
new instance fences old request IDs and has no retained results. Java/Python cases
include structured errors, signed64-bit seeds, lost-response reconciliation,
connection closure and concurrent callers.

Not executed here: real model quality/inference, krunkit render-node access, GPU
residency, production HA, Kubernetes templates or service-mesh policy application,
GUI SDK/run configuration selection. Those remain explicit manual/opt-in steps.
The migration does not inspect or change the original Minikube or Argo CD state.

GitHub Actions and clean-clone results are recorded by the coordinating migration
report after the repository is committed and pushed. The checked-in CI only
checks out this repository.
