#!/usr/bin/env node

/**
 * Environment Configuration Verification Script
 *
 * This script checks for common environment configuration issues:
 * 1. Ensures no default expansion (${VAR:-default}) in compose files
 * 2. Verifies env files don't have trailing spaces or CRLF
 * 3. Checks for duplicate ENV definitions in Dockerfiles
 */

import { readFileSync, existsSync, readdirSync, statSync } from 'fs';
import { join, dirname } from 'path';
import { fileURLToPath } from 'url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);
const projectRoot = join(__dirname, '..');

// Recursively find files matching pattern
function findFiles(dir, pattern, ignore = []) {
  const results = [];
  const files = readdirSync(dir, { withFileTypes: true });

  for (const file of files) {
    const fullPath = join(dir, file.name);
    const relativePath = fullPath.replace(projectRoot + '/', '');

    // Skip ignored directories
    if (ignore.some(ig => relativePath.includes(ig))) {
      continue;
    }

    if (file.isDirectory()) {
      results.push(...findFiles(fullPath, pattern, ignore));
    } else if (pattern.test(file.name)) {
      results.push(relativePath);
    }
  }

  return results;
}

let hasErrors = false;

function error(message) {
  console.error(`❌ ${message}`);
  hasErrors = true;
}

function success(message) {
  console.log(`✅ ${message}`);
}

function info(message) {
  console.log(`ℹ️  ${message}`);
}

// Check 1: No default expansion in compose files
info('Checking compose files for default expansion patterns...');
const composeFiles = [
  'compose/compose.dev.yml',
  'reserve-api/docker-compose.dev.yml',
  'reservation-web/docker-compose.dev.yml'
].filter(f => existsSync(join(projectRoot, f)));

for (const file of composeFiles) {
  const content = readFileSync(join(projectRoot, file), 'utf-8');
  const lines = content.split('\n');

  lines.forEach((line, idx) => {
    // Match ${VAR:-default} pattern
    const defaultExpansionPattern = /\$\{[^}]+:-[^}]*\}/g;
    if (defaultExpansionPattern.test(line)) {
      error(`${file}:${idx + 1} contains default expansion: ${line.trim()}`);
    }
  });
}

if (!hasErrors) {
  success('No default expansion patterns found in compose files');
}

// Check 2: No ENV ADMIN_TOKEN in Dockerfiles
info('Checking Dockerfiles for ENV ADMIN_TOKEN definitions...');
const dockerfiles = findFiles(projectRoot, /^Dockerfile/, [
  'node_modules',
  '.next',
  'dist',
  '.git'
]);

for (const file of dockerfiles) {
  const content = readFileSync(join(projectRoot, file), 'utf-8');
  const lines = content.split('\n');

  lines.forEach((line, idx) => {
    if (/^\s*ENV\s+ADMIN_TOKEN/i.test(line)) {
      error(`${file}:${idx + 1} contains ENV ADMIN_TOKEN definition: ${line.trim()}`);
    }
  });
}

if (!hasErrors) {
  success('No ENV ADMIN_TOKEN found in Dockerfiles');
}

// Check 3: Verify env files format
info('Checking env files format...');
const envFiles = [
  'compose/.env.dev',
  'reservation-web/.env.local',
  'reserve-api/.env.dev'
].filter(f => existsSync(join(projectRoot, f)));

for (const file of envFiles) {
  const content = readFileSync(join(projectRoot, file), 'utf-8');

  // Check for CRLF
  if (content.includes('\r\n')) {
    error(`${file} contains CRLF line endings (should be LF)`);
  }

  // Check for trailing spaces on value lines
  const lines = content.split('\n');
  lines.forEach((line, idx) => {
    if (line.includes('=') && /=.*\s+$/.test(line)) {
      error(`${file}:${idx + 1} has trailing spaces: ${line}`);
    }
  });
}

if (!hasErrors) {
  success('All env files have correct format');
}

// Check 4: ADMIN_TOKEN consistency
info('Checking ADMIN_TOKEN consistency across env files...');
const adminTokenValues = new Map();

for (const file of envFiles) {
  const content = readFileSync(join(projectRoot, file), 'utf-8');
  const match = content.match(/^ADMIN_TOKEN=(.+)$/m) ||
                content.match(/^NEXT_PUBLIC_ADMIN_TOKEN=(.+)$/m);

  if (match) {
    const value = match[1].trim();
    adminTokenValues.set(file, value);
  }
}

const uniqueValues = new Set(adminTokenValues.values());
if (uniqueValues.size > 1) {
  error('ADMIN_TOKEN values are inconsistent across env files:');
  for (const [file, value] of adminTokenValues) {
    console.error(`  ${file}: ${value}`);
  }
} else if (uniqueValues.size === 1) {
  success(`All ADMIN_TOKEN values are consistent: ${Array.from(uniqueValues)[0]}`);
}

// Summary
console.log('\n' + '='.repeat(50));
if (hasErrors) {
  console.error('❌ Verification failed! Please fix the issues above.');
  process.exit(1);
} else {
  console.log('✅ All checks passed!');
  process.exit(0);
}
