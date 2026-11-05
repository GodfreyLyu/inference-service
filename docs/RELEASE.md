# Independent service releases

The implementation package/image and generic protocol package have independent
versions. A service release contains only the service wheel and its SHA256 file.
It does not republish or replace the existing contract wheel, artifact commit or
`contracts-v1.0.0` tag.

## Publish a service wheel

Update the service version in root `pyproject.toml` when releasing a new version;
keep `contracts/pyproject.toml` unchanged unless the protocol package itself needs
a separate release. Update dependency locks when dependencies change, commit and
push this repository, and wait for its independent `ci.yml` workflow to pass for
that exact commit. The CI builds/tests only this repository and checks Python,
Java, Thrift generation and the ARM64 image.

From this project's own environment, build and validate without calling GitHub:

```bash
.venv/bin/python scripts/publish_service.py --dry-run
```

Publish after the exact commit's CI is green:

```bash
.venv/bin/python scripts/publish_service.py
```

This builds a normal service wheel, checks its package/version/contents, writes a
SHA256 sidecar, requires a clean checkout and a private GitHub repository, and
verifies successful independent CI for checkout HEAD. It atomically creates a new
`service-vVERSION` tag pointing to that exact commit, then creates the private
Release and uploads only the service wheel and checksum. It has no clobber/update
path and refuses an existing tag. `--tag` and `--target` may make the expected
version/commit explicit, but must match `pyproject.toml` and HEAD. `--wheel` can
consume the already validated wheel produced by the same commit's CI.

Use authenticated GitHub CLI access with repository write permission. Missing
authentication, failed CI, tag collisions and publication failures remain errors;
never change repository visibility to work around them. If tag creation succeeds
but Release upload fails, the tag remains at its exact commit. Inspect it and
complete that same Release manually after verifying its commit and wheel hash;
do not move/delete the tag or overwrite an existing artifact.

The service wheel declares a fixed contract dependency; installers need the
separately released contract wheel and locked runtime dependencies. A service wheel
alone does not include the native Ollama/model runtime. Use the independently
built image or a host Ollama installation as described in the README.

## Optional release workflow and image

The `Release inference service` workflow is explicitly dispatched from a committed
main revision after its normal CI succeeds. It reruns the reusable independent
CI, downloads its wheel artifact, and calls the same publish script with the exact
workflow commit. The input tag must match the root service package version.
It requires `contents:write` and `actions:read` for private wheel publication.

For example, after changing the service package to 1.0.1 and obtaining green CI:

```bash
gh workflow run release-service.yml -f tag=service-v1.0.1 -f publish_image=false
```

Selecting `publish_image=true` additionally builds this repository's ARM64 image
on an ARM hosted runner and pushes
`ghcr.io/godfreylyu/inference-service:VERSION`, using `packages:write`. The image
records the exact source commit and source repository as OCI labels. This path
requires package publication permission and private GHCR package access policy;
keep the package private and grant deployment identities read access. It is
optional and has not been exercised by the initial wheel-only migration release.
The successful standalone image build does not imply GPU runtime verification.

Choose the image option when creating the new release; an existing service tag
cannot be republished through the workflow. Re-run a failed image job only after
examining the existing wheel/tag state, preserving the same source/version.
Native runtime deployment, model-volume provisioning and production promotion
remain separate operations. This workflow never checks out backend or changes
its release/deployment.
