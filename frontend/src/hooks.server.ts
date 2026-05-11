import * as Sentry from '@sentry/sveltekit';
import { handleErrorWithSentry, sentryHandle } from '@sentry/sveltekit';
import { sequence } from '@sveltejs/kit/hooks';

const dsn = process.env.SENTRY_DSN;

if (dsn) {
  Sentry.init({
    dsn,
    environment: process.env.SENTRY_ENV || 'production',
    release: process.env.BUILD_ID,
    tracesSampleRate: 0.1
  });
}

export const handle = dsn ? sequence(sentryHandle()) : async ({ event, resolve }) => resolve(event);
export const handleError = handleErrorWithSentry();
