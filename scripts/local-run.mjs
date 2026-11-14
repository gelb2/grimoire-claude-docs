#!/usr/bin/env node
// 명시한 로컬 설정만 전달한다. 개인 셸의 API 키와 .env 기본값 유입을 차단한다.
import { readFileSync } from 'node:fs'
import { fileURLToPath } from 'node:url'
import path from 'node:path'
import { spawn } from 'node:child_process'

const [configPath, target, action] = process.argv.slice(2)
const commands = {
  server: {
    generate: ['prisma:generate'], migrate: ['prisma:migrate:deploy'],
    seed: ['seed:demo'], admin: ['seed:admin'], build: ['build'],
    test: ['test', '--', '--runInBand'], start: ['start:prod'],
  },
  web: { build: ['build'], test: ['test'], start: ['dev', '--', '--hostname', '127.0.0.1', '--port', '3001'] },
}

try {
  if (!path.isAbsolute(configPath ?? '') || !commands[target]?.[action]) {
    throw new Error('사용법: node scripts/local-run.mjs /절대경로/local.env server|web 명령')
  }
  const settings = {}
  for (const line of readFileSync(configPath, 'utf8').split(/\r?\n/)) {
    if (!line.trim() || line.trim().startsWith('#')) continue
    const match = line.match(/^([A-Z][A-Z0-9_]*)=(.*)$/)
    if (!match) throw new Error('설정은 KEY=value 형식으로 작성하세요')
    settings[match[1]] = match[2].replace(/^(["'])(.*)\1$/, '$2')
  }
  const db = new URL(settings.DATABASE_URL ?? '')
  if (settings.APP_ENV !== 'localhost' ||
      !['postgres:', 'postgresql:'].includes(db.protocol) ||
      !['localhost', '127.0.0.1', '[::1]'].includes(db.hostname) ||
      !db.port || db.port === '5432' || db.search || db.hash) {
    throw new Error('APP_ENV=localhost와 기본 5432에서 분리한 루프백 DATABASE_URL이 필요합니다')
  }
  if (!settings.JWT_SECRET || settings.JWT_SECRET.length < 32) {
    throw new Error('JWT_SECRET는 직접 생성한 32자 이상 값이 필요합니다')
  }
  const localPort = (key, fallback) => {
    const raw = settings[key] ?? String(fallback)
    if (!/^[0-9]+$/.test(raw) || Number(raw) < 1024 || Number(raw) > 65535) {
      throw new Error(`${key}는 1024~65535 범위 포트여야 합니다`)
    }
    return String(Number(raw))
  }
  const apiPort = localPort('LOCAL_API_PORT', 3000)
  const webPort = localPort('LOCAL_WEB_PORT', 3001)
  if (apiPort === webPort || [apiPort, webPort].includes(db.port)) {
    throw new Error('웹·API·DB 포트는 서로 달라야 합니다')
  }
  commands.web.start = ['dev', '--', '--hostname', '127.0.0.1', '--port', webPort]
  const env = {}
  for (const key of ['PATH', 'HOME', 'TMPDIR', 'LANG', 'USER', 'SYSTEMROOT']) {
    if (process.env[key]) env[key] = process.env[key]
  }
  for (const key of ['DATABASE_URL', 'JWT_SECRET', 'SEED_PASSWORD', 'SEED_ADMIN_SLUG',
    'SEED_ADMIN_EMAIL', 'SEED_ADMIN_NAME', 'SEED_ADMIN_PASSWORD', 'LEGAL_CONTACT_EMAIL']) {
    if (settings[key]) env[key] = settings[key]
  }
  Object.assign(env, {
    APP_ENV: 'localhost', NODE_ENV: action === 'test' ? 'test' : action === 'build' || (target === 'server' && action === 'start') ? 'production' : 'development',
    HOST: '127.0.0.1', API_URL: `http://localhost:${apiPort}/api`,
    PUBLIC_API_BASE_URL: `http://localhost:${apiPort}/api`, CORS_ORIGIN: `http://localhost:${webPort}`,
    PORT: target === 'server' ? apiPort : webPort, NEXT_PUBLIC_APP_ENV: 'localhost', NEXT_PUBLIC_SITE_URL: `http://localhost:${webPort}`,
    NEXT_PUBLIC_GOOGLE_CLIENT_ID: '', NEXT_PUBLIC_RECAPTCHA_SITE_KEY: '', NEXT_PUBLIC_API_ORIGIN: '',
    ANTHROPIC_API_KEY: '', OPENAI_API_KEY: '', OPENAI_KEY: '', GOOGLE_CLIENT_ID: '',
    RECAPTCHA_SECRET_KEY: '', GCS_BUCKET: '', GOOGLE_APPLICATION_CREDENTIALS: '',
    POLAR_ACCESS_TOKEN: '', POLAR_WEBHOOK_SECRET: '', POLAR_SERVER: 'sandbox',
    EMAIL_PROVIDER: 'null', EMAIL_FROM_ADDRESS: '', EMAIL_TOKEN_PEPPER: '',
    RESEND_API_KEY: '', SENDGRID_API_KEY: '',
    RECONCILIATION_DISABLED: '1', WEBHOOK_RETRY_DISABLED: '1', PAYMENT_CLEANUP_DISABLED: '1',
    MONTHLY_POOL_RESET_DISABLED: '1', USER_HARD_DELETE_DISABLED: '1', AUDIT_MASK_DISABLED: '1',
    NEXT_TELEMETRY_DISABLED: '1',
  })
  // 유닛 검사는 각 fixture가 환경과 cron 비활성 분기를 직접 설정한다.
  // 서버를 시작하지 않으므로 실행용 플래그를 강제로 덮어 주지 않는다.
  if (action === 'test') {
    delete env.APP_ENV
    for (const key of Object.keys(env)) if (key.endsWith('_DISABLED')) delete env[key]
  }
  const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..')
  const child = spawn('npm', ['run', ...commands[target][action]], {
    cwd: path.join(root, `grimoire-${target}`), env, stdio: 'inherit',
  })
  for (const signal of ['SIGINT', 'SIGTERM']) process.on(signal, () => child.kill(signal))
  child.on('error', () => { console.error('로컬 명령 시작 실패'); process.exitCode = 1 })
  child.on('exit', (code) => { process.exitCode = code ?? 1 })
} catch (error) {
  // URL 파싱 오류 등에서 입력 비밀값을 출력하지 않는다.
  console.error(error instanceof TypeError ? '로컬 DB URL 형식을 확인하세요' : error.message)
  process.exitCode = 1
}
