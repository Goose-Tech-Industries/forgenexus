import * as Sentry from '@sentry/sveltekit';
import { handleErrorWithSentry, replayIntegration } from '@sentry/sveltekit';

const dsn = import.meta.env.VITE_SENTRY_DSN as string | undefined;

if (dsn) {
  Sentry.init({
    dsn,
    environment: import.meta.env.MODE,
    release: import.meta.env.VITE_BUILD_ID,
    tracesSampleRate: 0.1,
    replaysSessionSampleRate: 0.0,
    replaysOnErrorSampleRate: 1.0,
    integrations: [replayIntegration()]
  });
}

export const handleError = handleErrorWithSentry();
