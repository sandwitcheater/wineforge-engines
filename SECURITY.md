# Security policy

## Reporting

Do not open a public issue for a suspected compromised source, workflow,
credential, or release. Use GitHub's private vulnerability reporting feature.
Repository administrators should publish a private reporting contact before the
first release.

Include the affected version/platform, artifact SHA-256, attestation result, and
the smallest safe reproduction. Do not include credentials or personal data.

## Supported artifacts

Only artifacts whose digest appears in a GitHub Release and has a valid GitHub
artifact attestation are supported. CI artifacts from pull requests, forks, and
untrusted branches are test outputs.

## Security boundaries

- A matching hash establishes integrity against this repository's pin, not
  publisher identity or absence of malicious code.
- An attestation establishes workflow provenance, not safety.
- An SBOM is an inventory aid and can be incomplete for dynamically loaded code.
- Wine runs Windows code with the permissions of its host process. Runtime
  provenance does not make an untrusted Windows program safe.

Release jobs use least-privilege `GITHUB_TOKEN` permissions, protected
environments, immutable action pins, verified downloads, and no pull-request
execution with write credentials.

## Revocation

For a compromised artifact, maintainers should remove it from the release,
publish a security advisory containing its digest, revoke or supersede its
manifest entry, and issue a replacement under a new version. Never silently
replace bytes under an existing tag.

