// scripts/generate_static_pages.js
//
// Generates real, crawlable static HTML pages from the live Clash API
// and writes them into build/web/, alongside the Flutter app's index.html.
// Runs as a build step AFTER `flutter build web` (see netlify build command).
//
// Node 24.x has fetch and fs.promises built in — no dependencies needed.

const fs = require('fs');
const path = require('path');

const API_BASE = 'https://clash-api-m5mr.onrender.com/api';
const OUT_DIR = path.join(process.cwd(), 'build', 'web');
const SITE_URL = 'https://www.funspot.co.ke';

function escapeHtml(str) {
    return String(str ?? '')
        .replace(/&/g, '&amp;')
        .replace(/</g, '&lt;')
        .replace(/>/g, '&gt;')
        .replace(/"/g, '&quot;');
}

function pageShell({ title, description, canonicalPath, bodyHtml }) {
    return `<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>${escapeHtml(title)}</title>
<meta name="description" content="${escapeHtml(description)}">
<link rel="canonical" href="${SITE_URL}${canonicalPath}">
<link rel="icon" type="image/png" href="/funspot.png">
<style>
  body{font-family:sans-serif;max-width:720px;margin:0 auto;padding:24px 20px;color:#0D0B1E;line-height:1.5;}
  h1{font-size:22px;} h2{font-size:16px;margin-top:28px;}
  a{color:#0D0B1E;text-decoration:none;}
  .match{border-bottom:1px solid #eee;padding:10px 0;display:flex;justify-content:space-between;gap:12px;}
  .teams{font-weight:600;}
  .meta{color:#666;font-size:13px;}
  nav a{margin-right:16px;font-size:13px;color:#666;}
</style>
</head>
<body>
<nav><a href="/">Home</a><a href="/fixtures/">Fixtures</a><a href="/results/">Results</a></nav>
${bodyHtml}
</body>
</html>`;
}

async function fetchJson(url) {
    try {
        const res = await fetch(url, { headers: { 'Content-Type': 'application/json' } });
        if (!res.ok) {
            console.warn(`⚠️  ${url} returned ${res.status}, skipping`);
            return null;
        }
        return await res.json();
    } catch (e) {
        console.warn(`⚠️  Failed to fetch ${url}: ${e.message}`);
        return null;
    }
}

function writeFile(relPath, content) {
    const fullPath = path.join(OUT_DIR, relPath);
    fs.mkdirSync(path.dirname(fullPath), { recursive: true });
    fs.writeFileSync(fullPath, content, 'utf8');
    console.log(`✅ wrote ${relPath}`);
}

async function buildFixturesPage() {
    const data = await fetchJson(`${API_BASE}/games`);
    const fixtures = (data && (data.data || data.fixtures)) || [];

    const rows = fixtures.slice(0, 60).map(f => {
        const home = f.homeTeam || f.home_team || 'TBD';
        const away = f.awayTeam || f.away_team || 'TBD';
        const league = f.league || '';
        const kickoff = f.kickoffTime || f.kickoff_time || f.matchDate || '';
        return `<div class="match">
      <div><div class="teams">${escapeHtml(home)} vs ${escapeHtml(away)}</div>
      <div class="meta">${escapeHtml(league)}</div></div>
      <div class="meta">${escapeHtml(kickoff)}</div>
    </div>`;
    }).join('\n');

    const body = `
<h1>Upcoming Football Fixtures — Funspot</h1>
<p>Vote and chat live on real football fixtures across major leagues.
Join a channel on the <a href="/">Funspot app</a> to take part.</p>
${rows || '<p>No upcoming fixtures right now — check back soon.</p>'}
`;

    writeFile('fixtures/index.html', pageShell({
        title: 'Upcoming Fixtures — Funspot',
        description: 'Upcoming football fixtures fans are voting and chatting about on Funspot.',
        canonicalPath: '/fixtures/',
        bodyHtml: body,
    }));

    return fixtures;
}

async function buildResultsPage() {
    const data = await fetchJson(`${API_BASE}/games/history?limit=60`);
    const games = (data && data.data) || [];

    const rows = games.map(g => {
        const home = g.homeTeam || g.home_team || 'TBD';
        const away = g.awayTeam || g.away_team || 'TBD';
        const hs = g.homeScore ?? g.home_score ?? '-';
        const as = g.awayScore ?? g.away_score ?? '-';
        const league = g.league || '';
        return `<div class="match">
      <div><div class="teams">${escapeHtml(home)} ${hs} - ${as} ${escapeHtml(away)}</div>
      <div class="meta">${escapeHtml(league)}</div></div>
    </div>`;
    }).join('\n');

    const body = `
<h1>Recent Results — Funspot</h1>
<p>Recent match results from channels on Funspot. Join the conversation on
the <a href="/">Funspot app</a>.</p>
${rows || '<p>No results yet.</p>'}
`;

    writeFile('results/index.html', pageShell({
        title: 'Recent Results — Funspot',
        description: 'Recent football results discussed and voted on by Funspot fans.',
        canonicalPath: '/results/',
        bodyHtml: body,
    }));
}

async function buildSitemap(fixtureCount) {
    const urls = ['/', '/fixtures/', '/results/'];
    const xml = `<?xml version="1.0" encoding="UTF-8"?>
<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">
${urls.map(u => `  <url><loc>${SITE_URL}${u}</loc></url>`).join('\n')}
</urlset>`;
    writeFile('sitemap.xml', xml);
}

async function main() {
    console.log('🔧 Generating static pages from Clash API...');
    const fixtures = await buildFixturesPage();
    await buildResultsPage();
    await buildSitemap(fixtures.length);
    console.log('✅ Static page generation complete.');
}

main().catch(e => {
    // Never fail the whole Netlify build if the API is down — the Flutter
    // app itself must still deploy. Log and exit cleanly.
    console.error('⚠️ Static page generation failed (non-fatal):', e);
    process.exit(0);
});