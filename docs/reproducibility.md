# Reproducibility roadmap

The current build is provenance-oriented: all inputs controlled by this
repository are pinned, while GitHub-hosted runner images remain rolling inputs.
Build metadata makes drift visible but does not eliminate it. CI uploads a
small reference record by default, not the compiled engine archive.

To claim reproducibility:

1. build Linux inside a builder image pinned by OCI digest;
2. build macOS with a versioned SDK and content-addressed dependency bundle;
3. set `SOURCE_DATE_EPOCH` from a reviewed manifest value;
4. normalize archive ownership, ordering, modes, and timestamps;
5. compare two independent builds after removing platform signatures;
6. document every accepted nondeterministic path; and
7. attest both the artifact and the comparison report.

The packaging script already normalizes the tar archive. Compilers, linkers,
Mach-O metadata, and source-generated files may still embed nondeterminism.
Source patches are version-scoped, SHA-256-pinned in the engine manifest, and
recorded in each artifact's build evidence.

## Independent local builds

Linux builds run in the pinned `containers/linux/Containerfile` using Podman or
Docker. macOS builds run natively because OCI runtimes on macOS host Linux
containers and cannot produce the native Mach-O runtime against macOS system
frameworks.

```sh
./scripts/build-local.sh 24.0.7 linux-x86_64 --runtime podman
./scripts/build-local.sh 24.0.7 macos-x86_64
```

Each build produces a `*.reference.json`. Download the matching CI reference
artifact and compare it without exchanging the engine binary:

```sh
./scripts/compare-reference.py \
  local-builds/crossover-24.0.7-linux-x86_64/dist/*.reference.json \
  ci-reference/wineforge-engine-24.0.7-linux-x86_64.reference.json
```

Input mismatch is always an error. Content or archive differences are reported
because rolling compilers and SDKs may still generate different bytes. Add
`--require-exact` when byte-for-byte equivalence is required.
