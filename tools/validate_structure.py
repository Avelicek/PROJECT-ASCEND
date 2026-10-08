#!/usr/bin/env python3
"""Static wiring checks only. Does not parse/typecheck/compile Swift or run XCTest."""
from pathlib import Path
import json, plistlib, re, sys, xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[1]
CHECKS = []
def check(condition, message):
    if not condition: raise AssertionError(message)
    CHECKS.append(message)

def parse_openstep(text):
    text=re.sub(r'/\*.*?\*/', '', text, flags=re.S)
    tokens=re.findall(r'"(?:\\.|[^"\\])*"|//[^\n]*|[{}()=;,]|[^\s{}()=;,]+',text)
    tokens=[token for token in tokens if not token.startswith('//')]
    cursor=0
    def take():
        nonlocal cursor
        token=tokens[cursor]; cursor+=1; return token
    def expect(value):
        actual=take()
        if actual != value: raise AssertionError(f'Expected {value}, got {actual}')
    def value():
        token=take()
        if token == '{':
            output={}
            while tokens[cursor] != '}':
                key=take()
                if key.startswith('"'): key=json.loads(key)
                expect('='); item=value(); expect(';')
                if key in output: raise AssertionError(f'Duplicate project key {key}')
                output[key]=item
            expect('}'); return output
        if token == '(':
            output=[]
            while tokens[cursor] != ')':
                output.append(value())
                if tokens[cursor] == ',': take()
            expect(')'); return output
        return json.loads(token) if token.startswith('"') else token
    result=value()
    check(cursor == len(tokens),'OpenStep project token stream consumed')
    return result

project=parse_openstep((ROOT/'ASCEND.xcodeproj/project.pbxproj').read_text(encoding='utf8'))
objects=project['objects']
check(project['rootObject'] in objects,'Project root object resolves')
check(len(objects) == len(set(objects)),'Project object IDs are unique')
for identifier, obj in objects.items():
    for key in ['fileRef','buildConfigurationList','mainGroup','productRefGroup','productReference','containerPortal','target','targetProxy','remoteGlobalIDString']:
        if key in obj: check(obj[key] in objects,f'{identifier}: {key} resolves')
    for key in ['children','files','buildPhases','buildConfigurations','dependencies','targets']:
        for reference in obj.get(key,[]): check(reference in objects,f'{identifier}: {key} reference resolves')
file_refs={obj['path']:identifier for identifier,obj in objects.items() if obj['isa']=='PBXFileReference' and obj.get('sourceTree')=='SOURCE_ROOT'}
for path in file_refs: check((ROOT/path).exists(),f'Project file exists: {path}')
actual_sources={str(path.relative_to(ROOT)).replace('\\','/') for folder in ['ASCEND','Tests','WidgetExtension'] for path in (ROOT/folder).rglob('*.swift')}
check(actual_sources == {path for path in file_refs if path.endswith('.swift')},'All Swift sources referenced exactly once')
targets={obj['name']:obj for obj in objects.values() if obj['isa']=='PBXNativeTarget'}
check(set(targets)=={'ASCEND','ASCENDTests','ASCENDUITests','AscendRestWidget'},'Application, hosted unit-test and UI-test targets exist')
check(targets['ASCENDUITests']['productType']=='com.apple.product-type.bundle.ui-testing','UI target has the XCUITest product type')
for target, prefix in [('ASCEND','ASCEND/'),('ASCENDTests','Tests/'),('ASCENDUITests','Tests/UI/')]:
    source_phase=[objects[phase] for phase in targets[target]['buildPhases'] if objects[phase]['isa']=='PBXSourcesBuildPhase']
    check(len(source_phase)==1,f'{target}: one source build phase')
    wired={objects[objects[entry]['fileRef']]['path'] for entry in source_phase[0]['files']}
    check(wired == {path for path in actual_sources if path.startswith(prefix) and (target != 'ASCENDTests' or not path.startswith('Tests/UI/'))},f'{target}: source build phase is complete')
widget_phase = [objects[phase] for phase in targets['AscendRestWidget']['buildPhases'] if objects[phase]['isa']=='PBXSourcesBuildPhase'][0]
widget_wired = {objects[objects[entry]['fileRef']]['path'] for entry in widget_phase['files']}
check(widget_wired == {'WidgetExtension/AscendRestWidget.swift', 'ASCEND/LiveActivity/RestActivityAttributes.swift'}, 'Live Activity extension shares its attributes and includes its WidgetBundle')
check(any(objects[phase]['isa']=='PBXCopyFilesBuildPhase' for phase in targets['ASCEND']['buildPhases']), 'Live Activity extension embedded in app')
for scheme in (ROOT/'ASCEND.xcodeproj/xcshareddata/xcschemes').glob('*.xcscheme'):
    xml=ET.parse(scheme)
    for ref in xml.findall('.//BuildableReference'): check(ref.attrib['BlueprintIdentifier'] in objects,f'{scheme.name}: buildable resolves')
    args=xml.findall('.//CommandLineArgument')
    check(any(arg.attrib.get('argument')=='--demo' for arg in args)==('Demo' in scheme.name),f'{scheme.name}: demo argument isolation')
    check({ref.attrib['BlueprintName'] for ref in xml.findall('.//TestableReference/BuildableReference')}=={'ASCENDTests','ASCENDUITests'},f'{scheme.name}: unit and UI targets are testable')
    check(xml.find('TestAction').attrib['shouldUseLaunchSchemeArgsEnv']=='NO',f'{scheme.name}: hosted tests do not inherit demo launch arguments')
ET.parse(ROOT/'ASCEND.xcodeproj/project.xcworkspace/contents.xcworkspacedata')
info=plistlib.loads((ROOT/'ASCEND/Resources/Info.plist').read_bytes())
check(info['LSRequiresIPhoneOS'] is True,'Info.plist is an iPhone application manifest')
configs=[obj['buildSettings'] for obj in objects.values() if obj['isa']=='XCBuildConfiguration']
check(any(config.get('IPHONEOS_DEPLOYMENT_TARGET')=='27.0' for config in configs),'Deployment target is iOS 27')

expected=[100,150,250,350,450,550,650,750,850,950,1050,1200,1350,1500,1700,2000,2150,2400]
rank_source=(ROOT/'ASCEND/Core/Domain/RankEngine.swift').read_text(encoding='utf8')
thresholds=[int(value) for value in re.findall(r'Rank\(tier: \.\w+, division: \d, threshold: (\d+)\)',rank_source)]
check(thresholds == [0]+expected,'Every specified rank threshold matches exactly')
assets=ROOT/'ASCEND/Resources/Assets.xcassets'
expected_names={f'rank_{tier}_{division}.imageset' for tier in ['bronze','silver','gold','platinum','diamond','conqueror'] for division in [1,2,3]}
check({path.name for path in assets.glob('rank_*.imageset')}==expected_names,'Exactly 18 stable rank asset names')
for asset in assets.rglob('Contents.json'):
    data=json.loads(asset.read_text(encoding='utf8'))
    check(data['info']['version']==1,f'Valid asset metadata: {asset.parent.name}')
    for image in data.get('images',[]):
        if image.get('filename'): check((asset.parent/image['filename']).exists(),f'Artwork resolves: {image["filename"]}')

models={match for path in (ROOT/'ASCEND/Core/Persistence').glob('*.swift') for match in re.findall(r'@Model final class (\w+)',path.read_text(encoding='utf8'))}
expected_models={'UserProfile','BodyWeightEntry','NutritionEntry','SleepEntry','Exercise','WorkoutSession','WorkoutExercise','WorkoutSet','DailyObjective','DailyObjectiveCompletion','DailyEvaluation','ELOHistoryEntry','PersonalRecord','MuscleState','BrainInsightRecord','UserSettings'}
# The user lists sixteen concrete names; all are present in the versioned schema.
check(models==expected_models,'All requested SwiftData entities are present')
schema=(ROOT/'ASCEND/Core/Persistence/PersistenceController.swift').read_text(encoding='utf8')
for name in models: check(name+'.self' in schema,f'{name} registered in schema')
check('cloudKitDatabase: .none' in schema,'CloudKit disabled explicitly')
all_app='\n'.join(path.read_text(encoding='utf8') for path in (ROOT/'ASCEND').rglob('*.swift'))
for prohibited in ['fatalError(', 'URLSession', 'import HealthKit', 'import CloudKit']:
    check(prohibited not in all_app,f'No prohibited normal app path: {prohibited}')
app=(ROOT/'ASCEND/App/AscendApp.swift').read_text(encoding='utf8')
check('#if DEBUG' in app and 'var memoryOnly = demo' in app and 'inMemory: memoryOnly' in app and 'demo = false' in app,'Demo data is Debug-only and memory-only at launch')
package=(ROOT/'Package.swift').read_text(encoding='utf8')
check('path: "ASCEND/Core/Domain"' in package and 'path: "Tests/Core"' in package,'Swift package targets independent domain and core tests')
for path in (ROOT/'ASCEND/Core/Domain').glob('*.swift'):
    imports=set(re.findall(r'^import\s+(\w+)', path.read_text(encoding='utf8'), re.M))
    check(imports <= {'Foundation'},f'Core imports only portable Foundation: {path.name}')
for destination in ['dashboard','workout','recovery','progress','profile']:
    check(f'accessibilityIdentifier("screen.{destination}")' in all_app,f'{destination}: primary screen identifier exists')
check('accessibilityIdentifier("tab.\\(item.rawValue)")' in all_app,'Five tab identifiers derive from destination names')
test_count=sum(len(re.findall(r'func test\w+',path.read_text(encoding='utf8'))) for path in (ROOT/'Tests').rglob('*.swift'))
check(test_count >= 35,'Meaningful engine and persistence test cases authored')

summary={
    'verification':'STATIC STRUCTURE ONLY — no Swift compiler, Xcode build, XCTest or runtime verification',
    'checks_passed':len(CHECKS),'app_swift_files':len([x for x in actual_sources if x.startswith('ASCEND/')]),
    'test_swift_files':len([x for x in actual_sources if x.startswith('Tests/')]),'test_methods_authored':test_count,
    'swiftdata_entities':len(models),'rank_asset_slots':len(expected_names),'core_dependencies':0,
}
print(json.dumps(summary,indent=2))
if len(sys.argv)>1:
    Path(sys.argv[1]).write_text(json.dumps(summary,indent=2)+'\n',encoding='utf8')
