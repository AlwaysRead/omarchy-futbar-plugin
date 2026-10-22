const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
const path = require('node:path');

// Execute the actual QML callback with a deadline: the reported payload must
// produce a recoverable error, preserve the prior table, and release loading.
const panel = fs.readFileSync(path.join(__dirname, '../qml/panels/FutBarPanel.qml'), 'utf8');
const request = panel.slice(panel.indexOf('id: internalStandingsRequest'));
const start = request.indexOf('onStreamFinished: {') + 'onStreamFinished: {'.length;
const end = request.indexOf('\n      }\n    }\n    stderr:', start);
assert.ok(start > 0 && end > start);
const script = new vm.Script('(function() {' + request.slice(start, end) + '\n})()');
function run(data) {
  const root = {
    standingsLoading: true, standingsError: '', standingsGroups: ['previous'],
    leagueMode: true, league: 'eng.1', standingsSeasonOffset: 0,
    safeIdentifier: String, sanitizePlainText: String, sanitizeImageUrl: String,
    recordNetworkSuccess() { this.success = true; }
  };
  script.runInNewContext({root, text: JSON.stringify(data), internalStandingsRequest: {responseCurrent: true}}, {timeout: 200});
  assert.equal(root.standingsLoading, false);
  return root;
}
const entry = {team: {id: '1', displayName: 'Club'}, stats: [{name: 'points', displayValue: '42'}]};
const valid = entries => ({children: [{name: 'League', standings: {entries}}]});
for (const bad of [{length: 1e30}, 'wrong', null, 42]) {
  for (const payload of [{children: bad}, {children: [{standings: {entries: bad}}]}, valid([{...entry, stats: bad}])]) {
    const result = run(payload);
    assert.equal(result.standingsError, 'Could not parse standings');
    assert.deepEqual(result.standingsGroups, ['previous']);
    assert.equal(result.success, undefined);
  }
}
for (const payload of [{children: [null]}, valid([null])]) {
  assert.equal(run(payload).standingsError, 'Could not parse standings');
}
const result = run(valid([entry]));
assert.equal(result.standingsError, '');
assert.equal(result.success, true);
assert.equal(result.standingsGroups[0].entries[0].stats.points, '42');
assert.equal(result.standingsGroups[0].entries[0].teamName, 'Club');
assert.equal(run({children: []}).standingsGroups.length, 0);
assert.equal(run(valid([{team: {id: '2'}}])).standingsGroups[0].entries.length, 1);
console.log('PASS: standings rejects array impostors without blocking or replacing prior data');
