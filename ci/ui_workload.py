"""Offline Qt workload for layout QA and reproducible QML Profiler captures.

Uses a temporary plugin copy and temporary preferences; never changes shell state.
"""
import argparse
import json
import os
from pathlib import Path
import shutil
import socket
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]
SHELL = Path(os.environ.get('FUTBAR_SHELL_ROOT', '/usr/share/omarchy/shell'))


def run(output, width=360, font_size=12, profile=False, history_count=3):
    output = Path(output).resolve()
    output.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix='futbar-ui-') as directory:
        work = Path(directory)
        shutil.copytree(ROOT / 'qml', work / 'qml')
        shutil.copytree(ROOT / 'lib', work / 'lib', ignore=shutil.ignore_patterns('__pycache__'))
        for name in ('Commons', 'Ui', 'services'):
            (work / name).symlink_to(SHELL / name, target_is_directory=True)
        panel = work / 'qml/panels/FutBarPanel.qml'
        panel.write_text(panel.read_text().replace('Quickshell.env("HOME") + "/.local/state/omarchy/futbar.json"', json.dumps(str(work / 'favorite.json'))).replace('["omarchy", "shell", "-q", "shell", "setBarWidget"', '["true", "shell", "-q", "shell", "setBarWidget"'))
        (work / 'favorite.json').write_text(json.dumps({'teamName': 'Fixture club', 'teamId': '83', 'league': 'esp.1', 'enableNotifications': False, 'antiSpoiler': False}))
        history = json.loads((ROOT / 'tests/fixtures/player-gamelog.json').read_text())
        if history_count > 3:
            seed = next(row for group in history['seasonTypes'] for cat in group['categories'] for row in cat['events'])
            event = history['events'][seed['eventId']]
            rows = []
            history['events'] = {}
            for i in range(min(200, history_count)):
                key = str(900000000+i)
                history['events'][key] = {**event, 'id': key}
                rows.append({**seed, 'eventId': key})
            history['seasonTypes'] = [{'categories': [{'events': rows}]}]
        (work / 'lib/history.json').write_text(json.dumps(history))
        (work / 'lib/fetch_json.py').write_text('''
import json,pathlib,sys
url=sys.argv[-1]
data={'events':[],'items':[],'sports':[],'leagues':[],'categories':[]}
if '/gamelog?' in url:
 data=json.loads(pathlib.Path(__file__).with_name('history.json').read_text())
elif '/news' in url:
 data={'articles':[{'headline':'Football headline '+str(i)+': a longer story to test wrapping and scaling','description':'A recorded-style summary for offline layout checks.','published':'2026-10-20','links':{'web':{'href':'https://www.espn.com/soccer/story/_/id/1'}}} for i in range(20)]}
elif '/athletes/123' in url:
 data.update({'id':'123','fullName':'Fixture player with a long display name','displayName':'Fixture player'})
print(json.dumps(data))
''')
        for name in ('fetch_image.py', 'fetch_photo.py'):
            (work / 'lib' / name).write_text('print("")\n')
        qml = '''
import QtQuick
import QtQuick.Window
import Quickshell
import qs.Commons
import "qml/panels"
import "qml/views"
import "qml/components"
ShellRoot {
 id: test
 property int phase: -1
 property bool failed: false
 property int buttonCount: 0
 property var standingRows: []
 FutBarPanel { id: panel; manageIpc: false }
 QtObject {id:newsContext;property bool opened:true;property bool antiSpoiler:false;property color contentForeground:"#e5e7eb";property string contentFontFamily:"DejaVu Sans"}
 function check(item) {
  if (!item.visible) return
  if (item.width < 0 || item.height < 0 || !isFinite(item.width) || !isFinite(item.height)) {
   console.error("UI_GEOMETRY_FAILURE", item, item.width, item.height); failed=true
  }
  if (item.tooltipText !== undefined && item.focusable !== undefined && typeof item.clicked === "function") {
   buttonCount++
   if (!item.focusable || !item.Accessible.name) {console.error("UI_FOCUS_FAILURE",item);failed=true}
  }
  for(var i=0;i<item.children.length;i++) check(item.children[i])
 }
 function prepare() {
  phase++
  panel.showTrending=false;panel.showStandings=false;panel.showStats=false;panel.showSettings=false;panel.showMatchDetail=false
  if(phase===0) {panel.openPlayerSearchDetail({id:"123",displayName:"Fixture player",subtitle:"Fixture club",image:"",webUrl:"",leagueSlug:"esp.1"});panel.searchPlayerCardTab="info"}
  if(phase===1) {
   panel.searchPlayerCardTab="matches"
   for(var i=0;i<profile.children.length;i++) if(profile.children[i].athleteId!==undefined) profile.children[i].active=true
  }
  if(phase===2) {panel.searchPlayerCardTab="stats";panel.ensurePlayerStats()}
  if(phase===3) {
   panel.selectedPlayerProfile=null;panel.showStandings=true
   var rows=[]
   for(var i=0;i<20;i++)rows.push({rank:i+1,teamId:String(i+1),name:"Fixture club with long name "+i,teamName:"Fixture club with long name "+i,teamAbbreviation:"FC",teamLogo:"",logo:"",stats:{gamesPlayed:"20",wins:"10",ties:"5",losses:"5",points:"35",goalsFor:"30",goalsAgainst:"20",pointDifferential:"10"}})
   standingRows=rows;panel.standingsGroups=[{name:"Fixture league",entries:rows}]
  }
  if(phase===4) {
   panel.showStats=true;var rows=[]
   for(var i=0;i<15;i++)rows.push({rank:i+1,id:String(i+1),name:"Fixture player with a long name "+i,teamName:"Fixture club",teamLogo:"",appearances:"20",value:"12"})
   panel.statsGoals=rows
  }
  if(phase===5) {panel.showTrending=true}
  if(phase===6) {panel.openMatchDetail({id:"123",competitionSlug:"esp.1",competitionName:"Fixture competition",started:true,state:"post",status:"FT",home:{name:"Fixture home",logo:"",score:"2"},away:{name:"Fixture away",logo:"",score:"1"}})}
  if(phase===7) {panel.showSettings=true}
  if(phase===8) {news.openArticle(news.articles[0])}
  if(phase===9) {
   checkTimer.stop()
   console.log("UI_WORKLOAD_PASS", "buttons", buttonCount)
   Qt.quit()
  }
 }
 Window {
  id: win
  visible:true;width:WIDTH;height:800;color:"#151820"
  Rectangle {
   id:surface;width:Math.min(parent.width,WIDTH);height:parent.height;anchors.horizontalCenter:parent.horizontalCenter;color:"#151820"
   Flickable {
   id: viewport;anchors.fill:parent;contentWidth:width;contentHeight:content.implicitHeight;clip:true
   Column {
    id: content;width:parent.width-24;x:12;spacing:12
    FutProfileView {id:profile;root:panel;visible:test.phase<3}
    FutStandingsView {id:standings;root:panel}
    FutStatsView {root:panel}
    FutTrendingView {root:panel}
    FutNewsView {id:news;root:newsContext;visible:test.phase===5 || test.phase===8}
    MatchDetailView {root:panel}
    FutSettingsView {root:panel}
   }
   }
  }

 }
 Timer {interval:700;running:true;onTriggered:{Style.fontBaseSize=FONT;Style.fontFamily="DejaVu Sans";test.prepare();checkTimer.start()}}
 Timer {
  id:checkTimer;interval:650;repeat:true
  onTriggered:{
   if(test.phase===3)panel.standingsGroups=[{name:"Fixture league",entries:test.standingRows}]
   test.check(content)
   if(test.phase===3 && standings.standingsTeamWidth<30){console.error("UI_TEAM_WIDTH_FAILURE",standings.standingsTeamWidth);test.failed=true}
   if(test.failed){Qt.quit();return}
   viewport.contentY=0
   surface.grabToImage(function(image){image.saveToFile(OUTPUT+"/stage-"+test.phase+".png");test.prepare()})
  }
 }
 Timer {interval:12000;running:true;onTriggered:{console.error("UI_WORKLOAD_TIMEOUT");Qt.quit()}}
}
'''.replace('WIDTH', str(width)).replace('FONT', str(font_size)).replace('OUTPUT', json.dumps(str(output)))
        (work / 'shell.qml').write_text(qml)
        command = ['quickshell', '--no-color', '-p', str(work / 'shell.qml')]
        environment = {**os.environ, 'QT_QPA_PLATFORM': 'wayland' if os.environ.get('WAYLAND_DISPLAY') else 'offscreen', 'QT_QUICK_BACKEND': 'software'}
        profiler = None
        if profile:
            with socket.socket() as port_socket:
                port_socket.bind(('127.0.0.1', 0))
                port = port_socket.getsockname()[1]
            command += ['--debug', str(port), '--waitfordebug']
        process = subprocess.Popen(command, env=environment, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)
        try:
            if profile:
                profiler = subprocess.Popen([shutil.which('qmlprofiler') or '/usr/lib/qt6/bin/qmlprofiler', '--attach', '127.0.0.1', '--port', str(port), '--output', str(output / 'trace.qtd')], stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)
            try:
                logs, _ = process.communicate(timeout=20)
            except subprocess.TimeoutExpired:
                process.kill()
                logs, _ = process.communicate()
                (output / 'runtime.log').write_text(logs)
                raise RuntimeError(logs)
            if profiler:
                profile_logs, _ = profiler.communicate(timeout=10)
                (output / 'profiler.log').write_text(profile_logs)
        finally:
            if process.poll() is None:
                process.kill(); process.wait()
            if profiler and profiler.poll() is None:
                profiler.kill(); profiler.wait()
        (output / 'runtime.log').write_text(logs)
        errors = ('ReferenceError', 'TypeError', 'Binding loop', 'FAILURE', 'FAIL!', 'UI_WORKLOAD_TIMEOUT', 'Error loading')
        if 'UI_WORKLOAD_PASS' not in logs or any(error in logs for error in errors):
            raise RuntimeError(logs)
        print(logs)


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', required=True)
    parser.add_argument('--width', type=int, default=360)
    parser.add_argument('--font-size', type=int, default=12)
    parser.add_argument('--profile', action='store_true')
    parser.add_argument('--history-count', type=int, default=3)
    args = parser.parse_args()
    run(args.output, args.width, args.font_size, args.profile, args.history_count)
