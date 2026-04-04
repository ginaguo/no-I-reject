'use strict';

const SUPABASE_URL = 'https://xrvokelhhoxrqgdpgula.supabase.co';
const SUPABASE_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Inhydm9rZWxoaG94cnFnZHBndWxhIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzUzMjgyMjIsImV4cCI6MjA5MDkwNDIyMn0.XhT2hzXoOmq5dcawG39wCpiyojkvX3TR6A-206e-mQ4';
let sb;

const CUSTOM_TAGS_KEY = 'noireject_custom_tags';
const PREDEFINED_TAGS = ['Work','Family','Gym','Health','Social','Study','Travel','Food'];

let currentUser   = null;
let cachedMoments = [];
let currentTab    = 'today';
let calMonth      = new Date();
let form          = { type:'uncomfortable', intensity:5, tags:[], note:'' };

// AUTH
async function initAuth() {
  const { data: { session } } = await sb.auth.getSession();
  if (session && session.user) {
    currentUser = session.user;
    await loadMoments();
    showApp();
  } else {
    showLoginScreen();
  }
  sb.auth.onAuthStateChange(async (event, session) => {
    if (event === 'SIGNED_IN' && session && session.user) {
      currentUser = session.user;
      await loadMoments();
      showApp();
    } else if (event === 'SIGNED_OUT') {
      currentUser = null;
      cachedMoments = [];
      showLoginScreen();
    }
  });
}

function setAuthError(msg) {
  const el = document.getElementById('auth-error');
  if (!el) return;
  el.textContent = msg;
  el.classList.toggle('hidden', !msg);
}

function setAuthBusy(busy) {
  document.getElementById('login-btn').disabled  = busy;
  document.getElementById('signup-btn').disabled = busy;
}

async function handleLogin() {
  const email    = document.getElementById('email-input').value.trim();
  const password = document.getElementById('password-input').value;
  if (!email || !password) { setAuthError('Enter your email and password.'); return; }
  setAuthBusy(true); setAuthError('');
  const { error } = await sb.auth.signInWithPassword({ email, password });
  setAuthBusy(false);
  if (error) setAuthError(error.message);
}

async function handleSignUp() {
  const email    = document.getElementById('email-input').value.trim();
  const password = document.getElementById('password-input').value;
  if (!email || !password) { setAuthError('Enter email and password (min 6 chars).'); return; }
  if (password.length < 6) { setAuthError('Password must be at least 6 characters.'); return; }
  setAuthBusy(true); setAuthError('');
  const { error } = await sb.auth.signUp({ email, password });
  setAuthBusy(false);
  if (error) setAuthError(error.message);
}

async function handleSignOut() { await sb.auth.signOut(); }

function showLoginScreen() {
  document.getElementById('login-screen').classList.remove('hidden');
  document.getElementById('app-content').classList.add('hidden');
}

function showApp() {
  document.getElementById('login-screen').classList.add('hidden');
  document.getElementById('app-content').classList.remove('hidden');
  bindAppListeners();
  showTab('today');
}

// DATA
async function loadMoments() {
  const { data, error } = await sb.from('moments').select('*')
    .eq('user_id', currentUser.id).order('created_at', { ascending: false });
  if (!error) cachedMoments = data || [];
}

function getMoments() { return cachedMoments; }

async function removeMoment(id) {
  cachedMoments = cachedMoments.filter(m => m.id !== id);
  renderCurrent();
  await sb.from('moments').delete().eq('id', id).eq('user_id', currentUser.id);
}

async function persistAddMoment(moment) {
  const { id: tempId, ...fields } = moment;
  const { data, error } = await sb.from('moments')
    .insert({ ...fields, user_id: currentUser.id }).select().single();
  if (!error && data) {
    // replace temp local id with the real Supabase UUID
    cachedMoments = cachedMoments.map(m => m.id === tempId ? data : m);
  }
}

// CUSTOM TAGS
function getCustomTags() {
  try {
    const raw = localStorage.getItem(CUSTOM_TAGS_KEY) || '';
    return raw ? raw.split(',').filter(Boolean) : [];
  } catch(e) { return []; }
}
function writeCustomTags(tags) { localStorage.setItem(CUSTOM_TAGS_KEY, tags.join(',')); }
function getAllTags() { return [...PREDEFINED_TAGS, ...getCustomTags()]; }

// HELPERS
function momentScore(m) { return m.type === 'excited' ? m.intensity : -m.intensity; }

function scoreForDate(dateStr) {
  return getMoments()
    .filter(m => m.date === dateStr)
    .reduce((s, m) => s + momentScore(m), 0);
}

function emojiForScore(score) {
  if (score < -20) return '\uD83D\uDE30';
  if (score <  -5) return '\uD83D\uDE14';
  if (score <=  5) return '\uD83D\uDE10';
  if (score <  20) return '\uD83D\uDE0A';
  return '\uD83E\uDD29';
}

function heatColor(score) {
  if (score < -20) return '#FF3B30';
  if (score <   0) return '#FF9500';
  if (score === 0) return '#C7C7CC';
  if (score <  20) return '#A8D5A2';
  return '#30B050';
}

function todayStr() { return new Date().toISOString().split('T')[0]; }

function dateParts(y, m, d) {
  return y + '-' + String(m).padStart(2,'0') + '-' + String(d).padStart(2,'0');
}

function formatDateLong(ds) {
  return new Date(ds + 'T12:00:00').toLocaleDateString(undefined, {
    weekday:'long', month:'long', day:'numeric'
  });
}

function formatDateFull(d) {
  return d.toLocaleDateString(undefined, { weekday:'long', month:'long', day:'numeric' });
}

function esc(str) {
  return String(str)
    .replace(/&/g,'&amp;').replace(/</g,'&lt;').replace(/>/g,'&gt;').replace(/"/g,'&quot;');
}

// TABS
const TAB_TITLES = { today:'Today', calendar:'Calendar', year:'Year', insights:'Insights' };

function showTab(tab) {
  currentTab = tab;
  document.querySelectorAll('.tab-btn').forEach(b => b.classList.toggle('active', b.dataset.tab === tab));
  document.querySelectorAll('.tab-pane').forEach(p => p.classList.toggle('active', p.id === tab + '-tab'));
  document.getElementById('header-title').textContent = TAB_TITLES[tab];
  document.getElementById('fab').style.display = tab === 'today' ? 'flex' : 'none';
  renderCurrent();
}

function renderCurrent() {
  if (currentTab === 'today')    renderToday();
  if (currentTab === 'calendar') renderCalendar();
  if (currentTab === 'year')     renderYear();
  if (currentTab === 'insights') renderInsights();
}

// TODAY
function renderToday() {
  const today   = todayStr();
  const moments = getMoments().filter(m => m.date === today);
  const score   = moments.reduce((s, m) => s + momentScore(m), 0);
  const scoreStr = (score > 0 ? '+' : '') + score;
  const el = document.getElementById('today-tab');
  const card =
    '<div class="score-card">' +
      '<div class="score-emoji">' + emojiForScore(score) + '</div>' +
      '<div class="score-num">' + scoreStr + '</div>' +
      '<div class="score-date">' + formatDateFull(new Date()) + '</div>' +
    '</div>';
  if (moments.length === 0) {
    el.innerHTML = card +
      '<div class="empty-state">' +
        '<div class="empty-icon">\uD83D\uDCDD</div>' +
        '<div class="empty-title">No moments yet</div>' +
        '<div class="empty-sub">Tap + to log your first moment</div>' +
      '</div>';
    return;
  }
  el.innerHTML = card +
    '<div class="section-label">Today\'s Moments</div>' +
    '<div class="list-card">' + moments.map(m => momentRowHtml(m, true)).join('') + '</div>';
}

function momentRowHtml(m, showDelete) {
  const s    = momentScore(m);
  const sStr = (s > 0 ? '+' : '') + s;
  const tags = Array.isArray(m.tags) ? m.tags : [];
  const del  = showDelete
    ? '<button class="del-btn" onclick="removeMoment(\'' + esc(m.id) + '\')" aria-label="Delete">&times;</button>'
    : '';
  return '<div class="moment-row">' +
    '<span class="moment-type-icon">' + (m.type === 'excited' ? '\uD83D\uDE80' : '\uD83D\uDE24') + '</span>' +
    '<div class="moment-info">' +
      '<div class="moment-tags-text">' + (tags.length ? tags.map(esc).join(', ') : '&mdash;') + '</div>' +
      (m.note ? '<div class="moment-note-text">' + esc(m.note) + '</div>' : '') +
    '</div>' +
    '<span class="moment-score-badge ' + m.type + '">' + sStr + '</span>' +
    del + '</div>';
}

// CALENDAR
function renderCalendar() {
  const year  = calMonth.getFullYear();
  const month = calMonth.getMonth();
  const label = calMonth.toLocaleString(undefined, { month:'long', year:'numeric' });
  const today = todayStr();
  const firstDOW    = new Date(year, month, 1).getDay();
  const daysInMonth = new Date(year, month + 1, 0).getDate();
  const heads = ['Sun','Mon','Tue','Wed','Thu','Fri','Sat']
    .map(d => '<div class="cal-dow">' + d + '</div>').join('');
  let cells = '';
  for (let i = 0; i < firstDOW; i++) cells += '<div class="cal-cell empty"></div>';
  for (let d = 1; d <= daysInMonth; d++) {
    const ds  = dateParts(year, month + 1, d);
    const ms  = getMoments().filter(m => m.date === ds);
    const sc  = ms.reduce((s, m) => s + momentScore(m), 0);
    const isTod = ds === today;
    cells += '<div class="cal-cell" onclick="openDayDetail(\'' + ds + '\')">' +
      '<div class="cal-day-num' + (isTod ? ' today-num' : '') + '">' + d + '</div>' +
      (ms.length ? '<div class="cal-emoji">' + emojiForScore(sc) + '</div>' : '') +
      '</div>';
  }
  document.getElementById('calendar-tab').innerHTML =
    '<div class="card cal-nav-card">' +
      '<button class="nav-btn" onclick="changeMonth(-1)">\u2039</button>' +
      '<span class="cal-month-label">' + esc(label) + '</span>' +
      '<button class="nav-btn" onclick="changeMonth(1)">\u203A</button>' +
    '</div>' +
    '<div class="card cal-grid-card"><div class="cal-grid">' + heads + cells + '</div></div>';
}

function changeMonth(delta) {
  calMonth = new Date(calMonth.getFullYear(), calMonth.getMonth() + delta, 1);
  renderCalendar();
}

function openDayDetail(dateStr) {
  const ms = getMoments().filter(m => m.date === dateStr);
  const sc = ms.reduce((s, m) => s + momentScore(m), 0);
  document.getElementById('day-sheet-title').textContent = formatDateLong(dateStr);
  let body = '<div class="day-score">' + emojiForScore(sc) + ' Score: ' + (sc > 0 ? '+' : '') + sc + '</div>';
  body += ms.length === 0
    ? '<div class="empty-state-sm">No moments logged</div>'
    : '<div class="list-card">' + ms.map(m => momentRowHtml(m, false)).join('') + '</div>';
  document.getElementById('day-sheet-content').innerHTML = body;
  document.getElementById('day-overlay').classList.remove('hidden');
}

function closeDayModal() { document.getElementById('day-overlay').classList.add('hidden'); }

// YEAR
function renderYear() {
  const today = todayStr();
  const year  = new Date().getFullYear();
  const LEGEND = [
    ['#FF3B30','Very bad'], ['#FF9500','Bad'], ['#E5E5EA','Neutral'],
    ['#A8D5A2','Good'],     ['#30B050','Great']
  ];
  let months = '';
  for (let mo = 0; mo < 12; mo++) {
    const dim  = new Date(year, mo + 1, 0).getDate();
    const name = new Date(year, mo, 1).toLocaleString(undefined, { month:'short' });
    let cells = '';
    for (let d = 1; d <= dim; d++) {
      const ds     = dateParts(year, mo + 1, d);
      const isPast = ds <= today;
      const has    = isPast && getMoments().some(m => m.date === ds);
      const bg     = has ? heatColor(scoreForDate(ds)) : (isPast ? '#E5E5EA' : '#F2F2F7');
      const ol     = ds === today ? ' style="outline:2px solid #007AFF;outline-offset:1px;"' : '';
      cells += '<div class="year-cell" style="background:' + bg + '"' + ol + '></div>';
    }
    months += '<div class="year-month-row">' +
      '<div class="year-month-name">' + esc(name) + '</div>' +
      '<div class="year-month-cells">' + cells + '</div>' +
      '</div>';
  }
  const leg = LEGEND.map(([c,l]) =>
    '<span class="legend-item"><span class="legend-dot" style="background:' + c + '"></span>' + esc(l) + '</span>'
  ).join('');
  document.getElementById('year-tab').innerHTML =
    '<div class="year-heading">' + year + ' Overview</div>' +
    '<div class="year-legend">' + leg + '</div>' +
    '<div class="card year-card">' + months + '</div>';
}

// INSIGHTS
function renderInsights() {
  const moments = getMoments();
  const el = document.getElementById('insights-tab');
  if (moments.length === 0) {
    el.innerHTML =
      '<div class="empty-state">' +
        '<div class="empty-icon">\uD83D\uDCA1</div>' +
        '<div class="empty-title">No data yet</div>' +
        '<div class="empty-sub">Log moments to unlock insights</div>' +
      '</div>';
    return;
  }
  const allDates = [...new Set(moments.map(m => m.date))].sort();
  const avgScore = allDates.reduce((s, d) => s + scoreForDate(d), 0) / allDates.length;
  const streak   = calcStreak(moments);
  const tagMap   = {};
  moments.forEach(m => {
    const tags = Array.isArray(m.tags) ? m.tags : [];
    tags.forEach(tag => {
      if (!tagMap[tag]) tagMap[tag] = { total:0, count:0 };
      tagMap[tag].total += momentScore(m);
      tagMap[tag].count++;
    });
  });
  const tagStats = Object.entries(tagMap)
    .map(([tag, { total, count }]) => ({ tag, avg: total / count, count }))
    .sort((a, b) => b.avg - a.avg);

  const tagRow = t =>
    '<div class="tag-stat-row">' +
      '<span class="tag-stat-name">' + esc(t.tag) + '</span>' +
      '<span class="tag-stat-count">' + t.count + ' moment' + (t.count > 1 ? 's' : '') + '</span>' +
      '<span class="tag-stat-avg ' + (t.avg >= 0 ? 'pos' : 'neg') + '">' + (t.avg > 0 ? '+' : '') + t.avg.toFixed(1) + '</span>' +
    '</div>';

  const happy    = tagStats.filter(t => t.avg > 0);
  const draining = [...tagStats.filter(t => t.avg < 0)].reverse();

  el.innerHTML =
    '<div class="card stats-card"><div class="stat-trio">' +
      '<div class="stat-block"><div class="stat-val">' + emojiForScore(avgScore) + '</div><div class="stat-label">Overall</div></div>' +
      '<div class="stat-block"><div class="stat-val">' + allDates.length + '</div><div class="stat-label">Days Logged</div></div>' +
      '<div class="stat-block"><div class="stat-val">' + streak + '\uD83D\uDD25</div><div class="stat-label">Streak</div></div>' +
    '</div></div>' +
    (happy.length    ? '<div class="section-label">\uD83D\uDE0A What Makes You Happy</div><div class="list-card">' + happy.map(tagRow).join('') + '</div>' : '') +
    (draining.length ? '<div class="section-label">\uD83D\uDE14 What Drains You</div><div class="list-card">' + draining.map(tagRow).join('') + '</div>' : '') +
    (tagStats.length ? '<div class="section-label">All Tags</div><div class="list-card">' + tagStats.map(tagRow).join('') + '</div>' : '');
}

function calcStreak(moments) {
  const logged = new Set(moments.map(m => m.date));
  let streak = 0;
  const d = new Date();
  while (logged.has(d.toISOString().split('T')[0])) {
    streak++;
    d.setDate(d.getDate() - 1);
  }
  return streak;
}

// ADD MOMENT
function openAddModal() {
  form = { type:'uncomfortable', intensity:5, tags:[], note:'' };
  renderForm();
  document.getElementById('add-overlay').classList.remove('hidden');
}
function closeAddModal() { document.getElementById('add-overlay').classList.add('hidden'); }

function renderForm() {
  document.getElementById('btn-uncomfortable').classList.toggle('active', form.type === 'uncomfortable');
  document.getElementById('btn-excited').classList.toggle('active', form.type === 'excited');
  const s  = form.type === 'excited' ? form.intensity : -form.intensity;
  const sp = document.getElementById('score-preview');
  sp.textContent = 'Score: ' + (s > 0 ? '+' : '') + s;
  sp.className   = 'score-preview ' + form.type;
  document.getElementById('intensity-picker').innerHTML =
    Array.from({ length:20 }, (_, i) => i + 1)
      .map(i => '<button class="int-btn' + (form.intensity === i ? ' active' : '') + '" onclick="selectIntensity(' + i + ')">' + i + '</button>')
      .join('');
  const allTags = getAllTags();
  document.getElementById('tags-picker').innerHTML = allTags
    .map((tag, idx) =>
      '<button class="tag-chip' + (form.tags.includes(tag) ? ' active' : '') + '" onclick="toggleTagIdx(' + idx + ')">' + esc(tag) + '</button>'
    ).join('');
  document.getElementById('note-input').value = form.note;
}

function selectType(type)   { form.type = type; renderForm(); }
function selectIntensity(i) { form.intensity = i; renderForm(); }

function toggleTagIdx(idx) {
  const tag = getAllTags()[idx];
  if (!tag) return;
  form.tags = form.tags.includes(tag) ? form.tags.filter(t => t !== tag) : [...form.tags, tag];
  renderForm();
}

function addCustomTag() {
  const input = document.getElementById('custom-tag-input');
  const tag   = input.value.trim();
  if (!tag) return;
  const custom = getCustomTags();
  if (!custom.includes(tag) && !PREDEFINED_TAGS.includes(tag)) { custom.push(tag); writeCustomTags(custom); }
  if (!form.tags.includes(tag)) form.tags.push(tag);
  input.value = '';
  renderForm();
}

async function submitMoment() {
  form.note = document.getElementById('note-input').value.trim();
  const moment = {
    id:        Date.now().toString(),
    date:      todayStr(),
    type:      form.type,
    intensity: form.intensity,
    tags:      [...form.tags],
    note:      form.note
  };
  closeAddModal();
  cachedMoments.unshift({ ...moment, user_id: currentUser.id });
  renderCurrent();
  await persistAddMoment(moment);
}

function handleOverlayClick(e, sheetId) {
  if (e.target !== e.currentTarget) return;
  if (sheetId === 'add-sheet') closeAddModal();
  if (sheetId === 'day-sheet') closeDayModal();
}

// BIND LISTENERS
function bindAppListeners() {
  const el = document.getElementById('custom-tag-input');
  if (el && !el._bound) {
    el._bound = true;
    el.addEventListener('keydown', e => { if (e.key === 'Enter') { e.preventDefault(); addCustomTag(); } });
  }
}

// WINDOW EXPORTS
window.handleLogin        = handleLogin;
window.handleSignUp       = handleSignUp;
window.handleSignOut      = handleSignOut;
window.showTab            = showTab;
window.openAddModal       = openAddModal;
window.closeAddModal      = closeAddModal;
window.submitMoment       = submitMoment;
window.selectType         = selectType;
window.selectIntensity    = selectIntensity;
window.toggleTagIdx       = toggleTagIdx;
window.addCustomTag       = addCustomTag;
window.removeMoment       = removeMoment;
window.changeMonth        = changeMonth;
window.openDayDetail      = openDayDetail;
window.closeDayModal      = closeDayModal;
window.handleOverlayClick = handleOverlayClick;

document.addEventListener('DOMContentLoaded', () => {
  if (typeof supabase === 'undefined') {
    alert('Failed to load Supabase. Refresh the page.');
    return;
  }
  sb = supabase.createClient(SUPABASE_URL, SUPABASE_KEY);
  initAuth();
  document.getElementById('password-input').addEventListener('keydown', e => {
    if (e.key === 'Enter') { e.preventDefault(); handleLogin(); }
  });
});
