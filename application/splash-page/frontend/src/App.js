import React, { useState, useEffect } from 'react';

const PLATFORM_SERVICES = [
  { name: 'ArgoCD', path: '/argocd', description: 'GitOps deployment dashboard — sync status, rollback history, live resource state.', color: '#e14038' },
  { name: 'Grafana', path: '/grafana', description: 'EKS metrics and Container Insights — node CPU, memory, pod health, dashboards.', color: '#f46800' },
];

const s = {
  page: { fontFamily: '-apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif', minHeight: '100vh', backgroundColor: '#f8f9fa', margin: 0, padding: 0 },
  header: { backgroundColor: '#1a1a2e', color: '#fff', padding: '48px 40px 40px', borderBottom: '4px solid #e14038' },
  title: { fontSize: '2rem', fontWeight: 700, margin: '0 0 12px' },
  sub: { fontSize: '1rem', color: '#adb5bd', margin: 0, maxWidth: 600, lineHeight: 1.6 },
  body: { maxWidth: 900, margin: '0 auto', padding: '40px 24px' },
  section: { marginBottom: 48 },
  sectionTitle: { fontSize: '1.25rem', fontWeight: 600, marginBottom: 16, color: '#343a40', borderBottom: '2px solid #dee2e6', paddingBottom: 8 },
  grid: { display: 'grid', gridTemplateColumns: 'repeat(auto-fill, minmax(260px, 1fr))', gap: 16 },
  card: { display: 'block', textDecoration: 'none', backgroundColor: '#fff', borderRadius: 8, padding: 24, border: '1px solid #dee2e6', borderTop: '4px solid #ccc', color: 'inherit' },
  cardName: { fontSize: '1.1rem', fontWeight: 700, margin: '0 0 8px' },
  cardDesc: { fontSize: '0.875rem', color: '#6c757d', margin: '0 0 16px', lineHeight: 1.5 },
  badge: { display: 'inline-block', backgroundColor: '#f1f3f5', color: '#495057', padding: '4px 10px', borderRadius: 4, fontSize: '0.8rem', fontFamily: 'monospace' },
  empty: { color: '#adb5bd', fontSize: '0.875rem', fontStyle: 'italic' },
  code: { display: 'inline-block', backgroundColor: '#f1f3f5', padding: '2px 8px', borderRadius: 4, fontFamily: 'monospace', fontSize: '0.875rem' },
};

export default function App() {
  const [customApps, setCustomApps] = useState([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    fetch('/api/apps')
      .then(r => r.json())
      .then(data => { setCustomApps(data); setLoading(false); })
      .catch(() => setLoading(false));
  }, []);

  return (
    <div style={s.page}>
      <div style={s.header}>
        <h1 style={s.title}>SWH Platform</h1>
        <p style={s.sub}>
          Your platform home. Navigate to deployed services and applications below.
          Apps appear automatically when deployed to the cluster.
        </p>
      </div>

      <div style={s.body}>

        <div style={s.section}>
          <h2 style={s.sectionTitle}>Platform Services</h2>
          <div style={s.grid}>
            {PLATFORM_SERVICES.map(svc => (
              <a key={svc.name} href={svc.path} style={{ ...s.card, borderTopColor: svc.color }}>
                <div style={s.cardName}>{svc.name}</div>
                <div style={s.cardDesc}>{svc.description}</div>
                <span style={s.badge}>{svc.path}</span>
              </a>
            ))}
          </div>
        </div>

        <div style={s.section}>
          <h2 style={s.sectionTitle}>
            Deployed Applications
            {!loading && customApps.length > 0 && (
              <span style={{ fontWeight: 400, fontSize: '0.875rem', color: '#6c757d', marginLeft: 8 }}>
                ({customApps.length} app{customApps.length !== 1 ? 's' : ''})
              </span>
            )}
          </h2>
          {loading ? (
            <p style={s.empty}>Loading...</p>
          ) : customApps.length === 0 ? (
            <p style={s.empty}>
              No apps deployed yet. Copy a template from <code style={s.code}>application/templates/</code>,
              rename it, and push to main — it will appear here automatically.
            </p>
          ) : (
            <div style={s.grid}>
              {customApps.map(app => (
                <a key={app.path} href={app.path} style={{ ...s.card, borderTopColor: '#4dabf7' }}>
                  <div style={s.cardName}>{app.name}</div>
                  <div style={s.cardDesc}>Custom deployed application</div>
                  <span style={s.badge}>{app.path}</span>
                </a>
              ))}
            </div>
          )}
        </div>

      </div>
    </div>
  );
}
