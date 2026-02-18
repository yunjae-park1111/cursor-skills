#!/usr/bin/env node
// stream-json 로그를 사람이 읽을 수 있는 형태로 실시간 변환
// Usage: <stream> | node parse-stream.js <output-file>
const fs = require('fs');
const readline = require('readline');

const outFile = process.argv[2];
if (!outFile) { console.error('Usage: parse-stream.js <output-file>'); process.exit(1); }

const fd = fs.openSync(outFile, 'w');
function emit(text) { fs.writeSync(fd, text); }

const rl = readline.createInterface({ input: process.stdin });
let inThinking = false;

rl.on('line', (line) => {
  line = line.replace(/^\x04+/, '');
  if (!line) return;
  let j;
  try { j = JSON.parse(line); } catch { return; }
  switch (j.type) {
    case 'system':
      if (j.subtype === 'init') emit(`[INIT] model=${j.model}\n`);
      break;
    case 'thinking':
      if (j.subtype === 'delta') {
        if (!inThinking) { emit('[THINKING]\n'); inThinking = true; }
        emit(j.text);
      } else if (j.subtype === 'completed') {
        if (inThinking) { emit('\n\n'); inThinking = false; }
      }
      break;
    case 'tool_call': {
      if (inThinking) { emit('\n\n'); inThinking = false; }
      const tc = j.tool_call;
      const name = Object.keys(tc)[0];
      if (j.subtype === 'started') {
        const args = tc[name]?.args || {};
        const detail = args.path || args.pattern || args.command?.substring(0, 100) || '';
        emit(`[TOOL] ${name}${detail ? ' → ' + detail : ''}\n`);
      }
      break;
    }
    case 'assistant': {
      if (inThinking) { emit('\n\n'); inThinking = false; }
      const text = j.message?.content?.[0]?.text;
      if (text && !j.timestamp_ms) emit(`[ASSISTANT]\n${text}\n\n`);
      break;
    }
    case 'result':
      if (inThinking) { emit('\n\n'); inThinking = false; }
      emit(`[RESULT]\n${j.subtype} duration=${j.duration_ms}ms\n\n`);
      break;
  }
});

rl.on('close', () => fs.closeSync(fd));
