const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
const path = require('node:path');
const extras = vm.createContext({});
vm.runInContext(fs.readFileSync(path.join(__dirname, '../qml/data/FutExtras.js'), 'utf8').replace(/^\.pragma library\s*/, ''), extras);
const article = {headline: '<b>Headline</b>', published: '2026-10-20', links: {web: {href: 'https://www.espn.com/soccer/story/_/id/1'}}, categories: [{type: 'team', teamId: 364}, {type: 'topic', description: 'soccer transfers'}]};
assert.equal(extras.news({articles: [article, article]}, []).length, 1);
assert.equal(extras.news({articles: [article]}, ['364'])[0].transfer, true);
assert.equal(extras.news({articles: [article]}, ['1']).length, 0);
assert.equal(extras.news({articles: [null, {headline: 'bad', links: {web: {href: 'javascript:alert(1)'}}}]}, []).length, 0);
assert.equal(extras.news({articles: 'wrong'}, []).length, 0);
assert.equal(extras.news({articles: [article]}, [])[0].title, '<b>Headline</b>'); // rendered PlainText
for (const url of ['file:///tmp/x', 'https://www.espn.com.evil.test/x', 'https://www.espn.com/\nx', 'https://www.espn.com@evil.test/x', 'https://watch.auth.api.espn.com/stream']) assert.equal(extras.webLink(url), '');
const clip = {headline: 'Analysis', duration: 90, links: {web: {href: 'https://www.espn.com/video/clip/_/id/2'}}};
assert.equal(extras.videos({videos: [clip, clip, null]}).length, 1);
assert.equal(extras.videos({videos: [{headline: 'stream only', links: {source: {href: 'https://www.espn.com/x'}}}]}).length, 0);
const log = {names: ['totalGoals', 'goalAssists'], labels: ['G', 'A'], events: {'123': {gameDate: '2026-10-17', opponent: {displayName: 'Opponent'}, links: [{rel: ['summary'], href: 'https://www.espn.com/football/match/_/gameId/123'}]}}, seasonTypes: [{displayName: 'League', categories: [{events: [{eventId: '123', stats: ['0']}]}]}]};
const row = extras.gameLog(log)[0];
assert.equal(row.opponent, 'Opponent');
assert.equal(row.stats.length, 1); // missing assists are not fabricated as zero
assert.equal(row.stats[0].name, 'totalGoals');
assert.equal(row.stats[0].value, '0');
log.seasonTypes[0].categories[0].events.push({eventId: '123', stats: ['2', '3']});
assert.equal(extras.gameLog(log).length, 1);
log.seasonTypes[0].categories[0].events = Array.from({length: 150}, (_, i) => ({eventId: String(i + 1), stats: ['1']}));
assert.equal(extras.gameLog(log).length, 100);
for (const input of [null, {}, {names: 'invalid'}, {names: [], seasonTypes: [null, {}]}]) assert.equal(extras.gameLog(input).length, 0);
console.log('PASS: ESPN news filtering, safe video links, game-log mapping, missing data and bounds');
