// scripts/generate_static_pages.js
//
// Generates real, crawlable static HTML pages from the live Clash API
// and writes them into build/web/, alongside the Flutter app's index.html.
// Runs as a build step AFTER `flutter build web` (see netlify build command).
//
// Each generated page shows real static content to crawlers (and to users
// for the first paint), then hides that content and hands off to the
// Flutter app the instant it mounts — the same pattern already used on
// index.html for #seo-content. This is NOT user-agent cloaking: every
// visitor (bot or human) receives identical HTML; only client-side JS,
// running after the page is already delivered, decides what stays visible.
//
// Node 24.x has fetch and fs.promises built in — no dependencies needed.
//
// ---------------------------------------------------------------------
// FINAL VERSION — endpoints below are confirmed against the real Dart
// source (post_models.dart / posts_page.dart / post_comments.dart /
// chat_screen.dart / leaderboard.dart / join_groups_modal.dart /
// swipeable_profile_modal.dart), not guessed:
//
//   Posts               GET  {API}/posts                                  -> { success, posts: [...] }
//   Post comments       GET  {API}/comments/posts/{postId}/comments       -> { success, comments: [...] }
//   Fixture commentary  GET  {API}/games/{id}/commentary/latest?limit=100 -> { commentary: [...] }   (live/upcoming)
//   History commentary  GET  {API}/games/history/{id}                     -> { data: { commentary: [...] } } (completed)
//   Lineups             GET  {API}/games/{id}/lineups                     -> { success, data: {...} }
//                        (fallback: {API}/games/{id}/lineups/simplified, same shape)
//   Match statistics    GET  {API}/games/{id}/statistics/latest           -> { data: { statistics: {...} } }
//                        (fallback: {API}/games/{id}/statistics, same shape)
//   Fixture voters      GET  {API}/actions/vote/fixture/{id}/voters       -> { success, voters: [...] }
//   All channels        GET  {API}/channels/all                           -> { channels: [...] }
//   Channel leaderboard GET  {API}/channels/{id}/leaderboard              -> { success, leaderboard: [...] }
//   All profiles        GET  {API}/profile/profiles                      -> RAW ARRAY (not wrapped)
//
// Deliberately NOT included, per instruction: betting/pledges, sub-fixture
// markets, payments, login, and channel-creation flows (transactional, not
// indexable content). Also skipped: per-user activity archive
// ({API}/archive/user/{userId}) — duplicates content already covered by
// fixture/post/leaderboard pages and isn't itself a distinct indexable page.
// ---------------------------------------------------------------------

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

function pageShell({ title, description, canonicalPath, appRoute, bodyHtml }) {
  const route = appRoute || canonicalPath;

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
  html{height:100%}
  body{margin:0;min-height:100%;font-family:sans-serif;color:#0D0B1E;line-height:1.5;background-color:#FFFFFF;}
  @media (prefers-color-scheme: dark) { body{background-color:#121A30;color:#EDEBFA;} }

  #static-fallback{max-width:720px;margin:0 auto;padding:24px 20px;}
  #static-fallback.app-ready{display:none;}

  h1{font-size:22px;} h2{font-size:16px;margin-top:28px;}
  a{color:inherit;text-decoration:none;}
  .match{border-bottom:1px solid rgba(128,128,128,0.25);padding:10px 0;display:flex;justify-content:space-between;gap:12px;}
  .teams{font-weight:600;}
  .meta{color:#888;font-size:13px;}
  nav a{margin-right:16px;font-size:13px;color:#888;}
  section{margin-top:24px;}
  .lb-row{display:flex;justify-content:space-between;padding:8px 0;border-bottom:1px solid rgba(128,128,128,0.2);}
  .lb-rank{color:#888;width:32px;}
  .profile-header{display:flex;align-items:center;gap:16px;}
  .profile-avatar{width:72px;height:72px;border-radius:50%;object-fit:cover;background:rgba(128,128,128,0.15);}
  .profile-stats{display:flex;gap:20px;margin-top:16px;}
  .profile-stat{text-align:center;}
  .profile-stat .num{font-size:18px;font-weight:700;display:block;}
  .profile-stat .label{font-size:12px;color:#888;}
  .profile-grid{display:grid;grid-template-columns:repeat(auto-fill,minmax(140px,1fr));gap:14px;margin-top:16px;}
  .profile-card{border:1px solid rgba(128,128,128,0.25);border-radius:10px;padding:12px;text-align:center;}
  .profile-card img{width:48px;height:48px;border-radius:50%;object-fit:cover;margin-bottom:6px;}
  img{max-width:100%;border-radius:8px;}
</style>
<script id="static-fallback-script">
  function hideStaticFallback() {
    var el = document.getElementById('static-fallback');
    if (el) { el.classList.add('app-ready'); }
  }
  function routeIntoApp() {
    if (window.funspotRouter && typeof window.funspotRouter.go === 'function') {
      window.funspotRouter.go(${JSON.stringify(route)});
    }
  }
  function onFunspotAppReady() {
    hideStaticFallback();
    routeIntoApp();
  }
</script>
</head>
<body>

<div id="static-fallback">
<nav><a href="/">Home</a><a href="/fixtures/">Fixtures</a><a href="/results/">Results</a><a href="/comrades/">Comrades</a><a href="/privacy/">Privacy</a><a href="/about/">About</a><a href="/contact/">Contact</a></nav>
${bodyHtml}
</div>

<!-- Firebase Phone Auth reCAPTCHA container (web only) -->
<div id="recaptcha-container"></div>

<script src="flutter_bootstrap.js" async=""></script>
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
    const id = f.id || f._id || f.matchId;
    const home = f.homeTeam || f.home_team || 'TBD';
    const away = f.awayTeam || f.away_team || 'TBD';
    const league = f.league || '';
    const kickoff = f.kickoffTime || f.kickoff_time || f.matchDate || f.date || '';
    const link = id ? `/fixtures/${id}/` : null;
    const teamsHtml = link
      ? `<a href="${link}">${escapeHtml(home)} vs ${escapeHtml(away)}</a>`
      : `${escapeHtml(home)} vs ${escapeHtml(away)}`;
    return `<div class="match">
      <div><div class="teams">${teamsHtml}</div>
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
    const id = g.id || g._id || g.matchId;
    const home = g.homeTeam || g.home_team || 'TBD';
    const away = g.awayTeam || g.away_team || 'TBD';
    const hs = g.homeScore ?? g.home_score ?? '-';
    const as = g.awayScore ?? g.away_score ?? '-';
    const league = g.league || '';
    const link = id ? `/fixtures/${id}/` : null;
    const teamsHtml = link
      ? `<a href="${link}">${escapeHtml(home)} ${hs} - ${as} ${escapeHtml(away)}</a>`
      : `${escapeHtml(home)} ${hs} - ${as} ${escapeHtml(away)}`;
    return `<div class="match">
      <div><div class="teams">${teamsHtml}</div>
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

  return games;
}

// ---------------------------------------------------------------------
// Fixture detail pages — real per-match commentary.
// Live/upcoming fixtures (from /games) use /games/{id}/commentary/latest.
// Completed fixtures (from /games/history) use /games/history/{id}, whose
// response nests commentary under data.commentary.
// ---------------------------------------------------------------------
async function buildFixtureDetailPages(upcomingFixtures, historyGames) {
  const sitemapUrls = [];

  async function buildOne(f, isHistory) {
    const id = f.id || f._id || f.matchId;
    if (!id) return;

    const home = f.homeTeam || f.home_team || 'TBD';
    const away = f.awayTeam || f.away_team || 'TBD';
    const league = f.league || '';
    const hs = f.homeScore ?? f.home_score;
    const as = f.awayScore ?? f.away_score;
    const scoreLine = (hs != null && as != null) ? `${hs} - ${as}` : '';

    let commentary = [];
    if (isHistory) {
      const histData = await fetchJson(`${API_BASE}/games/history/${id}`);
      commentary = (histData && histData.data && histData.data.commentary) || [];
    } else {
      const liveData = await fetchJson(`${API_BASE}/games/${id}/commentary/latest?limit=100`);
      commentary = (liveData && liveData.commentary) || [];
    }

    const rows = commentary.map(c => `
      <div class="match">
        <div>${escapeHtml(c.text || '')}</div>
        <div class="meta">${c.minute != null ? escapeHtml(String(c.minute)) + "'" : ''}</div>
      </div>
    `).join('\n');

    // ---- Lineups (GET /games/{id}/lineups, fallback /lineups/simplified) ----
    // Confirmed shape (match_details_modal.dart): { success, data: {...} }
    // Fields: home_formation, away_formation, home_coach, away_coach,
    // home_starting_xi/home_bench/away_starting_xi/away_bench (player lists).
    // Player fields: name, number (many possible source keys), position, captain.
    let lineupsHtml = '';
    let lineupData = await fetchJson(`${API_BASE}/games/${id}/lineups`);
    let lineupPayload = lineupData && lineupData.success && lineupData.data;
    if (!lineupPayload) {
      const fallback = await fetchJson(`${API_BASE}/games/${id}/lineups/simplified`);
      lineupPayload = fallback && fallback.success && fallback.data;
    }
    if (lineupPayload) {
      const playerName = (p) => p && (p.name || p.displayName || p.fullName || '');
      const renderXI = (list) => (list || [])
        .map(p => escapeHtml(playerName(p)))
        .filter(Boolean)
        .join(', ');
      const homeXI = renderXI(lineupPayload.home_starting_xi);
      const awayXI = renderXI(lineupPayload.away_starting_xi);
      if (homeXI || awayXI) {
        lineupsHtml = `
<h2>Lineups</h2>
<p class="meta">${escapeHtml(home)} (${escapeHtml(lineupPayload.home_formation || '')}) coached by ${escapeHtml(lineupPayload.home_coach || 'TBD')}</p>
${homeXI ? `<p>${homeXI}</p>` : ''}
<p class="meta">${escapeHtml(away)} (${escapeHtml(lineupPayload.away_formation || '')}) coached by ${escapeHtml(lineupPayload.away_coach || 'TBD')}</p>
${awayXI ? `<p>${awayXI}</p>` : ''}
`;
      }
    }

    // ---- Statistics (GET /games/{id}/statistics/latest, fallback /statistics) ----
    // Confirmed shape (match_details_modal.dart): stats live under data.statistics,
    // either as a Map { home: {...}, away: {...} } or a List of timestamped
    // snapshots (use the last one). Field names vary (possession/ball_possession,
    // shots/total_shots, shotsOnTarget/shots_on_target, corners, fouls,
    // yellowCards/yellow_cards, passAccuracy/pass_accuracy).
    let statsHtml = '';
    let statsData = await fetchJson(`${API_BASE}/games/${id}/statistics/latest`);
    let statsRoot = statsData && (statsData.data || statsData);
    if (!statsRoot || !statsRoot.statistics) {
      const fallback = await fetchJson(`${API_BASE}/games/${id}/statistics`);
      if (fallback && fallback.success) {
        statsRoot = fallback.data || fallback;
      }
    }
    if (statsRoot && statsRoot.statistics) {
      let statsBlock = statsRoot.statistics;
      if (Array.isArray(statsBlock) && statsBlock.length) {
        const latest = statsBlock[statsBlock.length - 1];
        statsBlock = latest.statistics || latest;
      }
      const h = statsBlock.home || {};
      const a = statsBlock.away || {};
      const pick = (obj, ...keys) => {
        for (const k of keys) if (obj[k] != null) return obj[k];
        return 0;
      };
      const rowsStats = [
        ['Possession', pick(h, 'possession', 'ball_possession'), pick(a, 'possession', 'ball_possession'), '%'],
        ['Shots', pick(h, 'shots', 'total_shots'), pick(a, 'shots', 'total_shots'), ''],
        ['Shots on target', pick(h, 'shotsOnTarget', 'shots_on_target'), pick(a, 'shotsOnTarget', 'shots_on_target'), ''],
        ['Corners', pick(h, 'corners'), pick(a, 'corners'), ''],
        ['Fouls', pick(h, 'fouls'), pick(a, 'fouls'), ''],
        ['Yellow cards', pick(h, 'yellowCards', 'yellow_cards'), pick(a, 'yellowCards', 'yellow_cards'), ''],
      ];
      statsHtml = `
<h2>Match Statistics</h2>
${rowsStats.map(([label, hv, av, suf]) => `<div class="match"><div>${hv}${suf}</div><div class="meta">${escapeHtml(label)}</div><div>${av}${suf}</div></div>`).join('\n')}
`;
    }

    // ---- Voters (GET /actions/vote/fixture/{fixtureId}/voters) ----
    // Confirmed shape: { success, voters: [...] }, fields userId/userName/selection.
    let votersHtml = '';
    const votersData = await fetchJson(`${API_BASE}/actions/vote/fixture/${id}/voters`);
    const voters = (votersData && votersData.success && votersData.voters) || [];
    if (voters.length) {
      const voteLabel = (sel) => {
        if (sel === 'home' || sel === 'home_team') return home;
        if (sel === 'away' || sel === 'away_team') return away;
        if (sel === 'draw') return 'Draw';
        return sel;
      };
      votersHtml = `
<h2>Fan Votes (${voters.length})</h2>
${voters.slice(0, 100).map(v => `<div class="match"><div>${escapeHtml(v.userName || v.user_name || 'Fan')}</div><div class="meta">voted ${escapeHtml(voteLabel(v.selection || ''))}</div></div>`).join('\n')}
`;
    }

    const body = `
<h1>${escapeHtml(home)} vs ${escapeHtml(away)}</h1>
<p class="meta">${escapeHtml(league)}${scoreLine ? ' · ' + escapeHtml(scoreLine) : ''}</p>
${rows || '<p>Commentary will appear here once the match is live.</p>'}
${lineupsHtml}
${statsHtml}
${votersHtml}
<p style="margin-top:24px;"><a href="/fixtures/">← Back to fixtures</a></p>
`;

    writeFile(`fixtures/${id}/index.html`, pageShell({
      title: `${home} vs ${away} — Funspot`,
      description: `Live commentary and fan chat for ${home} vs ${away} on Funspot.`,
      canonicalPath: `/fixtures/${id}/`,
      appRoute: `/fixtures/${id}`,
      bodyHtml: body,
    }));

    sitemapUrls.push(`/fixtures/${id}/`);
  }

  for (const f of upcomingFixtures.slice(0, 60)) {
    await buildOne(f, false);
  }
  for (const g of historyGames.slice(0, 60)) {
    await buildOne(g, true);
  }

  return sitemapUrls;
}

// ---------------------------------------------------------------------
// Post pages — real community posts from GET {API}/posts.
// Confirmed response shape: { success: true, posts: [...] }
// Confirmed Post fields (post_models.dart): id, userId, userName, caption
// (displayCaption picks the best of caption/imageCaption/videoCaption),
// bestImageUrl, videoUrl, timestamp (unix seconds), likesCount, commentsCount
// ---------------------------------------------------------------------
async function buildPostPages() {
  const data = await fetchJson(`${API_BASE}/posts`);
  const posts = (data && data.success && data.posts) || [];

  const sitemapUrls = [];

  for (const p of posts.slice(0, 200)) {
    const id = p.id || p._id;
    if (!id) continue;

    const author = p.userName || p.user_name || 'Funspot Fan';
    const caption = p.caption || p.image_caption || p.video_caption || '';
    const imageUrl = p.cloudinary_url || p.image_url || p.imageUrl || '';
    const createdAt = p.timestamp ? new Date(p.timestamp * 1000).toISOString().slice(0, 10) : '';

    // ---- Comments (GET /comments/posts/{postId}/comments) ----
    // Confirmed shape (post_comments.dart): { success, comments: [...] }.
    // Server sends camelCase (postId, userId, userName, likesCount, comment,
    // parentCommentId, replyCount, createdAt) — snake_case is a fallback only,
    // per the widget's own parsing comment about the Rust API's real output.
    let commentsHtml = '';
    const commentsData = await fetchJson(`${API_BASE}/comments/posts/${id}/comments`);
    const comments = (commentsData && commentsData.success && commentsData.comments) || [];
    if (comments.length) {
      commentsHtml = `
<h2>Comments (${comments.length})</h2>
${comments.slice(0, 100).map(c => {
        const cUser = c.userName || c.user_name || 'Fan';
        const cText = c.comment || '';
        return `<div class="match"><div><strong>${escapeHtml(cUser)}</strong>: ${escapeHtml(cText)}</div></div>`;
      }).join('\n')}
`;
    }

    const body = `
<h1>${escapeHtml(author)} on Funspot</h1>
${createdAt ? `<p class="meta">${escapeHtml(createdAt)}</p>` : ''}
${caption ? `<p>${escapeHtml(caption)}</p>` : ''}
${imageUrl ? `<img src="${escapeHtml(imageUrl)}" alt="Photo shared by ${escapeHtml(author)} on Funspot">` : ''}
${commentsHtml}
<p style="margin-top:24px;"><a href="/">← Back to Funspot</a></p>
`;

    writeFile(`post/${id}/index.html`, pageShell({
      title: `${author} on Funspot`,
      description: (caption && caption.slice(0, 155)) || `A post from ${author} on Funspot.`,
      canonicalPath: `/post/${id}/`,
      appRoute: `/post/${id}`,
      bodyHtml: body,
    }));

    sitemapUrls.push(`/post/${id}/`);
  }

  return sitemapUrls;
}

// ---------------------------------------------------------------------
// Leaderboard pages — per-channel ranked standings.
// Confirmed endpoints (join_groups_modal.dart / chat_screen.dart / leaderboard.dart):
//   GET {API}/channels/all               -> { channels: [...] }
//   GET {API}/channels/{id}/leaderboard  -> { success, leaderboard: [...] }
// Confirmed leaderboard entry fields (comrade_modal ComradeWithStats.fromChannelMember):
//   user_id, username, season_points, accuracy, rank, total_votes, correct_votes
// ---------------------------------------------------------------------
async function buildLeaderboardPages() {
  const data = await fetchJson(`${API_BASE}/channels/all`);
  const channels = (data && data.channels) || [];

  const sitemapUrls = [];

  for (const ch of channels.slice(0, 100)) {
    const id = ch.channel_id || ch.channelId || ch.id || ch._id;
    if (!id) continue;

    const name = ch.name || 'Channel';

    const lbData = await fetchJson(`${API_BASE}/channels/${id}/leaderboard`);
    const standings = (lbData && lbData.success && lbData.leaderboard) || [];

    const rows = standings.slice(0, 50).map((s, i) => {
      const username = s.username || 'Fan';
      const points = s.season_points ?? s.points ?? 0;
      const rank = s.rank ?? (i + 1);
      return `<div class="lb-row"><span class="lb-rank">#${escapeHtml(String(rank))}</span><span>${escapeHtml(username)}</span><span>${escapeHtml(String(points))} pts</span></div>`;
    }).join('\n');

    const body = `
<h1>${escapeHtml(name)} Leaderboard — Funspot</h1>
<p>Top fans in the ${escapeHtml(name)} channel, ranked by season points.</p>
${rows || '<p>No standings yet — be the first to climb the leaderboard.</p>'}
<p style="margin-top:24px;"><a href="/">← Back to Funspot</a></p>
`;

    writeFile(`leaderboard/${id}/index.html`, pageShell({
      title: `${name} Leaderboard — Funspot`,
      description: `See the top-ranked fans in the ${name} channel on Funspot.`,
      canonicalPath: `/leaderboard/${id}/`,
      appRoute: `/leaderboard/${id}`,
      bodyHtml: body,
    }));

    sitemapUrls.push(`/leaderboard/${id}/`);
  }

  return sitemapUrls;
}

// ---------------------------------------------------------------------
// Comrade / profile pages — public user profiles ("browsing comrades").
// Confirmed endpoint and shape (chat_screen.dart _fetchRealComradesFromApi,
// which calls this exact endpoint):
//   GET {API}/profile/profiles  ->  RAW JSON ARRAY, not wrapped in
//                                    { profiles: [...] } as originally guessed:
//                                      final List<dynamic> data = json.decode(response.body);
//                                      final profiles = data.cast<Map<String, dynamic>>();
// Confirmed field names (snake_case, from the same function's mapping):
//   user_id, username, nickname, club_fan, country_fan
// No avatarUrl field exists anywhere in the app's profile handling — dropped.
// (swipeable_profile_modal.dart independently confirms GET
//  {API}/profile/profile/{userId} is also unwrapped: a raw List or raw Map,
//  with the same snake_case fields plus phone/number_of_bets/balance — none
//  of which are public/appropriate for a static SEO page.)
// ---------------------------------------------------------------------
async function buildProfilePages() {
  const raw = await fetchJson(`${API_BASE}/profile/profiles`);
  const profiles = Array.isArray(raw) ? raw : (raw && raw.profiles) || [];

  const sitemapUrls = [];
  const indexCards = [];

  for (const p of profiles.slice(0, 200)) {
    const id = p.user_id || p.id;
    if (!id) continue;

    const username = p.username || 'Fan';
    const nickname = p.nickname || '';
    const club = p.club_fan || '';
    const country = p.country_fan || '';

    const displayName = nickname ? `${nickname} (@${username})` : `@${username}`;

    indexCards.push(`
      <a class="profile-card" href="/comrades/${id}/">
        <div>${escapeHtml(displayName)}</div>
        ${club ? `<div class="meta">${escapeHtml(club)}</div>` : ''}
      </a>
    `);

    const body = `
<div class="profile-header">
  <div>
    <h1>${escapeHtml(displayName)}</h1>
    <p class="meta">${[club, country].filter(Boolean).map(escapeHtml).join(' · ')}</p>
  </div>
</div>
<p>Follow ${escapeHtml(username)}'s votes, posts, and channel activity on
Funspot. Join the same channels to compete on the leaderboard together.</p>
<p style="margin-top:24px;"><a href="/comrades/">← Back to comrades</a></p>
`;

    writeFile(`comrades/${id}/index.html`, pageShell({
      title: `${displayName} — Funspot`,
      description: `${displayName}'s fan profile on Funspot${club ? ` — supports ${club}` : ''}.`,
      canonicalPath: `/comrades/${id}/`,
      appRoute: `/comrades/${id}`,
      bodyHtml: body,
    }));

    sitemapUrls.push(`/comrades/${id}/`);
  }

  const indexBody = `
<h1>Comrades — Funspot</h1>
<p>Browse fan profiles on Funspot. See who supports which club, and join
their channels to vote and chat together during matches.</p>
<div class="profile-grid">
${indexCards.join('\n')}
</div>
`;

  writeFile('comrades/index.html', pageShell({
    title: 'Comrades — Funspot',
    description: 'Browse fan profiles on Funspot and see who supports which club.',
    canonicalPath: '/comrades/',
    bodyHtml: indexBody,
  }));

  sitemapUrls.push('/comrades/');
  return sitemapUrls;
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
    channels with other fans, and chat in real time during matches.</li>
  <li><strong>Feed</strong> — share photos and videos with the community
    and follow other fans' posts.</li>
  <li><strong>History</strong> — browse settled fixtures, past results,
    and channel leaderboards.</li>
  <li><strong>Comrades</strong> — browse other fans' public profiles and
    see who supports which club.</li>
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
<p>For account issues (channel disputes, reporting abusive content, or
photo/video content concerns), please include your Funspot username or
phone number used to sign up so we can look into it faster.</p>
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
    <li><strong>Photos and videos</strong> — any photos or videos you choose
      to upload or share within the Feed or in channel chats.</li>
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
      photo/video sharing, and notifications.</li>
    <li>To maintain and improve the reliability and security of the app.</li>
  </ul>
</section>

<section>
  <h2>Third parties we use</h2>
  <p>Funspot relies on the following third-party service to operate:</p>
  <ul>
    <li><strong>Firebase</strong> (Google) — authentication and push
      notifications.</li>
  </ul>
  <p>This provider has its own privacy policy governing how it handles
  data on our behalf.</p>
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

async function buildSitemap(extraUrls) {
  const baseUrls = ['/', '/fixtures/', '/results/', '/comrades/', '/privacy/', '/about/', '/contact/'];
  const urls = [...baseUrls, ...extraUrls];
  const xml = `<?xml version="1.0" encoding="UTF-8"?>
<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">
${urls.map(u => `  <url><loc>${SITE_URL}${u}</loc></url>`).join('\n')}
</urlset>`;
  writeFile('sitemap.xml', xml);
}

async function main() {
  console.log('🔧 Generating static pages from Clash API...');

  const fixtures = await buildFixturesPage();
  const historyGames = await buildResultsPage();
  buildAboutPage();
  buildContactPage();
  buildPrivacyPage();

  // New content types — this is what closes the AdSense content gap.
  const fixtureDetailUrls = await buildFixtureDetailPages(fixtures, historyGames);
  const postUrls = await buildPostPages();
  const leaderboardUrls = await buildLeaderboardPages();
  const profileUrls = await buildProfilePages();

  await buildSitemap([...fixtureDetailUrls, ...postUrls, ...leaderboardUrls, ...profileUrls]);

  console.log(`✅ Static page generation complete. ${fixtureDetailUrls.length} fixture pages, ${postUrls.length} post pages, ${leaderboardUrls.length} leaderboard pages, ${profileUrls.length} comrade pages.`);
}

main().catch(e => {
  // Never fail the whole Netlify build if the API is down — the Flutter
  // app itself must still deploy. Log and exit cleanly.
  console.error('⚠️ Static page generation failed (non-fatal):', e);
  process.exit(0);
});