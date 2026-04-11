/**
 * Odświeża statyczny podgląd WWW: build Flutter Web → katalog www/app.
 * Uruchom z głównego folderu projektu: npm run rerun
 */
const fs = require('fs');
const path = require('path');
const { execSync } = require('child_process');

const root = path.join(__dirname, '..');
const mobileDir = path.join(root, 'mobile');
const buildWeb = path.join(mobileDir, 'build', 'web');
const dest = path.join(root, 'www', 'app');

if (!fs.existsSync(path.join(mobileDir, 'pubspec.yaml'))) {
  console.error('Brak mobile/pubspec.yaml — uruchom npm run rerun z katalogu SELLEKTYWNI.PL');
  process.exit(1);
}

console.log('[rerun] flutter build web --release --base-href=/app/ …');
execSync('flutter build web --release --base-href=/app/', {
  cwd: mobileDir,
  stdio: 'inherit',
  shell: true,
});

if (!fs.existsSync(buildWeb)) {
  console.error('[rerun] Oczekiwano folderu:', buildWeb);
  process.exit(1);
}

fs.mkdirSync(dest, { recursive: true });
fs.cpSync(buildWeb, dest, { recursive: true, force: true });

console.log('[rerun] Skopiowano do', dest);
console.log('[rerun] W przeglądarce: twarde odświeżenie (Ctrl+Shift+R), jeśli widać starą wersję.');
