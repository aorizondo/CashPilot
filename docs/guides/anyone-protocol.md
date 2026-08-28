# Anyone Protocol

> **Category:** DePIN | **Status:** Active
> **Website:** [https://anyone.io](https://anyone.io)

## Description

Anyone Protocol (formerly ATOR) is a decentralized onion-routing privacy network. Node operators run relay nodes and earn ANYONE tokens for bandwidth contributed. Think "incentivized Tor." This guide covers deploying the relay with CashPilot, which uses the `aorizondo/anyone-anon` image that renders the `anonrc` from environment variables at startup (no config file to mount). Available for amd64 and arm64.

## Earning Estimates

| Metric | Value |
|--------|-------|
| Monthly range | $0 - $50 (estimate) |
| Per | relay |
| Minimum payout |  |
| Payout frequency | Epoch-based |
| Payment methods | Crypto |

> Earnings based on bandwidth contributed and uptime. Non-hardware relays must lock 100 ANYONE per relay and hold the prerequisite at airdrop time.

## Requirements

| Requirement | Value |
|-------------|-------|
| Residential IP | No |
| Minimum bandwidth | 10 Mbps |
| GPU required | No |
| Minimum storage | None |
| Supported platforms | Docker, Linux |

## Setup Instructions

### 1. Create an account

No account creation is needed. Anyone Protocol relays are permissionless — you just run a node and earn ANYONE tokens based on uptime and bandwidth.

### 2. Deploy with CashPilot (env-var image)

In the CashPilot web UI, find **Anyone Protocol** in the service catalog and click **Deploy**. The `aorizondo/anyone-anon` image builds the `anonrc` from the fields you fill in — there is no `anonrc` file to mount. Key fields:

- **ANON_NICKNAME** — relay name, 1–19 chars `[a-zA-Z0-9]`, no spaces. Defaults to the deploy hostname so each relay is unique when deploying many at once.
- **ANON_ETHEREUM_ADDRESS** — your EVM wallet (`0x…`). Written as `ContactInfo @anon: <addr>`; required to earn ANYONE.
- **ANON_ORPORT** — onion routing port (default 9001). Must be reachable on the host.
- **ANON_CONTROLPORT** — control port for monitoring (default 9051); set `0` to disable.
- **ANON_EXITRELAY** — `0` = middle/guard (recommended), `1` = exit (needs an exit policy + more legal exposure).
- **ANON_AGREETOTERMS** — must be `1` or the relay exits immediately. Defaults to `1`.

> **`AgreeToTerms 1` is mandatory.** Without it the container exits with "User has not agreed to the terms and conditions."

### 3. Port forwarding (required)

**Port TCP 9001 must be forwarded** to the server running the relay. The relay performs a self-test by connecting to its own ORPort from the outside. If the port is not reachable, the relay **will not publish its descriptor** to the network directory — it stays invisible, handles zero traffic, and earns nothing. You'll see repeated warnings in `notices.log`:

> "Your server has not managed to confirm reachability for its ORPort(s). Relays do not publish descriptors until their ORPort and DirPort are reachable."

If running behind a firewall (e.g. ufw), also allow port 9001/tcp inbound.

### 4. MyFamily (operating multiple relays)

If you run more than one relay, declare them as a family so the network doesn't double-count your relays as independent bandwidth. `MyFamily` is a list of relay fingerprints.

- **You can't know a fingerprint before the relay runs once.** The fingerprint is a hash of the relay's identity key, generated on first start in the data volume. So the workflow is two-phase:
  1. **Deploy each relay with `ANON_MYFAMILY` empty.** Each generates its own identity.
  2. **Collect the fingerprints.** Read `/var/lib/anon/fingerprint` inside the container, run `docker exec cashpilot-anyone-protocol anon --list-fingerprint` on the host, or look the relay up at [api.ec.anyone.tech/relays](https://api.ec.anyone.tech/relays/).
  3. **Set `ANON_MYFAMILY` on every relay** to the comma-separated list of *all* your fingerprints (including each relay's own), then restart.
- **Persist the data volume.** The `anon-data` volume holds the identity key. If you delete it, the relay gets a new identity and a new fingerprint — and your `MyFamily` list silently breaks. Don't wipe it.

## Docker Configuration

- **Image:** `aorizondo/anyone-anon`
- **Platforms:** linux/amd64, linux/arm64

### Environment Variables

| Variable | Label | Required | Secret | Description |
|----------|-------|:--------:|:------:|-------------|
| `ANON_NICKNAME` | Relay nickname | Yes | No | 1–19 chars `[a-zA-Z0-9]`, no spaces. Defaults to hostname. |
| `ANON_ETHEREUM_ADDRESS` | Ethereum wallet (rewards) | No* | No | `0x…` address; written as `ContactInfo @anon: <addr>`. Required to earn. |
| `ANON_ORPORT` | ORPort | No | No | Default 9001. |
| `ANON_CONTROLPORT` | ControlPort | No | No | Default 9051; `0` disables. |
| `ANON_EXITRELAY` | Exit relay | No | No | `0` (default) = middle/guard; `1` = exit. |
| `ANON_BANDWIDTHRATE` | Bandwidth rate (Mbit) | No | No | e.g. `100`. Empty = unlimited. |
| `ANON_BANDWIDTHBURST` | Bandwidth burst (Mbit) | No | No | e.g. `120`. Empty = unlimited. |
| `ANON_MYFAMILY` | MyFamily fingerprints | No | No | Comma-separated fingerprints of all your relays. |
| `ANON_AGREETOTERMS` | Agree to terms | No | No | Must be `1`. Defaults to `1`. |
| `ANON_CONTACTINFO` | Operator contact (email) | No | No | Optional; published in the directory if set. |

\* Required to earn ANYONE tokens.

### Required Configuration

The relay must accept the terms. With this image that is `ANON_AGREETOTERMS=1` (the default), which the entrypoint writes as `AgreeToTerms 1` in the generated `anonrc`.
