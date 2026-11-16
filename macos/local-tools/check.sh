#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p build/checks build/module-cache
swiftc -swift-version 6 -module-cache-path build/module-cache -parse-as-library \
  Crisp/Models/InputSourceConfiguration.swift local-tools/check-input-configuration.swift \
  -o build/checks/input-configuration
build/checks/input-configuration
swiftc -swift-version 6 -module-cache-path build/module-cache -parse-as-library \
  local-tools/testing/InputServiceStubs.swift Crisp/Models/DDCInputSource.swift \
  Crisp/Models/InputSourceConfiguration.swift Crisp/Services/InputSwitchService.swift \
  local-tools/testing/InputServiceChecks.swift -o build/checks/input-service
build/checks/input-service
cat Crisp/Models/DDCInputSource.swift local-tools/check-input-source.swift > build/checks/input-source.swift
swift -module-cache-path build/module-cache build/checks/input-source.swift
cat Crisp/Utilities/BrightnessBoostMath.swift local-tools/check-boost-math.swift > build/checks/boost.swift
swift -module-cache-path build/module-cache build/checks/boost.swift

swiftc -swift-version 6 -module-cache-path build/module-cache -parse-as-library \
  Crisp/Models/CrispControlModel.swift Crisp/Models/BrightnessKeySteps.swift \
  Crisp/Models/SoftwareDimmingPolicy.swift local-tools/check-brightness-policy.swift \
  -o build/checks/brightness-policy
build/checks/brightness-policy

swiftc -swift-version 6 -module-cache-path build/module-cache -parse-as-library \
  Crisp/Models/HardwareBrightnessScale.swift local-tools/check-hardware-scale.swift \
  -o build/checks/hardware-scale
build/checks/hardware-scale

swiftc -swift-version 6 -module-cache-path build/module-cache -parse-as-library \
  Crisp/Models/MSTSideband.swift local-tools/check-mst-sideband.swift \
  -o build/checks/mst-sideband
build/checks/mst-sideband

swiftc -swift-version 6 -module-cache-path build/module-cache -parse-as-library \
  Crisp/Models/OutputColorMode.swift local-tools/check-output-color.swift \
  -o build/checks/output-color
build/checks/output-color

swiftc -swift-version 6 -module-cache-path build/module-cache -parse-as-library \
  Crisp/Models/DisplayModeGeometry.swift local-tools/check-resolution-slider.swift \
  -o build/checks/resolution-slider
build/checks/resolution-slider
