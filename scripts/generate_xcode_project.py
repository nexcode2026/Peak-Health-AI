#!/usr/bin/env python3
"""Generate Peak.xcodeproj from source file list."""

import os
import uuid
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
PEAK_DIR = ROOT / "Peak"
TEST_DIR = ROOT / "PeakTests"
PROJECT_DIR = ROOT / "Peak.xcodeproj"

def uid():
    return uuid.uuid4().hex[:24].upper()

def collect_swift_files(base: Path):
    files = []
    for path in sorted(base.rglob("*.swift")):
        rel = path.relative_to(ROOT)
        files.append(str(rel))
    return files

def main():
    app_swift = collect_swift_files(PEAK_DIR)
    test_swift = collect_swift_files(TEST_DIR)

    # IDs
    project_id = uid()
    main_group_id = uid()
    peak_group_id = uid()
    test_group_id = uid()
    products_group_id = uid()
    app_target_id = uid()
    test_target_id = uid()
    app_product_id = uid()
    test_product_id = uid()
    sources_phase_app = uid()
    sources_phase_test = uid()
    resources_phase = uid()
    frameworks_phase = uid()
    test_frameworks_phase = uid()
    native_target_app = uid()
    native_target_test = uid()
    test_target_proxy = uid()
    test_target_dependency = uid()
    project_config_list = uid()
    app_config_list = uid()
    test_config_list = uid()
    debug_proj = uid()
    release_proj = uid()
    debug_app = uid()
    release_app = uid()
    debug_test = uid()
    release_test = uid()

    # File references
    file_refs = {}
    build_files_app = {}
    build_files_test = {}

    for f in app_swift:
        fid = uid()
        bid = uid()
        file_refs[f] = fid
        build_files_app[f] = bid

    for f in test_swift:
        fid = uid()
        bid = uid()
        file_refs[f] = fid
        build_files_test[f] = bid

    assets_id = uid()
    preview_assets_id = uid()
    entitlements_id = uid()
    storekit_id = uid()
    privacy_id = uid()
    assets_build_id = uid()
    preview_build_id = uid()
    storekit_build_id = uid()
    privacy_build_id = uid()

    # Groups by folder
    def make_groups(files, prefix):
        groups = {}
        for f in files:
            parts = Path(f).parts
            for i in range(len(parts) - 1):
                key = "/".join(parts[:i+1])
                parent = "/".join(parts[:i]) if i > 0 else ""
                groups.setdefault(parent, set()).add(key)
        return groups

    lines = []
    lines.append("// !$*UTF8*$!")
    lines.append("{")
    lines.append("\tarchiveVersion = 1;")
    lines.append("\tclasses = {};")
    lines.append("\tobjectVersion = 60;")
    lines.append("\tobjects = {")
    lines.append("")
    lines.append("/* Begin PBXBuildFile section */")
    for f, bid in build_files_app.items():
        lines.append(f"\t\t{bid} /* {Path(f).name} in Sources */ = {{isa = PBXBuildFile; fileRef = {file_refs[f]} /* {Path(f).name} */; }};")
    for f, bid in build_files_test.items():
        lines.append(f"\t\t{bid} /* {Path(f).name} in Sources */ = {{isa = PBXBuildFile; fileRef = {file_refs[f]} /* {Path(f).name} */; }};")
    lines.append(f"\t\t{assets_build_id} /* Assets.xcassets in Resources */ = {{isa = PBXBuildFile; fileRef = {assets_id} /* Assets.xcassets */; }};")
    lines.append(f"\t\t{preview_build_id} /* Preview Assets.xcassets in Resources */ = {{isa = PBXBuildFile; fileRef = {preview_assets_id} /* Preview Assets.xcassets */; }};")
    lines.append(f"\t\t{storekit_build_id} /* Peak.storekit in Resources */ = {{isa = PBXBuildFile; fileRef = {storekit_id} /* Peak.storekit */; }};")
    lines.append(f"\t\t{privacy_build_id} /* PrivacyInfo.xcprivacy in Resources */ = {{isa = PBXBuildFile; fileRef = {privacy_id} /* PrivacyInfo.xcprivacy */; }};")
    lines.append("/* End PBXBuildFile section */")
    lines.append("")
    lines.append("/* Begin PBXContainerItemProxy section */")
    lines.append(f"\t\t{test_target_proxy} /* PBXContainerItemProxy */ = {{")
    lines.append("\t\t\tisa = PBXContainerItemProxy;")
    lines.append(f"\t\t\tcontainerPortal = {project_id} /* Project object */;")
    lines.append("\t\t\tproxyType = 1;")
    lines.append(f"\t\t\tremoteGlobalIDString = {native_target_app};")
    lines.append("\t\t\tremoteInfo = Peak;")
    lines.append("\t\t};")
    lines.append("/* End PBXContainerItemProxy section */")
    lines.append("")
    lines.append("/* Begin PBXFileReference section */")
    lines.append(f"\t\t{app_product_id} /* Peak.app */ = {{isa = PBXFileReference; explicitFileType = wrapper.application; includeInIndex = 0; path = Peak.app; sourceTree = BUILT_PRODUCTS_DIR; }};")
    lines.append(f"\t\t{test_product_id} /* PeakTests.xctest */ = {{isa = PBXFileReference; explicitFileType = wrapper.cfbundle; includeInIndex = 0; path = PeakTests.xctest; sourceTree = BUILT_PRODUCTS_DIR; }};")
    for f, fid in file_refs.items():
        name = Path(f).name
        lines.append(f"\t\t{fid} /* {name} */ = {{isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = {name}; sourceTree = \"<group>\"; }};")
    lines.append(f"\t\t{assets_id} /* Assets.xcassets */ = {{isa = PBXFileReference; lastKnownFileType = folder.assetcatalog; path = Assets.xcassets; sourceTree = \"<group>\"; }};")
    lines.append(f"\t\t{preview_assets_id} /* Preview Assets.xcassets */ = {{isa = PBXFileReference; lastKnownFileType = folder.assetcatalog; path = \"Preview Assets.xcassets\"; sourceTree = \"<group>\"; }};")
    lines.append(f"\t\t{entitlements_id} /* Peak.entitlements */ = {{isa = PBXFileReference; lastKnownFileType = text.plist.entitlements; path = Peak.entitlements; sourceTree = \"<group>\"; }};")
    lines.append(f"\t\t{storekit_id} /* Peak.storekit */ = {{isa = PBXFileReference; lastKnownFileType = text; path = Peak.storekit; sourceTree = \"<group>\"; }};")
    lines.append(f"\t\t{privacy_id} /* PrivacyInfo.xcprivacy */ = {{isa = PBXFileReference; lastKnownFileType = text.xml; path = PrivacyInfo.xcprivacy; sourceTree = \"<group>\"; }};")
    lines.append("/* End PBXFileReference section */")
    lines.append("")
    lines.append("/* Begin PBXFrameworksBuildPhase section */")
    lines.append(f"\t\t{frameworks_phase} /* Frameworks */ = {{")
    lines.append("\t\t\tisa = PBXFrameworksBuildPhase;")
    lines.append("\t\t\tbuildActionMask = 2147483647;")
    lines.append("\t\t\tfiles = ();")
    lines.append("\t\t\trunOnlyForDeploymentPostprocessing = 0;")
    lines.append("\t\t};")
    lines.append(f"\t\t{test_frameworks_phase} /* Frameworks */ = {{")
    lines.append("\t\t\tisa = PBXFrameworksBuildPhase;")
    lines.append("\t\t\tbuildActionMask = 2147483647;")
    lines.append("\t\t\tfiles = ();")
    lines.append("\t\t\trunOnlyForDeploymentPostprocessing = 0;")
    lines.append("\t\t};")
    lines.append("/* End PBXFrameworksBuildPhase section */")
    lines.append("")

    # Build folder groups
    group_ids = {}
    def get_group_id(path):
        if path not in group_ids:
            group_ids[path] = uid()
        return group_ids[path]

    peak_subdirs = set()
    for f in app_swift:
        p = Path(f).parent
        while str(p) != "Peak":
            peak_subdirs.add(str(p))
            p = p.parent

    lines.append("/* Begin PBXGroup section */")
    lines.append(f"\t\t{main_group_id} = {{")
    lines.append("\t\t\tisa = PBXGroup;")
    lines.append("\t\t\tchildren = (")
    lines.append(f"\t\t\t\t{peak_group_id} /* Peak */,")
    lines.append(f"\t\t\t\t{test_group_id} /* PeakTests */,")
    lines.append(f"\t\t\t\t{products_group_id} /* Products */,")
    lines.append("\t\t\t);")
    lines.append("\t\t\tsourceTree = \"<group>\";")
    lines.append("\t\t};")

    lines.append(f"\t\t{products_group_id} /* Products */ = {{")
    lines.append("\t\t\tisa = PBXGroup;")
    lines.append("\t\t\tchildren = (")
    lines.append(f"\t\t\t\t{app_product_id} /* Peak.app */,")
    lines.append(f"\t\t\t\t{test_product_id} /* PeakTests.xctest */,")
    lines.append("\t\t\t);")
    lines.append("\t\t\tname = Products;")
    lines.append("\t\t\tsourceTree = \"<group>\";")
    lines.append("\t\t};")

    # Peak top group children
    top_children = set()
    for f in app_swift:
        parts = Path(f).parts
        if len(parts) == 2:
            top_children.add(file_refs[f])
        else:
            top_children.add(get_group_id("/".join(parts[:2])))

    for special in [entitlements_id, assets_id, preview_assets_id, storekit_id, privacy_id]:
        top_children.add(special)

    lines.append(f"\t\t{peak_group_id} /* Peak */ = {{")
    lines.append("\t\t\tisa = PBXGroup;")
    lines.append("\t\t\tchildren = (")
    for cid in sorted(top_children):
        lines.append(f"\t\t\t\t{cid},")
    lines.append("\t\t\t);")
    lines.append("\t\t\tpath = Peak;")
    lines.append("\t\t\tsourceTree = \"<group>\";")
    lines.append("\t\t};")

    # Subgroups
    for subdir in sorted(peak_subdirs):
        gid = get_group_id(subdir)
        children = []
        for f in app_swift:
            if str(Path(f).parent) == subdir:
                children.append(file_refs[f])
            elif str(Path(f).parent).startswith(subdir + "/"):
                child_group = "/".join(Path(f).parts[:len(subdir.split("/"))+1])
                if child_group != subdir:
                    children.append(get_group_id(child_group))

        # direct swift files only at this level
        direct = [file_refs[f] for f in app_swift if str(Path(f).parent) == subdir]
        child_groups = set()
        for f in app_swift:
            parent = str(Path(f).parent)
            if parent.startswith(subdir + "/"):
                rel = parent[len(subdir)+1:]
                first = rel.split("/")[0]
                child_groups.add(get_group_id(subdir + "/" + first))

        lines.append(f"\t\t{gid} /* {Path(subdir).name} */ = {{")
        lines.append("\t\t\tisa = PBXGroup;")
        lines.append("\t\t\tchildren = (")
        for c in sorted(direct):
            lines.append(f"\t\t\t\t{c},")
        for cg in sorted(child_groups):
            if cg != gid:
                lines.append(f"\t\t\t\t{cg},")
        lines.append("\t\t\t);")
        lines.append(f"\t\t\tpath = {Path(subdir).name};")
        lines.append("\t\t\tsourceTree = \"<group>\";")
        lines.append("\t\t};")

    lines.append(f"\t\t{test_group_id} /* PeakTests */ = {{")
    lines.append("\t\t\tisa = PBXGroup;")
    lines.append("\t\t\tchildren = (")
    for f in test_swift:
        lines.append(f"\t\t\t\t{file_refs[f]} /* {Path(f).name} */,")
    lines.append("\t\t\t);")
    lines.append("\t\t\tpath = PeakTests;")
    lines.append("\t\t\tsourceTree = \"<group>\";")
    lines.append("\t\t};")

    lines.append("/* End PBXGroup section */")
    lines.append("")

    lines.append("/* Begin PBXNativeTarget section */")
    lines.append(f"\t\t{native_target_app} /* Peak */ = {{")
    lines.append("\t\t\tisa = PBXNativeTarget;")
    lines.append(f"\t\t\tbuildConfigurationList = {app_config_list} /* Build configuration list for PBXNativeTarget \"Peak\" */;")
    lines.append("\t\t\tbuildPhases = (")
    lines.append(f"\t\t\t\t{sources_phase_app} /* Sources */,")
    lines.append(f"\t\t\t\t{frameworks_phase} /* Frameworks */,")
    lines.append(f"\t\t\t\t{resources_phase} /* Resources */,")
    lines.append("\t\t\t);")
    lines.append("\t\t\tbuildRules = ();")
    lines.append("\t\t\tdependencies = ();")
    lines.append("\t\t\tname = Peak;")
    lines.append(f"\t\t\tproductName = Peak;")
    lines.append(f"\t\t\tproductReference = {app_product_id} /* Peak.app */;")
    lines.append("\t\t\tproductType = \"com.apple.product-type.application\";")
    lines.append("\t\t};")

    lines.append(f"\t\t{native_target_test} /* PeakTests */ = {{")
    lines.append("\t\t\tisa = PBXNativeTarget;")
    lines.append(f"\t\t\tbuildConfigurationList = {test_config_list} /* Build configuration list for PBXNativeTarget \"PeakTests\" */;")
    lines.append("\t\t\tbuildPhases = (")
    lines.append(f"\t\t\t\t{sources_phase_test} /* Sources */,")
    lines.append(f"\t\t\t\t{test_frameworks_phase} /* Frameworks */,")
    lines.append("\t\t\t);")
    lines.append("\t\t\tbuildRules = ();")
    lines.append("\t\t\tdependencies = (")
    lines.append(f"\t\t\t\t{test_target_dependency} /* PBXTargetDependency */,")
    lines.append("\t\t\t);")
    lines.append("\t\t\tname = PeakTests;")
    lines.append(f"\t\t\tproductName = PeakTests;")
    lines.append(f"\t\t\tproductReference = {test_product_id} /* PeakTests.xctest */;")
    lines.append("\t\t\tproductType = \"com.apple.product-type.bundle.unit-test\";")
    lines.append("\t\t};")
    lines.append("/* End PBXNativeTarget section */")
    lines.append("")

    lines.append("/* Begin PBXProject section */")
    lines.append(f"\t\t{project_id} /* Project object */ = {{")
    lines.append("\t\t\tisa = PBXProject;")
    lines.append("\t\t\tattributes = {")
    lines.append("\t\t\t\tBuildIndependentTargetsInParallel = 1;")
    lines.append("\t\t\t\tLastSwiftUpdateCheck = 1600;")
    lines.append("\t\t\t\tLastUpgradeCheck = 1600;")
    lines.append("\t\t\t\tTargetAttributes = {")
    lines.append(f"\t\t\t\t\t{native_target_app} = {{")
    lines.append("\t\t\t\t\t\tCreatedOnToolsVersion = 16.0;")
    lines.append("\t\t\t\t\t};")
    lines.append(f"\t\t\t\t\t{native_target_test} = {{")
    lines.append("\t\t\t\t\t\tCreatedOnToolsVersion = 16.0;")
    lines.append("\t\t\t\t\t\tTestTargetID = " + native_target_app + ";")
    lines.append("\t\t\t\t\t};")
    lines.append("\t\t\t\t};")
    lines.append("\t\t\t};")
    lines.append(f"\t\t\tbuildConfigurationList = {project_config_list} /* Build configuration list for PBXProject \"Peak\" */;")
    lines.append("\t\t\tcompatibilityVersion = \"Xcode 15.0\";")
    lines.append("\t\t\tdevelopmentRegion = en;")
    lines.append("\t\t\thasScannedForEncodings = 0;")
    lines.append("\t\t\tknownRegions = (en, Base);")
    lines.append(f"\t\t\tmainGroup = {main_group_id};")
    lines.append("\t\t\tproductRefGroup = " + products_group_id + " /* Products */;")
    lines.append("\t\t\tprojectDirPath = \"\";")
    lines.append("\t\t\tprojectRoot = \"\";")
    lines.append("\t\t\ttargets = (")
    lines.append(f"\t\t\t\t{native_target_app} /* Peak */,")
    lines.append(f"\t\t\t\t{native_target_test} /* PeakTests */,")
    lines.append("\t\t\t);")
    lines.append("\t\t};")
    lines.append("/* End PBXProject section */")
    lines.append("")

    lines.append("/* Begin PBXResourcesBuildPhase section */")
    lines.append(f"\t\t{resources_phase} /* Resources */ = {{")
    lines.append("\t\t\tisa = PBXResourcesBuildPhase;")
    lines.append("\t\t\tbuildActionMask = 2147483647;")
    lines.append("\t\t\tfiles = (")
    lines.append(f"\t\t\t\t{assets_build_id} /* Assets.xcassets in Resources */,")
    lines.append(f"\t\t\t\t{preview_build_id} /* Preview Assets.xcassets in Resources */,")
    lines.append(f"\t\t\t\t{storekit_build_id} /* Peak.storekit in Resources */,")
    lines.append(f"\t\t\t\t{privacy_build_id} /* PrivacyInfo.xcprivacy in Resources */,")
    lines.append("\t\t\t);")
    lines.append("\t\t\trunOnlyForDeploymentPostprocessing = 0;")
    lines.append("\t\t};")
    lines.append("/* End PBXResourcesBuildPhase section */")
    lines.append("")

    lines.append("/* Begin PBXSourcesBuildPhase section */")
    lines.append(f"\t\t{sources_phase_app} /* Sources */ = {{")
    lines.append("\t\t\tisa = PBXSourcesBuildPhase;")
    lines.append("\t\t\tbuildActionMask = 2147483647;")
    lines.append("\t\t\tfiles = (")
    for f, bid in build_files_app.items():
        lines.append(f"\t\t\t\t{bid} /* {Path(f).name} in Sources */,")
    lines.append("\t\t\t);")
    lines.append("\t\t\trunOnlyForDeploymentPostprocessing = 0;")
    lines.append("\t\t};")

    lines.append(f"\t\t{sources_phase_test} /* Sources */ = {{")
    lines.append("\t\t\tisa = PBXSourcesBuildPhase;")
    lines.append("\t\t\tbuildActionMask = 2147483647;")
    lines.append("\t\t\tfiles = (")
    for f, bid in build_files_test.items():
        lines.append(f"\t\t\t\t{bid} /* {Path(f).name} in Sources */,")
    lines.append("\t\t\t);")
    lines.append("\t\t\trunOnlyForDeploymentPostprocessing = 0;")
    lines.append("\t\t};")
    lines.append("/* End PBXSourcesBuildPhase section */")
    lines.append("")

    lines.append("/* Begin PBXTargetDependency section */")
    lines.append(f"\t\t{test_target_dependency} /* PBXTargetDependency */ = {{")
    lines.append("\t\t\tisa = PBXTargetDependency;")
    lines.append(f"\t\t\ttarget = {native_target_app} /* Peak */;")
    lines.append(f"\t\t\ttargetProxy = {test_target_proxy} /* PBXContainerItemProxy */;")
    lines.append("\t\t};")
    lines.append("/* End PBXTargetDependency section */")
    lines.append("")

    # Build settings helper
    def build_settings(is_test=False):
        s = []
        s.append("\t\t\t\tASSETCATALOG_COMPILER_APPICON_NAME = AppIcon;")
        s.append("\t\t\t\tASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME = AccentColor;")
        s.append("\t\t\t\tCODE_SIGN_ENTITLEMENTS = Peak/Peak.entitlements;")
        s.append("\t\t\t\tCODE_SIGN_STYLE = Automatic;")
        s.append("\t\t\t\tCURRENT_PROJECT_VERSION = 1;")
        s.append("\t\t\t\tDEVELOPMENT_TEAM = \"\";")
        s.append("\t\t\t\tENABLE_PREVIEWS = YES;")
        s.append("\t\t\t\tGENERATE_INFOPLIST_FILE = YES;")
        if not is_test:
            s.append("\t\t\t\tINFOPLIST_KEY_CFBundleDisplayName = Peak;")
            s.append("\t\t\t\tINFOPLIST_KEY_LSApplicationCategoryType = \"public.app-category.healthcare-fitness\";")
            s.append("\t\t\t\tINFOPLIST_KEY_NSFaceIDUsageDescription = \"Peak uses Face ID to quickly and securely unlock the app.\";")
            s.append("\t\t\t\tINFOPLIST_KEY_NSHealthShareUsageDescription = \"Peak reads your sleep, heart rate, HRV, and activity data to calculate your daily recovery score.\";")
            s.append("\t\t\t\tINFOPLIST_KEY_NSHealthUpdateUsageDescription = \"Peak can write hydration and mindfulness data to Health when you log entries.\";")
            s.append("\t\t\t\tINFOPLIST_KEY_NSPhotoLibraryUsageDescription = \"Peak lets you attach photos to mood reflections and journal entries.\";")
            s.append("\t\t\t\tINFOPLIST_KEY_UIApplicationSceneManifest_Generation = YES;")
            s.append("\t\t\t\tINFOPLIST_KEY_UILaunchScreen_Generation = YES;")
            s.append("\t\t\t\tINFOPLIST_KEY_UISupportedInterfaceOrientations = UIInterfaceOrientationPortrait;")
            s.append("\t\t\t\tINFOPLIST_KEY_UISupportedInterfaceOrientations_iPad = \"UIInterfaceOrientationPortrait UIInterfaceOrientationPortraitUpsideDown UIInterfaceOrientationLandscapeLeft UIInterfaceOrientationLandscapeRight\";")
            s.append("\t\t\t\tLD_RUNPATH_SEARCH_PATHS = (\"$(inherited)\", \"@executable_path/Frameworks\");")
            s.append("\t\t\t\tMARKETING_VERSION = 1.0.0;")
            s.append("\t\t\t\tPRODUCT_BUNDLE_IDENTIFIER = com.peak.health;")
            s.append("\t\t\t\tPRODUCT_NAME = \"$(TARGET_NAME)\";")
            s.append("\t\t\t\tSWIFT_EMIT_LOC_STRINGS = YES;")
            s.append("\t\t\t\tSWIFT_VERSION = 5.0;")
            s.append("\t\t\t\tTARGETED_DEVICE_FAMILY = \"1,2\";")
            s.append("\t\t\t\tIPHONEOS_DEPLOYMENT_TARGET = 18.0;")
        else:
            s.append("\t\t\t\tBUNDLE_LOADER = \"$(TEST_HOST)\";")
            s.append("\t\t\t\tGENERATE_INFOPLIST_FILE = YES;")
            s.append("\t\t\t\tIPHONEOS_DEPLOYMENT_TARGET = 18.0;")
            s.append("\t\t\t\tMARKETING_VERSION = 1.0;")
            s.append("\t\t\t\tPRODUCT_BUNDLE_IDENTIFIER = com.peak.health.tests;")
            s.append("\t\t\t\tPRODUCT_NAME = \"$(TARGET_NAME)\";")
            s.append("\t\t\t\tSWIFT_VERSION = 5.0;")
            s.append("\t\t\t\tTARGETED_DEVICE_FAMILY = \"1,2\";")
            s.append("\t\t\t\tTEST_HOST = \"$(BUILT_PRODUCTS_DIR)/Peak.app/$(BUNDLE_EXECUTABLE_FOLDER_PATH)/Peak\";")
        return s

    lines.append("/* Begin XCBuildConfiguration section */")
    for cfg_id, name, settings_extra in [
        (debug_proj, "Debug", ["\t\t\t\tALWAYS_SEARCH_USER_PATHS = NO;", "\t\t\t\tCLANG_ENABLE_MODULES = YES;", "\t\t\t\tCOPY_PHASE_STRIP = NO;", "\t\t\t\tDEBUG_INFORMATION_FORMAT = dwarf;", "\t\t\t\tENABLE_TESTABILITY = YES;", "\t\t\t\tGCC_OPTIMIZATION_LEVEL = 0;", "\t\t\t\tIPHONEOS_DEPLOYMENT_TARGET = 18.0;", "\t\t\t\tMTL_ENABLE_DEBUG_INFO = INCLUDE_SOURCE;", "\t\t\t\tONLY_ACTIVE_ARCH = YES;", "\t\t\t\tSDKROOT = iphoneos;", "\t\t\t\tSWIFT_ACTIVE_COMPILATION_CONDITIONS = \"DEBUG $(inherited)\";", "\t\t\t\tSWIFT_OPTIMIZATION_LEVEL = \"-Onone\";"]),
        (release_proj, "Release", ["\t\t\t\tALWAYS_SEARCH_USER_PATHS = NO;", "\t\t\t\tCLANG_ENABLE_MODULES = YES;", "\t\t\t\tCOPY_PHASE_STRIP = NO;", "\t\t\t\tDEBUG_INFORMATION_FORMAT = \"dwarf-with-dsym\";", "\t\t\t\tENABLE_NS_ASSERTIONS = NO;", "\t\t\t\tIPHONEOS_DEPLOYMENT_TARGET = 18.0;", "\t\t\t\tMTL_ENABLE_DEBUG_INFO = NO;", "\t\t\t\tSDKROOT = iphoneos;", "\t\t\t\tSWIFT_COMPILATION_MODE = wholemodule;", "\t\t\t\tVALIDATE_PRODUCT = YES;"]),
        (debug_app, "Debug", build_settings()),
        (release_app, "Release", build_settings()),
        (debug_test, "Debug", build_settings(is_test=True)),
        (release_test, "Release", build_settings(is_test=True)),
    ]:
        lines.append(f"\t\t{cfg_id} /* {name} */ = {{")
        lines.append("\t\t\tisa = XCBuildConfiguration;")
        if cfg_id in (debug_proj, release_proj):
            lines.append("\t\t\tbuildSettings = {")
            for s in settings_extra:
                lines.append(s)
            lines.append("\t\t\t};")
            lines.append("\t\t\tname = " + name + ";")
        elif cfg_id in (debug_app, release_app, debug_test, release_test):
            lines.append("\t\t\tbuildSettings = {")
            for s in settings_extra:
                lines.append(s)
            lines.append("\t\t\t};")
            lines.append("\t\t\tname = " + name + ";")
        lines.append("\t\t};")

    lines.append("/* End XCBuildConfiguration section */")
    lines.append("")
    lines.append("/* Begin XCConfigurationList section */")
    for list_id, name, configs in [
        (project_config_list, "Project", [(debug_proj, "Debug"), (release_proj, "Release")]),
        (app_config_list, "Peak", [(debug_app, "Debug"), (release_app, "Release")]),
        (test_config_list, "PeakTests", [(debug_test, "Debug"), (release_test, "Release")]),
    ]:
        lines.append(f"\t\t{list_id} /* Build configuration list for PBXNativeTarget \"{name}\" */ = {{")
        lines.append("\t\t\tisa = XCConfigurationList;")
        lines.append("\t\t\tbuildConfigurations = (")
        for cid, cname in configs:
            lines.append(f"\t\t\t\t{cid} /* {cname} */,")
        lines.append("\t\t\t);")
        lines.append("\t\t\tdefaultConfigurationIsVisible = 0;")
        lines.append("\t\t\tdefaultConfigurationName = Release;")
        lines.append("\t\t};")
    lines.append("/* End XCConfigurationList section */")
    lines.append("\t};")
    lines.append(f"\trootObject = {project_id} /* Project object */;")
    lines.append("}")

    PROJECT_DIR.mkdir(parents=True, exist_ok=True)
    (PROJECT_DIR / "project.pbxproj").write_text("\n".join(lines) + "\n")
    print(f"Generated {PROJECT_DIR / 'project.pbxproj'}")
    print(f"  App sources: {len(app_swift)}")
    print(f"  Test sources: {len(test_swift)}")

if __name__ == "__main__":
    main()
