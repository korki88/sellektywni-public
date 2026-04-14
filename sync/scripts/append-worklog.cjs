'use strict';
const fs = require('fs');
const path = require('path');
const msg = process.argv.slice(2).join(' ').trim() || '(empty message)';
const log = path.join(__dirname, '..', 'WORKLOG.md');
const utc = new Date().toISOString().replace('T', ' ').slice(0, 19);
const block = `\n## ${utc} UTC (auto)\n\n- ${msg}\n`;
fs.appendFileSync(log, block, 'utf8');
console.log('[sync/log] Appended to WORKLOG.md');
