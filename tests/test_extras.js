const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
const path = require('node:path');
const extras = vm.createContext({});
vm.runInContext(fs.readFileSync(path.join(__dirname, '../qml/data/FutExtras.js'), 'utf8').replace(/^\.pragma library\s*/, ''), extras);
const article = {headline: '<b>Headline</b>', published: '2026-10-20', links: {web: {href: 'https://www.espn.com/soccer/story/_/id/1'}}, categories: [{type: 'team', teamId: 364}, {type: 'topic', description: 'soccer transfers'}]};
assert.equal(extras.news({articles: [article, article]}).length, 1);
assert.equal(extras.news({articles: [article]})[0].transfer, true);
assert.equal(extras.news({articles: [null, {headline: 'bad', links: {web: {href: 'javascript:alert(1)'}}}]}).length, 0);
assert.equal(extras.news({articles: 'wrong'}).length, 0);
assert.equal(extras.news({articles: [article]})[0].title, '<b>Headline</b>'); // rendered PlainText
for (const url of ['file:///tmp/x', 'https://www.espn.com.evil.test/x', 'https://www.espn.com/\nx', 'https://www.espn.com@evil.test/x', 'https://watch.auth.api.espn.com/stream']) assert.equal(extras.webLink(url), '');
const withImage = Object.assign({}, article, {description: 'Story summary', images: [{url: 'https://evil.test/image.jpg'}, {url: 'https://a.espncdn.com/photo/example.jpg', credit: 'Photographer'}]});
assert.equal(extras.news({articles: [withImage]})[0].image, 'https://a.espncdn.com/photo/example.jpg');
assert.equal(extras.news({articles: [withImage]})[0].description, 'Story summary');
for (const url of ['http://a.espncdn.com/x', 'https://a.espncdn.com.evil.test/x', 'https://a.espncdn.com@evil.test/x', 'file:///x']) assert.equal(extras.imageLink(url), '');
console.log('PASS: news parsing, bounded summaries and image URL restrictions');
