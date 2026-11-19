import { useState } from 'react';
import { Layout } from './components/Layout';
import { Alert, Button, Card, Spinner } from './components/ui';
import { AuthProvider, useAuth } from './context/AuthContext';
import { useLookups } from './hooks/useLookups';
import { usePendingApprovals } from './hooks/usePendingApprovals';
import { isApprovedProfile, NAV_ITEMS, type ViewKey } from './lib/rbac';
import DashboardPage from './pages/DashboardPage';
import EventsPage from './pages/EventsPage';
import InquiriesPage from './pages/InquiriesPage';
import LoginPage from './pages/LoginPage';
import PendingApprovalPage from './pages/PendingApprovalPage';
import PoisPage from './pages/PoisPage';
import PromotePage from './pages/PromotePage';
import UserApprovalsPage from './pages/UserApprovalsPage';

function Splash({ label }: { label: string }) {
  return (
    <div className="flex min-h-screen flex-col items-center justify-center gap-4 bg-surface text-sm text-slate-500">
      <span className="flex h-12 w-12 items-center justify-center rounded-2xl bg-forest text-gold">
        <Spinner className="h-6 w-6 border-white/30 border-t-gold" />
      </span>
      {label}
    </div>
  );
}

function Portal() {
  const { session, profile, loading, error, signOut, refreshProfile } = useAuth();
  const lookups = useLookups();
  const [view, setView] = useState<ViewKey>('dashboard');
  const [pendingRefresh, setPendingRefresh] = useState(0);
  const pendingApprovals = usePendingApprovals(
    Boolean(profile && profile.role_tier >= 4 && isApprovedProfile(profile)),
    `${view}-${pendingRefresh}`,
  );

  if (!session) {
    return (
      <LoginPage
        municipalities={lookups.municipalities}
        barangays={lookups.barangays}
      />
    );
  }

  if (loading) return <Splash label="Loading your LGU account…" />;

  if (error) {
    return (
      <div className="flex min-h-screen items-center justify-center bg-surface px-4">
        <Card className="w-full max-w-lg p-6">
          <h1 className="text-lg font-bold text-forest">Portal access error</h1>
          <p className="mt-1 text-sm text-slate-500">
            We could not load your LGU profile from public.users.
          </p>
          <div className="mt-4">
            <Alert tone="error">{error}</Alert>
          </div>
          <div className="mt-5 flex justify-end gap-2">
            <Button variant="outline" onClick={() => void signOut()}>
              Sign out
            </Button>
            <Button onClick={() => void refreshProfile()}>Retry</Button>
          </div>
        </Card>
      </div>
    );
  }

  if (!profile) return <Splash label="Preparing your portal…" />;

  // Google and email sign-ins are gated the same way: role_tier + approval are
  // read from public.users after the OAuth redirect resolves. Unapproved LGU
  // staff land on the pending/request-access state instead of the dashboard.
  if (!isApprovedProfile(profile)) {
    return (
      <PendingApprovalPage
        profile={profile}
        municipalities={lookups.municipalities}
        onSignOut={() => void signOut()}
      />
    );
  }

  const visibleViews = NAV_ITEMS.filter((item) => item.visible(profile)).map(
    (item) => item.key,
  );
  const activeView: ViewKey = visibleViews.includes(view) ? view : 'dashboard';

  return (
    <Layout
      profile={profile}
      active={activeView}
      onNavigate={setView}
      municipalities={lookups.municipalities}
      onSignOut={() => void signOut()}
      pendingApprovals={pendingApprovals}
    >
      {activeView === 'dashboard' ? (
        <DashboardPage profile={profile} lookups={lookups} onNavigate={setView} />
      ) : null}
      {activeView === 'events' ? (
        <EventsPage profile={profile} lookups={lookups} />
      ) : null}
      {activeView === 'pois' ? (
        <PoisPage profile={profile} lookups={lookups} />
      ) : null}
      {activeView === 'inquiries' ? (
        <InquiriesPage profile={profile} lookups={lookups} />
      ) : null}
      {activeView === 'promote' ? (
        <PromotePage profile={profile} lookups={lookups} />
      ) : null}
      {activeView === 'users' ? (
        <UserApprovalsPage
          profile={profile}
          lookups={lookups}
          onReviewed={() => setPendingRefresh((value) => value + 1)}
        />
      ) : null}
    </Layout>
  );
}

export default function App() {
  return (
    <AuthProvider>
      <Portal />
    </AuthProvider>
  );
}
