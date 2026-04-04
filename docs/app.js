'use strict';

// ============================================================
// CONSTANTS
// ============================================================

const STORAGE_KEY      = 'noireject_moments';
const CUSTOM_TAGS_KEY  = 'noireject_custom_tags';
const PREDEFINED_TAGS  = ['Work','Family','Gym','Health','Social','Study','Travel','Food'];

// ============================================================
// DATA LAYER
// ============================================================

function getMoments() {
  try { return JSON.parse(localStorage.getItem(STORAGE_KEY) || '[]'); }
  catch { return []; }
}

function writeMoments(moments) {
  localStorage.setItem(STORAGE_KEY, JSON.stringify(moments));
}

function getCustomTags() {
  try {
    const raw = localStorage.getItem(CUSTOM_TAGS_KEY) || '';
    return raw ? raw.split(',').filter(Boolean) : [];
  } catch { return []; }
}

function writeCustomTags(tags) {
  localStorage.setItem(CUSTOM_TAGS_KEY, tags.join(','));
}

function getAllTags() {
  return [...PREDEFINED_TAGS, ...getCustomTags()];
}

function removeMoment(id) {
  writeMoments(getMoments().filter(m => m.id !== id));
  renderCurrent();
}

// ============================================================
// HELPERS
// ============================================================

function momentScore(m) {
  return m.type === 'excited' ? m.intensity : -m.intensity;
}

function scoreForDate(dateStr) {
  return getMoments()
    .filter(m => m.date === dateStr)
    .reduce((s, m) => s + momentScore(m), 0);
}

function emojiForScore(score) {
  if (score < -20) return '😰';
  if (score <  -5) return '😔';
  if (score <=  5) return '😐';
  if (score <  20) return '😊';
  return '🤩';
}

function heatColor(score) {
  if (score < -20) return '#FF3B30';
  if (score <   0) return '#FF9500';
  if (score ===  0) return '#C7C7CC';
  if (score <  20) return '#A8D5A2';
  return '#30B050';
}

function todayStr() {
  return new Date().toISOString().split('T')[0];
}

function dateParts(y, m, d) {
  return `${y}-${String(m).padStart(2,'0')}-${String(d).padStart(2,'0')}`;
}

function formatDateLong(dateStr) {
  const d = new Date(dateStr + 'T12:00:00');
  return d.toLocaleDateString(undefined, { weekday:'long', month:'long', day:'numeric' });
}

function formatDateFull(date) {
  return date.toLocaleDateString(undefined, { weekday:'long', month:'long', day:'numeric' });
}

/** Escape user content before inserting into innerHTML */
function esc(str) {
  return String(str)
    .replace(/&/g,'&amp;')
    .replace(/</g,'&lt;')
    .replace(/>/g,'&gt;')
    .replace(/"/g,'&quot;');
}

// ============================================================
// UI STATE
// ============================================================

let currentTab = 'today';
let calMonth   = new Date();   // month shown in calendar view

let form = { type:'uncomfortable', intensity:5, tags:[], note:'' };

// ============================================================
// TAB NAVIGATION
// ============================================================

const TAB_TITLES = { today:'Today', calendar:'Calendar', year:'Year', insights:'Insights' };

function showTab(tab) {
  currentTab = tab;
  document.querySelectorAll('.tab-btn')
    .forEach(b => b.classList.toggle('active', b.dataset.tab === tab));
  document.querySelectorAll('.tab-pane')
    .forEach(p => p.classList.toggle('active', p.id === tab + '-tab'));
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

// ============================================================
// TODAY TAB
// ============================================================

function renderToday() {
  const today   = todayStr();
  const moments = getMoments().filter(m => m.date === today);
  const score   = moments.reduce((s, m) => s + momentScore(m), 0);
  const scoreStr = (score > 0 ? '+' : '') + score;
  const el    = document.getElementById('today-tab');

  const card = `
    <div class="score-card">
      <div class="score-emoji">${emojiForScore(score)}</div>
      <div class="score-num">${scoreStr}</div>
      <div class="score-date">${formatDateFull(new Date())}</div>
    </div>`;

  if (moments.length === 0) {
    el.innerHTML = card + `
      <div class="empty-state">
        <div class="empty-icon">📝</div>
        <div class="empty-title">No moments yet</div>
        <div class="empty-sub">Tap + to log your first moment</div>
      </div>`;
    return;
  }

  el.innerHTML = card + `
    <div class="section-label">Today's Moments</div>
    <div class="list-card">${moments.map(m => momentRowHtml(m, true)).join('')}</div>`;
}

function momentRowHtml(m, showDelete) {
  const s      = momentScore(m);
  const sStr   = (s > 0 ? '+' : '') + s;
  const delBtn = showDelete
    ? `<button class="del-btn" onclick="removeMoment('${m.id}')" aria-label="Delete">×</button>`
    : '';
  return `
    <div class="moment-row">
      <span class="moment-type-icon">${m.type === 'excited' ? '🚀' : '😤'}</span>
      <div class="moment-info">
        <div class="moment-tags-text">${m.tags.length ? m.tags.map(esc).join(', ') : '—'}</div>
        ${m.note ? `<div class="moment-note-text">${esc(m.note)}</div>` : ''}
      </div>
      <span class="moment-score-badge ${m.type}">${sStr}</span>
      ${delBtn}
    </div>`;
}

// ============================================================
// CALENDAR TAB
// ============================================================

function renderCalendar() {
  const year  = calMonth.getFullYear();
  const month = calMonth.getMonth();
  const label = calMonth.toLocaleString(undefined, { month:'long', year:'numeric' });
  const today = todayStr();

  const firstDOW    = new Date(year, month, 1).getDay();
  const daysInMonth = new Date(year, month + 1, 0).getDate();

  const dayHeaders = ['Sun','Mon','Tue','Wed','Thu','Fri','Sat']
    .map(d => `<div class="cal-dow">${d}</div>`).join('');

  let cells = '';
  for (let i = 0; i < firstDOW; i++) cells += '<div class="cal-cell empty"></div>';
  for (let d = 1; d <= daysInMonth; d++) {
    const ds      = dateParts(year, month + 1, d);
    const moments = getMoments().filter(m => m.date === ds);
    const score   = moments.reduce((s, m) => s + momentScore(m), 0);
    const isToday = ds === today;
    cells += `
      <div class="cal-cell${isToday ? ' is-today' : ''}" onclick="openDayDetail('${ds}')">
        <div class="cal-day-num${isToday ? ' today-num' : ''}">${d}</div>
        ${moments.length ? `<div class="cal-emoji">${esc(emojiForScore(score))}</div>` : ''}
      </div>`;
  }

  document.getElementById('calendar-tab').innerHTML = `
    <div class="card cal-nav-card">
      <button class="nav-btn" onclick="changeMonth(-1)">‹</button>
      <span class="cal-month-label">${esc(label)}</span>
      <button class="nav-btn" onclick="changeMonth(1)">›</button>
    </div>
    <div class="card cal-grid-card">
      <div class="cal-grid">${dayHeaders}${cells}</div>
    </div>`;
}

function changeMonth(delta) {
  calMonth = new Date(calMonth.getFullYear(), calMonth.getMonth() + delta, 1);
  renderCalendar();
}

function openDayDetail(dateStr) {
  const moments = getMoments().filter(m => m.date === dateStr);
  const score   = moments.reduce((s, m) => s + momentScore(m), 0);

  document.getElementById('day-sheet-title').textContent = formatDateLong(dateStr);

  let body = `<div class="day-score">${esc(emojiForScore(score))} Score: ${score > 0 ? '+' : ''}${score}</div>`;
  if (moments.length === 0) {
    body += '<div class="empty-state-sm">No moments logged</div>';
  } else {
    body += `<div class="list-card">${moments.map(m => momentRowHtml(m, false)).join('')}</div>`;
  }

  document.getElementById('day-sheet-content').innerHTML = body;
  document.getElementById('day-overlay').classList.remove('hidden');
}

function closeDayModal() {
  document.getElementById('day-overlay').classList.add('hidden');
}

// ============================================================
// YEAR TAB
// ============================================================

function renderYear() {
  const today = todayStr();
  const year  = new Date().getFullYear();

  const months = [];
  for (let mo = 0; mo < 12; mo++) {
    const daysInMonth = new Date(year, mo + 1, 0).getDate();
    const monthName   = new Date(year, mo, 1).toLocaleString(undefined, { month:'short' });

    let cells = '';
    for (let d = 1; d <= daysInMonth; d++) {
      const ds         = dateParts(year, mo + 1, d);
      const isPast     = ds <= today;
      const hasMoments = isPast && getMoments().some(m => m.date === ds);
      const score      = hasMoments ? scoreForDate(ds) : null;
      const bg         = hasMoments ? heatColor(score) : (isPast ? '#E5E5EA' : '#F2F2F7');
      const outline    = ds === today ? ' style="outline:2px solid #007AFF;outline-offset:1px;"' : '';
      cells += `<div class="year-cell" style="background:${bg}"${outline}></div>`;
    }

    months.push(`
      <div class="year-month-row">
        <div class="year-month-name">${esc(monthName)}</div>
        <div class="year-month-cells">${cells}</div>
      </div>`);
  }

  const LEGEND = [
    ['#FF3B30','Very bad'],
    ['#FF9500','Bad'],
    ['#E5E5EA','Neutral'],
    ['#A8D5A2','Good'],
    ['#30B050','Great'],
  ];

  document.getElementById('year-tab').innerHTML = `
    <div class="year-heading">${year} Overview</div>
    <div class="year-legend">
      ${LEGEND.map(([c,l]) =>
        `<span class="legend-item"><span class="legend-dot" style="background:${c}"></span>${esc(l)}</span>`
      ).join('')}
    </div>
    <div class="card year-card">${months.join('')}</div>`;
}

// ============================================================
// INSIGHTS TAB
// ============================================================

function renderInsights() {
  const moments = getMoments();
  const el      = document.getElementById('insights-tab');

  if (moments.length === 0) {
    el.innerHTML = `
      <div class="empty-state">
        <div class="empty-icon">💡</div>
        <div class="empty-title">No data yet</div>
        <div class="empty-sub">Log moments to unlock insights</div>
      </div>`;
    return;
  }

  const allDates   = [...new Set(moments.map(m => m.date))].sort();
  const totalScore = allDates.reduce((s, d) => s + scoreForDate(d), 0);
  const avgScore   = totalScore / allDates.length;
  const streak     = calcStreak(moments);

  // Tag stats
  const tagMap = {};
  moments.forEach(m => {
    m.tags.forEach(tag => {
      if (!tagMap[tag]) tagMap[tag] = { total:0, count:0 };
      tagMap[tag].total += momentScore(m);
      tagMap[tag].count++;
    });
  });
  const tagStats = Object.entries(tagMap)
    .map(([tag, { total, count }]) => ({ tag, avg: total / count, count }))
    .sort((a, b) => b.avg - a.avg);

  const tagRow = t => `
    <div class="tag-stat-row">
      <span class="tag-stat-name">${esc(t.tag)}</span>
      <span class="tag-stat-count">${t.count} moment${t.count > 1 ? 's' : ''}</span>
      <span class="tag-stat-avg ${t.avg >= 0 ? 'pos' : 'neg'}">${t.avg > 0 ? '+' : ''}${t.avg.toFixed(1)}</span>
    </div>`;

  const happy    = tagStats.filter(t => t.avg > 0);
  const draining = [...tagStats.filter(t => t.avg < 0)].reverse();

  el.innerHTML = `
    <div class="card stats-card">
      <div class="stat-trio">
        <div class="stat-block">
          <div class="stat-val">${esc(emojiForScore(avgScore))}</div>
          <div class="stat-label">Overall</div>
        </div>
        <div class="stat-block">
          <div class="stat-val">${allDates.length}</div>
          <div class="stat-label">Days Logged</div>
        </div>
        <div class="stat-block">
          <div class="stat-val">${streak}🔥</div>
          <div class="stat-label">Streak</div>
        </div>
      </div>
    </div>
    ${happy.length ? `
      <div class="section-label">😊 What Makes You Happy</div>
      <div class="list-card">${happy.map(tagRow).join('')}</div>` : ''}
    ${draining.length ? `
      <div class="section-label">😔 What Drains You</div>
      <div class="list-card">${draining.map(tagRow).join('')}</div>` : ''}
    ${tagStats.length ? `
      <div class="section-label">All Tags</div>
      <div class="list-card">${tagStats.map(tagRow).join('')}</div>` : ''}`;
}

function calcStreak(moments) {
  const logged = new Set(moments.map(m => m.date));
  let streak = 0;
  const d = new Date();
  while (true) {
    const ds = d.toISOString().split('T')[0];
    if (logged.has(ds)) { streak++; d.setDate(d.getDate() - 1); }
    else break;
  }
  return streak;
}

// ============================================================
// ADD MOMENT MODAL
// ============================================================

function openAddModal() {
  form = { type:'uncomfortable', intensity:5, tags:[], note:'' };
  renderForm();
  document.getElementById('add-overlay').classList.remove('hidden');
}

function closeAddModal() {
  document.getElementById('add-overlay').classList.add('hidden');
}

function renderForm() {
  // Type buttons
  document.getElementById('btn-uncomfortable').classList.toggle('active', form.type === 'uncomfortable');
  document.getElementById('btn-excited').classList.toggle('active', form.type === 'excited');

  // Score preview
  const s  = form.type === 'excited' ? form.intensity : -form.intensity;
  const sp = document.getElementById('score-preview');
  sp.textContent = `Score: ${s > 0 ? '+' : ''}${s}`;
  sp.className   = `score-preview ${form.type}`;

  // Intensity
  document.getElementById('intensity-picker').innerHTML =
    Array.from({ length:20 }, (_, i) => i + 1)
      .map(i => `<button class="int-btn${form.intensity === i ? ' active' : ''}" onclick="selectIntensity(${i})">${i}</button>`)
      .join('');

  // Tags — use index to avoid unsafe strings in onclick
  const allTags = getAllTags();
  document.getElementById('tags-picker').innerHTML =
    allTags.map((tag, idx) =>
      `<button class="tag-chip${form.tags.includes(tag) ? ' active' : ''}" onclick="toggleTagIdx(${idx})">${esc(tag)}</button>`
    ).join('');

  // Note
  document.getElementById('note-input').value = form.note;
}

function selectType(type) {
  form.type = type;
  renderForm();
}

function selectIntensity(i) {
  form.intensity = i;
  renderForm();
}

function toggleTagIdx(idx) {
  const tag = getAllTags()[idx];
  if (!tag) return;
  if (form.tags.includes(tag)) {
    form.tags = form.tags.filter(t => t !== tag);
  } else {
    form.tags.push(tag);
  }
  renderForm();
}

function addCustomTag() {
  const input = document.getElementById('custom-tag-input');
  const tag   = input.value.trim();
  if (!tag) return;
  const custom = getCustomTags();
  if (!custom.includes(tag) && !PREDEFINED_TAGS.includes(tag)) {
    custom.push(tag);
    writeCustomTags(custom);
  }
  if (!form.tags.includes(tag)) form.tags.push(tag);
  input.value = '';
  renderForm();
}

function submitMoment() {
  form.note = document.getElementById('note-input').value.trim();
  writeMoments([...getMoments(), {
    id:        Date.now().toString(),
    date:      todayStr(),
    type:      form.type,
    intensity: form.intensity,
    tags:      [...form.tags],
    note:      form.note,
  }]);
  closeAddModal();
  renderCurrent();
}

// ============================================================
// OVERLAY DISMISS
// ============================================================

function handleOverlayClick(e, sheetId) {
  if (e.target !== e.currentTarget) return;
  if (sheetId === 'add-sheet') closeAddModal();
  if (sheetId === 'day-sheet') closeDayModal();
}

// ============================================================
// INIT
// ============================================================

document.addEventListener('DOMContentLoaded', () => {
  showTab('today');
  document.getElementById('custom-tag-input')
    .addEventListener('keydown', e => {
      if (e.key === 'Enter') { e.preventDefault(); addCustomTag(); }
    });
});
