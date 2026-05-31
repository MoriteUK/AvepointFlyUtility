'use strict';

const express        = require('express');
const http           = require('http');
const { WebSocketServer } = require('ws');
const session        = require('express-session');
const multer         = require('multer');
const { spawn }      = require('child_process');
const fs             = require('fs');
const path           = require('path');
const crypto         = require('crypto');
const os             = require('os');

// ── Paths ─────────────────────────────────────────────────────────────
const FLY_DIR        = __dirname;
const STORAGE_STATE  = path.join(FLY_DIR, 'auth', 'storageState.json');
const WORKLOADS_FILE = path.join(FLY_DIR, 'workloads.json');
const UPLOADS_DIR    = path.join(os.tmpdir(), 'fly-uploads');

fs.mkdirSync(path.join(FLY_DIR, 'auth'), { recursive: true });
fs.mkdirSync(UPLOADS_DIR, { recursive: true });

// ── Config from environment ───────────────────────────────────────────
const PASSWORD       = process.env.FLY_PASSWORD      || 'changeme';
const SESSION_SECRET = process.env.SESSION_SECRET     || crypto.randomBytes(32).toString('hex');
const PORT           = parseInt(process.env.PORT, 10) || 3000;
const TRUST_PROXY    = process.env.TRUST_PROXY === '1'; // set when behind nginx

// ── Express + HTTP server ─────────────────────────────────────────────
const app    = express();
const server = http.createServer(app);

if (TRUST_PROXY) app.set('trust proxy', 1);

app.use(session({
  secret:            SESSION_SECRET,
  resave:            false,
  saveUninitialized: false,
  cookie: {
    httpOnly: true,
    secure:   TRUST_PROXY,   // true only when proxied through HTTPS
    maxAge:   8 * 60 * 60 * 1000
  }
}));

app.use(express.json());
app.use(express.urlencoded({ extended: false }));

// ── Auth guard ────────────────────────────────────────────────────────
function requireAuth(req, res, next) {
  if (req.session.authenticated) return next();
  if (req.path.startsWith('/api/')) return res.status(401).json({ error: 'Unauthorized' });
  res.redirect('/login');
}

// ── Login routes ──────────────────────────────────────────────────────
app.get('/login', (req, res) => {
  if (req.session.authenticated) return res.redirect('/');
  res.sendFile(path.join(FLY_DIR, 'public', 'login.html'));
});

app.post('/auth/login', (req, res) => {
  if (req.body.password === PASSWORD) {
    req.session.authenticated = true;
    res.redirect('/');
  } else {
    res.redirect('/login?error=1');
  }
});

app.get('/auth/logout', (req, res) => {
  req.session.destroy();
  res.redirect('/login');
});

app.get('/', requireAuth, (req, res) => {
  res.sendFile(path.join(FLY_DIR, 'public', 'index.html'));
});

app.use('/assets', requireAuth, express.static(path.join(FLY_DIR, 'public')));

// ── WebSocket — keyed by caller-supplied jobId ────────────────────────
const wss  = new WebSocketServer({ server, path: '/ws' });
const jobs = new Map();   // jobId -> WebSocket

wss.on('connection', (ws, req) => {
  const jobId = new URL(req.url, 'http://x').searchParams.get('job');
  if (!jobId) { ws.close(); return; }
  jobs.set(jobId, ws);
  ws.on('close', () => jobs.delete(jobId));
});

function wsend(jobId, obj) {
  const ws = jobs.get(jobId);
  if (ws && ws.readyState === 1) ws.send(JSON.stringify(obj));
}

// ── Process runner — pipes stdout JSON events to the WebSocket ────────
function runProc(jobId, cmd, args, opts = {}) {
  const proc = spawn(cmd, args, {
    cwd: FLY_DIR,
    env: {
      ...process.env,
      PLAYWRIGHT_BROWSERS_PATH: process.env.PLAYWRIGHT_BROWSERS_PATH || '/ms-playwright',
      FLY_HEADLESS: '1'
    },
    ...opts
  });

  let buf = '';
  proc.stdout.on('data', chunk => {
    buf += chunk.toString();
    const lines = buf.split('\n');
    buf = lines.pop();                   // keep partial last line
    for (const line of lines) {
      const l = line.trim();
      if (!l) continue;
      try { wsend(jobId, JSON.parse(l)); }
      catch { wsend(jobId, { event: 'log', message: l }); }
    }
  });

  proc.stderr.on('data', chunk => {
    chunk.toString().split('\n').forEach(l => {
      const t = l.trim();
      if (t) wsend(jobId, { event: 'log', message: t });
    });
  });

  proc.on('exit', code => {
    if (buf.trim()) wsend(jobId, { event: 'log', message: buf.trim() });
    wsend(jobId, { event: 'exit', code: code ?? -1 });
  });

  return proc;
}

// ── Multer storage ────────────────────────────────────────────────────
const authUpload = multer({ dest: path.join(FLY_DIR, 'auth') });
const csvUpload  = multer({ dest: UPLOADS_DIR });

// ── API: session status & upload ──────────────────────────────────────
app.get('/api/session-status', requireAuth, (req, res) => {
  let age = null;
  try { age = Date.now() - fs.statSync(STORAGE_STATE).mtimeMs; } catch {}
  res.json({ hasSession: fs.existsSync(STORAGE_STATE), ageMs: age });
});

app.post('/api/session/upload', requireAuth, authUpload.single('session'), (req, res) => {
  if (!req.file) return res.status(400).json({ error: 'No file' });
  try {
    JSON.parse(fs.readFileSync(req.file.path, 'utf8'));   // must be valid JSON
    fs.renameSync(req.file.path, STORAGE_STATE);
    res.json({ ok: true });
  } catch {
    try { fs.unlinkSync(req.file.path); } catch {}
    res.status(400).json({ error: 'File is not valid JSON' });
  }
});

// ── API: workloads config ─────────────────────────────────────────────
app.get('/api/workloads', requireAuth, (req, res) => {
  try { res.json(JSON.parse(fs.readFileSync(WORKLOADS_FILE, 'utf8'))); }
  catch { res.json({}); }
});

app.put('/api/workloads', requireAuth, (req, res) => {
  fs.writeFileSync(WORKLOADS_FILE, JSON.stringify(req.body, null, 2));
  res.json({ ok: true });
});

// ── API: connections ──────────────────────────────────────────────────
const WORKLOAD_LABELS = {
  SharePoint: 'SharePoint Online',
  Exchange:   'Exchange Online',
  OneDrive:   'OneDrive for Business',
  Teams:      'Microsoft Teams',
  TeamChat:   'Teams Chat',
  Groups:     'Microsoft 365 Groups'
};

app.post('/api/connections/create', requireAuth, (req, res) => {
  const { jobId, displayName, tenantSearch, credentialsName, workloads } = req.body;
  if (!jobId || !displayName || !tenantSearch || !credentialsName || !Array.isArray(workloads) || !workloads.length) {
    return res.status(400).json({ error: 'Missing required fields' });
  }

  if (!fs.existsSync(STORAGE_STATE)) {
    return res.status(400).json({ error: 'No AOS session found. Upload storageState.json first.' });
  }

  const tasks = workloads.map(w => ({
    id:             w,
    workloadLabel:  WORKLOAD_LABELS[w] || w,
    connectionName: `${displayName} - ${WORKLOAD_LABELS[w] || w}`,
    tenantSearch,
    credentialsName
  }));

  const proc = runProc(jobId, 'node', [
    'fly-connector.js',
    '--mode=create',
    `--display-name=${displayName}`,
    '--headless'
  ]);

  tasks.forEach(t => proc.stdin.write(JSON.stringify(t) + '\n'));
  proc.stdin.end();

  res.json({ ok: true, taskCount: tasks.length });
});

// ── API: migration connect test ───────────────────────────────────────
app.post('/api/migration/connect', requireAuth, (req, res) => {
  const { flyUrl, clientId, clientSecret } = req.body;
  if (!flyUrl || !clientId || !clientSecret) {
    return res.status(400).json({ error: 'Missing credentials' });
  }

  // Write a temp param file to avoid shell injection
  const paramFile = path.join(os.tmpdir(), `fly-test-${Date.now()}.json`);
  fs.writeFileSync(paramFile, JSON.stringify({ flyUrl, clientId, clientSecret }));

  const script = `
    $p = Get-Content '${paramFile}' | ConvertFrom-Json
    Remove-Item '${paramFile}' -Force -ErrorAction SilentlyContinue
    $sec = ConvertTo-SecureString $p.clientSecret -AsPlainText -Force
    try {
      Connect-Fly -Url $p.flyUrl -ClientId $p.clientId -ClientSecret $sec | Out-Null
      Write-Output 'OK'
    } catch {
      Write-Output "FAIL:$($_.Exception.Message)"
    }
  `.trim().replace(/\n\s*/g, '; ');

  let out = '';
  const proc = spawn('pwsh', ['-NoProfile', '-NonInteractive', '-Command', script], { cwd: FLY_DIR });
  proc.stdout.on('data', d => { out += d.toString(); });
  proc.stderr.on('data', d => { out += d.toString(); });
  proc.on('exit', () => {
    const trimmed = out.trim();
    if (trimmed.startsWith('OK')) {
      res.json({ ok: true });
    } else {
      res.json({ ok: false, message: trimmed.replace(/^FAIL:/, '') });
    }
    try { fs.unlinkSync(paramFile); } catch {}
  });
});

// ── API: migration run ────────────────────────────────────────────────
const WORKLOAD_CMDLETS = {
  SharePoint: { import: 'Import-FlySharePointMappings', prescan: 'Start-FlySharePointPreScan',  verify: 'Start-FlySharePointVerification',  migrate: 'Start-FlySharePointMigration'  },
  Exchange:   { import: 'Import-FlyExchangeMappings',   prescan: 'Start-FlyExchangePreScan',    verify: 'Start-FlyExchangeVerification',    migrate: 'Start-FlyExchangeMigration'    },
  OneDrive:   { import: 'Import-FlyOneDriveMappings',   prescan: 'Start-FlyOneDrivePreScan',    verify: 'Start-FlyOneDriveVerification',    migrate: 'Start-FlyOneDriveMigration'    },
  Teams:      { import: 'Import-FlyTeamsMappings',      prescan: 'Start-FlyTeamsPreScan',       verify: 'Start-FlyTeamsVerification',      migrate: 'Start-FlyTeamsMigration'       },
  TeamChat:   { import: 'Import-FlyTeamChatMappings',   prescan: null,                          verify: 'Start-FlyTeamChatVerification',    migrate: 'Start-FlyTeamChatMigration'    },
  Groups:     { import: 'Import-FlyM365GroupMappings',  prescan: 'Start-FlyM365GroupPreScan',   verify: 'Start-FlyM365GroupVerification',   migrate: 'Start-FlyM365GroupMigration'   }
};

app.post('/api/migration/run', requireAuth, csvUpload.any(), (req, res) => {
  const { jobId, flyUrl, clientId, clientSecret, prefix } = req.body;
  let ops;
  try { ops = JSON.parse(req.body.ops || '{}'); } catch { ops = {}; }

  if (!jobId || !flyUrl || !clientId || !clientSecret || !prefix) {
    return res.status(400).json({ error: 'Missing required fields' });
  }

  // Map uploaded CSV files by their field name (= workload key)
  const csvPaths = {};
  (req.files || []).forEach(f => { csvPaths[f.fieldname] = f.path; });

  // Write all params to a temp JSON file (avoids any shell injection)
  const paramFile = path.join(os.tmpdir(), `fly-run-${Date.now()}.json`);
  fs.writeFileSync(paramFile, JSON.stringify({ flyUrl, clientId, clientSecret, prefix, ops, csvPaths }));

  const proc = runProc(jobId, 'pwsh', [
    '-NoProfile', '-NonInteractive', '-ExecutionPolicy', 'Bypass',
    '-File', path.join(FLY_DIR, 'fly-migrator.ps1'),
    '-ParamFile', paramFile
  ]);

  // Clean up CSV uploads once process exits
  proc.on('exit', () => {
    Object.values(csvPaths).forEach(p => { try { fs.unlinkSync(p); } catch {} });
    try { fs.unlinkSync(paramFile); } catch {}
  });

  res.json({ ok: true });
});

// ── API: report run ───────────────────────────────────────────────────
app.post('/api/report/run', requireAuth, (req, res) => {
  const { jobId, flyUrl, clientId, clientSecret, prefix, reportType, workloads } = req.body;
  if (!jobId || !flyUrl || !clientId || !clientSecret || !prefix || !Array.isArray(workloads) || !workloads.length) {
    return res.status(400).json({ error: 'Missing required fields' });
  }

  const paramFile = path.join(os.tmpdir(), `fly-report-${Date.now()}.json`);
  fs.writeFileSync(paramFile, JSON.stringify({
    flyUrl, clientId, clientSecret, prefix,
    reportType: reportType || 'migration',
    workloads
  }));

  const proc = runProc(jobId, 'pwsh', [
    '-NoProfile', '-NonInteractive', '-ExecutionPolicy', 'Bypass',
    '-File', path.join(FLY_DIR, 'fly-reporter.ps1'),
    '-ParamFile', paramFile
  ]);

  proc.on('exit', () => {
    try { fs.unlinkSync(paramFile); } catch {}
  });

  res.json({ ok: true });
});

// ── Start ─────────────────────────────────────────────────────────────
server.listen(PORT, () => {
  console.log(`Fly Migration web UI:  http://localhost:${PORT}`);
  if (PASSWORD === 'changeme') {
    console.warn('WARNING: using default password. Set FLY_PASSWORD env var before exposing to the internet.');
  }
});
