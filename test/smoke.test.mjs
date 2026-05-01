import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';

const cwd = process.cwd();

test('env example includes required production keys', () => {
  const envExamplePath = path.join(cwd, '.env.example');
  const envExample = fs.readFileSync(envExamplePath, 'utf8');

  assert.ok(envExample.includes('DATABASE_URL='));
  assert.ok(envExample.includes('JWT_SECRET='));
  assert.ok(envExample.includes('APP_SETTINGS_ENCRYPTION_KEY='));
  assert.ok(envExample.includes('PAYMENT_WEBHOOK_SECRET='));
  assert.ok(envExample.includes('NEXT_PUBLIC_APP_URL='));
});

test('payment runtime supports manual and online methods', () => {
  const runtimePath = path.join(cwd, 'lib', 'payment-runtime.ts');
  const runtimeSource = fs.readFileSync(runtimePath, 'utf8');

  assert.ok(runtimeSource.includes('MANUAL_PAYMENT_METHODS'));
  assert.ok(runtimeSource.includes("GATEWAY_PAYMENT_METHOD = 'online'"));
  assert.ok(runtimeSource.includes("mode: 'manual' | 'gateway'"));
});

test('online payment checkout routes are wired for retry flow', () => {
  const checkoutRoutePath = path.join(cwd, 'app', 'api', 'checkout', 'route.ts');
  const checkoutRouteSource = fs.readFileSync(checkoutRoutePath, 'utf8');

  assert.ok(checkoutRouteSource.includes('gatewayCheckoutUrls'));
  assert.ok(checkoutRouteSource.includes('onlineCheckoutErrors'));

  const retryRoutePath = path.join(
    cwd,
    'app',
    'api',
    'payments',
    '[id]',
    'online-checkout',
    'route.ts'
  );
  assert.ok(fs.existsSync(retryRoutePath));
  const retryRouteSource = fs.readFileSync(retryRoutePath, 'utf8');
  assert.ok(retryRouteSource.includes('createGatewayCheckout'));
});

test('admin readiness endpoint is available', () => {
  const readinessRoutePath = path.join(cwd, 'app', 'api', 'admin', 'readiness', 'route.ts');
  assert.ok(fs.existsSync(readinessRoutePath));
  const readinessRouteSource = fs.readFileSync(readinessRoutePath, 'utf8');
  assert.ok(readinessRouteSource.includes('buildReadinessReport'));
});
