// @ts-check
import { execSync } from 'child_process';
console.log('Installing dependencies');
execSync('npm ci', { stdio: 'inherit' });