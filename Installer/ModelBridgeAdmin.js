#!/usr/bin/env node
'use strict';

// ModelBridge 本地管理页（单文件 Node 服务，无第三方依赖）
// 只监听 127.0.0.1，职责：
//   1. 展示网关健康状态、模型、端口、版本、日志；
//   2. 修改模型/端口并重启网关（写入 modelbridge.conf，ModelBridge.sh 启动时读取）；
//   3. 按协议给出各 Agent 的 baseURL / key / model，供复制到客户端。
// 安全：绑定回环 + 每次启动生成 admin.token，写操作必须带 X-Admin-Token。

const http = require('http');
const fs = require('fs');
const path = require('path');
const crypto = require('crypto');
const { execFileSync } = require('child_process');

const DIR = process.env.MODELBRIDGE_INSTALL_DIR || '/opt/youjingsenlin';
const CONF_FILE = path.join(DIR, 'modelbridge.conf');
const ENV_FILE = path.join(DIR, 'modelbridge.env');
const LOG_FILE = path.join(DIR, 'modelbridge.log');
const LAUNCHER = path.join(DIR, 'ModelBridge.sh');
const PAGE_FILE = path.join(DIR, 'ModelBridgeAdmin.html');
const TOKEN_FILE = path.join(DIR, 'admin.token');
const PORT = Number(process.env.MODELBRIDGE_ADMIN_PORT || 8788);
const DEFAULT_MODEL = 'deepseek-v4-flash';
const DEFAULT_PORT = 8787;

const AGENTS = [
  { name: 'ClaudeCode', cmd: 'claude', mode: 'anthropic', note: '读 ANTHROPIC_BASE_URL / ANTHROPIC_AUTH_TOKEN' },
  { name: 'CodeBuddy', cmd: 'codebuddy', mode: 'openai', note: '读 OPENAI_* 或应用内自定义 baseURL' },
  { name: 'DeepSeek', cmd: 'dsh', mode: 'app', note: 'Web 界面，需在网页里配置' },
  { name: 'Codex', cmd: 'codex', mode: 'openai', note: '读 OPENAI_BASE_URL / OPENAI_API_KEY' },
  { name: 'Gemini', cmd: 'gemini', mode: 'gemini', note: '读 GOOGLE_GEMINI_BASE_URL / GEMINI_API_KEY' },
  { name: 'Copilot', cmd: 'copilot', mode: 'app', note: '走 GitHub 登录，通常不支持自定义 baseURL' },
  { name: 'Qwen', cmd: 'qwen', mode: 'openai', note: '读 OPENAI_BASE_URL / OPENAI_API_KEY / OPENAI_MODEL' },
  { name: 'Amp', cmd: 'amp', mode: 'app', note: '应用内登录，通常不支持自定义 baseURL' },
  { name: 'Crush', cmd: 'crush', mode: 'openai', note: '支持自定义 OpenAI 兼容 provider' },
  { name: 'OpenCode', cmd: 'opencode', mode: 'openai', note: '在 opencode.json 里配置 provider' },
  { name: 'Continue', cmd: 'cn', mode: 'openai', note: '在 Continue 配置里填写 OpenAI 兼容地址' },
  { name: 'iFlow', cmd: 'iflow', mode: 'openai', note: '支持自定义 OpenAI 兼容地址时可直接填' },
  { name: 'Cursor', cmd: 'cursor-agent', mode: 'app', note: 'Cursor 账号体系，通常不支持自定义 baseURL' }
];

function readToken() {
  try {
    const t = fs.readFileSync(TOKEN_FILE, 'utf8').trim();
    if (t) return t;
  } catch (_) { /* 首次启动 */ }
  const t = crypto.randomBytes(24).toString('hex');
  fs.mkdirSync(DIR, { recursive: true });
  fs.writeFileSync(TOKEN_FILE, t, { mode: 0o600 });
  return t;
}
const TOKEN = readToken();

function readConf() {
  const conf = { model: DEFAULT_MODEL, port: DEFAULT_PORT };
  try {
    for (const line of fs.readFileSync(CONF_FILE, 'utf8').split('\n')) {
      const m = line.match(/^MODELBRIDGE_(MODEL|PORT)=(.*)$/);
      if (!m) continue;
      if (m[1] === 'MODEL') conf.model = m[2].trim();
      if (m[1] === 'PORT') conf.port = Number(m[2].trim()) || DEFAULT_PORT;
    }
  } catch (_) { /* 没有 conf 就用默认值 */ }
  return conf;
}

function writeConf(model, port) {
  fs.mkdirSync(DIR, { recursive: true });
  fs.writeFileSync(CONF_FILE, `MODELBRIDGE_MODEL=${model}\nMODELBRIDGE_PORT=${port}\n`, { mode: 0o644 });
}

function tail(file, lines) {
  let fd = null;
  try {
    fd = fs.openSync(file, 'r');
    const size = fs.fstatSync(fd).size;
    // 只读末尾 256KB，日志涨大后也不会每次把整份文件读进内存
    const bytes = Math.min(size, 256 * 1024);
    const buf = Buffer.alloc(bytes);
    fs.readSync(fd, buf, 0, bytes, size - bytes);
    return buf.toString('utf8').split('\n').slice(-lines).join('\n');
  } catch (_) {
    return '';
  } finally {
    if (fd !== null) {
      try { fs.closeSync(fd); } catch (_) { /* 忽略关闭失败 */ }
    }
  }
}

function commandExists(cmd) {
  try {
    execFileSync('bash', ['-c', `command -v ${cmd}`], { stdio: 'ignore', timeout: 2000 });
    return true;
  } catch (_) {
    return false;
  }
}

// Agent 是镜像里预装的，运行期不会变；启动时探测一次即可，避免每个状态请求都起 13 个 shell
const AGENT_INSTALLED = new Map(AGENTS.map((a) => [a.cmd, commandExists(a.cmd)]));

function httpGet(url, timeout = 1500) {
  return new Promise((resolve) => {
    const req = http.get(url, (res) => {
      let body = '';
      res.setEncoding('utf8');
      res.on('data', (chunk) => { body += chunk; });
      res.on('end', () => resolve({ ok: res.statusCode === 200, status: res.statusCode, body }));
    });
    req.on('error', (err) => resolve({ ok: false, error: err.message }));
    req.setTimeout(timeout, () => {
      req.destroy();
      resolve({ ok: false, error: 'timeout' });
    });
  });
}

function parseJson(text) {
  try { return JSON.parse(text); } catch (_) { return null; }
}

function readPid() {
  try { return fs.readFileSync(path.join(DIR, 'modelbridge.pid'), 'utf8').trim(); } catch (_) { return null; }
}

function json(res, code, data) {
  const body = JSON.stringify(data);
  res.writeHead(code, { 'Content-Type': 'application/json; charset=utf-8', 'Cache-Control': 'no-store' });
  res.end(body);
}

function readBody(req, limit = 65536) {
  return new Promise((resolve, reject) => {
    let size = 0;
    let body = '';
    req.on('data', (chunk) => {
      size += chunk.length;
      if (size > limit) {
        reject(new Error('请求体过大'));
        req.destroy();
        return;
      }
      body += chunk;
    });
    req.on('end', () => resolve(body));
    req.on('error', reject);
  });
}

async function collectStatus() {
  const conf = readConf();
  const base = `http://127.0.0.1:${conf.port}`;
  const health = await httpGet(`${base}/healthz`);
  const info = health.ok ? parseJson(health.body) : null;
  return {
    ok: true,
    gateway: {
      running: health.ok,
      port: conf.port,
      model: conf.model,
      version: info && info.version ? info.version : null,
      commit: info && info.commit ? info.commit : null,
      pid: readPid(),
      envReady: fs.existsSync(ENV_FILE),
      error: health.ok ? null : (health.error || `HTTP ${health.status}`)
    },
    agents: AGENTS.map((a) => ({
      name: a.name,
      cmd: a.cmd,
      mode: a.mode,
      note: a.note,
      installed: AGENT_INSTALLED.get(a.cmd) === true
    })),
    log: tail(LOG_FILE, 15)
  };
}

function requireToken(req, res) {
  if (req.headers['x-admin-token'] === TOKEN) return true;
  json(res, 403, { ok: false, error: '缺少或错误的 X-Admin-Token' });
  return false;
}

const server = http.createServer(async (req, res) => {
  const url = new URL(req.url, `http://127.0.0.1:${PORT}`);
  const pathname = url.pathname;

  try {
    if (req.method === 'GET' && pathname === '/healthz') {
      res.writeHead(200, { 'Content-Type': 'text/plain; charset=utf-8' });
      res.end('ok');
      return;
    }

    if (req.method === 'GET' && (pathname === '/' || pathname === '/index.html')) {
      let html = fs.readFileSync(PAGE_FILE, 'utf8');
      html = html.replace(/__ADMIN_TOKEN__/g, TOKEN);
      res.writeHead(200, { 'Content-Type': 'text/html; charset=utf-8', 'Cache-Control': 'no-store' });
      res.end(html);
      return;
    }

    if (req.method === 'GET' && pathname === '/api/status') {
      json(res, 200, await collectStatus());
      return;
    }

    if (req.method === 'GET' && pathname === '/api/log') {
      const lines = Math.min(Math.max(Number(url.searchParams.get('lines')) || 200, 10), 1000);
      res.writeHead(200, { 'Content-Type': 'text/plain; charset=utf-8', 'Cache-Control': 'no-store' });
      res.end(tail(LOG_FILE, lines));
      return;
    }

    if (req.method === 'GET' && pathname === '/api/test') {
      const conf = readConf();
      const r = await httpGet(`http://127.0.0.1:${conf.port}/v1/models`, 5000);
      const parsed = parseJson(r.body);
      json(res, 200, {
        ok: r.ok,
        status: r.status || null,
        error: r.ok ? null : (r.error || null),
        models: parsed && Array.isArray(parsed.data) ? parsed.data.map((m) => m.id) : null,
        body: parsed ? null : (r.body || '').slice(0, 500)
      });
      return;
    }

    if (req.method === 'POST' && pathname === '/api/config') {
      if (!requireToken(req, res)) return;
      const raw = await readBody(req);
      const body = parseJson(raw) || {};
      const model = String(body.model || '').trim();
      const port = Number(body.port);
      if (!/^[A-Za-z0-9._:\/-]{1,64}$/.test(model)) {
        json(res, 400, { ok: false, error: '模型名只允许字母、数字和 . _ : / -，最长 64 字符' });
        return;
      }
      if (!Number.isInteger(port) || port < 1024 || port > 65535) {
        json(res, 400, { ok: false, error: '端口必须是 1024-65535 的整数' });
        return;
      }
      writeConf(model, port);
      let output = '';
      let failed = false;
      try {
        output = execFileSync('bash', [LAUNCHER, 'restart'], {
          encoding: 'utf8',
          timeout: 40000,
          env: Object.assign({}, process.env, {
            MODELBRIDGE_MODEL: model,
            MODELBRIDGE_PORT: String(port)
          })
        });
      } catch (err) {
        failed = true;
        output = `${err.stdout || ''}${err.stderr || ''}${err.message || ''}`;
      }
      json(res, failed ? 500 : 200, { ok: !failed, output: output.trim().slice(0, 3000), gateway: (await collectStatus()).gateway });
      return;
    }

    if (req.method === 'POST' && pathname === '/api/restart') {
      if (!requireToken(req, res)) return;
      let output = '';
      let failed = false;
      try {
        output = execFileSync('bash', [LAUNCHER, 'restart'], { encoding: 'utf8', timeout: 40000 });
      } catch (err) {
        failed = true;
        output = `${err.stdout || ''}${err.stderr || ''}${err.message || ''}`;
      }
      json(res, failed ? 500 : 200, { ok: !failed, output: output.trim().slice(0, 3000), gateway: (await collectStatus()).gateway });
      return;
    }

    json(res, 404, { ok: false, error: 'not found' });
  } catch (err) {
    json(res, 500, { ok: false, error: err.message || String(err) });
  }
});

server.listen(PORT, '127.0.0.1', () => {
  process.stdout.write(`[${new Date().toISOString()}] modelbridge admin listening on http://127.0.0.1:${PORT}\n`);
});
