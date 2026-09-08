const fs = require('fs');
const path = require('path');
const binDir = path.join(__dirname, '..', 'node_modules', '.bin');
fs.mkdirSync(binDir, { recursive: true });
const target = path.join(__dirname, '..', 'bin', 'node-preamble.js');
const symlink = path.join(binDir, 'node-preamble');
try { fs.unlinkSync(symlink); } catch (e) {}
fs.symlinkSync(target, symlink);
fs.chmodSync(target, '755');
