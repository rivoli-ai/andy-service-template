// Copyright (c) Rivoli AI 2026. All rights reserved.

import { Component } from '@angular/core';
import { CommonModule } from '@angular/common';
import { environment } from '../../../environments/environment';

@Component({
  selector: 'app-help',
  standalone: true,
  imports: [CommonModule],
  template: `
    <div class="help-page">
      <h1>Help &amp; Documentation</h1>

      <section class="help-section">
        <h2>Getting Started</h2>
        <ol>
          <li>Sign in using your Andy Auth credentials ({{ testUser }})</li>
          <li>Navigate to <strong>Items</strong> to create and manage resources</li>
          <li>Use the <strong>Dashboard</strong> for an overview of your data</li>
        </ol>
      </section>

      <section class="help-section">
        <h2>API Access</h2>
        <div class="card-grid">
          <a class="help-card" [href]="swaggerUrl" target="_blank">
            <div class="card-icon">REST</div>
            <div class="card-body">
              <h3>Swagger / OpenAPI</h3>
              <p>Interactive API documentation. Try endpoints directly from the browser.</p>
            </div>
          </a>
          <div class="help-card">
            <div class="card-icon">MCP</div>
            <div class="card-body">
              <h3>Model Context Protocol</h3>
              <p>Connect AI assistants (Claude, ChatGPT) via the <code>/mcp</code> endpoint.</p>
            </div>
          </div>
          <div class="help-card">
            <div class="card-icon">gRPC</div>
            <div class="card-body">
              <h3>gRPC</h3>
              <p>High-performance RPC for service-to-service communication.</p>
            </div>
          </div>
          <div class="help-card">
            <div class="card-icon">CLI</div>
            <div class="card-body">
              <h3>Command Line</h3>
              <p>Manage resources from the terminal with the CLI tool.</p>
              <code>dotnet run --project tools/*.Cli -- items list</code>
            </div>
          </div>
        </div>
      </section>

      <section class="help-section">
        <h2>Authentication</h2>
        <table class="info-table">
          <tr><td>Provider</td><td>Andy Auth (OAuth2 / OIDC)</td></tr>
          <tr><td>Test user</td><td><code>{{ testUser }}</code></td></tr>
          <tr><td>Test password</td><td><code>Test123!</code></td></tr>
          <tr><td>Auth server</td><td><code>{{ authAuthority }}</code></td></tr>
        </table>
        <p class="note">Test credentials are for development only. Never use in production.</p>
      </section>

      <section class="help-section">
        <h2>Architecture</h2>
        <table class="info-table">
          <tr><td>Backend</td><td>.NET 8 — Clean Architecture (Domain, Application, Infrastructure, API)</td></tr>
          <tr><td>Frontend</td><td>Angular 18 — Standalone components, OIDC auth</td></tr>
          <tr><td>Database</td><td>PostgreSQL (default) / SQLite (embedded)</td></tr>
          <tr><td>Authorization</td><td>Andy RBAC — Role-based access control</td></tr>
          <tr><td>Settings</td><td>Andy Settings — Centralized configuration</td></tr>
          <tr><td>Telemetry</td><td>OpenTelemetry — Traces, metrics, OTLP export</td></tr>
        </table>
      </section>

      <section class="help-section">
        <h2>Support</h2>
        <ul>
          <li>Documentation: <a [href]="docsUrl" target="_blank">{{ docsUrl }}</a></li>
          <li>Source: <a [href]="repoUrl" target="_blank">{{ repoUrl }}</a></li>
          <li>Issues: <a [href]="repoUrl + '/issues'" target="_blank">{{ repoUrl }}/issues</a></li>
        </ul>
      </section>

      <footer class="help-footer">
        <p>__SERVICE_DISPLAY__ &mdash; Copyright &copy; Rivoli AI 2026</p>
      </footer>
    </div>
  `,
  styles: [`
    .help-page { max-width: 900px; }
    h1 { margin-bottom: 32px; }
    .help-section { margin-bottom: 32px; }
    h2 { font-size: 18px; margin-bottom: 12px; color: var(--text); border-bottom: 1px solid var(--border); padding-bottom: 8px; }
    ol, ul { padding-left: 24px; font-size: 14px; line-height: 2; }

    .card-grid { display: grid; grid-template-columns: repeat(auto-fill, minmax(280px, 1fr)); gap: 16px; }
    .help-card {
      display: flex; gap: 16px; padding: 16px;
      background: var(--surface); border: 1px solid var(--border); border-radius: 8px;
      text-decoration: none; color: var(--text); transition: border-color 0.15s;
    }
    .help-card:hover { border-color: var(--primary); }
    .card-icon {
      min-width: 48px; height: 48px; border-radius: 8px;
      background: rgba(26,115,232,0.08); color: var(--primary);
      display: flex; align-items: center; justify-content: center;
      font-size: 12px; font-weight: 700;
    }
    .card-body h3 { font-size: 14px; margin-bottom: 4px; }
    .card-body p { font-size: 13px; color: var(--text-secondary); margin: 0; }
    .card-body code { font-size: 12px; background: var(--background); padding: 2px 6px; border-radius: 3px; display: inline-block; margin-top: 6px; }

    .info-table { width: 100%; border-collapse: collapse; font-size: 14px; }
    .info-table td { padding: 8px 12px; border-bottom: 1px solid var(--border); }
    .info-table td:first-child { font-weight: 600; width: 140px; color: var(--text-secondary); }
    .info-table code { background: var(--background); padding: 2px 6px; border-radius: 3px; }

    .note { font-size: 13px; color: var(--text-secondary); margin-top: 8px; font-style: italic; }
    .help-footer { margin-top: 48px; padding-top: 16px; border-top: 1px solid var(--border); font-size: 13px; color: var(--text-secondary); }
  `],
})
export class HelpComponent {
  testUser = 'test@andy.local';
  authAuthority = environment.authAuthority || 'https://localhost:5001';
  swaggerUrl = environment.apiUrl.replace('/api', '') + '/swagger';
  docsUrl = 'https://rivoli-ai.github.io/__SERVICE_KEBAB__';
  repoUrl = 'https://github.com/rivoli-ai/__SERVICE_KEBAB__';
}
