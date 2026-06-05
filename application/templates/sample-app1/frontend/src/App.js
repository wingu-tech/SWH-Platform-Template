import React from 'react';

const s = {
  page: { fontFamily: '-apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif', minHeight: '100vh', display: 'flex', flexDirection: 'column', alignItems: 'center', justifyContent: 'center', backgroundColor: '#f8f9fa' },
  card: { backgroundColor: '#fff', borderRadius: 8, padding: '48px 64px', border: '1px solid #dee2e6', borderTop: '4px solid #4dabf7', textAlign: 'center' },
  title: { fontSize: '2rem', fontWeight: 700, margin: '0 0 12px', color: '#1a1a2e' },
  sub: { color: '#6c757d', margin: 0, fontSize: '1rem' },
  back: { marginTop: 24, display: 'inline-block', color: '#4dabf7', textDecoration: 'none', fontSize: '0.875rem' },
};

export default function App() {
  return (
    <div style={s.page}>
      <div style={s.card}>
        <h1 style={s.title}>Hello from Sample App 1</h1>
        <p style={s.sub}>Replace this with your application.</p>
        <a href="/" style={s.back}>← Back to Platform Home</a>
      </div>
    </div>
  );
}
