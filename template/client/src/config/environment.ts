/**
 * Runtime configuration, read from Vite env vars so one build can be pointed at
 * any deployment. Mirrors what `scripts/set-environment.js` generated for the
 * Angular client, minus the codegen step: Vite substitutes these at build time.
 */
export interface Environment {
  production: boolean;
  apiUrl: string;
  /**
   * Andy Auth issuer. Empty disables authentication entirely, which matches the
   * backend: with `AndyAuth:Authority` unset the API falls through to an
   * allow-all policy, so a client that demanded a token could never sign in.
   */
  oidcAuthority: string;
  oidcClientId: string;
  oidcScope: string;
}

export const environment: Environment = {
  production: import.meta.env.PROD,
  apiUrl: import.meta.env.VITE_API_URL ?? '/api',
  oidcAuthority: import.meta.env.VITE_OIDC_AUTHORITY ?? '',
  oidcClientId: import.meta.env.VITE_OIDC_CLIENT_ID ?? '',
  oidcScope: import.meta.env.VITE_OIDC_SCOPE ?? 'openid profile email',
};

/** True when an issuer is configured. Everything auth-related keys off this. */
export const authEnabled = environment.oidcAuthority.length > 0;
