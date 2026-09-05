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

## 12. Update — laat in de avond, 5 september 2026: rail-overlap en vensterpositie

Clifton testte de live presenteren-fix met een verticaal opgestelde monitor en stuurde een screenshot. Twee dingen kwamen daaruit naar voren, beide verwerkt in `cockpit_rebuilt.html` (nog niet gedeployed op het moment van schrijven — zie sectie 3 voor de laatste live-status):

**a) Layout-bug bij smallere/verticale schermen.** Tussen 720px en 1180px breedte kneep het ontwerp de linker-navigatiebalk terug naar 66px, maar de knoppen/labels (o.a. "Presenteren") waren daar niet op voorbereid — geen tekstterugloop, geen kleinere opmaak — waardoor tekst over de rand van de knop heen liep en leek te overlappen met de rest van de pagina. Opgelost door: dat kneep-niveau te laten vervallen (de navigatiebalk blijft nu leesbaar op volle breedte tot 720px, alleen het rechterpaneel verdwijnt eerder om ruimte te besparen); onder de 720px wordt de balk niet langer onzichtbaar maar klapt om tot een compacte, horizontaal omlopende rij knoppen bovenaan — dus niets valt meer helemaal weg.

**b) Onthouden op welk scherm/positie de vensters laatst stonden.** Voor het **presentatievenster** (het losse venster uit sectie 5) is dit nu echt gebouwd: bij het sluiten (via "Terug naar SPoW" of via het kruisje) wordt de positie en grootte (`screenX/screenY/outerWidth/outerHeight`) opgeslagen in `localStorage`; bij de volgende keer "Presenteren" opent het venster automatisch weer op dezelfde plek/grootte. Voor het **hoofdvenster van de cockpit zelf kan dit niet via code** — een normaal genavigeerd browsertabblad mag door een webpagina niet verplaatst of van grootte veranderd worden, dat is een browserbeveiliging, geen keuze van mij. De praktische oplossing die er wél is en al klaarligt: de cockpit heeft al een `manifest.json` en iconen (PWA-ondersteuning); als Clifton de cockpit als app installeert (in Chrome/Edge: installatie-icoon in de adresbalk, of menu → "App installeren"), onthoudt de browser zelf de vensterpositie en -grootte per launch, net als een native app — dat is geen extra bouwwerk, alleen een andere manier van openen. Dit is nog niet door Clifton gedaan of getest, dus ook hier: aanbevolen pad, geen bevestigde werking.

Beide fixes zitten in dezelfde `cockpit_rebuilt.html` als eerder, klaar voor een volgende run van `DEPLOY-RICH-COCKPIT.ps1` — geen haast, kan ook morgen.

## 13. Update — 5 september 2026, volgende dag: Contributor/Owner op RG-BOELS-D-SPOW bevestigd

Clifton PIMde en vroeg mij te checken of hij nu Owner is op `RG-BOELS-D-SPOW` (subscription "Boels - LZ Generic - Development"). Gecontroleerd via Access control (IAM) op de resource group zelf, ingelogd als `azadm_dobbec@boels.com`:

- **Owner** — direct op deze resource group, "Active permanent assignments" (dus geen tijdgebonden PIM-activatie die weer afloopt, maar een permanente toewijzing).
- **Contributor** — geërfd vanaf subscription-niveau via groep `Azure_Group_TeamPlatf...` (naam afgekapt in de UI), ook permanent.
- **Reader** — de oudere, al bekende inherited-rol vanaf management-group-niveau via groep "Team Cloud Services" (dit is het item dat eerder als hervatpunt "Contributor op rg-boels-d-spow" in Vandaag stond — dat losstaande Reader-erfenis is niet weg, maar wordt nu overstemd door de nieuwe, hogere Owner-toewijzing direct op de resource group).

Kortom: **bevestigd, klopt** — Clifton (azadm) kan nu deployen/beheren op deze resource group. Dit was puur een verificatie; ik heb naar aanleiding hiervan nog niets gebouwd of geprovisioneerd (de Managed Identity/Voedingslaag-vraag uit sectie 7 stond nog geparkeerd in afwachting van Cliftons "ga" op de bredere ontwerpvraag, en het vrijkomen van de rechten alleen is daar geen impliciete toestemming voor).

**Apart genoteerd, niet actie op ondernomen**: Clifton wil de twee openstaande `spow_onboarding`-offboardingpunten (Owner-rechten Dennis Knarren en Diederik Mulder, sectie 8, beide status "Ingediend") pas na 15 september aanpakken, zodra hun vervangers zijn begonnen. Bewust laten liggen tot dan — niet per ongeluk oppakken als "nu maar even opruimen".

## 14. Nieuw concept: SPoF-register (Single Points of Failure) — nog niet gebouwd, mag nooit vergeten worden

Clifton realiseerde zich (5 sept) dat we tijdens dit hele traject gegarandeerd steeds weer SPoFs (Single Points of Failure) gaan tegenkomen — mensen, systemen, leveranciersrelaties die maar door één schakel gedragen worden. Zijn punt: eenmaal gezien of gevonden moet daar iets mee gebeuren, dus het moet op de planning/roadmap komen — ook als we het nu nog niet oppakken, mag het nooit zomaar vergeten worden. En belangrijk: als er later, via een heel andere route, een nieuw project of incident opduikt dat aan zo'n SPoF gerelateerd is, moet die kruisverwijzing er al lang liggen — want dat verandert de urgentie/impact van die SPoF met terugwerkende kracht.

Dit is nog geen gebouwde functionaliteit — puur het concept, vastgelegd zodat het niet kwijtraakt. Twee dingen zijn al ontdekt die hier feitelijk al onder vallen, zonder dat ze ooit zo genoemd zijn:

- De **bus-factor-waarschuwing** in "Dienstkaarten Verifiëren" (sectie 6) — "diensten die op één persoon rusten" — is in de praktijk al een eerste, primitieve SPoF-detector, alleen dan voor de dimensie "wie kan dit dragen".
- De twee **Owner-rechten van Knarren en Mulder** (sectie 8/13) zijn zelf ook een SPoF-achtig patroon: tenantbrede rechten die aan mensen hangen die er niet meer zijn, en die niemand anders heeft overgenomen.

Voorstel (nog niet uitgevoerd, wacht op prioritering samen met Clifton): een eigen `spow_spof`-achtige registratie, met minimaal een titel, waar/wie het raakt, urgentie én impact (die dus achteraf kunnen veranderen als er een kruisverwijzing bijkomt), status, en een lijst van kruisverwijzingen naar projecten/incidenten/onboardingpunten die 'm raken. Qua patroon vergelijkbaar met hoe `spow_onboarding` is opgezet (sectie 8) — mogelijk zelfs met overlap of hergebruik van diezelfde tabel (een SPoF zou je kunnen zien als "iets dat ooit ge-offboard moet worden, maar nu vooral gevolgd moet worden"). Dat ontwerp moet nog gemaakt worden, dit is alleen de vastlegging van het idee zelf.

## 15. Strategische koers — 5 september 2026, vervolgdag

Clifton's prioriteit voor de eerstvolgende stap, expliciet zo gezegd: **agenda's, Excels en andere systemen uitleesbaar maken, te beginnen met de mail-agenda's**, en vervolgens het mechanisme bouwen waarbij informatie die uit alle meetings komt ook als voeding dient voor al het andere binnen SPoW (dus niet alleen "lees de agenda", maar: wat een meeting oplevert — acties, besluiten, gevonden SPoFs — stroomt door naar de rest van SPoW). Dit is de facto een herprioritering van de Graph/Voedingslaag-vraag uit sectie 7: onderdeel (a), Cliftons eigen agenda via de bestaande app-registratie + `Calendars.Read`, is nu met voorrang aangewezen als eerste concrete stap. Nog steeds niet uitgevoerd — dat blijft een expliciete ja/nee-vraag aan Clifton per de standing rules (OAuth-scope-wijziging), maar wel: dit is niet langer "geparkeerd", dit is nu de top van de lijst.

Daarnaast wil Clifton dat alles wat al klaar is (rijke cockpit, presentatievenster-fix) volgende week al écht in gebruik genomen wordt, zeker tijdens vergaderingen — dus deployen en testen krijgt voorrang boven nieuwe features.

Tot slot een fundamentele architectuurvraag van Clifton: hoe moet SPoW straks samenwerken met de verschillende Copilots (M365 Copilot, GitHub Copilot, Security Copilot, Copilot Studio zijn allemaal aparte producten), en waar zit in SPoW eigenlijk de AI/compute? Zijn eigen constatering: SPoW voelt nu aan als "een zeer uitgebreide koppeling van tabellen" — geen AI-laag, geen slimmigheden op of boven AI-niveau, terwijl dat wel zijn visie is. Eerlijk antwoord genoteerd: die AI/compute-laag bestaat op dit moment nergens in SPoW zelf. Alle intelligentie tot nu toe (schema ontdekken, velden koppelen, teksten schrijven, dit document) komt van Claude, handmatig, in gesprekken — niet van iets dat een gebruiker van de live cockpit zelf ervaart of aanroept. Dit is een apart, nog te ontwerpen fase (een soort "denklaag" bovenop de voedingslaag — bijvoorbeeld een Azure OpenAI-aanroep die door een Dataverse-trigger/Power Automate wordt afgevuurd zodra er nieuwe data binnenkomt, of een eigen Copilot Studio-agent die dezelfde Dataverse als bron gebruikt en vanuit de cockpit of Teams aanspreekbaar is) — nog niet gestart, hier moet nog een apart ontwerpgesprek over komen.

## 16. Rooster CGI-team + uitsluiting Boels-collega's — 5 september 2026

Vervolg op sectie 15 ("wie zit onder/naast mij" voor agenda/planning/inzetbaarheid/vakantie/verlof/verzuim). Clifton gaf twee dingen tegelijk: een harde uitsluiting, en het volledige CGI-rooster.

**a) Expliciete uitsluiting — voorlopig niet aanraken.** De volgende 10 Boels-interne collega's mogen voorlopig NIET benaderd, bekeken of ge(re)onboard worden in dit traject — reden letterlijk: *"ik kan het me niet permitteren dat er alarmbellen bij hun afgaan. bedoeld of onbedoeld. laten we het eerst testen en kijken wat er gebeurd."* Dit is een staande beperking totdat Clifton expliciet anders aangeeft:

Bob de Leeuw, Dave Lardinois, Emile Coenen, Eric de Jong, Maarten Merkens, Richard Bolk, Roel Pluijmen, Roland Peeters, Toussin Pooters, Steinar Heijkoop.

Alle 10 bestaan al als `spow_persoon`-record (groep Intern, `spow_upn` grotendeels al gevuld) — ze worden dus met rust gelaten zoals ze zijn, geen wijzigingen, geen agenda/mailkoppeling, geen nieuwe velden.

**b) CGI-rooster — deze wil Clifton er wél allemaal in ("die wil ik er allemaal in sowieso"):**

| Naam | Boels-adres (van Clifton) | cgi.com-adres (van Clifton) | Status in Dataverse (`spow_persoon`, live gecheckt) |
|---|---|---|---|
| Prashanth Doddamane Ramappa | Prashanth.DoddamaneRamappa@boels.nl | prashanth.dr@cgi.com | **Nieuw** — nog geen record |
| Manjula Salem | Ext_Manjula.Salem@boels.nl | manjula.salem@cgi.com | **Bestaat al** (groep CGI, `spow_upn` nu nog leeg) |
| Suma GS | Suma.GS@boels.nl | — | **Nieuw** — nog geen record |
| Chethan KM | Ext_Chethan.KM@boels.nl | chethan.m@cgi.com | **Nieuw** — nog geen record |
| Harish AC | Ext_Harish.AC@boels.nl | harish.ac@cgi.com | **Bestaat al** (groep CGI, `spow_upn` nu nog leeg) |
| Aathavan A | aathavan.a@boels.nl | aathavan.a@cgi.com | **Nieuw** — nog geen record |
| Pavan Kumar | Pavan.Kumar@boels.nl | pavan.ta@cgi.com | **Onduidelijk, zie let op hieronder** |
| Jayaprakash Rao Gollapalli | JayaprakashRao.Gollapalli@boels.nl | — | **Nieuw** — nog geen record |
| Pavan Vishwanath Pochinapeddi | Pavan.Vishwanath@boels.nl | pavanvishwanath.pochinapeddi@cgi.com | **Nieuw** — nog geen record |
| Soumya Prateem Roy | SoumyaPrateem.Roy@boels.nl | — | **Nieuw** — nog geen record |
| Vishwanath S | Vishwanath.S@boels.nl | — | **Nieuw** — nog geen record |

**Let op — twee openstaande vragen aan Clifton, kan ik niet zelf raden:**

1. **"Pavan Kumar" is dubbel in Dataverse.** Er bestaan al twee aparte records: `Pavan Kumar` én `Pavan Kumar TA` (beide groep CGI, beide FTE 1, beide zonder upn). Het cgi.com-adres dat Clifton meegaf voor "Pavan Kumar" is `pavan.ta@cgi.com` — de "ta" erin doet vermoeden dat dit eigenlijk bij het record `Pavan Kumar TA` hoort, niet bij het kale `Pavan Kumar`-record. Maar dat is een gok, geen zekerheid: het kunnen ook gewoon twee verschillende mensen zijn die toevallig dezelfde naam delen, waarbij Clifton er hier maar één van doorgaf. Graag even bevestigen welk record welk adres krijgt (en of het andere "Pavan Kumar"-record een andere, nog ontbrekende persoon is).
2. **Siddlingappa Masali staat al in Dataverse (groep CGI) maar zat niet in het doorgestuurde rooster.** Hoort hij (nog) bij het team, of is dit iemand die inmiddels weg is / niet meer relevant is voor deze tracking? Zolang dat niet duidelijk is, laat ik dit record met rust.

**Ook genoteerd, geen actie op ondernomen:** het "Ext_"-voorvoegsel zit niet consistent op de Boels-adressen — Manjula, Chethan en Harish hebben het, de overige 8 namen niet. Kan een echt verschil in provisioning zijn (bijv. ouder vs. nieuwer aangemaakte gastaccounts), kan ook een tikfout/inconsistentie in de bron zijn. Niet zelf gecorrigeerd of aangenomen — vermeld zodat het niet als "fout" wordt gezien als het straks ergens niet matcht.

**Nog niet gedaan (bewust, wacht op akkoord):** er is nog niets weggeschreven naar Dataverse. De 8 nieuwe personen zijn nog niet aangemaakt als `spow_persoon`-record, en `spow_upn` van Manjula/Harish (en eventueel Pavan Kumar/TA) is nog niet gevuld. Reden: `spow_upn` is één los tekstveld — voor deze mensen zijn er per persoon minimaal 2 adressen (Boels + cgi.com), soms mogelijk 3 (+Cramo, nog niet bevestigd). Eerst moet het datamodel dat aankan (nieuwe velden, of een los kindtabelletje "e-mailadres per persoon per type"), anders gaat het eerste veld dat ingevuld wordt het andere overschrijven zodra er een tweede adres bijkomt. Dit sluit aan bij de al bekende datamodel-valkuil uit sectie 9.

**Openstaande vervolgvraag (ongewijzigd van eerder, hoort er inhoudelijk bij):** zodra namen en adressen vaststaan, is de volgende stap — precies zoals Clifton zelf aangaf — welke toegang/akkoorden nodig zijn om agenda's/kalenders van deze 11 mensen daadwerkelijk te kunnen uitlezen (cross-tenant: een cgi.com-mailbox valt buiten het Boels-tenant, dus Graph-consent vanuit de Boels-kant kan die niet bereiken; alleen de Boels-mailbox zou in potentie via de bestaande "SPoW Cockpit"-appregistratie + een gedelegeerde `Calendars.Read`-scope te benaderen zijn, en dat wacht nog steeds op Cliftons ja/nee daarop uit sectie 15/7). Nog niets aangevraagd of aangezet.

*Volgende keer dat dit project wordt opgepakt: begin met dit bestand lezen, dan pas verder kijken.*
