<!-- SPDX-FileCopyrightText: Copyright (c) 2026 NVIDIA CORPORATION & AFFILIATES. All rights reserved. -->
<!-- SPDX-License-Identifier: Apache-2.0 -->

# FSM extensibility interface checklist

Issue #6224 checklist for feature-level interfaces consumed by the onboard FSM.
Use this as an inventory when adding or redesigning extensibility around messaging,
web search, model credentials, agent harnesses, policies, runtime patches, or future
features.

## Proposal flow

One possible extensibility model is to treat NemoClaw as a secure lifecycle manager for
agent harnesses and their capabilities. In that model, OpenClaw, Hermes, and Deep
Agents Code are built-in harness adapters today, and future harnesses could be added
through constrained plugins that declare what they need and what they can consume.

```text
NemoClaw FSM
  consumes declared interfaces
    from agent harness plugins
    from capability plugins
  then applies policies, credentials, build/runtime config, verification, and registry state
```

This suggests two plugin shapes:

1. Agent harness plugins

   Examples: OpenClaw, Hermes, Deep Agents Code, and future user-provided harnesses.

   They could declare:

   - install/build steps
   - startup command
   - config render targets
   - supported capabilities, such as messaging, web search, MCP, dashboards, tools, and
     voice
   - required ports/forwards
   - health checks
   - runtime state paths
   - required policy presets
   - unsupported paths and failure messages

2. Capability plugins

   Examples: messaging channels, web search providers, voice-call, custom tools,
   observability, and model-provider adapters.

   They could declare:

   - config inputs
   - secret inputs
   - credential bindings
   - policy contributions
   - package/runtime requirements
   - config fragments for compatible harnesses
   - health/status hooks
   - rebuild/recreate/live-apply behavior

The likely secure default is a declarative plugin boundary: plugins describe
configuration, credentials, policies, packages, config render targets, runtime setup,
forwards, health checks, and state fidelity; the onboard FSM consumes those contracts
and applies the trusted host-side effects. If a plugin needs host-side executable code,
that probably needs a separate trust model with sandboxing, allowlisting, provenance,
and replay semantics.

## Feature interfaces consumed by the FSM

| Interface | FSM consumption points | Contract | Current examples |
|---|---|---|---|
| Agent harness adapter | `init`, `sandbox`, `agent_setup`, `policies`, `finalizing`. | Declare harness identity, install/build/start commands, config targets, runtime state paths, forwards, health checks, supported capability interfaces, and reject paths. | Built-in OpenClaw, Hermes, and Deep Agents Code adapters; future user-provided harness plugins. |
| Capability descriptor | `init`, `sandbox`, `policies`, `agent_setup`. | Describe the feature, supported harnesses, required phases, persisted fidelity, and whether it is build-time, runtime, or live-mutable. | Messaging manifests, web-search provider metadata, VoiceClaw/voice-call, custom tool or observability plugins, Hermes tool gateways. |
| Plugin trust boundary | `init`, `sandbox`, resume/repair compatibility paths. | Prefer declarative manifests and audited primitives; any host-side executable plugin hook needs sandboxing, allowlisting, provenance, and replay semantics. | Messaging build/runtime primitives, Dockerfile patch primitives, policy primitives, future managed plugin/package metadata. |
| Support gate | `init`, `provider_selection`, `sandbox`, `policies`. | Fail or skip before mutation when the selected agent, provider, image, driver, or runtime cannot consume the feature. | Messaging `supportedAgents`, Hermes-only Tavily web search, Deep Agents Code messaging rejection, Docker-driver GPU/base-image constraints. |
| Configuration input | `init`, `provider_selection`, `sandbox`, `policies`. | Capture non-secret choices with defaults, validation, resume semantics, and one owning state. | Messaging channel config, web-search provider choice, model/provider selection, Hermes auth/tool gateways, policy tier, tool disclosure mode. |
| Secret input | `provider_selection`, `sandbox`, `finalizing`. | Prompt, stage, validate, migrate, or clean up raw values only at the application edge; plans, events, registry, and session store env names, placeholders, hashes, or redacted URLs. | Model provider keys, Bedrock auth, Brave/Tavily keys, messaging tokens, Hermes API keys/OAuth, legacy credential migration. |
| Credential binding | `provider_selection`, `sandbox`. | Convert a secret input into an OpenShell provider, env placeholder, local proxy token, or route binding with reuse and conflict checks. | Remote inference upserts, recovered gateway credential reuse, Ollama/vLLM local credentials, messaging provider placeholders, web-search provider tokens. |
| Inference route | `provider_selection`, `inference`, `sandbox`, `finalizing`. | Own endpoint validation, model ID, preferred API, provider route upsert, smoke verification, and route repair before the sandbox consumes model settings. | NVIDIA/NIM, OpenAI-compatible endpoints, Bedrock Runtime adapter, Ollama local proxy, vLLM local route, Hermes provider setup. |
| Sandbox create plan | `sandbox`. | Materialize create args, provider bindings, build context, policy seed, resource/GPU args, rollback, and registry registration from secret-free plan data. | `SandboxCreateIntent`, `SandboxCreatePlan`, messaging plan materialization, web-search placeholders, Hermes tool gateway providers. |
| Policy contribution | `sandbox`, `policies`. | Contribute built-in or agent-specific policies that can be seeded at create time, reconciled live, and recorded once finalized. | Slack/Teams/Telegram/Discord egress, Brave/Tavily egress, OpenClaw OTEL, Hermes gateway/tool policies, custom policy carryforward. |
| Build and package mutation | `sandbox`, `agent_setup`. | Define deterministic build-time packages, Dockerfile patches, base-image decisions, generated config, and runtime assets with replay and fail-closed custom-Dockerfile behavior. | Channel packages, OpenClaw/Hermes/Deep Agents Code config generation, tool-disclosure Dockerfile contract, Docker GPU patch, base-image pinning. |
| Runtime setup and monkey patching | `sandbox`, `agent_setup`, `finalizing`. | Scope patches by phase, agent, driver, and rollback story; startup env carries placeholders instead of raw secrets. | Messaging preloads, Hermes runtime config guard, Deep Agents Code managed runtime guards, `vm-dns-monkeypatch`, extra placeholder keys. |
| Host forward and dashboard | `gateway`, `sandbox`, `agent_setup`, `finalizing`. | Reserve, validate, persist, recover, and clean up inbound ports or dashboard/API forwards separately from agent config. | OpenClaw dashboard, Hermes API/dashboard, Teams webhook port, orphaned dashboard forward cleanup. |
| Hooks, health, and verification | `sandbox`, `agent_setup`, `policies`, `finalizing`, `post_verify`. | Name side effects by phase and provide checks that can be replayed for status, diagnostics, or post-policy verification. | Messaging hooks/health checks, web-search egress verification, inference smoke tests, agent readiness probes, deployment verification. |
| State and replay | All states through `runtime-boundary` and `onboard-session`. | Persist compact fidelity needed for resume/rebuild while filtering unsafe fields and recomputing transient topology. | Session safe updates, sandbox registry fields, messaging compact state, web-search fidelity, GPU proof, tool disclosure, Hermes tool gateways. |
| Mutation boundary | `sandbox`, `policies`, resume/repair compatibility paths. | Declare live apply, rebuild, recreate, repair, status, prune, and unsupported-agent behavior before exposing user commands. | Messaging add/remove/start/stop/status, policy add/remove, inference route repair, web-search provider change, MCP-preserving sandbox recreate. |
| Events and diagnostics | All states through machine events. | Expose only redacted context and sanitized metadata; detailed values stay in flow context, local logs, or credential storage. | `OnboardMachineContext`, `emitOnboardMachineEvent`, resume conflict events, repair events, skipped-state metadata. |

## Consumer examples

- Agent harness adapters are the primary extensibility consumers. OpenClaw consumes
  plugin/config outputs, Hermes consumes gateway/platform/search outputs, and Deep
  Agents Code consumes terminal/runtime-guard outputs while rejecting unsupported
  messaging paths. Future harness plugins should declare the same consume/reject
  contract rather than requiring NemoClaw source changes.
- Capability plugins attach features to compatible harnesses. Messaging channels, web
  search providers, voice-call, custom tools, observability, and model-provider adapters
  should expose declarative inputs and effects that the FSM can validate, apply, replay,
  and verify.
- Messaging currently exercises the fullest interface set: descriptor, support gate,
  config input, secret input, credential binding, policy contribution, build packages,
  config render, runtime setup, host forwards, hooks, health, state replay, and mutation
  boundaries.
- Web search is the same shape without a manifest: the FSM consumes provider config,
  Brave/Tavily secrets, OpenShell credential bindings, policy presets, Dockerfile/config
  patches, runtime egress verification, and registry/session replay.
- Model credentials and inference routes are feature interfaces consumed before sandbox
  create: provider selection owns credential env names, endpoint validation, route upsert,
  compatible-endpoint reasoning, local proxy credentials, Bedrock adapter tokens, Hermes
  auth mode, and smoke verification.
- Tool disclosure, MCP preservation, GPU passthrough, dashboard forwards, DNS patches,
  and runtime monkey patches are FSM-consumed interfaces even when they are not product
  features; each can force reuse, rebuild, recreate, repair, or verification behavior.

## FSM ownership reference

| FSM state | Primary interfaces consumed |
|---|---|
| `init` | Agent harness adapter, capability descriptor, support gate, config input, plugin trust boundary, mutation lock, session bootstrap. |
| `preflight` | Host prerequisites, GPU support gate, dashboard-port preflight, fatal backstops. |
| `gateway` | Gateway lifecycle, driver config, GPU reuse, host forwards. |
| `provider_selection` / `inference` | Secret input, credential binding, inference route, route smoke, route repair. |
| `sandbox` | Sandbox create plan, support gates, policy seed, build mutation, runtime setup, state registration, rollback. |
| `openclaw` / `agent_setup` | Harness package/config, capability consume/reject paths, host forwards, readiness probes, skipped unsupported paths. |
| `policies` | Policy contribution, live reconcile, compatible-endpoint smoke, finalized registry state. |
| `finalizing` / `post_verify` | Cleanup, default sandbox, runtime verification, deployment verification, final handoff. |
| Resume/repair | State replay, mutation boundaries, compatibility result handling, sanitized diagnostics. |

Current gap to revisit: `post_verify` is modeled as a state boundary, but the
finalization handler still records post-verify progress and completes from
`finalizing` through the compatibility boundary. New verification work should make
ownership explicit instead of adding more hidden finalization effects.

## Revisit checklist

- [ ] Is this an agent harness plugin, a capability plugin, or a built-in FSM interface?
- [ ] Which feature interface is being added or extended, and which FSM states consume it?
- [ ] What belongs in transient flow context, redacted machine event context, persisted
      session, sandbox registry, generated config, and local credential storage?
- [ ] Are raw secrets kept out of plans, events, registry rows, session files, generated
      configs, Dockerfile patches, and logs?
- [ ] Does the interface define support gate, config input, secret input, credential
      binding, policy contribution, build mutation, runtime setup, host forward, hooks,
      health, state replay, mutation boundary, and diagnostics separately?
- [ ] Does it have explicit create, resume, rebuild, recreate, live-apply, repair, status,
      prune, and unsupported-agent behavior?
- [ ] Does every agent harness have an explicit consume/reject path for the interface?
- [ ] Is the plugin contract declarative, or does it require a new host-side executable
      trust boundary?
- [ ] Is each runtime monkey patch or preload bounded to a named module, driver/agent
      scope, phase, rollback story, and test?
- [ ] Can stale state be pruned without deleting user-owned config, credentials, custom
      Dockerfiles, or preserved MCP state?
- [ ] Does new repair or verification logic need a first-class FSM state instead of another
      compatibility/ahead-state replay exception?
