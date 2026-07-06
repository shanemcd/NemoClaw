<!-- SPDX-FileCopyrightText: Copyright (c) 2026 NVIDIA CORPORATION & AFFILIATES. All rights reserved. -->
<!-- SPDX-License-Identifier: Apache-2.0 -->

# VoiceClaw Messaging Architecture Notes

## 1. What VoiceClaw Needs From the Stack

VoiceClaw should be treated as a human communication channel where the user speaks instead of typing. NemoClaw does not need to own STT, TTS, TURN, WebRTC, SIP, or media processing. Those belong to OpenClaw voice-call, VoiceClaw services, or provider-specific infrastructure.

### 1.1 Requirements From OpenClaw

- A `voice-call` plugin or channel that can turn caller speech into agent-visible messages and return agent responses over the call.
- A stable plugin configuration shape for telephony provider, public URL, webhook path, serve port, allowed caller IDs, and speech/backend settings.
- A call lifecycle event model: call started, transcript partial/final, user turn complete, assistant response, call ended, error.
- Plugin package install support, so NemoClaw can install the OpenClaw voice-call package during sandbox image build.
- Optional native NVIDIA speech provider support if OpenClaw wants NVIDIA speech to be selectable directly inside voice-call.

### 1.2 Requirements From OpenShell

- Sandbox isolation with controlled egress to telephony providers, VoiceClaw services, or speech endpoints.
- Secret/provider injection so telephony credentials are not baked into images or persisted in plain text.
- Local host port forwarding when an in-sandbox webhook server must receive traffic.
- A future public ingress or tunnel primitive if external telephony providers must call directly into a sandbox-owned webhook.
- Stable gateway lifecycle so reconnect/rebuild does not silently break call routing.

### 1.3 Requirements From NemoClaw

- Install the OpenClaw voice-call plugin during create/rebuild.
- Persist voice-call desired state across rebuilds.
- Render non-secret voice-call config into OpenClaw config.
- Bind secret placeholders through OpenShell providers.
- Apply the network policy needed for telephony or VoiceClaw-owned services.
- Restore local port forwarding after rebuild when a webhook port is configured.
- Surface status/doctor signals for plugin installed, config rendered, policy applied, forward healthy, and webhook reachable.

## 2. What `src/lib/messaging` Already Supports

NemoClaw's messaging architecture is a manifest-first lifecycle for human communication channels. It already supports most of the control-plane pieces needed by voice-call.

### Supported

- **Manifest:** a channel can declare id, display name, supported agents, auth mode, config inputs, secret inputs, credential bindings, policy presets, render targets, runtime setup, package installs, and hooks.
- **Config render:** channel manifests can render JSON fragments or env lines into agent config, including OpenClaw `plugins.entries.*`.
- **Plugin install:** channel manifests can request OpenClaw plugin package installs through `agentPackages`.
- **Upstream agent monkey patch:** runtime preloads, env aliases, secret scans, and build-file hooks can patch or adapt upstream agent behavior without adding one-off logic to onboard/rebuild.
- **Port forwarding:** a channel can declare a host-forwarded port for webhook-style bridges.
- **Policy apply:** a channel can declare policy presets that are applied during add/start/rebuild and removed during channel removal.
- **Lifecycle:** add, remove, start, stop, rebuild, persisted state, health checks, status, and doctor integration are already modeled.

### Not Supported Yet

- **Custom-endpoint policy apply:** current channel policy is preset-oriented. If a channel takes a user-provided endpoint such as `VOICECLAW_BRIDGE_URL` or a custom speech endpoint, NemoClaw does not yet generate/apply a policy from that config value.

This is an easy win: extend the manifest vocabulary so config inputs can produce policy endpoints, then apply them as generated custom policy entries.

## 3. VoiceClaw as First-Class Messaging

If VoiceClaw is first-class messaging, the fit is strong.

The model is:

```text
caller speech -> voice-call channel -> OpenClaw agent message/context -> spoken response
```

The voice-call channel would behave like Teams, Telegram, or WhatsApp from NemoClaw's point of view. The transport is different, but the lifecycle is the same.

Expected channel lifecycle:

- `nemoclaw <sandbox> channels add voice-call`
  - collect provider config, public URL, serve port/path, caller allowlist, and credentials
  - apply network policy
  - persist desired channel state
- `nemoclaw <sandbox> rebuild`
  - install OpenClaw voice-call plugin
  - render voice-call config
  - reapply config after OpenClaw doctor if needed
  - restore webhook port forwarding
- `nemoclaw <sandbox> channels start voice-call`
  - re-enable desired channel state and policy
  - rebuild or run an immediate start hook if supported
- `nemoclaw <sandbox> channels stop voice-call`
  - disable desired channel state
  - optionally run an immediate disable hook so the system stops answering calls before rebuild
- `nemoclaw <sandbox> channels remove voice-call`
  - remove desired state, credentials, policy, and channel state
  - rebuild to remove runtime config
- `nemoclaw <sandbox> channels status --channel voice-call`
  - report plugin loaded, config present, policy active, forward healthy, webhook reachable, and recent call health

NemoClaw owns the channel control plane. OpenClaw and VoiceClaw own call behavior, media, speech, and provider-specific details.

## 4. VoiceClaw as Third-Party Messaging

If VoiceClaw is not built into NemoClaw, the main gap is extensibility.

Today, adding a new messaging channel requires NemoClaw source changes:

- add a manifest under `src/lib/messaging/channels/<channel>`
- register it in the built-in channel registry
- add a template resolver when config needs derived values
- add hooks for enrollment, reachability, status, health, or conflict checks
- add runtime assets or monkey patches when needed
- add a policy preset
- add tests and docs

That is good for first-party channels, but it means third-party users must fork NemoClaw to add a custom OpenClaw agent plugin or adjust agent config.

The missing capability is a managed plugin/package path:

- `nemoclaw plugins add npm:<package>` or equivalent
- persist plugin desired state in the sandbox registry
- install the package during rebuild
- render declared config into OpenClaw
- bind secrets through OpenShell providers
- apply static policy presets or config-derived custom endpoint policy
- support `list`, `status`, `start`, `stop`, and `remove`
- keep the metadata declarative so arbitrary package code does not run with NemoClaw host privileges

This gives two viable product paths:

- **First-class VoiceClaw:** fastest integration and best user experience, because NemoClaw can expose `channels add voice-call` directly.
- **Third-party VoiceClaw:** better ecosystem model, but requires the managed plugin/package architecture first so users can install and configure custom OpenClaw plugins without cloning NemoClaw.
