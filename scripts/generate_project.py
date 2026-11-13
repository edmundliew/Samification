"""Generate the dependency-free Xcode project. Run from any directory."""
from pathlib import Path
import hashlib
import json

root = Path(__file__).resolve().parents[1]
objects = {}

def ident(value):
    return hashlib.sha1(value.encode()).hexdigest()[:24].upper()

def obj(key, value):
    objects[ident(key)] = value
    return ident(key)

sources = sorted([*root.glob('App/*.swift'), *root.glob('Sources/SamificationCore/*.swift')])
children, builds = [], []
for path in sources:
    rel = str(path.relative_to(root))
    ref = obj(rel, {'isa': 'PBXFileReference', 'lastKnownFileType': 'sourcecode.swift', 'path': rel, 'sourceTree': '<group>'})
    children.append(ref)
    builds.append(obj(rel + '-build', {'isa': 'PBXBuildFile', 'fileRef': ref}))
assets = obj('assets', {'isa': 'PBXFileReference', 'lastKnownFileType': 'folder.assetcatalog', 'path': 'App/Assets.xcassets', 'sourceTree': '<group>'})
children.append(assets)
asset_build = obj('asset-build', {'isa': 'PBXBuildFile', 'fileRef': assets})
privacy = obj('privacy', {'isa': 'PBXFileReference', 'lastKnownFileType': 'text.xml', 'path': 'App/PrivacyInfo.xcprivacy', 'sourceTree': '<group>'})
children.append(privacy)
privacy_build = obj('privacy-build', {'isa': 'PBXBuildFile', 'fileRef': privacy})
product = obj('product', {'isa': 'PBXFileReference', 'explicitFileType': 'wrapper.application', 'path': 'Samification.app', 'sourceTree': 'BUILT_PRODUCTS_DIR'})
products = obj('products', {'isa': 'PBXGroup', 'name': 'Products', 'children': [product], 'sourceTree': '<group>'})
main = obj('main', {'isa': 'PBXGroup', 'children': children + [products], 'sourceTree': '<group>'})
source_phase = obj('sources', {'isa': 'PBXSourcesBuildPhase', 'buildActionMask': 2147483647, 'files': builds, 'runOnlyForDeploymentPostprocessing': 0})
resource_phase = obj('resources', {'isa': 'PBXResourcesBuildPhase', 'buildActionMask': 2147483647, 'files': [asset_build, privacy_build], 'runOnlyForDeploymentPostprocessing': 0})
framework_phase = obj('frameworks', {'isa': 'PBXFrameworksBuildPhase', 'buildActionMask': 2147483647, 'files': [], 'runOnlyForDeploymentPostprocessing': 0})

config_ref = obj('base-config', {'isa': 'PBXFileReference', 'lastKnownFileType': 'text.xcconfig', 'path': 'Config/Base.xcconfig', 'sourceTree': '<group>'})
objects[main]['children'].append(config_ref)
project_configs, target_configs = [], []
for config in ['Debug', 'Release']:
    project_configs.append(obj('project-' + config, {'isa': 'XCBuildConfiguration', 'name': config, 'buildSettings': {
        'CLANG_ENABLE_MODULES': 'YES', 'SWIFT_VERSION': '5.0', 'IPHONEOS_DEPLOYMENT_TARGET': '17.0',
        'SDKROOT': 'iphoneos', 'SWIFT_OPTIMIZATION_LEVEL': '-Onone' if config == 'Debug' else '-O',
        'DEBUG_INFORMATION_FORMAT': 'dwarf' if config == 'Debug' else 'dwarf-with-dsym',
        'SWIFT_ACTIVE_COMPILATION_CONDITIONS': 'DEBUG' if config == 'Debug' else '',
    }}))
    target_configs.append(obj('target-' + config, {'isa': 'XCBuildConfiguration', 'name': config, 'baseConfigurationReference': config_ref, 'buildSettings': {
        'INFOPLIST_FILE': 'Config/Info.plist',
        'PRODUCT_BUNDLE_IDENTIFIER': 'com.edmundliew.samification', 'PRODUCT_NAME': '$(TARGET_NAME)',
        'GENERATE_INFOPLIST_FILE': 'YES', 'INFOPLIST_KEY_CFBundleDisplayName': 'Samification',
        'INFOPLIST_KEY_UILaunchScreen_Generation': 'YES', 'TARGETED_DEVICE_FAMILY': '1,2',
        'SUPPORTED_PLATFORMS': 'iphoneos iphonesimulator', 'SUPPORTS_MACCATALYST': 'NO',
        'INFOPLIST_KEY_UISupportedInterfaceOrientations': 'UIInterfaceOrientationPortrait UIInterfaceOrientationLandscapeLeft UIInterfaceOrientationLandscapeRight',
        'INFOPLIST_KEY_UISupportedInterfaceOrientations_iPad': 'UIInterfaceOrientationPortrait UIInterfaceOrientationPortraitUpsideDown UIInterfaceOrientationLandscapeLeft UIInterfaceOrientationLandscapeRight',
        'MARKETING_VERSION': '0.2.0', 'CURRENT_PROJECT_VERSION': '10', 'CODE_SIGN_STYLE': 'Automatic', 'DEVELOPMENT_TEAM': '3T3328WVBE',
        'ASSETCATALOG_COMPILER_APPICON_NAME': 'AppIcon',
        'LD_RUNPATH_SEARCH_PATHS': '$(inherited) @executable_path/Frameworks',
        'ENABLE_PREVIEWS': 'YES',
    }}))
project_list = obj('project-list', {'isa': 'XCConfigurationList', 'buildConfigurations': project_configs, 'defaultConfigurationIsVisible': 0, 'defaultConfigurationName': 'Release'})
target_list = obj('target-list', {'isa': 'XCConfigurationList', 'buildConfigurations': target_configs, 'defaultConfigurationIsVisible': 0, 'defaultConfigurationName': 'Release'})
target = obj('target', {'isa': 'PBXNativeTarget', 'name': 'Samification', 'productName': 'Samification', 'productType': 'com.apple.product-type.application', 'productReference': product, 'buildConfigurationList': target_list, 'buildPhases': [source_phase, framework_phase, resource_phase], 'buildRules': [], 'dependencies': []})
project = obj('project', {'isa': 'PBXProject', 'attributes': {'BuildIndependentTargetsInParallel': 'YES', 'LastUpgradeCheck': '1500'}, 'buildConfigurationList': project_list, 'compatibilityVersion': 'Xcode 14.0', 'developmentRegion': 'en', 'hasScannedForEncodings': 0, 'knownRegions': ['en', 'Base'], 'mainGroup': main, 'productRefGroup': products, 'projectDirPath': '', 'projectRoot': '', 'targets': [target]})

def encode(value, depth=0):
    if isinstance(value, dict):
        return '{\n' + ''.join('\t' * (depth + 1) + json.dumps(str(k)) + ' = ' + encode(v, depth + 1) + ';\n' for k, v in value.items()) + '\t' * depth + '}'
    if isinstance(value, list):
        return '(' + ', '.join(encode(x, depth) for x in value) + (',' if value else '') + ')'
    return json.dumps(value) if isinstance(value, str) else str(value)

folder = root / 'Samification.xcodeproj'
folder.mkdir(exist_ok=True)
(folder / 'project.pbxproj').write_text('// !$*UTF8*$!\n' + encode({'archiveVersion': 1, 'classes': {}, 'objectVersion': 56, 'objects': objects, 'rootObject': project}) + '\n')
schemes = folder / 'xcshareddata/xcschemes'
schemes.mkdir(parents=True, exist_ok=True)
ref = f'<BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="{target}" BuildableName="Samification.app" BlueprintName="Samification" ReferencedContainer="container:Samification.xcodeproj"/>'
(schemes / 'Samification.xcscheme').write_text(f'''<?xml version="1.0" encoding="UTF-8"?>
<Scheme LastUpgradeVersion="1500" version="1.3">
<BuildAction parallelizeBuildables="YES" buildImplicitDependencies="YES"><BuildActionEntries><BuildActionEntry buildForTesting="YES" buildForRunning="YES" buildForProfiling="YES" buildForArchiving="YES" buildForAnalyzing="YES">{ref}</BuildActionEntry></BuildActionEntries></BuildAction>
<TestAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.IDEFoundation.Launcher.LLDB" shouldUseLaunchSchemeArgsEnv="YES"><Testables/></TestAction>
<LaunchAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.IDEFoundation.Launcher.LLDB" launchStyle="0" useCustomWorkingDirectory="NO" ignoresPersistentStateOnLaunch="NO" debugDocumentVersioning="YES" allowLocationSimulation="YES"><BuildableProductRunnable runnableDebuggingMode="0">{ref}</BuildableProductRunnable></LaunchAction>
<ProfileAction buildConfiguration="Release" shouldUseLaunchSchemeArgsEnv="YES" savedToolIdentifier="" useCustomWorkingDirectory="NO" debugDocumentVersioning="YES"><BuildableProductRunnable runnableDebuggingMode="0">{ref}</BuildableProductRunnable></ProfileAction>
<AnalyzeAction buildConfiguration="Debug"/><ArchiveAction buildConfiguration="Release" revealArchiveInOrganizer="YES"/>
</Scheme>
''')
print(f'Generated Xcode project: {len(sources)} Swift files, iPhone and iPad, iOS 17+.')
