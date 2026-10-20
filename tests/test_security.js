const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
const path = require('node:path');
function load(name) {
  const context = vm.createContext({});
  vm.runInContext(fs.readFileSync(path.join(__dirname, '..', name), 'utf8').replace(/^\.pragma library\s*/, ''), context);
  return context;
}
const network = load('FutNetwork.js');
assert.equal(network.safeProfileUrl('https://www.espn.com/soccer/player/_/id/1'), 'https://www.espn.com/soccer/player/_/id/1');
for (const url of ['javascript:alert(1)', 'file:///etc/passwd', 'https://evil.test/', 'https://espn.com.evil.test/', 'https://espn.com@evil.test/', 'https://espn.com/\n', 'https://espn.com/"']) {
  assert.equal(network.safeProfileUrl(url), '');
}
network.Qt = {resolvedUrl: name => 'file:///trusted/repo/' + name};
const payload = ["https://example.test/$(touch /tmp/should-not-run);'\""];
const command = network.statsCommand('club', payload);
assert.equal(command[0], 'python3');
assert.ok(!command.includes('-c'));
assert.equal(command[command.length - 1], JSON.stringify(payload));
const cache = load('FutImageCache.js');
for (let i = 0; i < 4; i++) assert.equal(cache.acquire(), true);
assert.equal(cache.acquire(), false);
for (let i = 0; i < 4; i++) cache.release();
assert.equal(cache.active, 0);
for (let i = 0; i < 150; i++) cache.remember('https://example/' + i, 'image');
assert.equal(cache.order.length, 128);
assert.equal(cache.lookup('https://example/0'), undefined);
for (let i = 0; i < 20; i++) cache.remember('https://example/big' + i, 'x'.repeat(700000));
assert.ok(cache.bytes <= 8 * 1024 * 1024);
cache.remember('https://example/update', 'first');
cache.remember('https://example/update', 'second');
assert.equal(cache.lookup('https://example/update'), 'second');
console.log('PASS: profile URL restrictions, concurrency cap, cache eviction and replacement');
