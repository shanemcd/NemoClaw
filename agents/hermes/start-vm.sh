#!/usr/bin/env bash
# SPDX-FileCopyrightText: Copyright (c) 2026 NVIDIA CORPORATION & AFFILIATES. All rights reserved.
# SPDX-License-Identifier: Apache-2.0
#
# NemoClaw Hermes entrypoint for KubeVirt / OpenShell network-only sidecar.
# Sets NEMOCLAW_VM_SIDECAR=1 so start.sh and the runtime guards accept a
# sibling openshell-sandbox supervisor (PID 1 is systemd, not the supervisor).

set -euo pipefail

export NEMOCLAW_VM_SIDECAR=1
exec /usr/local/bin/nemoclaw-start "$@"
