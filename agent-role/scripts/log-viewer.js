#!/usr/bin/env node
// Agent Role Log Viewer
// Usage: node log-viewer.js <job-dir>
// 예시:  node log-viewer.js .agent/job-1

const http = require('http');
const fs = require('fs');
const path = require('path');
const { exec } = require('child_process');

const absJobDir = path.dirname(path.resolve(process.argv[1]));
const port = parseInt(process.argv[2]) || 9999;
if (!fs.existsSync(absJobDir)) {
  console.error(`디렉토리 없음: ${absJobDir}`);
  process.exit(1);
}

// --- 하트비트 자동 종료 ---
const HEARTBEAT_TIMEOUT = 10000;
let lastHeartbeat = Date.now();
setInterval(() => {
  if (Date.now() - lastHeartbeat > HEARTBEAT_TIMEOUT) {
    console.log('\n브라우저 연결 끊김 → 서버 종료');
    process.exit(0);
  }
}, 3000);

// --- 역할 스캔 ---
function scanRoles() {
  const roles = [];
  const files = fs.readdirSync(absJobDir).filter(f => /^role-\d+\.md$/.test(f)).sort((a, b) => {
    return parseInt(a.match(/\d+/)[0]) - parseInt(b.match(/\d+/)[0]);
  });
  for (const f of files) {
    const num = f.match(/\d+/)[0];
    const mdPath = path.join(absJobDir, f);
    const logPath = path.join(absJobDir, 'log', `role-${num}.log`);
    roles.push({ id: num, mdPath, logPath });
  }
  return roles;
}

function parseRoleMd(filePath) {
  try {
    const text = fs.readFileSync(filePath, 'utf-8');
    const get = (key) => {
      const m = text.match(new RegExp(`^- ${key}:\\s*(.*)$`, 'm'));
      return m ? m[1].trim() : '-';
    };
    // 결과 요약 섹션 파싱
    const summaryMatch = text.match(/## 결과 요약\n([\s\S]*?)(?=\n##|$)/);
    const summary = summaryMatch ? summaryMatch[1].trim() : '';
    return {
      status: get('status'),
      locked: get('locked'),
      locked_by: get('locked_by'),
      goal: get('goal'),
      target: get('target'),
      summary,
    };
  } catch { return { status: '-', locked: '-', locked_by: '-', goal: '-', target: '-', summary: '' }; }
}

function readLogTail(filePath, maxBytes = 64 * 1024) {
  try {
    const stat = fs.statSync(filePath);
    const start = Math.max(0, stat.size - maxBytes);
    const buf = Buffer.alloc(Math.min(stat.size, maxBytes));
    const fd = fs.openSync(filePath, 'r');
    fs.readSync(fd, buf, 0, buf.length, start);
    fs.closeSync(fd);
    return { content: buf.toString('utf-8'), size: stat.size };
  } catch { return { content: '', size: 0 }; }
}

// --- SSE ---
let clients = [];
let prevState = '';

function broadcastState() {
  const roles = scanRoles();
  const state = roles.map(r => {
    const md = parseRoleMd(r.mdPath);
    const log = readLogTail(r.logPath);
    return { ...r, ...md, log: log.content, logSize: log.size };
  });

  // job.md 읽기
  let jobMd = '';
  const jobMdPath = path.join(absJobDir, 'job.md');
  try { jobMd = fs.readFileSync(jobMdPath, 'utf-8'); } catch {}

  // .done 체크
  const doneFile = path.join(absJobDir, '.done');
  let done = null;
  try { done = fs.readFileSync(doneFile, 'utf-8').trim(); } catch {}

  const payload = JSON.stringify({ roles: state, jobMd, done, ts: Date.now() });

  if (payload !== prevState) {
    prevState = payload;
    const msg = `data: ${payload}\n\n`;
    clients.forEach(res => { try { res.write(msg); } catch {} });
  }
}

setInterval(broadcastState, 500);

// --- HTTP 서버 ---
const server = http.createServer((req, res) => {
  const url = new URL(req.url, `http://localhost:${port}`);

  if (url.pathname === '/heartbeat') {
    lastHeartbeat = Date.now();
    res.writeHead(200); res.end('ok');
    return;
  }

  if (url.pathname === '/events') {
    res.writeHead(200, {
      'Content-Type': 'text/event-stream',
      'Cache-Control': 'no-cache',
      'Connection': 'keep-alive',
    });
    res.write('\n');
    clients.push(res);
    req.on('close', () => { clients = clients.filter(c => c !== res); });
    return;
  }

  if (url.pathname === '/log' && url.searchParams.get('role')) {
    lastHeartbeat = Date.now();
    const logPath = path.join(absJobDir, 'log', `role-${url.searchParams.get('role')}.log`);
    const log = readLogTail(logPath, 256 * 1024);
    res.writeHead(200, { 'Content-Type': 'text/plain; charset=utf-8' });
    res.end(log.content);
    return;
  }

  // HTML
  res.writeHead(200, { 'Content-Type': 'text/html; charset=utf-8' });
  res.end(HTML.replace('__JOB_DIR__', path.basename(absJobDir)));
});

server.listen(port, () => {
  const actualPort = server.address().port;
  console.log(`\n  Agent Role Log Viewer`);
  console.log(`  Job: ${absJobDir}`);
  console.log(`  URL: http://localhost:${actualPort}`);
  console.log(`  종료: Ctrl+C 또는 브라우저 탭 닫기\n`);

  const openCmd = process.platform === 'darwin' ? 'open' : process.platform === 'win32' ? 'start' : 'xdg-open';
  exec(`${openCmd} http://localhost:${port}`);
});

// --- HTML ---
const HTML = `<!DOCTYPE html>
<html lang="ko">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>__JOB_DIR__ - Log Viewer</title>
<style>
* { margin:0; padding:0; box-sizing:border-box; }
body {
  font-family: 'SF Mono','Menlo','Monaco','Consolas',monospace;
  background: #0d1117; color: #c9d1d9;
  height: 100vh; display: flex; flex-direction: column;
}

/* 헤더 */
.header {
  background: #161b22; border-bottom: 1px solid #30363d;
  padding: 12px 20px; display: flex; align-items: center; gap: 14px;
  flex-shrink: 0;
}
.header .job-name { color: #58a6ff; font-size: 15px; font-weight: 600; }
.header .badge {
  padding: 3px 10px; border-radius: 12px; font-size: 11px; font-weight: 600;
}
.badge-live { background: #238636; color: #fff; animation: pulse 2s infinite; }
.badge-done { background: #1f6feb; color: #fff; }
@keyframes pulse { 0%,100%{opacity:1} 50%{opacity:.5} }
.header .summary { color: #8b949e; font-size: 12px; margin-left: auto; }

/* 역할 탭 */
.tabs {
  background: #161b22; border-bottom: 1px solid #30363d;
  display: flex; padding: 0 12px; flex-shrink: 0; overflow-x: auto;
}
.tab {
  padding: 10px 16px; font-size: 12px; cursor: pointer;
  border-bottom: 2px solid transparent; color: #8b949e;
  white-space: nowrap; display: flex; align-items: center; gap: 8px;
}
.tab:hover { color: #c9d1d9; }
.tab.active { color: #58a6ff; border-bottom-color: #58a6ff; }
.tab .dot {
  width: 8px; height: 8px; border-radius: 50%;
}
.dot-idle { background: #484f58; }
.dot-in_progress { background: #d29922; animation: pulse 1.5s infinite; }
.dot-completed { background: #3fb950; }
.dot-failed { background: #f85149; }

/* 메인 영역 */
.main { flex: 1; display: flex; overflow: hidden; }

/* 사이드바: 역할 정보 */
.sidebar {
  width: 280px; min-width: 280px; background: #161b22;
  border-right: 1px solid #30363d; padding: 16px;
  overflow-y: auto; flex-shrink: 0;
}
.sidebar h3 { color: #58a6ff; font-size: 13px; margin-bottom: 12px; }
.info-row {
  display: flex; justify-content: space-between;
  padding: 4px 0; font-size: 12px; border-bottom: 1px solid #21262d;
}
.info-row .label { color: #8b949e; }
.info-row .value { color: #c9d1d9; text-align: right; max-width: 160px; overflow: hidden; text-overflow: ellipsis; }

.status-badge {
  display: inline-block; padding: 2px 8px; border-radius: 10px;
  font-size: 11px; font-weight: 600;
}
.status-idle { background: #21262d; color: #8b949e; }
.status-in_progress { background: #d2992233; color: #d29922; }
.status-completed { background: #23863633; color: #3fb950; }
.status-failed { background: #da363333; color: #f85149; }

.role-summary {
  margin-top: 12px; padding: 10px; background: #0d1117;
  border: 1px solid #30363d; border-radius: 6px;
  font-size: 12px; color: #8b949e; line-height: 1.5;
  white-space: pre-wrap;
}

/* 로그 패널 */
.log-panel {
  flex: 1; display: flex; flex-direction: column; overflow: hidden;
}
.log-toolbar {
  padding: 8px 16px; background: #0d1117;
  border-bottom: 1px solid #21262d;
  display: flex; align-items: center; gap: 8px; flex-shrink: 0;
}
.log-toolbar label { color: #8b949e; font-size: 11px; }
.log-toolbar input {
  flex: 1; background: #161b22; border: 1px solid #30363d;
  border-radius: 4px; color: #c9d1d9; padding: 5px 8px;
  font-family: inherit; font-size: 11px; outline: none;
}
.log-toolbar input:focus { border-color: #58a6ff; }
.log-toolbar .log-size { color: #484f58; font-size: 11px; white-space: nowrap; }

.log-content {
  flex: 1; overflow-y: auto; padding: 8px 16px;
  font-size: 12px; line-height: 1.55; white-space: pre-wrap; word-break: break-all;
}

.log-line { padding: 1px 0; }
.log-line:hover { background: #161b22; }
.log-line .ln { color: #484f58; display: inline-block; width: 45px; text-align: right; margin-right: 12px; user-select: none; }

.level-error { color: #f85149; }
.level-warn { color: #d29922; }
.level-info { color: #58a6ff; }
.level-debug { color: #6e7681; }
.highlight { background: #e3b34155; border-radius: 2px; }

/* done 배너 */
.done-banner {
  background: #1f6feb22; border: 1px solid #1f6feb;
  color: #58a6ff; padding: 10px 20px; font-size: 13px;
  text-align: center; flex-shrink: 0; display: none;
}

.scroll-btn {
  position: absolute; bottom: 12px; right: 12px;
  background: #30363d; color: #c9d1d9; border: 1px solid #484f58;
  border-radius: 6px; padding: 6px 10px; font-size: 11px;
  cursor: pointer; font-family: inherit; display: none;
}
.scroll-btn:hover { background: #484f58; }
</style>
</head>
<body>

<div class="header">
  <span class="job-name">__JOB_DIR__</span>
  <span class="badge badge-live" id="liveBadge">LIVE</span>
  <span class="summary" id="headerSummary"></span>
</div>

<div class="tabs" id="tabs"></div>

<div class="done-banner" id="doneBanner"></div>

<div class="main">
  <div class="sidebar" id="sidebar"></div>
  <div class="log-panel">
    <div class="log-toolbar">
      <label>Filter</label>
      <input type="text" id="logFilter" placeholder="정규식 필터" />
      <span class="log-size" id="logSize"></span>
    </div>
    <div style="position:relative; flex:1; overflow:hidden;">
      <div class="log-content" id="logContent"></div>
      <button class="scroll-btn" id="scrollBtn" onclick="scrollBottom()">↓ 최신</button>
    </div>
  </div>
</div>

<script>
let roles = [];
let activeRole = null;
let autoScroll = true;

// 하트비트
setInterval(() => fetch('/heartbeat').catch(()=>{}), 3000);

// SSE
const es = new EventSource('/events');
es.onmessage = e => {
  const data = JSON.parse(e.data);
  roles = data.roles;

  // 첫 로드 시 첫 역할 선택
  if (!activeRole && roles.length > 0) activeRole = roles[0].id;

  renderTabs();
  renderSidebar();
  renderLog();
  renderHeader(data);

  // done 배너
  if (data.done) {
    document.getElementById('doneBanner').style.display = 'block';
    document.getElementById('doneBanner').textContent = '완료: ' + data.done;
    document.getElementById('liveBadge').className = 'badge badge-done';
    document.getElementById('liveBadge').textContent = 'DONE';
  }
};

function renderHeader(data) {
  const counts = { idle: 0, in_progress: 0, completed: 0, failed: 0 };
  roles.forEach(r => { counts[r.status] = (counts[r.status] || 0) + 1; });
  const parts = [];
  if (counts.completed) parts.push(counts.completed + ' completed');
  if (counts.in_progress) parts.push(counts.in_progress + ' in_progress');
  if (counts.failed) parts.push(counts.failed + ' failed');
  if (counts.idle) parts.push(counts.idle + ' idle');
  document.getElementById('headerSummary').textContent = 'Roles: ' + roles.length + ' | ' + parts.join(', ');
}

function renderTabs() {
  const container = document.getElementById('tabs');
  container.innerHTML = roles.map(r =>
    '<div class="tab' + (r.id === activeRole ? ' active' : '') + '" onclick="selectRole(\\'' + r.id + '\\')">'
    + '<span class="dot dot-' + r.status + '"></span>'
    + 'Role ' + r.id
    + '</div>'
  ).join('');
}

function selectRole(id) {
  activeRole = id;
  autoScroll = true;
  renderTabs();
  renderSidebar();
  renderLog();
}

function renderSidebar() {
  const r = roles.find(r => r.id === activeRole);
  if (!r) { document.getElementById('sidebar').innerHTML = ''; return; }

  document.getElementById('sidebar').innerHTML =
    '<h3>Role ' + r.id + '</h3>'
    + infoRow('Status', '<span class="status-badge status-' + r.status + '">' + r.status + '</span>')
    + infoRow('Locked', r.locked)
    + infoRow('PID', r.locked_by)
    + infoRow('Goal', esc(r.goal))
    + infoRow('Target', esc(r.target))
    + infoRow('Log Size', formatSize(r.logSize))
    + (r.summary ? '<div class="role-summary">' + esc(r.summary) + '</div>' : '');
}

function infoRow(label, value) {
  return '<div class="info-row"><span class="label">' + label + '</span><span class="value">' + value + '</span></div>';
}

function renderLog() {
  const r = roles.find(r => r.id === activeRole);
  if (!r) return;

  const content = r.log || '(로그 없음)';
  const filter = document.getElementById('logFilter').value.trim();
  let regex = null;
  if (filter) { try { regex = new RegExp(filter, 'gi'); } catch {} }

  const lines = content.split('\\n');
  const container = document.getElementById('logContent');
  const wasAtBottom = container.scrollHeight - container.scrollTop - container.clientHeight < 60;

  let html = '';
  lines.forEach((line, i) => {
    if (regex && !regex.test(line)) { regex.lastIndex = 0; return; }
    if (regex) regex.lastIndex = 0;

    let cls = 'log-line';
    const lower = line.toLowerCase();
    if (/\\b(error|err|fatal|panic)\\b/.test(lower)) cls += ' level-error';
    else if (/\\b(warn|warning)\\b/.test(lower)) cls += ' level-warn';
    else if (/\\b(info)\\b/.test(lower)) cls += ' level-info';
    else if (/\\b(debug|trace)\\b/.test(lower)) cls += ' level-debug';

    let txt = esc(line);
    if (regex) {
      txt = txt.replace(regex, m => '<span class="highlight">' + m + '</span>');
      regex.lastIndex = 0;
    }

    html += '<div class="' + cls + '"><span class="ln">' + (i+1) + '</span>' + txt + '</div>';
  });

  container.innerHTML = html;
  document.getElementById('logSize').textContent = formatSize(r.logSize) + ' | ' + lines.length + ' lines';

  if (autoScroll && wasAtBottom) scrollBottom();

  // 스크롤 버튼
  const atBottom = container.scrollHeight - container.scrollTop - container.clientHeight < 60;
  document.getElementById('scrollBtn').style.display = atBottom ? 'none' : 'block';
}

document.getElementById('logContent').addEventListener('scroll', function() {
  const atBottom = this.scrollHeight - this.scrollTop - this.clientHeight < 60;
  autoScroll = atBottom;
  document.getElementById('scrollBtn').style.display = atBottom ? 'none' : 'block';
});

document.getElementById('logFilter').addEventListener('input', renderLog);

function scrollBottom() {
  const el = document.getElementById('logContent');
  el.scrollTop = el.scrollHeight;
  autoScroll = true;
  document.getElementById('scrollBtn').style.display = 'none';
}

function esc(s) { return String(s).replace(/&/g,'&amp;').replace(/</g,'&lt;').replace(/>/g,'&gt;'); }

function formatSize(bytes) {
  if (!bytes) return '0 B';
  if (bytes < 1024) return bytes + ' B';
  if (bytes < 1024*1024) return (bytes/1024).toFixed(1) + ' KB';
  return (bytes/1024/1024).toFixed(1) + ' MB';
}
</script>

</body>
</html>`;
