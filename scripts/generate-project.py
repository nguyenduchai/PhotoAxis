#!/usr/bin/env python3
"""Deterministic, dependency-free Xcode project. Run after adding/removing sources."""
import hashlib
import json
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parent.parent
objects = {}


def ref(key):
    return hashlib.sha256(key.encode()).hexdigest()[:24].upper()


def obj(key, **fields):
    if ref(key) in objects:
        raise ValueError(f"Duplicate project object: {key}")
    objects[ref(key)] = fields
    return ref(key)


def file(path, file_type):
    return obj(path, isa="PBXFileReference", lastKnownFileType=file_type, path=path, sourceTree="SOURCE_ROOT")


def phase(key, isa, files=(), **extra):
    return obj(key, isa=isa, buildActionMask=2147483647, files=list(files), runOnlyForDeploymentPostprocessing=0, **extra)


configs = [file(f"Config/{name}.xcconfig", "text.xcconfig") for name in ["Debug", "Release"]]
app_sources = sorted(ROOT.glob("Sources/PhotoAxisApp/**/*.swift"))
core_sources = sorted(ROOT.glob("Sources/PhotoAxisCore/**/*.swift"))
test_sources = sorted(ROOT.glob("Tests/PhotoAxisCoreTests/**/*.swift"))
app_test_sources = sorted(ROOT.glob("Tests/PhotoAxisAppTests/**/*.swift"))
source_groups = []
products = []

localized = []
for language in ["en", "vi"]:
    path = f"Sources/PhotoAxisApp/Localization/{language}.lproj/Localizable.strings"
    localized.append(obj(path, isa="PBXFileReference", lastKnownFileType="text.plist.strings",
                         name=language, path=path, sourceTree="SOURCE_ROOT"))
strings = obj("strings", isa="PBXVariantGroup", children=localized, name="Localizable.strings", sourceTree="<group>")

target_specs = [
    ("PhotoAxisCore", core_sources, "framework", "wrapper.framework"),
    ("PhotoAxis", app_sources, "application", "wrapper.application"),
    ("PhotoAxisCoreTests", test_sources, "bundle.unit-test", "wrapper.cfbundle"),
    ("PhotoAxisAppTests", app_test_sources, "bundle.unit-test", "wrapper.cfbundle"),
]

for name, sources, product_type, file_type in target_specs:
    extension = {"framework": "framework", "application": "app", "bundle.unit-test": "xctest"}[product_type]
    product = obj(name + "Product", isa="PBXFileReference", explicitFileType=file_type,
                  path=f"{name}.{extension}", sourceTree="BUILT_PRODUCTS_DIR", includeInIndex=0)
    products.append(product)
    files = [file(str(p.relative_to(ROOT)), "sourcecode.swift") for p in sources]
    source_groups.append(obj(name + "Sources", isa="PBXGroup", children=files,
                             name=name, sourceTree="<group>"))
    builds = [obj(name + f + "Build", isa="PBXBuildFile", fileRef=f) for f in files]
    phases = [phase(name + "Compile", "PBXSourcesBuildPhase", builds)]
    links, dependencies = [], []
    if name != "PhotoAxisCore":
        links.append(obj(name + "CoreLinkBuildFile", isa="PBXBuildFile", fileRef=ref("PhotoAxisCoreProduct")))
        proxy = obj(name + "Proxy", isa="PBXContainerItemProxy", containerPortal=ref("Project"),
                    proxyType=1, remoteGlobalIDString=ref("PhotoAxisCoreTarget"), remoteInfo="PhotoAxisCore")
        dependencies.append(obj(name + "Dependency", isa="PBXTargetDependency", target=ref("PhotoAxisCoreTarget"), targetProxy=proxy))
    if name == "PhotoAxisAppTests":
        proxy = obj(name + "HostProxy", isa="PBXContainerItemProxy", containerPortal=ref("Project"),
                    proxyType=1, remoteGlobalIDString=ref("PhotoAxisTarget"), remoteInfo="PhotoAxis")
        dependencies.append(obj(name + "HostDependency", isa="PBXTargetDependency", target=ref("PhotoAxisTarget"), targetProxy=proxy))
    phases.append(phase(name + "Link", "PBXFrameworksBuildPhase", links))
    if name == "PhotoAxisAppTests":
        resource_builds = []
        for folder in sorted((ROOT / "Fixtures").iterdir()):
            if folder.is_dir() and folder.name.startswith("P"):
                fixture = file("Fixtures/" + folder.name, "folder")
                objects[ref(name + "Sources")]["children"].append(fixture)
                resource_builds.append(obj(folder.name + "FixturesBuild", isa="PBXBuildFile", fileRef=fixture))
        phases.append(phase(name + "Resources", "PBXResourcesBuildPhase", resource_builds))
    if name == "PhotoAxis":
        kernel_path = "Sources/PhotoAxisApp/Renderer/Perspective.ci.metal"
        kernel = file(kernel_path, "sourcecode.metal")
        objects[ref(name + "Sources")]["children"].append(kernel)
        phases.append(phase("PerspectiveKernel", "PBXShellScriptBuildPhase", name="Compile Core Image kernel",
            inputPaths=["$(SRCROOT)/" + kernel_path],
            outputPaths=["$(TARGET_BUILD_DIR)/$(UNLOCALIZED_RESOURCES_FOLDER_PATH)/Perspective.metallib"],
            shellPath="/bin/bash", shellScript='set -euo pipefail\n'
                'mkdir -p "$TARGET_BUILD_DIR/$UNLOCALIZED_RESOURCES_FOLDER_PATH" "$TEMP_DIR/PerspectiveKernel"\n'
                'xcrun -sdk macosx metal -fcikernel -c -mmacosx-version-min="$MACOSX_DEPLOYMENT_TARGET" "$SCRIPT_INPUT_FILE_0" -o "$TEMP_DIR/PerspectiveKernel/Perspective.air"\n'
                'xcrun metallib -cikernel "$TEMP_DIR/PerspectiveKernel/Perspective.air" -o "$TEMP_DIR/PerspectiveKernel/Perspective.metallib"\n'
                'cp "$TEMP_DIR/PerspectiveKernel/Perspective.metallib" "$SCRIPT_OUTPUT_FILE_0"\n'))
        icon = file("Sources/PhotoAxisApp/Resources/PhotoAxis.icns", "image.icns")
        objects[ref(name + "Sources")]["children"].append(icon)
        resources = [obj("StringsBuild", isa="PBXBuildFile", fileRef=strings), obj("AppIconBuild", isa="PBXBuildFile", fileRef=icon)]
        phases.append(phase(name + "Resources", "PBXResourcesBuildPhase", resources))
        embed = obj("CoreEmbed", isa="PBXBuildFile", fileRef=ref("PhotoAxisCoreProduct"),
                    settings={"ATTRIBUTES": ["CodeSignOnCopy", "RemoveHeadersOnCopy"]})
        phases.append(phase(name + "Embed", "PBXCopyFilesBuildPhase", [embed], dstPath="", dstSubfolderSpec=10, name="Embed Frameworks"))

    settings = {"PRODUCT_NAME": "$(TARGET_NAME)",
                "PRODUCT_BUNDLE_IDENTIFIER": "local.photoaxis." + {"PhotoAxis": "development", "PhotoAxisCore": "core", "PhotoAxisCoreTests": "tests", "PhotoAxisAppTests": "apptests"}[name],
                "LD_RUNPATH_SEARCH_PATHS": ["$(inherited)", "@executable_path/../Frameworks", "@loader_path/../Frameworks"]}
    if name == "PhotoAxis":
        settings.update(INFOPLIST_FILE="Config/Info.plist", GENERATE_INFOPLIST_FILE="NO", PRODUCT_BUNDLE_IDENTIFIER="$(PHOTOAXIS_APP_BUNDLE_ID)")
    elif name == "PhotoAxisCore":
        settings.update(PRODUCT_BUNDLE_IDENTIFIER="$(PHOTOAXIS_CORE_BUNDLE_ID)", DEFINES_MODULE="YES", SKIP_INSTALL="YES", DYLIB_INSTALL_NAME_BASE="@rpath", INSTALL_PATH="$(LOCAL_LIBRARY_DIR)/Frameworks")
    else:
        settings.update(SKIP_INSTALL="YES", SWIFT_EMIT_LOC_STRINGS="NO")
        if name == "PhotoAxisAppTests":
            settings.update(TEST_HOST="$(BUILT_PRODUCTS_DIR)/PhotoAxis.app/Contents/MacOS/PhotoAxis", BUNDLE_LOADER="$(TEST_HOST)")
    ids = [obj(name + config, isa="XCBuildConfiguration", name=config, buildSettings=settings) for config in ["Debug", "Release"]]
    config_list = obj(name + "Configurations", isa="XCConfigurationList", buildConfigurations=ids,
                      defaultConfigurationIsVisible=0, defaultConfigurationName="Release")
    obj(name + "Target", isa="PBXNativeTarget", buildConfigurationList=config_list, buildPhases=phases,
        buildRules=[], dependencies=dependencies, name=name, productName=name,
        productReference=product, productType="com.apple.product-type." + product_type)

project_configs = [obj("Project" + name, isa="XCBuildConfiguration", baseConfigurationReference=config,
                       buildSettings={}, name=name) for name, config in zip(["Debug", "Release"], configs)]
config_list = obj("ProjectConfigurations", isa="XCConfigurationList", buildConfigurations=project_configs,
                  defaultConfigurationIsVisible=0, defaultConfigurationName="Release")
product_group = obj("Products", isa="PBXGroup", children=products, name="Products", sourceTree="<group>")
config_group = obj("Config", isa="PBXGroup", children=configs + [file("Config/Base.xcconfig", "text.xcconfig"), file("Config/Info.plist", "text.plist.xml")], name="Config", sourceTree="<group>")
main = obj("Main", isa="PBXGroup", children=source_groups + [strings, config_group, product_group], sourceTree="<group>")
obj("Project", isa="PBXProject", attributes={"BuildIndependentTargetsInParallel": "YES", "LastUpgradeCheck": "1600"},
    buildConfigurationList=config_list, compatibilityVersion="Xcode 14.0", developmentRegion="en",
    hasScannedForEncodings=0, knownRegions=["en", "vi", "Base"], mainGroup=main,
    productRefGroup=product_group, projectDirPath="", projectRoot="",
    targets=[ref(name + "Target") for name, *_ in target_specs])


def encode(value, indent=0):
    if isinstance(value, dict):
        return "{\n" + "".join("\t" * (indent + 1) + f"{k} = {encode(v, indent + 1)};\n" for k, v in value.items()) + "\t" * indent + "}"
    if isinstance(value, list):
        return "(" + ", ".join(encode(v, indent) for v in value) + ")"
    if isinstance(value, int):
        return str(value)
    return json.dumps(value, ensure_ascii=False)


content = "// !$*UTF8*$!\n" + encode({"archiveVersion": 1, "classes": {}, "objectVersion": 56,
                                       "objects": objects, "rootObject": ref("Project")}) + "\n"
path = ROOT / "PhotoAxis.xcodeproj/project.pbxproj"
if "--check" in sys.argv:
    if not path.exists() or path.read_text() != content:
        sys.exit("Xcode project is stale. Run python3 scripts/generate-project.py")
    print("PASS: Xcode project matches source inventory")
else:
    path.parent.mkdir(exist_ok=True)
    path.write_text(content)
    print("Generated PhotoAxis.xcodeproj/project.pbxproj")
