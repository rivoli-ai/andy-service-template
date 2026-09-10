import { environment } from '../../config/environment';

/**
 * Thin fetch wrapper. This is the React counterpart of the Angular client's
 * `api.service.ts` plus `auth.interceptor.ts`: one place that knows the base
 * URL, attaches the bearer token, and turns a non-2xx into a thrown error so
 * callers do not each have to check `response.ok`.
 */

let tokenProvider: () => string | undefined = () => undefined;

/**
 * Registers where the access token comes from. Called once, from the auth
 * provider. Keeping it a callback rather than a stored string means the token
 * is read at request time, so a silent renew is picked up without re-wiring.
 */
export function setTokenProvider(provider: () => string | undefined): void {
  tokenProvider = provider;
}

export class ApiError extends Error {
  readonly status: number;
  readonly body?: unknown;

  constructor(message: string, status: number, body?: unknown) {
    super(message);
    this.name = 'ApiError';
    this.status = status;
    this.body = body;
  }
}

async function request<T>(path: string, init: RequestInit = {}): Promise<T> {
  const headers = new Headers(init.headers);
  if (init.body !== undefined) headers.set('Content-Type', 'application/json');

  const token = tokenProvider();
  if (token) headers.set('Authorization', `Bearer ${token}`);

  const response = await fetch(`${environment.apiUrl}${path}`, { ...init, headers });

  if (!response.ok) {
    // Read the body before throwing: ProblemDetails from the API carries the
    // reason, and discarding it leaves the user with a bare status code.
    let body: unknown;
    try {
      body = await response.json();
    } catch {
      body = await response.text().catch(() => undefined);
    }
    throw new ApiError(
      `${init.method ?? 'GET'} ${path} failed with ${response.status}`,
      response.status,
      body,
    );
  }

  if (response.status === 204) return undefined as T;
  return (await response.json()) as T;
}

export const api = {
  get: <T>(path: string) => request<T>(path),
  post: <T>(path: string, body: unknown) =>
    request<T>(path, { method: 'POST', body: JSON.stringify(body) }),
  put: <T>(path: string, body: unknown) =>
    request<T>(path, { method: 'PUT', body: JSON.stringify(body) }),
  delete: (path: string) => request<void>(path, { method: 'DELETE' }),
};

// ---- resource types, mirroring the API's DTOs ----

export type ItemStatus = 'Draft' | 'Active' | 'Archived';

export interface Item {
  id: string;
  name: string;
  description?: string | null;
  status: ItemStatus;
  createdBy: string;
  createdAt: string;
  updatedAt?: string | null;
}

export interface CreateItemRequest {
  name: string;
  description?: string;
}

export interface HelpTopic {
  slug: string;
  title: string;
  summary?: string;
}

export interface HealthStatus {
  status: string;
  timestamp: string;
}

export const itemsApi = {
  list: () => api.get<Item[]>('/items'),
  get: (id: string) => api.get<Item>(`/items/${id}`),
  create: (body: CreateItemRequest) => api.post<Item>('/items', body),
  update: (id: string, body: CreateItemRequest) => api.put<Item>(`/items/${id}`, body),
  remove: (id: string) => api.delete(`/items/${id}`),
};

export const helpApi = {
  topics: () => api.get<HelpTopic[]>('/help/topics'),
};

/** Health lives outside the /api prefix, so it bypasses the wrapper's base URL. */
export async function fetchHealth(): Promise<HealthStatus> {
  const base = environment.apiUrl.replace(/\/api$/, '');
  const response = await fetch(`${base}/health`);
  if (!response.ok) throw new ApiError('health check failed', response.status);
  return (await response.json()) as HealthStatus;
}
