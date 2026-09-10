import { NavLink, Route, Routes } from 'react-router-dom';
import { AppShell } from '@astryxdesign/core/AppShell';
import { TopNav } from '@astryxdesign/core/TopNav';
import { AuthCallback, RequireAuth } from './core/auth/AuthProvider';
import { DashboardPage } from './features/dashboard/DashboardPage';
import { ItemsPage } from './features/items/ItemsPage';
import { HelpPage } from './features/help/HelpPage';

const links = [
  { to: '/', label: 'Dashboard' },
  { to: '/items', label: 'Items' },
  { to: '/help', label: 'Help' },
];

export function App() {
  return (
    <AppShell
      contentPadding={4}
      topNav={
        <TopNav label="Main">
          <nav aria-label="Sections" style={{ display: 'flex', gap: '1rem' }}>
            {links.map((l) => (
              <NavLink key={l.to} to={l.to} end={l.to === '/'}>
                {l.label}
              </NavLink>
            ))}
          </nav>
        </TopNav>
      }
    >
      <Routes>
        <Route path="/auth/callback" element={<AuthCallback />} />
        <Route path="/" element={<RequireAuth><DashboardPage /></RequireAuth>} />
        <Route path="/items" element={<RequireAuth><ItemsPage /></RequireAuth>} />
        <Route path="/help" element={<RequireAuth><HelpPage /></RequireAuth>} />
      </Routes>
    </AppShell>
  );
}
