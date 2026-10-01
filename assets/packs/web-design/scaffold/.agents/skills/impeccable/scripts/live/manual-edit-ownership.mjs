import fs from 'node:fs';
import path from 'node:path';
import { randomUUID } from 'node:crypto';
import { AsyncLocalStorage } from 'node:async_hooks';
import { execFileSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';
import { getLiveDir } from '../lib/impeccable-paths.mjs';

const ownershipContext = new AsyncLocalStorage();
const ownershipRoot = (cwd) => path.dirname(path.dirname(getLiveDir(cwd)));

function blocked(message) {
  const error = new Error(message);
  error.code = 'MANUAL_EDIT_OPERATION_OWNED';
  return error;
}

function processIdentity(pid) {
  try {
    const value = fs.readFileSync('/proc/' + pid + '/stat', 'utf8');
    return value.slice(value.lastIndexOf(')') + 2).split(' ')[19];
  } catch (error) {
    if (error.code === 'ENOENT' || error.code === 'ESRCH') return null;
    throw blocked('Cannot inspect manual-edit owner identity: ' + error.message);
  }
}

export function manualEditOwnershipPath(cwd = process.cwd()) {
  return path.join(getLiveDir(cwd), 'manual-edit-operation-owner.json');
}

function safePath(file, directory = false) {
  let current = path.resolve(file);
  let leaf = true;
  for (;;) {
    try {
      const info = fs.lstatSync(current);
      if (info.isSymbolicLink()) throw blocked('Unsafe manual-edit ownership symlink: ' + current);
      if (leaf && !directory && (!info.isFile() || info.nlink !== 1)) throw blocked('Unsafe manual-edit ownership file: ' + current);
    } catch (error) {
      if (error.code !== 'ENOENT') throw error;
    }
    const parent = path.dirname(current);
    if (parent === current) break;
    current = parent;
    leaf = false;
  }
}

function readOwner(cwd) {
  const file = manualEditOwnershipPath(cwd);
  safePath(file);
  if (!fs.existsSync(file)) return null;
  try {
    const owner = JSON.parse(fs.readFileSync(file, 'utf8'));
    if (!owner || owner.version !== 1 || owner.cwd !== ownershipRoot(cwd) ||
        typeof owner.id !== 'string' || !owner.id || !Number.isSafeInteger(owner.pid) || owner.pid <= 0 ||
        typeof owner.birth !== 'string' || !/^[0-9]+$/.test(owner.birth) || !Array.isArray(owner.workers) ||
        typeof (owner.released ?? false) !== 'boolean' || typeof (owner.externalWriterActive ?? false) !== 'boolean' ||
        !Array.isArray(owner.verifiedPreviousOwnerIds ?? []) || (owner.verifiedPreviousOwnerIds ?? []).some(id => typeof id !== 'string' || !id) ||
        owner.workers.some(worker => !worker || typeof worker.nonce !== 'string' || !worker.nonce ||
          typeof worker.statusPath !== 'string' || !worker.statusPath ||
          worker.pid !== null && (!Number.isSafeInteger(worker.pid) || worker.pid <= 0))) {
      throw new Error('invalid ownership record');
    }
    return owner;
  } catch (error) {
    throw blocked('Manual-edit ownership is unreadable; preserve transaction and inspect: ' + error.message);
  }
}

function persistOwner(owner) {
  const file = manualEditOwnershipPath(owner.cwd);
  safePath(file);
  const temporary = file + '.' + randomUUID() + '.tmp';
  try {
    fs.writeFileSync(temporary, JSON.stringify(owner), { flag: 'wx', mode: 0o600 });
    fs.renameSync(temporary, file);
  } finally {
    if (fs.existsSync(temporary)) fs.unlinkSync(temporary);
  }
}

function certificatesQuiescent(owner) {
  if (owner.externalWriterActive) return false;
  return owner.workers.every((worker) => {
    try {
      safePath(worker.statusPath);
      const result = JSON.parse(fs.readFileSync(worker.statusPath, 'utf8'));
      return result.nonce === worker.nonce && result.quiescent === true &&
        (Number.isSafeInteger(result.supervisor_pid) && result.supervisor_pid > 0 ||
          result.supervisor_pid === 0 && result.noLauncherStarted === true && worker.pid === null) &&
        (worker.pid === null || result.supervisor_pid === worker.pid);
    } catch { return false; }
  });
}

export function acquireManualEditOwnership(cwd = process.cwd()) {
  if (process.platform !== 'linux') {
    throw blocked('Supervised manual Apply requires Linux or WSL; no transaction was restored or worker launched');
  }
  const root = ownershipRoot(cwd);
  const file = manualEditOwnershipPath(root);
  safePath(file);
  try {
    // Kernel flock serializes stale-lease recovery with fresh acquisition. A
    // read/unlink/create sequence alone could delete another process's lease.
    return JSON.parse(execFileSync('python3', [fileURLToPath(new URL('./manual-edit-owner-lock.py', import.meta.url)),
      '--file', file, '--cwd', root, '--pid', String(process.pid),
      '--birth', processIdentity(process.pid), '--id', randomUUID()],
    { encoding: 'utf8', timeout: 3000, stdio: ['ignore', 'pipe', 'pipe'] }));
  } catch (error) {
    throw blocked(error.stderr?.toString?.().trim() || error.message);
  }
}

function assertCurrent(owner) {
  const current = readOwner(owner.cwd);
  if (!current || current.id !== owner.id || current.pid !== process.pid ||
      current.birth !== processIdentity(process.pid) || current.released === true) {
    throw blocked('Manual-edit operation lost ownership; preserve transaction');
  }
}

export function runWithManualEditOwnership(owner, callback) {
  assertCurrent(owner);
  return ownershipContext.run(owner, callback);
}

export function currentManualEditOwnership(cwd = process.cwd()) {
  const owner = ownershipContext.getStore();
  return owner?.cwd === ownershipRoot(cwd) ? owner : null;
}

export function assertManualEditQuiescent(owner) {
  assertCurrent(owner);
  if (!certificatesQuiescent(owner)) {
    throw blocked('Owned manual-edit writers are not confirmed stopped; preserve transaction and do not restore or clear it');
  }
}

export function finishManualEditOwnership(owner) {
  assertCurrent(owner);
  if (!certificatesQuiescent(owner)) return false;
  // Keep the proven old owner binding for retained repair transactions. Fresh
  // acquisition carries it forward only after locked certificate validation.
  owner.released = true;
  persistOwner(owner);
  return true;
}

export function assertManualEditTransactionOwner(cwd, transaction) {
  const owner = currentManualEditOwnership(cwd);
  if (!owner || transaction.version !== 2 || !transaction.ownershipId ||
      transaction.ownershipId !== owner.id && !owner.verifiedPreviousOwnerIds?.includes(transaction.ownershipId)) {
    throw blocked('Transaction has no verified original-owner shutdown proof; preserve recovery evidence and inspect ownership');
  }
}

export function withSynchronousManualEditOwnership(cwd, callback) {
  const existing = currentManualEditOwnership(cwd);
  if (existing) {
    assertManualEditQuiescent(existing);
    return callback();
  }
  const owner = acquireManualEditOwnership(cwd);
  try { return runWithManualEditOwnership(owner, callback); }
  finally { finishManualEditOwnership(owner); }
}

export async function withManualEditOwnership(cwd, callback) {
  const existing = currentManualEditOwnership(cwd);
  if (existing) {
    assertCurrent(existing);
    return callback();
  }
  const owner = acquireManualEditOwnership(cwd);
  try { return await runWithManualEditOwnership(owner, callback); }
  finally { finishManualEditOwnership(owner); }
}

export function prepareManualEditWorker(cwd, nonce) {
  const owner = currentManualEditOwnership(cwd);
  if (!owner) throw blocked('Worker launch requires durable manual-edit operation ownership');
  assertCurrent(owner);
  const folder = path.join(getLiveDir(cwd), 'manual-edit-worker-evidence', owner.id);
  safePath(folder, true);
  fs.mkdirSync(folder, { recursive: true, mode: 0o700 });
  const statusPath = path.join(folder, nonce + '.json');
  safePath(statusPath);
  fs.writeFileSync(statusPath, '', { flag: 'wx', mode: 0o600 });
  const worker = { statusPath, nonce, pid: null };
  owner.workers.push(worker);
  persistOwner(owner); // Durable intent BEFORE launching the supervisor.
  return { statusPath, confirmNoLaunch: () => {
    assertCurrent(owner);
    if (worker.pid !== null) throw blocked('Cannot declare no launch after assigning a supervisor PID');
    safePath(statusPath);
    fs.writeFileSync(statusPath, JSON.stringify({ nonce, supervisor_pid: 0,
      noLauncherStarted: true, quiescent: true }), { mode: 0o600 });
  }, registerPid: (pid) => {
    worker.pid = pid;
    assertCurrent(owner);
    persistOwner(owner);
  } };
}

export function markExternalManualEditWriter(cwd, active) {
  const owner = currentManualEditOwnership(cwd);
  if (!owner) throw blocked('Chat Apply requires durable operation ownership');
  assertCurrent(owner);
  owner.externalWriterActive = active;
  persistOwner(owner);
}
