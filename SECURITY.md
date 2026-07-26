# Security Policy

## Secrets

Never commit:

- Tailscale auth keys.
- OAuth client secrets.
- Router API keys.
- Model provider API keys.
- SSH private keys.
- Real production policy files containing sensitive identities or network structure.
- Prompt or audit logs containing regulated or confidential data.

The files in `config/` are templates.

## Reporting

Report suspected credential exposure by revoking the credential first, isolating affected nodes, and then using the private project security channel.

## Scope

The included model router is an instructional reference. It is not a substitute for production authentication, authorization, secret management, audit retention, prompt redaction, or policy enforcement.
