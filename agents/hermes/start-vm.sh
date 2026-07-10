#!/usr/bin/env bash
# SPDX-FileCopyrightText: Copyright (c) 2026 NVIDIA CORPORATION & AFFILIATES. All rights reserved.
# SPDX-License-Identifier: Apache-2.0
#
# NemoClaw Hermes entrypoint for KubeVirt / OpenShell VM supervision.
# Sets NEMOCLAW_VM_SIDECAR=1 so start.sh and the runtime guards accept an
# openshell-sandbox supervisor that is either a sibling systemd unit
# (--mode=network) or this process's parent (--mode=network,process).
# PID 1 is systemd in both cases, not the supervisor.

set -euo pipefail

export NEMOCLAW_VM_SIDECAR=1
exec /usr/local/bin/nemoclaw-start "$@"
