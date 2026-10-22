const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
const path = require('node:path');
const data = vm.createContext({});
vm.runInContext(fs.readFileSync(path.join(__dirname, '../qml/data/FutData.js'), 'utf8').replace(/^\.pragma library\s*/, ''), data);

// Reject oversized input before the quadratic collision solver does any work.
data.players = Array.from({length: 5000}, () => ({name: 'Player'}));
vm.runInContext('result = layoutPitchPlayers(players)', data, {timeout: 200});
assert.equal(data.result.length, 0);
for (const invalid of [null, 'wrong', {length: 1e30}]) {
  assert.equal(data.layoutPitchPlayers(invalid).length, 0);
}
const normal = Array.from({length: 11}, (_, i) => ({name: 'Player ' + i, formationPlace: i + 1}));
const placed = data.layoutPitchPlayers(normal);
assert.equal(placed.length, 11);
assert.ok(placed.every(p => Number.isFinite(p.x) && Number.isFinite(p.y)));
assert.equal(data.layoutPitchPlayers([null, ...normal.slice(0, 10)]).length, 10);

for (const [input, expected] of [[0.86, '86%'], ['86%', '86%'], [86, '86%'], [0, '0%'], ['0%', '0%'], [1, '100%'], ['1%', '1%']]) {
  assert.equal(data.formatPassPercentage(input), expected);
  const stats = Object.freeze({passPct: input, appearances: '10'});
  const first = data.applySingleStatMap({}, stats, '2026');
  const second = data.applySingleStatMap(first, stats, '2026');
  const fromFormatted = data.applySingleStatMap(first, first.seasonStatMap, '2026');
  assert.equal(second.seasonPassPct, expected);
  assert.equal(fromFormatted.seasonPassPct, expected);
  assert.equal(stats.passPct, input);
}
for (const invalid of [null, undefined, '', 'NaN', 'Infinity', '86junk', -1, 101, {}, []]) {
  assert.equal(data.formatPassPercentage(invalid), '');
}
assert.deepEqual(Array.from(data.formatGroupedScorers([
  {name: 'constructor', clock: '10'}, {name: '__proto__', clock: '20'}, {name: 'toString', clock: '30'}
])), ["constructor 10'", "__proto__ 20'", "toString 30'"]);
console.log('PASS: bounded pitch layout, stable pass percentages and prototype-safe scorer names');

for (const note of ['Club win 5–4 on penalties', 'Club win on penalties (5-4)']) {
  const score = data.penaltyScore(note);
  assert.equal(score[1], '5'); assert.equal(score[2], '4');
}
data.note = '9'.repeat(65536);
vm.runInContext('for (var i = 0; i < 1000; i++) penaltyScore(note)', data, {timeout: 200});
assert.equal(data.penaltyScore(data.note), null);

const oldRow = {id: '1', state: 'post', homeScore: '1', awayScore: '0', homeName: 'Old', homeLogo: 'old.png', seriesNote: ''};
const original = [oldRow];
assert.equal(data.mergeRows(original, [{...oldRow}]), original);
for (const key of ['homeName', 'homeLogo', 'seriesNote', 'competitionName', 'kickoff']) {
  const incoming = {...oldRow, [key]: 'updated'};
  const merged = data.mergeRows(original, [incoming]);
  assert.equal(merged[0], incoming);
  assert.equal(merged[0][key], 'updated');
}
console.log('PASS: bounded penalty parsing and corrected fixture presentation refresh');
