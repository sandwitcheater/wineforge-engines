# Third-party licensing

This repository's MIT licence covers only original manifests, scripts, and
workflow definitions.

The CodeWeavers source archives aggregate Wine and other projects under
component-specific licences. Builds must preserve notices from the source tree.
Before any public runtime release, a reviewer must:

1. inspect the source archive's licence and copyright files;
2. map every shipped file to an SPDX licence expression;
3. confirm source-offer and notice obligations;
4. exclude any component that cannot be redistributed;
5. record the decision in a reviewed manifest change; and
6. set `redistribution.status` to `approved` with reviewer and evidence links.

User acceptance is useful for displaying licence terms but is not a substitute
for redistribution permission. Until approval, workflows may create private CI
artifacts for testing but refuse GitHub Release publication.

