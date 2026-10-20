"""Keep profile navigation and request completion working after controller extraction."""
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest
ROOT=Path(__file__).resolve().parents[1]
SHELL=Path(os.environ.get('FUTBAR_SHELL_ROOT','/usr/share/omarchy/shell'))


@unittest.skipUnless(shutil.which('quickshell') and os.environ.get('WAYLAND_DISPLAY') and (SHELL/'Ui').is_dir(),'Omarchy runtime is required')
class ProfileRuntimeTests(unittest.TestCase):
    def test_player_then_club_profiles_complete(self):
        with tempfile.TemporaryDirectory(prefix='futbar-profile-test-') as directory:
            work=Path(directory); plugin=work/'plugin'
            shutil.copytree(ROOT/'qml',plugin/'qml')
            shutil.copytree(ROOT/'lib',plugin/'lib',ignore=shutil.ignore_patterns('__pycache__'))
            for name in ('Commons','Ui','services'):
                (work/name).symlink_to(SHELL/name,target_is_directory=True)
            panel=plugin/'qml/panels/FutBarPanel.qml'
            panel.write_text(panel.read_text().replace('Quickshell.env("HOME") + "/.local/state/omarchy/futbar.json"',json.dumps(str(work/'favorite.json'))))
            panel.write_text(panel.read_text().replace('["omarchy", "shell", "-q", "shell", "setBarWidget"','["true", "shell", "-q", "shell", "setBarWidget"'))
            (work/'favorite.json').write_text(json.dumps({'teamName':'Fixture club','teamId':'83','league':'esp.1','antiSpoiler':True,'enableNotifications':False}))
            (plugin/'lib/fetch_json.py').write_text('''
import json,sys,time
url=sys.argv[-1]
time.sleep(.05)
data={'events':[],'items':[],'sports':[],'leagues':[],'categories':[]}
if '/standings?' in url:
 data={'children':[{'name':'Fixture league','standings':{'entries':[{'team':{'id':'83','displayName':'Fixture club'},'stats':[{'name':'rank','value':1},{'name':'points','value':35}]}]}}]}
if '/athletes/123' in url:
 data.update({'id':'123','fullName':'Fixture player','displayName':'Fixture player'})
if '/athletes/456' in url:
 data.update({'id':'456','fullName':'Second player','displayName':'Second player'})
if '/teams/83' in url:
 data.update({'team':{'id':'83','displayName':'Fixture club','record':{'items':[]}}})
print(json.dumps(data))
''')
            for helper in ('fetch_image.py','fetch_photo.py'):
                (plugin/'lib'/helper).write_text('print("")\n')
            (work/'shell.qml').write_text('''
import QtQuick
import Quickshell
import "plugin/qml/panels"
ShellRoot {
 id: test
 property int phase: 0
 property int ticks: 0
 FutBarPanel { id: panel; manageIpc: false }
 Timer {
  interval: 50; running: true; repeat: true
  onTriggered: {
   test.ticks++
   if (test.ticks>100) { console.error("PROFILE_TIMEOUT",test.phase,panel._clubFetchPending); Qt.quit() }
   if (test.phase === 0 && test.ticks > 2) {
    panel.openPlayerSearchDetail({id:"123",displayName:"Initial player",subtitle:"",leagueSlug:"esp.1",image:"",webUrl:""})
    test.phase=1
   } else if (test.phase===1 && !panel.searchPlayerLoading && panel.selectedPlayerProfile && panel.selectedPlayerProfile.fullName === "Fixture player") {
    var first=Object.assign({},panel.selectedPlayerProfile)
    first.availableSeasons=[{seasonYear:2026,competitions:[{league:"esp.1"}]}]
    first.seasonGoals="5";panel.selectedPlayerProfile=first;panel.searchPlayerStatsTab="tournament"
    panel.pinComparison()
    if(panel.comparisonProfiles.length!==1 || panel.comparisonProfiles[0].id!=="123") {console.error("FIRST_PIN_FAILURE");Qt.quit();return}
    panel.openPlayerSearchDetail({id:"456",displayName:"Second player",subtitle:"",leagueSlug:"esp.1",image:"",webUrl:""})
    test.phase=10
   } else if(test.phase===10 && !panel.searchPlayerLoading && panel.selectedPlayerProfile && panel.selectedPlayerProfile.fullName==="Second player") {
    var second=Object.assign({},panel.selectedPlayerProfile)
    second.availableSeasons=[{seasonYear:2026,competitions:[{league:"esp.1"}]}]
    second.seasonGoals="7";panel.selectedPlayerProfile=second;panel.searchPlayerStatsTab="tournament"
    panel.pinComparison()
    if(panel.comparisonProfiles.length!==2 || panel.comparisonProfiles[0].id!=="123" || panel.comparisonProfiles[1].id!=="456") {console.error("SECOND_PIN_FAILURE");Qt.quit();return}
    panel.pinComparison()
    if(panel.comparisonProfiles.length!==2 || panel.comparisonProfiles[0].id!=="123") {console.error("UPDATE_PIN_FAILURE");Qt.quit();return}
    panel.removeComparison("player","123")
    if(panel.comparisonProfiles.length!==1 || panel.comparisonProfiles[0].id!=="456") {console.error("REMOVE_PIN_FAILURE");Qt.quit();return}
    panel.openClubSearchDetail({id:"83",displayName:"Initial club",subtitle:"La Liga",leagueSlug:"esp.1",image:"",webUrl:""})
    test.phase=2
   } else if (test.phase===2 && !panel.searchClubLoading && panel.selectedClubProfile && panel.selectedClubProfile.displayName === "Fixture club") {
    if (panel._clubFetchPending !== 0) { console.error("PROFILE_PENDING_FAILURE"); Qt.quit(); return }
    if (!panel.spoilerGuardActive) { console.error("SPOILER_GUARD_FAILURE"); Qt.quit(); return }
    panel.spoilerSessionRevealed = true
    if (panel.spoilerGuardActive || !panel.antiSpoiler) { console.error("SPOILER_SESSION_FAILURE"); Qt.quit(); return }
    panel.setSettingValue("reducedMotion",true)
    if (!panel.reducedMotion) { console.error("PREFERENCE_WRITE_FAILURE"); Qt.quit(); return }
    panel.restoreSettings(JSON.stringify({format:"futbar-settings",version:1,settings:{density:"compact",reducedMotion:false,enableNotifications:false}}))
    if (panel.reducedMotion || panel.density !== "compact") { console.error("PREFERENCE_RESTORE_FAILURE"); Qt.quit(); return }
    panel.savedFavorite={teamName:"Fixture club",teamId:"83",league:"esp.1",enableNotifications:false}
    panel.needsTeam=false
    panel.loadStandings(true)
    if (!panel.standingsRequest.running) {console.error("STANDINGS_START_FAILURE",panel.needsTeam,panel.league,JSON.stringify(panel.standingsRequest.command));Qt.quit();return}
    test.phase=3
   } else if(test.phase===3 && !panel.standingsLoading && panel.standings.length===1) {
    if(panel.standings[0].teamName!=="Fixture club") {console.error("STANDINGS_DATA_FAILURE");Qt.quit();return}
    panel._lastStandingsKey=panel.league+"|"+String(panel.standingsSeasonOffset)
    panel.loadStandings(true)
    if(panel.standings.length!==1) {console.error("STANDINGS_CACHE_FAILURE");Qt.quit();return}
    console.log("PROFILE_PASS"); Qt.quit()
   }
  }
 }
}
''')
            result=subprocess.run(['quickshell','--no-color','-p',str(work/'shell.qml')],env={**os.environ,'QT_QPA_PLATFORM':'wayland'},capture_output=True,text=True,timeout=15)
            output=result.stdout+result.stderr
            self.assertIn('PROFILE_PASS',output,output)
            for failure in ('ReferenceError','TypeError','FAILURE','Binding loop'):
                self.assertNotIn(failure,output,output)
