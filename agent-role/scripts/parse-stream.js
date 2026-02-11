#!/usr/bin/env node
// stream-json 로그를 사람이 읽을 수 있는 형태로 실시간 변환
// Usage: tail -f raw.log | node parse-stream.js >> parsed.log
const readline = require('readline');
const rl = readline.createInterface({ input: process.stdin });
let thinkingBuf = '';
let toolBuf = [];

function flushTools() {
  if (toolBuf.length === 0) return;
  console.log(`[TOOL]\n${toolBuf.join('\n')}\n`);
  toolBuf = [];
}

rl.on('line', (line) => {
  line = line.replace(/^\x04+/, '');
  if (!line) return;
  let j;
  try { j = JSON.parse(line); } catch { return; }
  switch (j.type) {
    case 'system':
      if (j.subtype === 'init') console.log(`[INIT] model=${j.model}`);
      break;
    case 'thinking':
      flushTools();
      if (j.subtype === 'delta') thinkingBuf += j.text;
      else if (j.subtype === 'completed' && thinkingBuf) {
        console.log(`[THINKING]\n${thinkingBuf}\n`);
        thinkingBuf = '';
      }
      break;
    case 'tool_call': {
      const tc = j.tool_call;
      const name = Object.keys(tc)[0];
      if (j.subtype === 'started') {
        const args = tc[name]?.args || {};
        const detail = args.path || args.pattern || args.command?.substring(0, 100) || '';
        toolBuf.push(`${name}${detail ? ' → ' + detail : ''}`);
      }
      break;
    }
    case 'assistant': {
      flushTools();
      const text = j.message?.content?.[0]?.text;
      if (text && !j.timestamp_ms) console.log(`[ASSISTANT]\n${text}\n`);
      break;
    }
    case 'result':
      flushTools();
      console.log(`[RESULT]\n${j.subtype} duration=${j.duration_ms}ms\n`);
      break;
  }
});

rl.on('close', () => flushTools());
