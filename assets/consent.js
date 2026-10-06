// Sīkdatņu piekrišanas panelis (GDPR / ePrivacy).
// - Analītikas skripti drīkst ielādēties TIKAI pēc piekrišanas (skat. onAnalyticsGranted zemāk).
// - "Piekrītu" un "Nepiekrītu" ir vienādi izmēri un vienlīdz viegli nospiežami.
// - Izvēle glabājas pārlūkā (localStorage) 12 mēnešus, tad jautā vēlreiz.
// - Piekrišanu var mainīt jebkurā laikā: window.openCookieSettings() (saite lapas apakšā).
(function () {
  const STORAGE_KEY = 'inboxContestConsent';
  const MAX_AGE_MS = 365 * 24 * 60 * 60 * 1000;

  const T = {
    lv: {
      title: 'Sīkdatnes un privātums',
      text: 'Šī vietne vēlas izmantot analītikas sīkdatnes, lai saprastu, cik cilvēku apmeklē konkursu, un to uzlabotu. Tās tiek ieslēgtas tikai ar tavu piekrišanu. Vietnes darbībai nepieciešamie dati (piemēram, valodas izvēle) tiek saglabāti vienmēr.',
      policy: 'Sīkdatņu politika',
      accept: 'Piekrītu',
      reject: 'Nepiekrītu',
      settings: 'Sīkdatņu iestatījumi',
    },
    ru: {
      title: 'Файлы cookie и конфиденциальность',
      text: 'Этот сайт хотел бы использовать аналитические файлы cookie, чтобы понимать, сколько людей посещает конкурс, и улучшать его. Они включаются только с вашего согласия. Данные, необходимые для работы сайта (например, выбор языка), сохраняются всегда.',
      policy: 'Политика cookie',
      accept: 'Согласен',
      reject: 'Не согласен',
      settings: 'Настройки cookie',
    },
    en: {
      title: 'Cookies and privacy',
      text: 'This site would like to use analytics cookies to understand how many people visit the contest and to improve it. They are switched on only with your consent. Data needed for the site to work (such as your language choice) is always stored.',
      policy: 'Cookie policy',
      accept: 'Accept',
      reject: 'Decline',
      settings: 'Cookie settings',
    },
  };

  const lang = () => (T[document.documentElement.lang] ? document.documentElement.lang : 'lv');

  function readStored() {
    try {
      const v = JSON.parse(localStorage.getItem(STORAGE_KEY) || 'null');
      if (v && (v.status === 'granted' || v.status === 'denied') && Date.now() - v.ts < MAX_AGE_MS) return v;
    } catch (e) {}
    return null;
  }
  function store(status) {
    try { localStorage.setItem(STORAGE_KEY, JSON.stringify({ v: 1, status, ts: Date.now() })); } catch (e) {}
  }

  // Dzēš analītikas/reklāmas sīkdatnes, ja piekrišana atsaukta vai atteikta.
  function clearTrackingCookies() {
    const names = document.cookie.split(';').map((c) => c.split('=')[0].trim())
      .filter((n) => /^(_ga|_gid|_gat|_gcl|_fbp|_fbc)/.test(n));
    const host = location.hostname.split('.');
    const domains = ['', location.hostname];
    for (let i = 1; i < host.length - 1; i++) domains.push('.' + host.slice(i).join('.'));
    names.forEach((n) => domains.forEach((d) => {
      document.cookie = n + '=; expires=Thu, 01 Jan 1970 00:00:00 GMT; path=/' + (d ? '; domain=' + d : '');
    }));
  }

  const listeners = [];
  let analyticsLoaded = false;

  // ---------- Google Tag Manager ----------
  // GTM kods un Consent Mode noklusējums (viss liegts) ir lapas <head>; šeit tikai atjaunojam piekrišanu.
  window.dataLayer = window.dataLayer || [];
  function gtag() { window.dataLayer.push(arguments); }

  function onAnalyticsGranted() {
    gtag('consent', 'update', { analytics_storage: 'granted' });
    if (analyticsLoaded) return;
    analyticsLoaded = true;
    listeners.forEach((fn) => { try { fn(); } catch (e) {} });
  }
  function onAnalyticsDenied() {
    gtag('consent', 'update', { analytics_storage: 'denied' });
    clearTrackingCookies();
  }

  window.consent = {
    get analytics() { const s = readStored(); return !!s && s.status === 'granted'; },
    onGranted(fn) { listeners.push(fn); if (this.analytics && analyticsLoaded) fn(); },
  };

  // ---------- UI ----------
  const css = `
  #cookieConsent{position:fixed;left:16px;right:16px;bottom:16px;z-index:1000;max-width:760px;margin:0 auto;background:#fff;color:#17151C;
    border-radius:16px;box-shadow:0 12px 40px rgba(0,0,0,.28);padding:20px 22px;font-family:-apple-system,BlinkMacSystemFont,"Segoe UI",Roboto,Arial,sans-serif;display:none}
  #cookieConsent.open{display:block}
  #cookieConsent h2{font-size:16px;margin:0 0 6px;font-weight:700}
  #cookieConsent p{font-size:13.5px;line-height:1.5;margin:0 0 14px;color:#3b3740}
  #cookieConsent a{color:#6C4FE0;text-decoration:underline}
  #cookieConsent .cc-actions{display:flex;gap:10px}
  #cookieConsent button{flex:1;font:inherit;font-size:14px;font-weight:700;padding:12px 16px;border-radius:10px;border:2px solid #17151C;cursor:pointer;min-height:44px}
  #cookieConsent button.cc-accept{background:#17151C;color:#fff}
  #cookieConsent button.cc-reject{background:#fff;color:#17151C}
  #cookieConsent button:focus-visible{outline:3px solid #6C4FE0;outline-offset:2px}
  @media (max-width:520px){#cookieConsent .cc-actions{flex-direction:column}}
  `;
  const style = document.createElement('style'); style.textContent = css; document.head.appendChild(style);

  const box = document.createElement('div');
  box.id = 'cookieConsent';
  box.setAttribute('role', 'dialog');
  box.setAttribute('aria-labelledby', 'ccTitle');
  box.setAttribute('aria-describedby', 'ccText');
  box.innerHTML = '<h2 id="ccTitle"></h2><p id="ccText"></p><div class="cc-actions"><button type="button" class="cc-reject"></button><button type="button" class="cc-accept"></button></div>';
  document.body.appendChild(box);

  function render() {
    const t = T[lang()];
    box.querySelector('#ccTitle').textContent = t.title;
    box.querySelector('#ccText').innerHTML = '';
    box.querySelector('#ccText').append(t.text + ' ');
    const a = document.createElement('a');
    a.href = 'https://help.inbox.lv/cookie-usage?language=' + lang();
    a.target = '_blank'; a.rel = 'noopener'; a.textContent = t.policy;
    box.querySelector('#ccText').appendChild(a);
    box.querySelector('.cc-accept').textContent = t.accept;
    box.querySelector('.cc-reject').textContent = t.reject;
    document.querySelectorAll('[data-cookie-settings]').forEach((el) => { el.textContent = t.settings; });
  }

  function open(focus) { render(); box.classList.add('open'); if (focus === true) box.querySelector('.cc-reject').focus({ preventScroll: true }); }
  function close() { box.classList.remove('open'); }

  box.querySelector('.cc-accept').addEventListener('click', () => { store('granted'); close(); onAnalyticsGranted(); });
  box.querySelector('.cc-reject').addEventListener('click', () => { store('denied'); close(); onAnalyticsDenied(); });

  window.openCookieSettings = () => open(true);
  document.addEventListener('click', (e) => {
    const el = e.target.closest('[data-cookie-settings]');
    if (el) { e.preventDefault(); open(true); }
  });

  new MutationObserver(() => { render(); }).observe(document.documentElement, { attributes: true, attributeFilter: ['lang'] });

  const saved = readStored();
  if (!saved) open();
  else { render(); if (saved.status === 'granted') onAnalyticsGranted(); else onAnalyticsDenied(); }
})();
