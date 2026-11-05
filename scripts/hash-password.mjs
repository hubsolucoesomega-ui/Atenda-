// Gera o hash de senha no formato usado pelo Worker (PBKDF2-SHA256, 100 mil iterações).
// Uso: node scripts/hash-password.mjs "nova-senha"
import { pbkdf2Sync, randomBytes } from 'node:crypto';

const password = process.argv[2];
if (!password || password.length < 8) {
  console.error('Informe uma senha com pelo menos 8 caracteres.');
  process.exit(1);
}
const salt = randomBytes(16);
const hash = pbkdf2Sync(password, salt, 100000, 32, 'sha256');
console.log(`pbkdf2_sha256$100000$${salt.toString('hex')}$${hash.toString('hex')}`);
