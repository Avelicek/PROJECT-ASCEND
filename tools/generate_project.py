from pathlib import Path
import hashlib, json, plistlib, xml.etree.ElementTree as ET
root = Path(__file__).resolve().parents[1]
def write(path, text):
    output = root / path
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(text, encoding='utf-8')
def seed(path, text):
    if not (root/path).exists(): write(path,text)
def uid(value): return hashlib.sha1(value.encode()).hexdigest()[:24].upper()
def quote(value): return json.dumps(str(value))
sources = sorted(str(path.relative_to(root)).replace('\\', '/') for path in (root/'ASCEND').rglob('*.swift'))
all_tests = sorted(str(path.relative_to(root)).replace('\\', '/') for path in (root/'Tests').rglob('*.swift'))
tests = [path for path in all_tests if not path.startswith('Tests/UI/')]
widget_sources = ["WidgetExtension/AscendRestWidget.swift", "ASCEND/LiveActivity/RestActivityAttributes.swift"]
ui_tests = [path for path in all_tests if path.startswith('Tests/UI/')]
objects = {}
def obj(key, value): objects[uid(key)] = value; return uid(key)
fileids = {}
for name in sorted(set(sources + all_tests + widget_sources)):
    fileids[name] = obj('file:'+name, f'isa = PBXFileReference; lastKnownFileType = sourcecode.swift; name = {quote(Path(name).name)}; path = {quote(name)}; sourceTree = SOURCE_ROOT;')
widget_product = obj('widget-product', 'isa = PBXFileReference; explicitFileType = "wrapper.app-extension"; includeInIndex = 0; path = AscendRestWidget.appex; sourceTree = BUILT_PRODUCTS_DIR;')
asset = obj('assets', 'isa = PBXFileReference; lastKnownFileType = folder.assetcatalog; path = ASCEND/Resources/Assets.xcassets; sourceTree = SOURCE_ROOT;')
anatomy = obj('anatomy', 'isa = PBXFileReference; lastKnownFileType = folder; path = ASCEND/Resources/Anatomy; sourceTree = SOURCE_ROOT;')
app_product = obj('app-product', 'isa = PBXFileReference; explicitFileType = wrapper.application; includeInIndex = 0; path = ASCEND.app; sourceTree = BUILT_PRODUCTS_DIR;')
test_product = obj('test-product', 'isa = PBXFileReference; explicitFileType = wrapper.cfbundle; includeInIndex = 0; path = ASCENDTests.xctest; sourceTree = BUILT_PRODUCTS_DIR;')
ui_product = obj('ui-product', 'isa = PBXFileReference; explicitFileType = wrapper.cfbundle; includeInIndex = 0; path = ASCENDUITests.xctest; sourceTree = BUILT_PRODUCTS_DIR;')

def array(ids): return '(' + ', '.join(ids) + ',)'
def sourcephase(key, names):
    builds = [obj('build:'+key+':'+name, f'isa = PBXBuildFile; fileRef = {fileids[name]};') for name in names]
    return obj(key, f'isa = PBXSourcesBuildPhase; buildActionMask = 2147483647; files = {array(builds)}; runOnlyForDeploymentPostprocessing = 0;')
app_sources = sourcephase('app-sources', sources)
test_sources = sourcephase('test-sources', tests)
ui_sources = sourcephase('ui-sources', ui_tests)
widget_phase = sourcephase('widget-sources', widget_sources)
asset_build = obj('asset-build', f'isa = PBXBuildFile; fileRef = {asset};')
anatomy_build = obj('anatomy-build', f'isa = PBXBuildFile; fileRef = {anatomy};')
app_resources = obj('app-resources', f'isa = PBXResourcesBuildPhase; buildActionMask = 2147483647; files = {array([asset_build, anatomy_build])}; runOnlyForDeploymentPostprocessing = 0;')
test_resources = obj('test-resources', 'isa = PBXResourcesBuildPhase; buildActionMask = 2147483647; files = (); runOnlyForDeploymentPostprocessing = 0;')
app_frameworks = obj('app-frameworks', 'isa = PBXFrameworksBuildPhase; buildActionMask = 2147483647; files = (); runOnlyForDeploymentPostprocessing = 0;')
test_frameworks = obj('test-frameworks', 'isa = PBXFrameworksBuildPhase; buildActionMask = 2147483647; files = (); runOnlyForDeploymentPostprocessing = 0;')
ui_frameworks = obj('ui-frameworks', 'isa = PBXFrameworksBuildPhase; buildActionMask = 2147483647; files = (); runOnlyForDeploymentPostprocessing = 0;')
ui_resources = obj('ui-resources', 'isa = PBXResourcesBuildPhase; buildActionMask = 2147483647; files = (); runOnlyForDeploymentPostprocessing = 0;')
def grouped(prefix, refs):
    direct = [ref for name,ref in sorted(refs.items()) if str(Path(name).parent).replace('\\','/') == prefix]
    descendants = sorted({name[len(prefix)+1:].split('/')[0] for name in refs if name.startswith(prefix+'/') and '/' in name[len(prefix)+1:]})
    children = [grouped(prefix+'/'+directory, refs) for directory in descendants]+direct
    return obj('group:'+prefix, f'isa = PBXGroup; children = {array(children)}; name = {quote(prefix.split("/")[-1])}; sourceTree = "<group>";')
app_group = grouped('ASCEND', {name:ref for name,ref in fileids.items() if name.startswith('ASCEND/')} | {'ASCEND/Resources/Assets.xcassets':asset, 'ASCEND/Resources/Anatomy':anatomy})
test_group = grouped('Tests', {name:ref for name,ref in fileids.items() if name.startswith('Tests/')})
widget_group = grouped('WidgetExtension', {name:ref for name,ref in fileids.items() if name.startswith('WidgetExtension/')})
product_group = obj('products', f'isa = PBXGroup; children = {array([app_product, test_product, ui_product, widget_product])}; name = Products; sourceTree = "<group>";')
main_group = obj('main', f'isa = PBXGroup; children = {array([app_group, test_group, widget_group, product_group])}; sourceTree = "<group>";')
common = {
    'SDKROOT':'iphoneos', 'IPHONEOS_DEPLOYMENT_TARGET':'27.0', 'SWIFT_VERSION':'5.0',
    'CLANG_ENABLE_MODULES':'YES', 'CLANG_ENABLE_OBJC_ARC':'YES', 'ENABLE_USER_SCRIPT_SANDBOXING':'YES',
    'GCC_WARN_64_TO_32_BIT_CONVERSION':'YES', 'CLANG_WARN_BOOL_CONVERSION':'YES', 'CLANG_WARN_CONSTANT_CONVERSION':'YES',
    'CLANG_WARN_DOCUMENTATION_COMMENTS':'YES', 'CLANG_WARN_EMPTY_BODY':'YES', 'CLANG_WARN_UNREACHABLE_CODE':'YES',
    'SWIFT_STRICT_CONCURRENCY':'targeted', 'SUPPORTED_PLATFORMS':'iphoneos iphonesimulator', 'TARGETED_DEVICE_FAMILY':'1',
}
def config(key, name, settings):
    pairs = ' '.join(f'{k} = {quote(v)};' for k,v in settings.items())
    return obj(key, f'isa = XCBuildConfiguration; buildSettings = {{ {pairs} }}; name = {name};')
def configlist(key, configs):
    return obj(key, f'isa = XCConfigurationList; buildConfigurations = {array(configs)}; defaultConfigurationIsVisible = 0; defaultConfigurationName = Release;')
project_configs = []
app_configs = []
test_configs = []
ui_configs = []
widget_configs = []
for name in ['Debug', 'Release']:
    options = common | ({'SWIFT_OPTIMIZATION_LEVEL':'-Onone', 'SWIFT_ACTIVE_COMPILATION_CONDITIONS':'DEBUG $(inherited)', 'ENABLE_TESTABILITY':'YES', 'DEBUG_INFORMATION_FORMAT':'dwarf'} if name == 'Debug' else {'SWIFT_OPTIMIZATION_LEVEL':'-O', 'SWIFT_COMPILATION_MODE':'wholemodule', 'DEBUG_INFORMATION_FORMAT':'dwarf-with-dsym'})
    project_configs.append(config('project-'+name, name, options))
    app_configs.append(config('app-'+name, name, {
        'PRODUCT_NAME':'$(TARGET_NAME)', 'PRODUCT_BUNDLE_IDENTIFIER':'com.karel.projectascend',
        'INFOPLIST_FILE':'ASCEND/Resources/Info.plist', 'CODE_SIGN_STYLE':'Automatic', 'DEVELOPMENT_TEAM':'',
        'MARKETING_VERSION':'1.0.0', 'CURRENT_PROJECT_VERSION':'1', 'ASSETCATALOG_COMPILER_APPICON_NAME':'AppIcon',
        'ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME':'AccentColor', 'LD_RUNPATH_SEARCH_PATHS':'$(inherited) @executable_path/Frameworks',
    }))
    test_configs.append(config('tests-'+name, name, {
        'PRODUCT_NAME':'$(TARGET_NAME)', 'PRODUCT_BUNDLE_IDENTIFIER':'com.karel.projectascend.tests',
        'GENERATE_INFOPLIST_FILE':'YES', 'CODE_SIGN_STYLE':'Automatic', 'DEVELOPMENT_TEAM':'',
        'TEST_HOST':'$(BUILT_PRODUCTS_DIR)/ASCEND.app/ASCEND',
        'BUNDLE_LOADER':'$(TEST_HOST)', 'LD_RUNPATH_SEARCH_PATHS':'$(inherited) @executable_path/Frameworks @loader_path/Frameworks',
    }))
    widget_configs.append(config('widget-'+name, name, {
        'PRODUCT_NAME':'AscendRestWidget', 'PRODUCT_BUNDLE_IDENTIFIER':'com.karel.projectascend.rest',
        'INFOPLIST_FILE':'WidgetExtension/Info.plist', 'GENERATE_INFOPLIST_FILE':'YES',
        'CODE_SIGN_STYLE':'Automatic', 'DEVELOPMENT_TEAM':'', 'MARKETING_VERSION':'1.0.0', 'CURRENT_PROJECT_VERSION':'1',
        'APPLICATION_EXTENSION_API_ONLY':'YES', 'SKIP_INSTALL':'YES', 'LD_RUNPATH_SEARCH_PATHS':'$(inherited) @executable_path/Frameworks @executable_path/../../Frameworks',
    }))
    ui_configs.append(config('ui-'+name, name, {
        'PRODUCT_NAME':'$(TARGET_NAME)', 'PRODUCT_BUNDLE_IDENTIFIER':'com.karel.projectascend.uitests',
        'GENERATE_INFOPLIST_FILE':'YES', 'CODE_SIGN_STYLE':'Automatic', 'DEVELOPMENT_TEAM':'',
        'TEST_TARGET_NAME':'ASCEND',
        'LD_RUNPATH_SEARCH_PATHS':'$(inherited) @executable_path/Frameworks @loader_path/Frameworks',
    }))
proj_list = configlist('project-configs', project_configs)
app_list = configlist('app-configs', app_configs)
test_list = configlist('test-configs', test_configs)
ui_list = configlist('ui-configs', ui_configs)
widget_list = configlist('widget-configs', widget_configs)
widget_target = obj('widget-target', f'isa = PBXNativeTarget; buildConfigurationList = {widget_list}; buildPhases = {array([widget_phase])}; buildRules = (); dependencies = (); name = AscendRestWidget; productName = AscendRestWidget; productReference = {widget_product}; productType = "com.apple.product-type.app-extension";')
project_id = uid('project')
widget_proxy = obj('widget-proxy', f'isa = PBXContainerItemProxy; containerPortal = {project_id}; proxyType = 1; remoteGlobalIDString = {widget_target}; remoteInfo = AscendRestWidget;')
widget_dependency = obj('widget-dependency', f'isa = PBXTargetDependency; target = {widget_target}; targetProxy = {widget_proxy};')
widget_build = obj('widget-embed-build', f'isa = PBXBuildFile; fileRef = {widget_product}; settings = {{ ATTRIBUTES = (RemoveHeadersOnCopy,); }};')
widget_embed = obj('widget-embed-phase', f'isa = PBXCopyFilesBuildPhase; buildActionMask = 2147483647; dstPath = ""; dstSubfolderSpec = 13; files = {array([widget_build])}; runOnlyForDeploymentPostprocessing = 0; name = "Embed App Extensions";')
app_target = obj('app-target', f'isa = PBXNativeTarget; buildConfigurationList = {app_list}; buildPhases = {array([app_sources,app_frameworks,app_resources,widget_embed])}; buildRules = (); dependencies = {array([widget_dependency])}; name = ASCEND; productName = ASCEND; productReference = {app_product}; productType = "com.apple.product-type.application";')
proxy = obj('proxy', f'isa = PBXContainerItemProxy; containerPortal = {project_id}; proxyType = 1; remoteGlobalIDString = {app_target}; remoteInfo = ASCEND;')
dependency = obj('dependency', f'isa = PBXTargetDependency; target = {app_target}; targetProxy = {proxy};')
test_target = obj('test-target', f'isa = PBXNativeTarget; buildConfigurationList = {test_list}; buildPhases = {array([test_sources,test_frameworks,test_resources])}; buildRules = (); dependencies = {array([dependency])}; name = ASCENDTests; productName = ASCENDTests; productReference = {test_product}; productType = "com.apple.product-type.bundle.unit-test";')
ui_target = obj('ui-target', f'isa = PBXNativeTarget; buildConfigurationList = {ui_list}; buildPhases = {array([ui_sources,ui_frameworks,ui_resources])}; buildRules = (); dependencies = {array([dependency])}; name = ASCENDUITests; productName = ASCENDUITests; productReference = {ui_product}; productType = \"com.apple.product-type.bundle.ui-testing\";')
obj('project', f'''isa = PBXProject; attributes = {{ BuildIndependentTargetsInParallel = YES; LastUpgradeCheck = 2700;
    TargetAttributes = {{ {app_target} = {{ CreatedOnToolsVersion = 27.0; }}; {test_target} = {{ CreatedOnToolsVersion = 27.0; TestTargetID = {app_target}; }}; {ui_target} = {{ CreatedOnToolsVersion = 27.0; TestTargetID = {app_target}; }}; }}; }};
    buildConfigurationList = {proj_list}; compatibilityVersion = "Xcode 14.0"; developmentRegion = en; hasScannedForEncodings = 0;
    knownRegions = (en, Base,); mainGroup = {main_group}; productRefGroup = {product_group}; projectDirPath = ""; projectRoot = "";
    targets = {array([app_target,test_target,ui_target,widget_target])};''')
body = '\n'.join(f'\t\t{key} = {{ {value} }};' for key,value in sorted(objects.items()))
write('ASCEND.xcodeproj/project.pbxproj', '// !$*UTF8*$!\n{\n\tarchiveVersion = 1;\n\tclasses = {};\n\tobjectVersion = 56;\n\tobjects = {\n'+body+'\n\t};\n\trootObject = '+project_id+';\n}\n')
def ref(target, name, product):
    return f'<BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="{target}" BuildableName="{product}" BlueprintName="{name}" ReferencedContainer="container:ASCEND.xcodeproj"/>'
appref = ref(app_target,'ASCEND','ASCEND.app')
testref = ref(test_target,'ASCENDTests','ASCENDTests.xctest')
uiref = ref(ui_target,'ASCENDUITests','ASCENDUITests.xctest')
scheme = f'''<?xml version="1.0" encoding="UTF-8"?>
<Scheme LastUpgradeVersion="2700" version="1.3">
  <BuildAction parallelizeBuildables="YES" buildImplicitDependencies="YES"><BuildActionEntries>
    <BuildActionEntry buildForTesting="YES" buildForRunning="YES" buildForProfiling="YES" buildForArchiving="YES" buildForAnalyzing="YES">{appref}</BuildActionEntry>
    <BuildActionEntry buildForTesting="YES" buildForRunning="NO" buildForProfiling="NO" buildForArchiving="NO" buildForAnalyzing="NO">{testref}</BuildActionEntry>
    <BuildActionEntry buildForTesting="YES" buildForRunning="NO" buildForProfiling="NO" buildForArchiving="NO" buildForAnalyzing="NO">{uiref}</BuildActionEntry>
  </BuildActionEntries></BuildAction>
  <TestAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.IDEFoundation.Launcher.LLDB" shouldUseLaunchSchemeArgsEnv="NO">
    <Testables><TestableReference skipped="NO">{testref}</TestableReference><TestableReference skipped="NO">{uiref}</TestableReference></Testables>
  </TestAction>
  <LaunchAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.IDEFoundation.Launcher.LLDB" launchStyle="0" useCustomWorkingDirectory="NO" ignoresPersistentStateOnLaunch="NO" debugDocumentVersioning="YES" debugServiceExtension="internal" allowLocationSimulation="YES">
    <BuildableProductRunnable runnableDebuggingMode="0">{appref}</BuildableProductRunnable>
    DEMO_ARGUMENTS
  </LaunchAction>
  <ProfileAction buildConfiguration="Release" shouldUseLaunchSchemeArgsEnv="YES" savedToolIdentifier="" useCustomWorkingDirectory="NO" debugDocumentVersioning="YES"><BuildableProductRunnable runnableDebuggingMode="0">{appref}</BuildableProductRunnable></ProfileAction>
  <AnalyzeAction buildConfiguration="Debug"/><ArchiveAction buildConfiguration="Release" revealArchiveInOrganizer="YES"/>
</Scheme>
'''
write('ASCEND.xcodeproj/xcshareddata/xcschemes/ASCEND.xcscheme', scheme.replace('DEMO_ARGUMENTS',''))
write('ASCEND.xcodeproj/xcshareddata/xcschemes/ASCEND Demo.xcscheme', scheme.replace('DEMO_ARGUMENTS','<CommandLineArguments><CommandLineArgument argument="--demo" isEnabled="YES"/></CommandLineArguments>'))
write('ASCEND.xcodeproj/project.xcworkspace/contents.xcworkspacedata','<?xml version="1.0" encoding="UTF-8"?><Workspace version="1.0"><FileRef location="self:"/></Workspace>\n')
info = {
    'CFBundleDevelopmentRegion':'$(DEVELOPMENT_LANGUAGE)', 'CFBundleDisplayName':'ASCEND', 'CFBundleExecutable':'$(EXECUTABLE_NAME)',
    'CFBundleIdentifier':'$(PRODUCT_BUNDLE_IDENTIFIER)', 'CFBundleInfoDictionaryVersion':'6.0', 'CFBundleName':'$(PRODUCT_NAME)',
    'CFBundlePackageType':'APPL', 'CFBundleShortVersionString':'$(MARKETING_VERSION)', 'CFBundleVersion':'$(CURRENT_PROJECT_VERSION)',
    'LSRequiresIPhoneOS':True, 'UIApplicationSceneManifest':{'UIApplicationSupportsMultipleScenes':False},
    'UILaunchScreen':{}, 'UISupportedInterfaceOrientations':['UIInterfaceOrientationPortrait'], 'UIUserInterfaceStyle':'Dark',
    'ITSAppUsesNonExemptEncryption':False,
}
if not (root/'ASCEND/Resources/Info.plist').exists():
    (root/'ASCEND/Resources/Info.plist').write_bytes(plistlib.dumps(info))
seed('ASCEND/Resources/Assets.xcassets/Contents.json', json.dumps({'info':{'author':'xcode','version':1}},indent=2)+'\n')
seed('ASCEND/Resources/Assets.xcassets/AccentColor.colorset/Contents.json',json.dumps({'colors':[{'idiom':'universal','color':{'color-space':'srgb','components':{'red':'0.48','green':'0.50','blue':'1.0','alpha':'1.0'}}}], 'info':{'author':'xcode','version':1}},indent=2)+'\n')
seed('ASCEND/Resources/Assets.xcassets/AppIcon.appiconset/Contents.json',json.dumps({'images':[{'idiom':'universal','platform':'ios','size':'1024x1024'}], 'info':{'author':'xcode','version':1}},indent=2)+'\n')
for tier in ['bronze','silver','gold','platinum','diamond','conqueror']:
    for division in [1,2,3]:
        seed(f'ASCEND/Resources/Assets.xcassets/rank_{tier}_{division}.imageset/Contents.json',json.dumps({'images':[{'idiom':'universal'}], 'info':{'author':'xcode','version':1}},indent=2)+'\n')
seed('.gitignore','.DS_Store\n.build/\nDerivedData/\n*.xcuserstate\nxcuserdata/\n*.xcresult/\n.swiftpm/\nwork/\n')
# The same checked-in generator allows adding source files without requiring a project tool.
source = Path(__file__).read_text(encoding='utf-8')
source = source.replace("root = Path(r'C:\\Users\\karel\\Desktop\\GymApp')", "root = Path(__file__).resolve().parents[1]")
write('tools/generate_project.py',source)
print(f'Generated Xcode project: {len(sources)} app sources, {len(tests)} unit sources, {len(ui_tests)} UI sources, 18 badge slots')
