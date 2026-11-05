# Generic LLM protocol package

`llm.thrift` is the protocol source of truth. `python/llm_contract/generated` and
`java/demo/llm/generated` are byte-for-byte reproducible generated outputs of
**Apache Thrift 0.25.0**. Python runtime and Maven libthrift are also fixed at
**0.25.0**. Do not edit generated files manually. No review-specific fields or
business rules belong in this package.

## Version and distribution

The Python package is `local-llm-contract==1.0.0`; the inference implementation has
an independent package/image version. Build this package from the repository root:

```bash
.venv/bin/python -m build --wheel --outdir dist contracts
```

```bash
.venv/bin/python scripts/generate_thrift.py --check
```

The immutable initial wheel is published in the private
[contracts-v1.0.0 release](https://github.com/GodfreyLyu/inference-service/releases/tag/contracts-v1.0.0).
Its SHA256 is `620efac1f6f81475e71e4a5d22c06090c6a4c028ed2a46bc1554ffb1a9c41d2f`.
The source commit is `30fbcecb5b5a071e33afe0b268c75dd3da6192c7`. A second retrieval
route is the artifact-only `contracts-dist` branch, pinned to immutable commit
`7a51e2717085d774c55696a1fb8d050bec7c62b0`, which contains the wheel and checksum
without inference source. Backend fetches that exact Git object using its own
read-only deploy key, verifies the wheel hash, and installs the wheel normally.
It neither follows `main` nor installs the implementation. Private Release downloads
require authenticated repository read permission too. The repository stays private.

Do not move existing contract tags, replace wheel assets or overwrite published
versions. Future releases bump `contracts/pyproject.toml` deliberately, regenerate
and test Python/Java, build and checksum a wheel, publish it and pin consumers to
its immutable artifact commit/hash. CI's local builds test the package; they do
not automatically publish or overwrite an artifact.

## Wire and field semantics

Transport is framed TCP with strict binary protocol. Frames/strings are capped
at 2 MiB, decoded containers at 64 entries. The service allows up to 32 messages,
64,000 message characters and 128,000 result characters by default. TCP has no
native TLS/auth; callers must use a trusted private network or authenticated TLS
proxy/service mesh. Authentication policy is outside v1 IDL, not a review field.

| Structure | Stable field meaning |
| --- | --- |
| Message | role is system/user/assistant; content is generic text. |
| GenerationOptions | Optional output cap, finite temperature 0..2, top-p >0..1, nonnegative signed i64 seed. Omitted values use service defaults. |
| Limits | Actual active/pending/retained limits, TTL/deadline milliseconds and input/output caps. |
| ModelInfo | Per-process instance UUID, pinned model identity/revision, defaults/limits and optional quantization/device. |
| Health | ready/draining and current active/pending counts. |
| GenerationRequest | Caller request ID and exact instance, messages/options, admission-to-completion elapsed deadline in ms (includes queueing). |
| GenerationSnapshot | Request/instance identity, state, optional result/error and terminal expiry epoch ms. |
| GenerationResult | Content, model identity, input/output token usage, stop/length reason and optional durations. |
| LlmError | Stable code, safe message without submitted/generated content, retryable hint. |

| RPC | Semantics |
| --- | --- |
| getModelInfo | Discover instance, identity and execution policy before submission. |
| getHealth | Inspect readiness/draining and slot occupancy, independently of model info. |
| startGeneration | Admit bounded generic execution and return a snapshot quickly. Same ID+identical payload on same instance returns existing task, including terminal result. Different payload gives idempotency_conflict. Explicit defaults and omitted values are distinct. |
| getGeneration | Query on the same endpoint with original instance/request. Does not start execution. |
| cancelGeneration | Idempotently request cancellation on that same endpoint/instance. Queued work can become CANCELLED immediately. Active work becomes CANCELLING until native exit is proven. |

States QUEUED(1), RUNNING(2), CANCELLING(3), SUCCEEDED(4), FAILED(5), CANCELLED(6)
have permanent numeric values. Terminal snapshots carry `expires_at_ms`; results
are never evicted before their TTL to admit another request. After expiry, ID reuse
can execute again. Restart loses the in-memory registry and creates a new UUID.

## Errors, deadlines and uncertain execution

| Codes | Meaning and caller rule |
| --- | --- |
| invalid_request, input_limit | Reject invalid messages/options or limits; correct input instead of retrying unchanged. |
| idempotency_conflict | Existing request has a different payload; do not overwrite it. |
| overloaded, retention_full, unavailable | Admission rejected due to bounded capacity, retention or recovery/shutdown. Retryable hint permits policy-bounded backoff, subject to caller deadlines. |
| instance_changed | Supplied instance differs from current process. Old execution/result is unknown; never blindly resubmit. |
| not_found | Request never existed or retention expired. This does not prove no native work ran. |
| deadline_exceeded, cancelled, shutdown | Execution cancelled by deadline, explicit cancellation or shutdown; inspect terminal state. |
| ollama_unavailable, model_missing, model_mismatch, gpu_required, version_unsupported | Runtime/model startup or execution failed validation. Correct deployment or reconcile, respecting retryable hint. |
| invalid_response, output_limit, execution_failed | Native execution/output failed validation; the service sanitizes errors. |

A two-second client socket timeout is a per-connection/read limit, not the model
execution deadline. An RPC timeout/lost response does not stop GPU work. Persist
IDs before submitting, recover with getGeneration and cancel when required, and
wait for terminal acknowledgement. If identity changed, a result expired, or exit
cannot be confirmed, persist an explicit recovery state and require reconciliation.
Never assume a `retryable` error permits re-executing an uncertain start.

Defaults are one active generation, eight pending, 128 retained entries, 300-second
maximum deadline and 600-second terminal TTL. Actual settings are discoverable.
During active cancellation the owned Ollama process group is terminated/reaped and
the pinned model reloaded; that recovery may exceed the generation deadline. The
slot remains occupied while recovery is unresolved. If native exit cannot be
proven, the service drains/fails closed and cannot advertise terminal cancellation.

## Compatibility policy

- Never reuse/renumber field IDs or enum values or change their wire type/meaning.
- Add optional fields with new IDs; preserve required fields and omission semantics.
- Add methods without changing existing signatures. Required fields, removed or
  renamed methods and breaking semantics require a new protocol version/rollout.
- Old clients skip unknown optional fields. Unknown enum/error values must fail
  safely. Cancellation, retention and instance guarantees remain compatible.
- Contract versions and service/image releases are independent; service releases
  declare supported protocol version. This extraction preserves generic v1 exactly.

Java bindings and examples are compiled against pinned libthrift using Maven3.9+
and JDK11+. The real TCP interop gate covers shared request IDs, cancellation,
structured errors, lost responses, maximum signed i64 seeds, concurrent clients
and connection closure:

```bash
.venv/bin/python scripts/java_thrift.py --compile-only
```

```bash
RUN_JAVA_INTEROP=1 .venv/bin/python -m pytest tests/test_java.py
```
