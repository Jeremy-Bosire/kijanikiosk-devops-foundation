'use strict';

// Produces dist/: the runtime code plus a build-info.json stamp that ties
// the package back to the exact commit and pipeline run that produced it.

const fs = require('node:fs');
const path = require('node:path');

const root = path.resolve(__dirname, '..');
const src = path.join(root, 'source');
const dist = path.join(root, 'dist');
const pkg = require(path.join(root, 'package.json'));

fs.rmSync(dist, { recursive: true, force: true });
fs.mkdirSync(dist, { recursive: true });

for (const file of fs.readdirSync(src)) {
  fs.copyFileSync(path.join(src, file), path.join(dist, file));
}

const buildInfo = {
  name: pkg.name,
  version: pkg.version,
  gitCommit: process.env.GIT_COMMIT || 'local',
  buildNumber: process.env.BUILD_NUMBER || 'local',
  builtAt: new Date().toISOString(),
};
fs.writeFileSync(path.join(dist, 'build-info.json'), JSON.stringify(buildInfo, null, 2) + '\n');

console.log(`Built ${pkg.name}@${pkg.version} -> dist/ (${fs.readdirSync(dist).length} files)`);
