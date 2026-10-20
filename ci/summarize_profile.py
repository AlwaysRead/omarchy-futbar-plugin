"""Summarize a Qt QML Profiler XML capture without counting nested times as wall time."""
import collections
import json
from pathlib import Path
import sys
import xml.etree.ElementTree as ET


def summarize(path):
    root=ET.parse(path).getroot()
    events={event.attrib['index']:event for event in root.find('eventData')}
    counts=collections.Counter()
    durations=collections.Counter()
    longest=collections.Counter()
    unfinished=0
    hotspots=[]
    for record in root.find('profilerDataModel'):
        event=events.get(record.attrib.get('eventIndex'))
        if event is None:
            continue
        kind=event.findtext('type')
        duration=int(record.attrib.get('duration',0))
        if duration < 0:
            unfinished+=1
            continue
        counts[kind]+=1
        durations[kind]+=duration
        longest[kind]=max(longest[kind],duration)
        if kind in ('Binding','Javascript','HandlingSignal') and duration>0:
            hotspots.append({'kind':kind,'duration_ms':round(duration/1e6,3),'file':Path(event.findtext('filename') or '').name,'line':event.findtext('line'),'details':(event.findtext('details') or '')[:200]})
    return {'wall_seconds':round((int(root.attrib['traceEnd'])-int(root.attrib['traceStart']))/1e9,3),
            'unfinished_records_excluded':unfinished,
            'types':{kind:{'count':counts[kind],'inclusive_total_ms':round(durations[kind]/1e6,3),'longest_ms':round(longest[kind]/1e6,3)} for kind in counts if durations[kind]},
            'longest_handlers':sorted(hotspots,key=lambda r:r['duration_ms'],reverse=True)[:10]}


if __name__=='__main__':
    print(json.dumps(summarize(sys.argv[1]),indent=2))
