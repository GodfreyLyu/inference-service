# Extraction provenance

The read-only source was `GodfreyLyu/LocalQwenDemo`, commit
`a76de47f75362ef6f34fe21771383c70f90c5379` (2026-11-05). Its working tree was clean
before extraction. Only tracked inference implementation, generated contracts,
protocol tooling and applicable examples were copied. No credentials, model
weights, virtual environments, runtime data or platform deployment state were copied.
The original remote, Minikube, Argo CD, frontend and platform infrastructure remain
in the source project. The new repository requires none of those paths.

The generic v1 Thrift API and compiler/runtime 0.25.0 remain unchanged. Contract
package version and service version are separate release decisions even though
both begin at 1.0.0. `contracts/` is an independently buildable Python package in
this repository, not an implementation dependency in another source checkout.

The Fedora ARM64/Ollama/Mesa krunkit package pins are retained. The extraction
changes the image build context to this project root. Deployment examples are
new templates; they do not modify the existing cluster or release ownership.
