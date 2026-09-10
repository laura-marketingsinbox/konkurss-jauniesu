# Projekta kopsavilkums — "Radi nākamo Inbox.lv talismanu"

**Eksportēts:** 2026-09-10
**Statuss:** Dizaina makets gatavs, gaida GitHub publicēšanu (Claude Code solis)

## Kas ir šis projekts

Interaktīva publiska konkursa mikrosite portāla inbox.lv ietvaros, sadarbībā ar Samsung kā ekskluzīvo tehnoloģiju partneri. Jauniešiem (14–30 g.) ar AI rīku palīdzību jārada jauns Inbox.lv zīmola tēls (talismans) — vizuāls tēls, vārds un stāsts.

**5 posmi:** CREATE (30.09.–30.10.2026, radīšana/iesniegšana) → DISCOVER (žūrijas finālistu atlase) → VOTE (publiskā balsošana sociālajos tīklos) → REVEAL (uzvarētāja atklāšana) → BRING TO LIFE (profesionāla ieviešana zīmolā).

Valodas: latviešu, krievu, angļu.

## Galvenie pieņemtie lēmumi

- **Reģistrācija:** bez pilna konta — vārds/segvārds + e-pasts ar verifikācijas saiti
- **Moderācija:** PIRMS publicēšanas (nepilngadīgo un publiskā satura dēļ)
- **Nepilngadīgie:** 14–17 g. dalībniekiem nepieciešama vecāka/aizbildņa piekrišana, kas skaidri attiecas arī uz tiesību nodošanu (nevis tikai dalību)
- **Autortiesības:** dalībnieks nodod Inbox.lv īpašumā visas izmantošanas tiesības uz iesniegto darbu (izņemot neatsavināmās autora morālās tiesības) — formulējums sagatavots "mierīgā" tonī, bet **nav juridiski pārbaudīts, jāapstiprina ar juristu**
- **Tehniskā arhitektūra (ieteikums izstrādei):** Next.js + Supabase, kods GitHub, hostings Vercel
- **Zīmols:** oficiālās krāsas — sarkans `#CC0717`, silti pelēks `#8C8279`, melns, balts; oficiālais logo saņemts un iestrādāts (SVG, ar balto versiju tumšajam fonam)
- **Fonts:** sistēmas fontu virkne (`-apple-system, Segoe UI, Roboto, Arial`) kā tuvākais pieņēmums bez maksas/licences — **nav apstiprināts precīzs inbox.lv fonts**, jāpārbauda ar pārlūka "Inspect" rīku un jāpaziņo, ja atšķiras
- **Samsung zīmols:** netiek izmantots (bez logo/co-branding), tikai tekstuāla pieminēšana

## Faili šajā eksportā

- `01_saruna_transkripts.md` — pilns sarunas pieraksts
- `dokumenti/TU_inbox_konkursa_lapa.md` — tehniskais uzdevums
- `dokumenti/Konkursa_nolikums_paraugs.md` — konkursa nolikuma paraugs
- `makets/index.html` — dizaina makets (LV/RU/EN pārslēgs, gatavs GitHub Pages)
- `makets/inbox_logo.svg` — oficiālā logo vektors, izvilkts no PDF
- `original_augsupieladeti/` — sākotnējie augšupielādētie faili (Samsung prezentācijas, logo, krāsu PDF)
- `claude_code_projekts/` — gatava mape ar norādi, ko iedot Claude Code, lai publicētu GitHub

## Nākamais solis (kur pārtrauca saruna)

Lietotāja vēlas publicēt `index.html` uz GitHub Pages, bet negrib manuāli pieslēgties/kopēt tokenu šajā čatā. Ieteiktais risinājums: atvērt `claude_code_projekts/` mapi ar Claude Code (darbojas lokāli datorā, izmanto lietotāja jau esošo GitHub pieslēgšanos pārlūkā, nevis prasa tokenu čatā). Instrukcija jau sagatavota tās `README.md` failā.

## Atlikušie atvērtie jautājumi (no TU 13. sadaļas)

- Konkrēts Samsung balvu klāsts un modeļi
- Precīzi datumi posmiem DISCOVER / VOTE / REVEAL
- Vai iesniegumu skaitu uz personu atstāt 1 vai palielināt
- Vai publiski rādāms konkrēts kontakts vai vispārēja kontaktforma
- Precīzs subdomēns un DNS piekļuve
- Juridiska pārskatīšana tiesību nodošanas klauzulai
- Budžets un vēlamais izstrādes termiņš
- Precīzs inbox.lv fonts (jāpārbauda ar pārlūka Inspect rīku)
