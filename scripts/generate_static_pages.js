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
const CONTACT_EMAIL = 'quantcapiyo@gmail.com';
const CONTACT_PHONE = '+254 704 306 867';
const LAST_UPDATED = new Date().toISOString().slice(0, 10);

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
section{margin-top:24px;}
</style>
</head>
<body>
<nav><a href="/">Home</a><a href="/fixtures/">Fixtures</a><a href="/results/">Results</a><a href="/privacy/">Privacy</a><a href="/about/">About</a><a href="/contact/">Contact</a></nav>
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

function buildAboutPage() {
    const body = `
<h1>About Funspot</h1>
<p>Funspot is a live football fan engagement app built for supporters who
want more than just the final score. Fans join channels around real
fixtures, vote on outcomes, chat live during matches, and follow each
other's activity through the season.</p>

<h2>What Funspot offers</h2>
<ul>
  <li><strong>Arena</strong> — vote on upcoming and live fixtures, join
    channels with other fans, and chat in real time during matches,
    including sub-fixture markets like first to score or first corner.</li>
  <li><strong>Feed</strong> — share photos and videos with the community
    and follow other fans' posts.</li>
  <li><strong>History</strong> — browse settled fixtures, past results,
    and channel leaderboards.</li>
</ul>

<h2>Who's behind it</h2>
<p>Funspot is built and maintained by a small independent team based in
Nairobi, Kenya. You can reach us any time via the
<a href="/contact/">contact page</a>.</p>
`;
    writeFile('about/index.html', pageShell({
        title: 'About — Funspot',
        description: 'About Funspot, a live football fan engagement app for channel-based voting, live match chat, and leaderboards.',
        canonicalPath: '/about/',
        bodyHtml: body,
    }));
}

function buildContactPage() {
    const body = `
<h1>Contact Funspot</h1>
<p>Questions, feedback, or an issue with the app? Reach out any time.</p>
<section>
  <h2>Email</h2>
  <p><a href="mailto:${CONTACT_EMAIL}">${CONTACT_EMAIL}</a></p>
  <h2>Phone / WhatsApp</h2>
  <p><a href="tel:${CONTACT_PHONE.replace(/\s+/g, '')}">${CONTACT_PHONE}</a></p>
  <h2>Based in</h2>
  <p>Nairobi, Kenya</p>
</section>
<p>For account or payment issues (M-Pesa transactions, channel disputes,
reporting abusive content), please include your Funspot username or phone
number used to sign up so we can look into it faster.</p>
`;
    writeFile('contact/index.html', pageShell({
        title: 'Contact — Funspot',
        description: 'Contact the Funspot team by email or phone for support, feedback, or account issues.',
        canonicalPath: '/contact/',
        bodyHtml: body,
    }));
}

function buildPrivacyPage() {
    const body = `
<h1>Privacy Policy</h1>
<p class="meta">Last updated: ${LAST_UPDATED}</p>

<p>This policy explains what information Funspot ("we", "us", "the app")
collects when you use the Funspot mobile and web app, and how that
information is used.</p>

<section>
  <h2>Information we collect</h2>
  <ul>
    <li><strong>Account information</strong> — your phone number (used for
      sign-in via Firebase Phone Authentication), username, and any profile
      details you add (nickname, club, country).</li>
    <li><strong>Activity data</strong> — fixture votes, channel memberships,
      chat messages, comments, likes, and posts you make within the app.</li>
    <li><strong>Payment data</strong> — where you use M-Pesa within the app
      (for example, pledges or bets tied to a channel), transaction details
      are processed to complete that transaction. We do not store your
      M-Pesa PIN or full payment credentials.</li>
    <li><strong>Push notification tokens</strong> — a device token used to
      deliver notifications about votes, comments, and channel activity.</li>
    <li><strong>Basic device/usage data</strong> — standard technical data
      (such as device type and app version) used for debugging and
      reliability.</li>
  </ul>
</section>

<section>
  <h2>How we use this information</h2>
  <ul>
    <li>To operate core app features: voting, channels, chat, leaderboards,
      and notifications.</li>
    <li>To process in-app M-Pesa transactions you initiate.</li>
    <li>To maintain and improve the reliability and security of the app.</li>
  </ul>
</section>

<section>
  <h2>Third parties we use</h2>
  <p>Funspot relies on the following third-party services to operate:</p>
  <ul>
    <li><strong>Firebase</strong> (Google) — authentication and push
      notifications.</li>
    <li><strong>M-Pesa / Safaricom</strong> — payment processing for
      in-app transactions you choose to make.</li>
  </ul>
  <p>Each of these providers has its own privacy policy governing how they
  handle data on our behalf.</p>
</section>

<section>
  <h2>Data sharing</h2>
  <p>We do not sell your personal information. Your username, votes, and
  public posts are visible to other users within the channels you join, as
  that is the core function of the app. We share data with third parties
  only as described above, or where required by law.</p>
</section>

<section>
  <h2>Your choices</h2>
  <p>You can update your profile information within the app at any time.
  To request deletion of your account and associated data, contact us at
  <a href="mailto:${CONTACT_EMAIL}">${CONTACT_EMAIL}</a>.</p>
</section>

<section>
  <h2>Contact</h2>
  <p>Questions about this policy can be sent to
  <a href="mailto:${CONTACT_EMAIL}">${CONTACT_EMAIL}</a> or
  <a href="tel:${CONTACT_PHONE.replace(/\s+/g, '')}">${CONTACT_PHONE}</a>.</p>
</section>
`;
    writeFile('privacy/index.html', pageShell({
        title: 'Privacy Policy — Funspot',
        description: 'Funspot privacy policy: what data we collect, how it is used, and your choices.',
        canonicalPath: '/privacy/',
        bodyHtml: body,
    }));
}

async function buildSitemap(fixtureCount) {
    const urls = ['/', '/fixtures/', '/results/', '/privacy/', '/about/', '/contact/'];
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
    buildAboutPage();
    buildContactPage();
    buildPrivacyPage();
    await buildSitemap(fixtures.length);
    console.log('✅ Static page generation complete.');
}

main().catch(e => {
    // Never fail the whole Netlify build if the API is down — the Flutter
    // app itself must still deploy. Log and exit cleanly.
    console.error('⚠️ Static page generation failed (non-fatal):', e);
    process.exit(0);
});