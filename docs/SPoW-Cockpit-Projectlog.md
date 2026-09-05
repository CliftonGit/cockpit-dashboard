# SPoW Cockpit — Projectlog & documentatie

Laatst bijgewerkt: 5 september 2026, door Claude (samen met Clifton Dobbelsteyn, Boels IT).

Dit document bestaat omdat contextverlies eerder al eens gebeurde (samenvatting van een lang gesprek, waarbij details verdwenen). Doel van dit bestand: alles wat nodig is om dit project — ook over een jaar, ook in een compleet nieuw gesprek — weer op te pakken zonder dat Clifton alles opnieuw hoeft te voeden. Dit bestand wordt **aangevuld, nooit vervangen**: nieuwe secties toevoegen of bijwerken, oude inhoud niet weggooien tenzij het aantoonbaar achterhaald is (en dan liever doorstrepen/annoteren dan verwijderen).

De originele ontwerpartefacten (de "gouden" bronnen) staan **onveranderd en volledig** bewaard in `docs/ontwerp/` naast dit bestand — zie sectie 6.

---

## 1. Wat SPoW is en waarom dit bestaat

SPoW = **S**ingle **Po**int of **W**ork. Eén cockpit voor het IT-Infra & Connectivity-team (Clifton's team, inclusief de CGI-contractors die daaronder vallen) die het werk van de dag, het team, kennis en services samenbrengt — in plaats van dat iedereen dat verspreid over TOPdesk, mail, Teams en hoofden bij elkaar moet zoeken.

De cockpit is een losstaande, statische website (niet een Claude Artifact) omdat een Artifact op claude.ai per ontwerp nooit met de Boels-tenant kan verbinden (zie ook `docs/ontwerp/SPoW-Ontwerpdossier-v4.html`, §34 "Open"-punt 1). Vandaar: eigen Entra-app-registratie, eigen statische site, eigen koppeling met Dataverse.

## 2. Standing rules — deze gelden altijd, ook in een nieuw gesprek

- **Toegang tot SPoW Cockpit is beperkt** tot leden van de Entra ID-beveiligingsgroep **"IT-Infra | Server & Connectivity"** (`IT-Infra-Server@boels.com`). Iedereen die daar geen lid van is heeft standaard geen toegang.
- **Iemand extra toegang geven gebeurt uitsluitend op uitnodiging en met Cliftons expliciete, per-geval goedkeuring.** Nooit aannemen, nooit automatisch, nooit "voor het gemak".
- **Nooit doen alsof gedeeltelijk werk af is.** Cliftons expliciete correctie (4 sept 2026): data vullen ≠ het hele ontwerp is klaar. Iedere statusupdate benoemt expliciet wat écht live/gekoppeld is en wat nog niet gebouwd is — geen "definitief" totdat het dat ook is.
- **Geen OAuth/admin-consent of Azure-resources zelf regelen zonder expliciete toestemming per geval.** Ook niet als het "voor de hand ligt".
- **Werkwijze**: Claude bouwt/bewerkt in de eigen sandbox, stuurt bestanden naar Clifton, Clifton voert lokaal PowerShell-scripts uit (met automatische logging naar een `.txt`-bestand), antwoordt "ok", en Claude leest het logbestand om te verifiëren. Clifton voert uit, Claude doet de rest ("jij doet het werk").

## 3. Live status — wat is ECHT live, wat niet (peildatum: 5 sept 2026)

**Live op** `https://nice-flower-0071a6e03.6.azurestaticapps.net/cockpit.html` (commit `69a71ed`, gedeployed 5 sept 2026 ~01:41):

- 5 thema's (nachtwacht/glas/fosfor/radar/papier), navigatie, look & feel — volledig zoals ontworpen.
- **Vandaag, Team, Kennis, Services** — echt gekoppeld aan live Dataverse-data (Vandaag/hervatpunten, teamoverzicht, kennis-zoeken, dienstkaarten). Waar geen echte data is staat een eerlijke placeholder ("nog niet vastgesteld" / "nog niet gekoppeld"), nooit verzonnen inhoud.
- MSAL-login (Entra ID, app "SPoW Cockpit") — sign-in gate, werkt structureel (geverifieerd: title, DOM-elementen, MSAL laadt). **De volledige login → data-laad happy path is nog niet écht end-to-end getest** — mijn eigen automatiseringsbrowser blokkeert de MSAL-popup. Clifton: graag zelf een keer testen op de echte site en terugkoppelen.

**Klaar om te deployen, nog NIET live** (staat als `cockpit_rebuilt.html` in de Changes-map, wacht op een herhaalde run van `DEPLOY-RICH-COCKPIT.ps1`):

- Presenteren opent een **echt los venster** (`window.open`, te verslepen naar een tweede scherm), i.p.v. dezelfde pagina om te toggelen. Hoofdvenster blijft onafhankelijk klikbaar. "Terug naar SPoW" in dat losse venster sluit het venster. Zie sectie 5 voor detail.

**Bewust nog niet gebouwd** (dit is geen bug, dit is nog-niet-aan-de-beurt):

- Planning-view (placeholder "Nog niet gekoppeld").
- Presenteren-inhoud zelf is nog illustratief, niet gevuld met live taken.
- Daily-mail, "Vandaag in je agenda" — vereist Graph/Outlook-koppeling (zie sectie 7).
- Signalen/trends over inzetbaarheid — vereist de "voedingslaag" (zie sectie 7 en Ontwerpdossier §19).
- Onboarding/offboarding-registratie zichtbaar in de cockpit — de data bestaat al live in Dataverse (`spow_onboarding`, zie sectie 8) maar heeft nog geen scherm.
- Impact-registratie ("Impact Onbekend"-achtige kaart) is uit de oude scaffold niet overgenomen — bestond niet in het rijke ontwerp, dus bewust weggelaten, geen open item tenzij Clifton 'm terug wil.

## 4. Architectuur & techniek

- **Repo**: `CliftonGit/cockpit-dashboard` op GitHub, main branch. Lokaal gesynchroniseerd via OneDrive op Cliftons machine: `OneDrive - Boels Group\Documents\Changes`.
- **Deploy**: GitHub Actions, `Azure/static-web-apps-deploy@v1`, target Static Web App **spow-cockpit-64837**. Draait automatisch op elke push naar main.
- **Frontend**: één statisch bestand `cockpit.html` (HTML/CSS/JS, geen framework). PWA-ondersteuning aanwezig (manifest.json, icons).
- **Auth**: MSAL.js v3.30.0 (jsDelivr CDN), Entra App-registratie **"SPoW Cockpit"** — clientId `6b6a3359-9c81-451e-84bf-ef23bb7bc14e`, tenant `8b5e74a6-d91e-4dca-ad0a-147b4ce3cf3d`. Cache in `localStorage` (dus gedeeld tussen tabs/vensters van dezelfde origin — belangrijk voor het presentatievenster, zie sectie 5).
- **Data**: Microsoft Dataverse Web API v9.2, omgeving `https://boels-spow.crm4.dynamics.com`. Live schema-ontdekking gebeurt door een reeds ingelogd Dataverse-tabblad te hergebruiken (ambient auth via `Xrm.Utility.getGlobalContext()` + `fetch`) — sneller en betrouwbaarder dan veldnamen raden.
- **Lokaal deployscript**: `DEPLOY-RICH-COCKPIT.ps1` (in de Changes-map) — generiek en herbruikbaar: checkt of `cockpit_rebuilt.html` bestaat en ≥20000 bytes is, back-upt het huidige `cockpit.html` naar een timestamped `.bak-<stamp>` (nooit overschrijven zonder back-up), kopieert, committed, pushed, logt alles naar `DEPLOY-RICH-COCKPIT-LOG.txt`. Dit script hoeft niet herschreven te worden voor een volgende deploy — gewoon `cockpit_rebuilt.html` verversen en opnieuw laten draaien.

## 5. Het presentatievenster (5 sept 2026)

Klacht van Clifton: "Presenteren" opende geen nieuw venster dat op een tweede scherm gezet kan worden tijdens een meeting, terwijl het hoofdvenster los bruikbaar blijft.

Oplossing: `#goPresent` en `[data-present]`-knoppen openen nu `window.open(location.pathname + "?present=1", "spow-presenter", "width=1400,height=900,...")` i.p.v. een CSS-klasse op hetzelfde venster te togglen. Het losse venster herkent `?present=1` bij het laden en start zelf, zodra de app zichtbaar is (na inloggen — hergebruikt de gedeelde MSAL-sessie via localStorage, dus geen tweede keer inloggen), direct in presentatiemodus. "Terug naar SPoW" sluit dat venster (`window.close()`) als het als popup geopend is; anders (fallback) gedraagt het zich als voorheen.

Status: **geïmplementeerd en gecontroleerd** (JS-syntax, dubbele HTML-ID's, dangling `getElementById`-referenties, tag-balans — allemaal schoon), **nog niet live gedeployed**, **nog niet écht getest** (mijn sandboxbrowser blokkeert de popup zelf).

## 6. Bewaarde ontwerpartefacten — "het goud"

Op verzoek van Clifton (5 sept) zijn de volledige, originele Claude Artifacts die aan dit project ten grondslag liggen **letterlijk en ongewijzigd** gekopieerd naar `docs/ontwerp/` naast dit bestand, zodat ze niet verloren gaan als een claude.ai-gesprek ooit onvindbaar wordt. Alle vier zijn ook rechtstreeks te benaderen als gepubliceerde Claude Artifacts op het account van Clifton (via `claude.ai/code/artifact/...`) — die live versie kan intussen verder bewerkt zijn; de kopie hieronder is een momentopname op de genoemde datum.

- `docs/ontwerp/SPoW-Cockpit-artifact-origineel.html` — de originele "SPoW Cockpit"-Artifact (1117 regels, live: `https://claude.ai/code/artifact/1ca77c92-d66c-4002-acaf-2eb8be269010`, laatst bijgewerkt 1 sept 2026): het volledige rijke ontwerp (5 thema's, alle views, presenteren-doorloop) zoals dat er vóór de Dataverse-koppeling uitzag. Dit was de bron voor de huidige `cockpit.html`.
- `docs/ontwerp/SPoW-Ontwerpdossier-v4.html` — "SPoW Ontwerpdossier" versie 4 (1187 regels, live: `https://claude.ai/code/artifact/7c9f3352-e3e1-4587-a3f8-abfa08431e1b`, laatst bijgewerkt 2 sept 2026): de onderliggende ontwerpbeslissingen, statustabel (§19), en de motivatie voor een losse statische site (§34).
- `docs/ontwerp/SPoW-Roadmap.html` — "SPoW Roadmap" (2506 regels, live: `https://claude.ai/code/artifact/4e67d413-fb4f-43a9-ba6c-557e8d319dde`, laatst bijgewerkt 2 sept 2026). **Let op: ik heb zelf tot nu toe maar ongeveer de eerste 850 regels hiervan echt gelezen** — het bestand is wel volledig en ongewijzigd bewaard, maar mijn eigen kennis van de inhoud is nog niet compleet. Een vervolgstap kan zijn: dit bestand alsnog helemaal laten lezen en samenvatten.
- `docs/ontwerp/SPoW-Dienstkaarten-Verifieren.html` — "Dienstkaarten Verifiëren" (live: `https://claude.ai/code/artifact/b0b6063a-5264-4ee1-83da-e7d8bc4c3cd2`, laatst bijgewerkt 2 sept 2026). **Correctie op wat ik eerder zei**: ik meldde eerst dat ik deze niet meer kon terugvinden vanuit deze sessie. Dat klopte niet — Clifton liet via screenshots zien dat dit Artifact nog springlevend is (en inmiddels omgebouwd van "invullen" naar "nalopen": elk veld toont wat SPoW vond en waar het vandaan komt — groen = uit een bron, oranje = door Claude afgeleid/gok, grijs = nog niet gezocht; jij bevestigt alleen "klopt"/"klopt niet"). Alle vier Artifacts bleken gewoon opvraagbaar te zijn via de Artifact-tool van dit account (`list`/`read`) — ik had dat simpelweg niet geprobeerd voor ik het te snel "kwijt" verklaarde. Inhoud: 19 dienstkaarten (Server & Connectivity / Cloud Services / Endpoint Management) met per veld (Leverancier, Contactpersoon, Account of methode, Vervaldatum, Waar te vinden) een herkomstlabel, plus een "wie kan deze dienst dragen"-toewijzing per dienst met bus-factor-waarschuwing, een overzichtsscherm met open-acties-lijst, en een "Laat Copilot zoeken"-knop die een kant-en-klare zoekvraag genereert (voor Copilot, dat wél toegang heeft tot mail/Teams/SharePoint/OneDrive, in tegenstelling tot deze losstaande pagina). Nog niet gekoppeld aan Dataverse — de "Naar SPoW"-knop toont nu een kopieerbare JSON-export, schrijft nog niet rechtstreeks weg.

## 7. Openstaande ontwerpvraag: Graph/Outlook-koppeling (Voedingslaag)

Twee te onderscheiden delen:

**a) Cliftons eigen agenda** ("Vandaag in je agenda"): eenvoudig — hergebruik de bestaande app-registratie "SPoW Cockpit" met een extra delegated scope `Calendars.Read`. Geen cross-tenant probleem, geen aparte managed identity nodig. **Nog niet uitgevoerd — wacht op Cliftons akkoord** (OAuth-scope-wijziging vereist expliciete toestemming, zie standing rules).

**b) Teambeschikbaarheid van de CGI-contractors** (Cliftons eigenlijke prioriteit — zijn eigen team, met name de mensen onder hem, niet zozeer peers/boven hem): fundamenteel lastiger. Deze mensen gebruiken vooral hun eigen CGI-mailbox, daarnaast een Boels-mailbox en mogelijk een Cramo-mailbox — elk in een andere Microsoft 365-tenant. Boels' Graph-consent kan alléén mailboxen bereiken die in de Boels-tenant zitten; CGI's of Cramo's eigen tenant vereist hún eigen admin-consent, wat waarschijnlijk niet haalbaar/wenselijk is als governance-vraag. **Mijn voorlopige advies: niet proberen automatisch meerdere tenant-mailboxen te combineren.** Alternatief: het al ontworpen, handmatig bijgehouden `inzetbaarheid`-veld op `spow_persoon` gebruiken/uitbreiden (dit is al zo ontworpen — zie Ontwerpdossier §13/§14: inzetbaarheid is bewust een handmatig veld, niet afgeleid).

**Waar dit op is blijven staan (5 sept)**: Clifton wil dit niet nu ad hoc beslissen. Hij wil een "Single Point of Truth" — flexibel, passend bij de SPoW-naamgeving ("Single Point of ___", laatste woord mag verschillen). Zie sectie 8: die single point of truth bestaat voor een groot deel al (`spow_onboarding`). Voorstel (nog niet uitgevoerd, wacht op Cliftons "ga"): zodra er een cockpit-scherm voor onboarding/offboarding is, worden zowel "Calendars.Read voor eigen agenda" als "aanpak CGI-beschikbaarheid" zelf `spow_onboarding`-records (i.p.v. losse chatbeslissingen) — met aanvrager, beoordelaar en status, en zichtbaar in slechts één passende plek in de navigatie (niet overal), conform Cliftons wens dat niet alle functionaliteit in elke modus zichtbaar is.

## 8. Belangrijke ontdekking: `spow_onboarding` bestaat al live in Dataverse

Ontdekt 5 sept 2026 tijdens het uitzoeken van de Graph-vraag. Dit is precies het generieke on/offboarding-mechanisme dat Clifton in eerdere gesprekken heeft ontworpen ("het on- en offboarden van alles wat je je kan bedenken in SPoW, op elk willekeurig moment, vanuit de juiste modus") — en het is geen ontwerpidee meer, het is een echte, gevulde Dataverse-tabel.

Velden (belangrijkste): `spow_titel` (Wat), `spow_richting` (Onboarden / Offboarden / Wijzigen), `spow_soort` (Persoon / Tool / Portaal / Koppeling / Licentie / Leverancier / Overig), `spow_status` (Concept → Ingediend → In beoordeling → Goedgekeurd / Afgewezen → Uitgevoerd / Ingetrokken), `spow_aanvrager` / `spow_beoordelaar` (lookups naar persoon), `spow_businesscase`, `spow_toelichting`, `spow_afhankelijkheden`, `spow_kosten` (per jaar), `spow_vervalt`, `spow_url`, `spow_dienst` / `spow_portaal` (lookups).

Huidige live records (6 stuks, 5 sept 2026):

1. "Offboarden Owner-rechten Dennis Knarren" — Persoon, Offboarden, status **Ingediend**. Uit dienst, maar nog eligible permanent Owner op de Azure management group (hoogste rechtenniveau, erft naar alle 9 abonnementen).
2. "Offboarden Owner-rechten Diederik Mulder" — zelfde situatie, status **Ingediend**. Businesscase noemt dit expliciet: twee leavers met tenantbrede rechten wijst op een gat in het leaver-proces.
3. "TOPdesk API-koppeling" — Koppeling, Onboarden, status **Ingediend**. Belangrijkste voedingsbron voor SPoW (incidenten/changes/problems).
4. "N-able N-central" — Tool, Onboarden, status **Goedgekeurd** (beoordeeld 3 sept). Patchbeheer-signaalbron.
5. "Veeam Data Cloud" — Portaal, Onboarden, status **In beoordeling**, extern=ja. Dekkingsbron voor de dienst Back-up en restore.
6. "Graph-connector voor de netwerkschijven" — Koppeling, Onboarden, status **Concept**. Maakt netwerkschijven doorzoekbaar voor Copilot; vraagt een agent binnen het netwerk + indexquota (prijs nog niet bekend, open vraag).

**Status van dit in de cockpit: nul.** Er is nog geen enkel scherm dat deze data toont. Dit is puur een bevestigde databron, geen gebouwde functionaliteit — expliciet benoemd zodat dit niet als "af" wordt gelezen.

## 9. Bekende datamodel-valkuilen (opgelost, maar goed om te weten)

- `spow_ci`: gebruik `spow_cinaam` / `spow_soort` / `spow_locatie` — niet `spow_name`/`spow_type`/`spow_environment` (die bestaan niet).
- `spow_impact`: statusveld heet `spow_geraakt` (numerieke keuzelijst: 420690000=Onbekend, 420690001=Ja, 420690002=Nee, 420690003=Mogelijk) — niet `spow_status eq 'Onbekend'` (bestaat niet, geeft geen fout maar ook geen data).
- Dataverse `EntityDefinitions`-metadata-endpoint ondersteunt geen `$filter=startswith(...)` (HTTP 501). Los dit op door client-side te filteren na een volledige ophaal.

## 10. Nog openstaande, niet-urgente punten (uit eerdere gesprekken, nog niet besloten/uitgevoerd)

- Welk type Dataverse-omgeving is SPoW (Developer vs Production/Sandbox) — bepaalt of de opzet gratis blijft. Volgens eerdere info "twee klikken" in het Power Platform admin center — nog niet gedaan.
- Een leesbaar-in-platte-tekst wachtwoord gevonden in een `spow_resumecontext`-record (in de notulen) — geflagd, bewust niet zelf aangepast/verwijderd, ligt bij Clifton.
- Of/hoe de "Dienstkaarten Verifiëren"-tool ontsloten wordt zodat Clifton zelf de lege leverancier/contactpersoon/vervaldatum-velden van de 19 services kan invullen.
- Volledige lezing en verwerking van `docs/ontwerp/SPoW-Roadmap.html` (nu pas ~850/2506 regels door mij gelezen).

## 11. Bestandenkaart (waar staat wat)

| Wat | Waar |
|---|---|
| Live site | `https://nice-flower-0071a6e03.6.azurestaticapps.net/cockpit.html` |
| GitHub-repo | `CliftonGit/cockpit-dashboard`, branch `main` |
| Lokale synced map | `OneDrive - Boels Group\Documents\Changes` |
| Huidige live broncode | `cockpit.html` in bovenstaande map (commit `69a71ed`) |
| Volgende deploy, klaarstaand | `cockpit_rebuilt.html` in dezelfde map (presentatievenster-fix) |
| Deployscript (herbruikbaar) | `DEPLOY-RICH-COCKPIT.ps1` |
| Deploylog | `DEPLOY-RICH-COCKPIT-LOG.txt` |
| Backups van eerdere cockpit.html-versies | `cockpit.html.bak-<timestamp>`, nooit overschreven |
| Bewaarde originele ontwerpartefacten | `docs/ontwerp/*.html` (zie sectie 6) |
| Dit document | `docs/SPoW-Cockpit-Projectlog.md` |

---

*Volgende keer dat dit project wordt opgepakt: begin met dit bestand lezen, dan pas verder kijken.*
