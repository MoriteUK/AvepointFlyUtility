'use strict';

// ── Tab navigation ────────────────────────────────────────────────────
document.querySelectorAll('.nav-item').forEach(btn => {
  btn.addEventListener('click', () => {
    document.querySelectorAll('.nav-item').forEach(b => b.classList.remove('active'));
    document.querySelectorAll('.tab').forEach(t => t.classList.remove('active'));
    btn.classList.add('active');
    document.getElementById(`tab-${btn.dataset.tab}`).classList.add('active');
  });
});

// ── Log panel ─────────────────────────────────────────────────────────
function log(msg, cls = 'info') {
  const el   = document.createElement('div');
  el.className = `log-line log-${cls}`;
  const now  = new Date().toTimeString().slice(0, 8);
  el.textContent = `[${now}] ${msg}`;
  const body = document.getElementById('log-body');
  body.appendChild(el);
  body.scrollTop = body.scrollHeight;
}
function clearLog() { document.getElementById('log-body').innerHTML = ''; }

// ── Job ID generator ──────────────────────────────────────────────────
function makeJobId() { return Math.random().toString(36).slice(2, 10); }

// ── WebSocket helper — connects and delivers events to a callback ──────
function openJobSocket(jobId, onEvent) {
  const proto = location.protocol === 'https:' ? 'wss' : 'ws';
  const ws    = new WebSocket(`${proto}://${location.host}/ws?job=${jobId}`);
  ws.onmessage = e => {
    let data;
    try { data = JSON.parse(e.data); } catch { data = { event: 'log', message: e.data }; }
    onEvent(data);
  };
  ws.onerror = () => log('WebSocket error', 'error');
  return ws;
}

// ── Generic event router ──────────────────────────────────────────────
function handleEvent(evt, rowMap) {
  const { event, message, id, status } = evt;

  if (event === 'done')   { log(message || 'Done.', 'done'); return; }
  if (event === 'fatal')  { log(`FATAL: ${message}`, 'error'); return; }
  if (event === 'error')  { log(message, 'error'); return; }
  if (event === 'warn')   { log(message, 'warn'); return; }
  if (event === 'exit')   { log(`Process exited (code ${evt.code})`, 'exit'); return; }
  if (event === 'info' || event === 'log') { log(message); return; }
  if (event === 'login-ok') { log(message, 'done'); return; }

  // Task-row update: { id, status, message }
  if (id && status && rowMap && rowMap[id]) {
    const cells = rowMap[id].querySelectorAll('td');
    // Find the status cell (penultimate) and message cell (last)
    const statusCell  = cells[cells.length - 2];
    const messageCell = cells[cells.length - 1];
    if (statusCell)  statusCell.innerHTML = `<span class="status-pill status-${status}">${status}</span>`;
    if (messageCell) messageCell.textContent = message || '';
    log(`[${id}] ${status} ${message || ''}`, status === 'FAILED' ? 'error' : 'info');
  }
}

// ── Session status (header badge) ─────────────────────────────────────
async function refreshSessionStatus() {
  try {
    const r    = await fetch('/api/session-status');
    const data = await r.json();
    const badge = document.getElementById('session-badge');
    const info  = document.getElementById('session-info');
    if (data.hasSession) {
      const hrs = data.ageMs ? Math.round(data.ageMs / 3_600_000) : '?';
      badge.className     = 'badge badge-ok';
      badge.textContent   = 'AOS session active';
      if (info) info.innerHTML = `<strong style="color:var(--success)">Session present</strong> — saved ${hrs} hour(s) ago. Re-upload if connections start failing with &ldquo;Session stale&rdquo;.`;
    } else {
      badge.className     = 'badge badge-warn';
      badge.textContent   = 'No AOS session';
      if (info) info.innerHTML = '<strong style="color:var(--warn)">No session found.</strong> Upload a <code>storageState.json</code> file to enable the Connections tab.';
    }
  } catch { /* ignore */ }
}
refreshSessionStatus();

// ── Upload session ────────────────────────────────────────────────────
document.getElementById('btn-upload-session').addEventListener('click', async () => {
  const file = document.getElementById('session-file').files[0];
  if (!file) { log('Select a storageState.json file first.', 'warn'); return; }

  const fd = new FormData();
  fd.append('session', file);

  try {
    const r = await fetch('/api/session/upload', { method: 'POST', body: fd });
    const j = await r.json();
    if (j.ok) { log('AOS session uploaded.', 'done'); refreshSessionStatus(); }
    else       log(`Upload failed: ${j.error}`, 'error');
  } catch (e) { log(`Upload error: ${e.message}`, 'error'); }
});

// ── Load workloads.json into editor ───────────────────────────────────
async function loadWorkloads() {
  try {
    const r = await fetch('/api/workloads');
    document.getElementById('workloads-json').value = JSON.stringify(await r.json(), null, 2);
  } catch { /* ignore */ }
}
loadWorkloads();

document.getElementById('btn-save-workloads').addEventListener('click', async () => {
  let parsed;
  try { parsed = JSON.parse(document.getElementById('workloads-json').value); }
  catch { log('Invalid JSON — fix syntax and try again.', 'error'); return; }

  try {
    await fetch('/api/workloads', { method: 'PUT', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(parsed) });
    document.getElementById('workloads-saved').style.display = 'inline';
    setTimeout(() => { document.getElementById('workloads-saved').style.display = 'none'; }, 2500);
  } catch (e) { log(`Save failed: ${e.message}`, 'error'); }
});

// ── Connections tab ───────────────────────────────────────────────────
const WORKLOAD_LABELS = {
  SharePoint: 'SharePoint Online',
  Exchange:   'Exchange Online',
  OneDrive:   'OneDrive for Business',
  Teams:      'Microsoft Teams',
  TeamChat:   'Teams Chat',
  Groups:     'Microsoft 365 Groups'
};

document.getElementById('form-connections').addEventListener('submit', async e => {
  e.preventDefault();

  const displayName     = document.getElementById('c-display').value.trim();
  const tenantSearch    = document.getElementById('c-search').value.trim();
  const credentialsName = document.getElementById('c-creds').value.trim();
  const workloads       = [...document.querySelectorAll('input[name=wl]:checked')].map(c => c.value);

  if (!workloads.length) { log('Select at least one workload.', 'warn'); return; }

  const jobId  = makeJobId();
  const rowMap = {};

  // Build results table
  const tbody   = document.getElementById('connections-tbody');
  tbody.innerHTML = '';
  workloads.forEach(w => {
    const tr = document.createElement('tr');
    tr.innerHTML = `
      <td>${WORKLOAD_LABELS[w]}</td>
      <td>${displayName} - ${WORKLOAD_LABELS[w]}</td>
      <td><span class="status-pill status-WORKING">Queued</span></td>
      <td>—</td>`;
    tbody.appendChild(tr);
    rowMap[w] = tr;
  });
  document.getElementById('connections-results').style.display = 'block';

  const btn = document.getElementById('btn-connections');
  btn.disabled = true;

  // Open WebSocket before posting so we don't miss early events
  const ws = openJobSocket(jobId, evt => handleEvent(evt, rowMap));
  ws.onopen = async () => {
    try {
      const r = await fetch('/api/connections/create', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ jobId, displayName, tenantSearch, credentialsName, workloads })
      });
      const j = await r.json();
      if (!j.ok) { log(`Server error: ${j.error}`, 'error'); btn.disabled = false; }
    } catch (ex) { log(`Request failed: ${ex.message}`, 'error'); btn.disabled = false; }
  };
  ws.onclose = () => {
    btn.disabled = false;
    loadWorkloads();          // refresh workloads after connections created
    refreshSessionStatus();
  };
});

// ── Migration tab ─────────────────────────────────────────────────────
(function buildMigrationTable() {
  const tbody = document.getElementById('migration-tbody');
  const WORKLOADS = Object.keys(WORKLOAD_LABELS);

  WORKLOADS.forEach(w => {
    const tr = document.createElement('tr');
    tr.dataset.workload = w;
    tr.innerHTML = `
      <td><input type="checkbox" class="mig-enable" checked></td>
      <td>${WORKLOAD_LABELS[w]}</td>
      <td><input type="text" class="mig-src" placeholder="Source connection" style="min-width:160px"></td>
      <td><input type="text" class="mig-dst" placeholder="Destination connection" style="min-width:160px"></td>
      <td><input type="file" class="mig-csv" accept=".csv"></td>
      <td>
        <select class="mig-op">
          <option value="import">Import only</option>
          <option value="prescan">Pre-Scan</option>
          <option value="verify">Verification</option>
          <option value="migrate" selected>Migration</option>
        </select>
      </td>`;
    tbody.appendChild(tr);
  });
})();

// Pre-fill migration table from workloads.json
async function prefillMigrationTable() {
  try {
    const r = await fetch('/api/workloads');
    const j = await r.json();
    document.querySelectorAll('#migration-tbody tr').forEach(tr => {
      const w   = tr.dataset.workload;
      const cfg = j[w];
      if (!cfg) return;
      tr.querySelector('.mig-src').value = cfg.Source      || '';
      tr.querySelector('.mig-dst').value = cfg.Destination || '';
    });
  } catch { /* ignore */ }
}
prefillMigrationTable();

// Test connection
document.getElementById('btn-connect').addEventListener('click', async () => {
  const flyUrl      = document.getElementById('m-url').value.trim();
  const clientId    = document.getElementById('m-cid').value.trim();
  const clientSecret = document.getElementById('m-secret').value.trim();
  const status      = document.getElementById('connect-status');

  if (!flyUrl || !clientId || !clientSecret) { log('Fill in all API credentials first.', 'warn'); return; }
  status.textContent = 'Testing…';
  status.style.color = '';

  try {
    const r = await fetch('/api/migration/connect', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ flyUrl, clientId, clientSecret })
    });
    const j = await r.json();
    if (j.ok) {
      status.textContent = '✓ Connected';
      status.style.color = 'var(--success)';
      log('Fly API connection OK.', 'done');
    } else {
      status.textContent = '✗ Failed';
      status.style.color = 'var(--danger)';
      log(`Connect failed: ${j.message}`, 'error');
    }
  } catch (ex) {
    status.textContent = '✗ Error';
    status.style.color = 'var(--danger)';
    log(`Connect error: ${ex.message}`, 'error');
  }
});

// Run migration
document.getElementById('btn-migration').addEventListener('click', async () => {
  const flyUrl       = document.getElementById('m-url').value.trim();
  const clientId     = document.getElementById('m-cid').value.trim();
  const clientSecret = document.getElementById('m-secret').value.trim();
  const prefix       = document.getElementById('m-prefix').value.trim();

  if (!flyUrl || !clientId || !clientSecret || !prefix) {
    log('Fill in all API credentials and customer prefix.', 'warn');
    return;
  }

  const jobId  = makeJobId();
  const rowMap = {};
  const fd     = new FormData();
  const ops    = {};

  fd.append('jobId',        jobId);
  fd.append('flyUrl',       flyUrl);
  fd.append('clientId',     clientId);
  fd.append('clientSecret', clientSecret);
  fd.append('prefix',       prefix);

  // Build results table
  const tbody = document.getElementById('migration-results-tbody');
  tbody.innerHTML = '';
  let hasWork = false;

  document.querySelectorAll('#migration-tbody tr').forEach(tr => {
    const w       = tr.dataset.workload;
    const enabled = tr.querySelector('.mig-enable').checked;
    const csvFile = tr.querySelector('.mig-csv').files[0];
    const op      = tr.querySelector('.mig-op').value;

    if (!enabled) return;
    hasWork = true;

    ops[w] = op;
    if (csvFile) fd.append(w, csvFile);

    const resTr = document.createElement('tr');
    resTr.innerHTML = `
      <td>${WORKLOAD_LABELS[w]}</td>
      <td><span class="status-pill status-WORKING">Queued</span></td>
      <td>—</td>`;
    tbody.appendChild(resTr);
    rowMap[w] = resTr;
  });

  if (!hasWork) { log('Enable at least one workload.', 'warn'); return; }

  fd.append('ops', JSON.stringify(ops));
  document.getElementById('migration-results').style.display = 'block';

  const btn = document.getElementById('btn-migration');
  btn.disabled = true;

  const ws = openJobSocket(jobId, evt => handleEvent(evt, rowMap));
  ws.onopen = async () => {
    try {
      const r = await fetch('/api/migration/run', { method: 'POST', body: fd });
      const j = await r.json();
      if (!j.ok) { log(`Server error: ${j.error}`, 'error'); btn.disabled = false; }
    } catch (ex) { log(`Request failed: ${ex.message}`, 'error'); btn.disabled = false; }
  };
  ws.onclose = () => { btn.disabled = false; };
});

// ── Reporting tab ─────────────────────────────────────────────────────

const ERROR_PATTERNS = [
  {
    pattern: /access.?denied|permission.?denied|insufficient.?privil|forbidden|403/i,
    type: 'Access Denied',
    cls:  'err-access',
    fix:  'Ensure the migration account has Site Collection Admin (SharePoint/OneDrive), Full Access (Exchange), or equivalent rights on the source and destination. Re-test the connection after granting permissions.'
  },
  {
    pattern: /401|unauthorized|token.?expired|invalid.?credential|auth.*fail/i,
    type: 'Authentication Error',
    cls:  'err-auth',
    fix:  'Credentials have expired or are incorrect. Reconnect the Fly API connection and re-test before retrying the migration.'
  },
  {
    pattern: /throttl|429|too.?many.?request|rate.?limit/i,
    type: 'Throttling',
    cls:  'err-throttle',
    fix:  'Microsoft is rate-limiting requests. Fly will retry automatically. Consider reducing project concurrency in the Fly portal under Project Settings > Advanced.'
  },
  {
    pattern: /timeout|timed.?out|connection.?reset|socket|network/i,
    type: 'Network Timeout',
    cls:  'err-timeout',
    fix:  'A network interruption occurred during transfer. The item will be retried on the next incremental pass. If persistent, check firewall rules or increase the Fly timeout setting.'
  },
  {
    pattern: /not.?found|does.?not.?exist|no.?such|404|mailbox.*missing|smtp.*invalid/i,
    type: 'Item / Mailbox Not Found',
    cls:  'err-notfound',
    fix:  'The source or destination object no longer exists. Verify the URL, email address, or mailbox in the mapping CSV and ensure the destination is licensed and provisioned.'
  },
  {
    pattern: /size.?exceed|too.?large|exceeds.?limit|max.?size|file.?too.?big/i,
    type: 'Item Too Large',
    cls:  'err-size',
    fix:  'The item exceeds the Microsoft size limit (e.g. 250 GB for SharePoint files, 150 MB for Exchange items). Split, compress, or migrate manually outside of Fly.'
  },
  {
    pattern: /duplicate|already.?exist|conflict/i,
    type: 'Duplicate / Conflict',
    cls:  'err-duplicate',
    fix:  'An item with the same name exists at the destination. Update the Fly project conflict resolution policy (Overwrite vs. Skip) under Project Settings > Migration Policy.'
  },
  {
    pattern: /unsupported|not.?support|cannot.?migrat/i,
    type: 'Unsupported Content',
    cls:  'err-unsupport',
    fix:  'This content type is not supported by Fly. Consult the AvePoint supported content matrix and migrate this item manually if required.'
  }
];

function analyzeError(message) {
  if (!message) return { type: '—', cls: 'err-generic', fix: '—' };
  for (const p of ERROR_PATTERNS) {
    if (p.pattern.test(message)) return { type: p.type, cls: p.cls, fix: p.fix };
  }
  return { type: 'Unknown Error', cls: 'err-generic', fix: 'Review the full error message in the Activity Log. Check the Fly portal for more detail, or contact AvePoint support if the error persists.' };
}

function findField(row, candidates) {
  for (const k of candidates) {
    if (row[k] !== undefined && row[k] !== '') return row[k];
  }
  // Case-insensitive fallback
  const lc = Object.fromEntries(Object.entries(row).map(([k, v]) => [k.toLowerCase(), v]));
  for (const k of candidates) {
    if (lc[k.toLowerCase()] !== undefined) return lc[k.toLowerCase()];
  }
  return '';
}

const STATUS_SUCCESS_RE = /^success$|^completed$|^done$/i;
const STATUS_WARN_RE    = /^warning$|^skipped$|^partial/i;
const STATUS_FAIL_RE    = /^fail|^error/i;

// Accumulated report rows across all workloads for CSV export
let reportRows = [];

const reportStats = { total: 0, success: 0, warn: 0, failed: 0 };

function resetReport() {
  reportRows = [];
  reportStats.total = reportStats.success = reportStats.warn = reportStats.failed = 0;
  document.getElementById('report-tbody').innerHTML = '';
  document.getElementById('report-summary').style.display = 'none';
  document.getElementById('report-results').style.display = 'none';
  ['stat-total','stat-success','stat-warn','stat-failed'].forEach(id => {
    document.getElementById(id).textContent = '0';
  });
}

function updateStats() {
  document.getElementById('stat-total').textContent   = reportStats.total;
  document.getElementById('stat-success').textContent = reportStats.success;
  document.getElementById('stat-warn').textContent    = reportStats.warn;
  document.getElementById('stat-failed').textContent  = reportStats.failed;
  document.getElementById('report-summary').style.display = 'block';
}

function appendReportRow(workload, data) {
  const status = findField(data, ['Status','Result','MigrationStatus','State']);
  const source = findField(data, ['SourceItem','SourceUser','SourceSite','SourceMailbox','Source','Name','Item']);
  const errMsg = findField(data, ['ErrorMessage','Error','Message','FailReason','Description','Details']);

  reportStats.total++;
  if (STATUS_SUCCESS_RE.test(status))    reportStats.success++;
  else if (STATUS_WARN_RE.test(status))  reportStats.warn++;
  else if (STATUS_FAIL_RE.test(status) || errMsg) reportStats.failed++;
  else                                   reportStats.success++;

  // Only add non-success rows to the analysis table
  if (STATUS_SUCCESS_RE.test(status) && !errMsg) { updateStats(); return; }

  const analysis = analyzeError(errMsg);

  const tr = document.createElement('tr');
  tr.innerHTML = `
    <td>${WORKLOAD_LABELS[workload] || workload}</td>
    <td>${source || '—'}</td>
    <td><span class="status-pill status-${STATUS_FAIL_RE.test(status) ? 'FAILED' : STATUS_WARN_RE.test(status) ? 'SKIPPED' : 'WORKING'}">${status || '—'}</span></td>
    <td><span class="err-badge ${analysis.cls}">${analysis.type}</span></td>
    <td>${errMsg || '—'}</td>
    <td class="fix-text">${analysis.fix}</td>`;
  document.getElementById('report-tbody').appendChild(tr);
  document.getElementById('report-results').style.display = 'block';

  reportRows.push({ workload: WORKLOAD_LABELS[workload] || workload, source, status, errorType: analysis.type, errorMessage: errMsg, recommendedFix: analysis.fix });
  updateStats();
}

// Export to CSV
document.getElementById('btn-export-report').addEventListener('click', () => {
  if (!reportRows.length) { log('No error rows to export.', 'warn'); return; }
  const headers = ['Workload','Source Object','Status','Error Type','Error Message','Recommended Fix'];
  const escape  = v => `"${String(v ?? '').replace(/"/g, '""')}"`;
  const lines   = [
    headers.map(escape).join(','),
    ...reportRows.map(r => [r.workload, r.source, r.status, r.errorType, r.errorMessage, r.recommendedFix].map(escape).join(','))
  ];
  const blob = new Blob([lines.join('\r\n')], { type: 'text/csv' });
  const url  = URL.createObjectURL(blob);
  const a    = Object.assign(document.createElement('a'), { href: url, download: 'fly-report-errors.csv' });
  a.click();
  URL.revokeObjectURL(url);
});

// Run report
document.getElementById('btn-report').addEventListener('click', async () => {
  const flyUrl       = document.getElementById('r-url').value.trim();
  const clientId     = document.getElementById('r-cid').value.trim();
  const clientSecret = document.getElementById('r-secret').value.trim();
  const prefix       = document.getElementById('r-prefix').value.trim();
  const reportType   = document.querySelector('input[name="r-type"]:checked').value;
  const workloads    = [...document.querySelectorAll('input[name="r-wl"]:checked')].map(c => c.value);

  if (!flyUrl || !clientId || !clientSecret || !prefix) {
    log('Fill in all API credentials and customer prefix.', 'warn'); return;
  }
  if (!workloads.length) { log('Select at least one workload.', 'warn'); return; }

  resetReport();

  const jobId = makeJobId();
  const btn   = document.getElementById('btn-report');
  btn.disabled = true;

  const ws = openJobSocket(jobId, evt => {
    if (evt.event === 'row') {
      appendReportRow(evt.workload, evt.data);
    } else {
      handleEvent(evt, null);
    }
  });

  ws.onopen = async () => {
    try {
      const r = await fetch('/api/report/run', {
        method:  'POST',
        headers: { 'Content-Type': 'application/json' },
        body:    JSON.stringify({ jobId, flyUrl, clientId, clientSecret, prefix, reportType, workloads })
      });
      const j = await r.json();
      if (!j.ok) { log(`Server error: ${j.error}`, 'error'); btn.disabled = false; }
    } catch (ex) { log(`Request failed: ${ex.message}`, 'error'); btn.disabled = false; }
  };
  ws.onclose = () => { btn.disabled = false; };
});
