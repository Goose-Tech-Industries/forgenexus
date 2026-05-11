import { defineConfig } from '@playwright/test';

export default defineConfig({
  testDir: './tests',
  timeout: 30000,
  retries: 2,
  workers: 1,
  use: {
    baseURL: 'http://localhost:5173',
    headless: true,
    screenshot: 'only-on-failure',
    trace: 'retain-on-failure',
    actionTimeout: 10000,
    navigationTimeout: 15000,
  },
  projects: [
    {
      name: 'api-smoke',
      testMatch: 'api-smoke.spec.ts',
      use: { baseURL: 'http://localhost:4000', browserName: 'chromium' }
    },
    {
      name: 'api-backend',
      testMatch: 'api-backend.spec.ts',
      use: { baseURL: 'http://localhost:4000', browserName: 'chromium' }
    },
    {
      name: 'e2e',
      testMatch: 'e2e-full.spec.ts',
      use: { browserName: 'chromium' }
    },
    {
      name: 'e2e-admin',
      testMatch: 'e2e-admin.spec.ts',
      use: { browserName: 'chromium' }
    },
    {
      name: 'e2e-actions',
      testMatch: 'e2e-actions.spec.ts',
      use: { browserName: 'chromium' }
    },
    {
      name: 'e2e-complete',
      testMatch: 'e2e-complete.spec.ts',
      use: { browserName: 'chromium' }
    },
    {
      name: 'comprehensive',
      testMatch: 'comprehensive.spec.ts',
      use: { browserName: 'chromium' },
      retries: 1
    }
  ],
  reporter: [['list']],
  webServer: {
    command: 'npm run dev',
    url: 'http://localhost:5173',
    reuseExistingServer: true,
    timeout: 30000,
  },
});
