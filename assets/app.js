(function () {
  const sb = supabase.createClient(SUPABASE_URL, SUPABASE_ANON_KEY);

  const currentLang = () => document.documentElement.lang || 'lv';
  const t = (key) => (window.dict && window.dict[currentLang()] && window.dict[currentLang()][key]) || key;

  function esc(str) {
    return String(str == null ? '' : str).replace(/[&<>"']/g, (c) => ({
      '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;',
    }[c]));
  }

  // ---------- Lightbox: full-size preview for gallery/podium media ----------
  const lightbox = document.getElementById('lightbox');
  const lightboxInner = document.getElementById('lightboxInner');

  function openLightbox(url, type, label) {
    if (!url) return;
    lightboxInner.innerHTML = type === 'video'
      ? `<video src="${url}" controls autoplay playsinline></video>`
      : `<img src="${url}" alt="${esc(label || '')}">`;
    lightbox.classList.add('open');
  }
  function closeLightbox() {
    lightbox.classList.remove('open');
    lightboxInner.innerHTML = '';
  }
  document.getElementById('lightboxClose').addEventListener('click', closeLightbox);
  lightbox.addEventListener('click', (e) => { if (e.target === lightbox) closeLightbox(); });
  document.addEventListener('keydown', (e) => { if (e.key === 'Escape') closeLightbox(); });

  function bindLightboxClicks(container) {
    container.addEventListener('click', (e) => {
      const card = e.target.closest('[data-media-url]');
      if (!card) return;
      openLightbox(card.getAttribute('data-media-url'), card.getAttribute('data-media-type'), card.getAttribute('data-media-label'));
    });
  }
  bindLightboxClicks(document.getElementById('galleryGrid'));
  bindLightboxClicks(document.getElementById('podiumGrid'));

  // ---------- Form: show/hide parent fields for minors ----------
  const form = document.getElementById('entryForm');
  const parentFields = document.getElementById('parentFields');
  const ageSelect = form.querySelector('select[name="age_bracket"]');
  const parentNameInput = form.querySelector('input[name="parent_name"]');
  const parentEmailInput = form.querySelector('input[name="parent_email"]');

  function syncParentFields() {
    const isMinor = ageSelect.value === 'minor';
    parentFields.classList.toggle('field-hidden', !isMinor);
    parentNameInput.required = isMinor;
    parentEmailInput.required = isMinor;
  }
  ageSelect.addEventListener('change', syncParentFields);
  syncParentFields();

  // ---------- Form submit ----------
  const msgBox = document.getElementById('formMsg');
  const submitBtn = form.querySelector('.submit-btn');

  function showMsg(text, ok) {
    msgBox.textContent = text;
    msgBox.className = 'form-msg ' + (ok ? 'ok' : 'err');
  }

  const MAX_BYTES = 50 * 1000 * 1000; // decimal MB, safely under Supabase's ~50 MiB server-side storage limit

  form.addEventListener('submit', async (e) => {
    e.preventDefault();
    msgBox.className = 'form-msg';

    if (!form.reportValidity()) return;

    const fd = new FormData(form);
    const file = fd.get('file');
    const ageBracket = fd.get('age_bracket');

    if (!ageBracket) { showMsg(t('msgErrAge'), false); return; }
    if (!file || file.size === 0) { showMsg(t('msgErrFile'), false); return; }
    if (file.size > MAX_BYTES || !/^(image|video)\//.test(file.type)) {
      showMsg(t('msgErrFile'), false);
      return;
    }
    const isMinor = ageBracket === 'minor';
    if (isMinor && (!fd.get('parent_name') || !fd.get('parent_email'))) {
      showMsg(t('msgErrParent'), false);
      return;
    }

    submitBtn.disabled = true;
    showMsg(t('msgSending'), true);

    try {
      const ext = (file.name.split('.').pop() || 'bin').toLowerCase().replace(/[^a-z0-9]/g, '');
      const path = `${crypto.randomUUID()}.${ext}`;

      const { error: uploadError } = await sb.storage.from(SUPABASE_BUCKET).upload(path, file, {
        contentType: file.type,
        upsert: false,
      });
      if (uploadError) throw uploadError;

      const { error: insertError } = await sb.from('submissions').insert({
        display_name: fd.get('display_name'),
        email: fd.get('email'),
        mascot_name: fd.get('mascot_name'),
        story: fd.get('story'),
        file_path: path,
        file_type: file.type.startsWith('video') ? 'video' : 'image',
        is_minor: isMinor,
        parent_name: isMinor ? fd.get('parent_name') : null,
        parent_email: isMinor ? fd.get('parent_email') : null,
        consent_rules: true,
        consent_rights_transfer: true,
      });
      if (insertError) throw insertError;

      form.reset();
      syncParentFields();
      showMsg(t('msgOk'), true);
    } catch (err) {
      console.error(err);
      if (err && (err.statusCode === '413' || err.error === 'Payload too large')) {
        showMsg(t('msgErrFile'), false);
      } else {
        const detail = err && (err.message || err.error_description || err.statusCode);
        showMsg(t('msgErr') + (detail ? ` (${detail})` : ''), false);
      }
    } finally {
      submitBtn.disabled = false;
    }
  });

  // ---------- Winners podium (visible only from the reveal date onward) ----------
  const WINNER_REVEAL_DATE = new Date('2026-11-16T00:00:00');
  const MEDALS = { 1: '🥇', 2: '🥈', 3: '🥉' };

  async function loadWinners() {
    if (new Date() < WINNER_REVEAL_DATE) return;

    const { data, error } = await sb
      .from('submissions')
      .select('id, display_name, mascot_name, file_path, file_type, winner_rank, prize_label')
      .not('winner_rank', 'is', null)
      .eq('status', 'approved')
      .order('winner_rank', { ascending: true })
      .limit(3);

    if (error || !data || data.length === 0) return;

    const spots = await Promise.all(data.map(async (row) => {
      const { data: signed } = await sb.storage.from(SUPABASE_BUCKET).createSignedUrl(row.file_path, 3600);
      const url = signed && signed.signedUrl;
      const media = url
        ? (row.file_type === 'video'
            ? `<video src="${url}" muted playsinline preload="metadata"></video>`
            : `<img src="${url}" alt="${esc(row.mascot_name)}">`)
        : '';
      const rank = Number(row.winner_rank) || 0;
      return `
        <div class="podium-spot rank-${rank}">
          <div class="medal">${MEDALS[rank] || ''}</div>
          <div class="media" data-media-url="${esc(url || '')}" data-media-type="${row.file_type}" data-media-label="${esc(row.mascot_name)}">${media}</div>
          <h3>${esc(row.mascot_name)}</h3>
          <div class="author">${esc(row.display_name)}</div>
          ${row.prize_label ? `<div class="prize">${esc(row.prize_label)}</div>` : ''}
        </div>`;
    }));

    document.getElementById('podiumGrid').innerHTML = spots.join('');
    document.getElementById('winnersSection').hidden = false;
  }
  loadWinners();

  // ---------- Gallery: show approved entries ----------
  async function loadGallery() {
    const grid = document.getElementById('galleryGrid');
    const { data, error } = await sb
      .from('submissions')
      .select('id, mascot_name, file_path, file_type')
      .eq('status', 'approved')
      .order('created_at', { ascending: false })
      .limit(4);

    if (error || !data || data.length === 0) return;

    const cards = await Promise.all(data.map(async (row) => {
      const { data: signed } = await sb.storage.from(SUPABASE_BUCKET).createSignedUrl(row.file_path, 3600);
      const url = signed && signed.signedUrl;
      const media = row.file_type === 'video'
        ? `<video src="${url}" muted playsinline preload="metadata"></video>`
        : `<img src="${url}" alt="${esc(row.mascot_name)}" loading="lazy">`;
      return `<div class="gcard filled" data-media-url="${esc(url || '')}" data-media-type="${row.file_type}" data-media-label="${esc(row.mascot_name)}">${url ? media : ''}<div class="gname">${esc(row.mascot_name)}</div></div>`;
    }));

    grid.innerHTML = cards.join('');
  }
  loadGallery();
})();
