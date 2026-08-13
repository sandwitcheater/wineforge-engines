# Reproducibility roadmap

The current build is provenance-oriented: all inputs controlled by this
repository are pinned, while GitHub-hosted runner images remain rolling inputs.
Build metadata makes drift visible but does not eliminate it.

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

