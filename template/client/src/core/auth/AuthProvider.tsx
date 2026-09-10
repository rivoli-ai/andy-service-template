import { type ReactNode, useEffect } from 'react';
import { AuthProvider as OidcProvider, useAuth } from 'react-oidc-context';
import { WebStorageStateStore } from 'oidc-client-ts';
import { Navigate, useLocation } from 'react-router-dom';
import { authEnabled, environment } from '../../config/environment';
import { setTokenProvider } from '../api/client';

/**
 * Andy Auth wiring, and the React counterpart of the Angular client's
 * `auth.guard.ts` and `auth.interceptor.ts`.
 *
 * Authentication is opt-in on both sides. The API enables JWT bearer only when
 * `AndyAuth:Authority` is configured and otherwise installs an allow-all policy,
 * so a client that always demanded a token would be unusable against a default
 * backend. `authEnabled` mirrors that switch exactly.
 */

const oidcConfig = {
  authority: environment.oidcAuthority,
  client_id: environment.oidcClientId,
  redirect_uri: `${window.location.origin}/auth/callback`,
  post_logout_redirect_uri: window.location.origin,
  scope: environment.oidcScope,
  // Session storage keeps the token out of long-lived local storage; a closed
  // tab ends the session rather than leaving a bearer token on disk.
  userStore: new WebStorageStateStore({ store: window.sessionStorage }),
  onSigninCallback: () => {
    // Strip the code and state from the URL so a refresh does not replay the
    // callback against an already-consumed authorization code.
    window.history.replaceState({}, document.title, window.location.pathname);
  },
};

/** Publishes the current access token to the API client. */
function TokenBridge({ children }: { children: ReactNode }) {
  const auth = useAuth();

  useEffect(() => {
    setTokenProvider(() => auth.user?.access_token);
  }, [auth.user]);

  return <>{children}</>;
}

export function AppAuthProvider({ children }: { children: ReactNode }) {
  if (!authEnabled) return <>{children}</>;

  return (
    <OidcProvider {...oidcConfig}>
      <TokenBridge>{children}</TokenBridge>
    </OidcProvider>
  );
}

/**
 * Route guard. With authentication disabled it is a pass-through, so the same
 * route table works against a configured and an unconfigured backend.
 */
export function RequireAuth({ children }: { children: ReactNode }) {
  if (!authEnabled) return <>{children}</>;
  return <RequireAuthInner>{children}</RequireAuthInner>;
}

function RequireAuthInner({ children }: { children: ReactNode }) {
  const auth = useAuth();
  const location = useLocation();

  useEffect(() => {
    if (!auth.isLoading && !auth.isAuthenticated && !auth.activeNavigator) {
      void auth.signinRedirect({ state: { returnTo: location.pathname } });
    }
  }, [auth, location.pathname]);

  if (auth.isLoading) return <p>Signing in…</p>;
  if (auth.error) return <p role="alert">Sign-in failed: {auth.error.message}</p>;
  if (!auth.isAuthenticated) return null;

  return <>{children}</>;
}

/** Landing route for the OIDC redirect. */
export function AuthCallback() {
  if (!authEnabled) return <Navigate to="/" replace />;
  return <AuthCallbackInner />;
}

function AuthCallbackInner() {
  const auth = useAuth();

  if (auth.isLoading) return <p>Completing sign-in…</p>;
  if (auth.error) return <p role="alert">Sign-in failed: {auth.error.message}</p>;

  const returnTo = (auth.user?.state as { returnTo?: string } | undefined)?.returnTo;
  return <Navigate to={returnTo ?? '/'} replace />;
}
