# SELLEKTYWNI.PL — Technical Report (AI Readiness)

Data: 2026-04-14  
Cel: techniczny snapshot pod wdrożenie modułu generowania obrazów AI oraz UI podglądu kampanii.

## 1) Code Quality & Build

### Backend

- `npm run lint:ci`: **PASS**
- `npm run build`: **PASS**

### Flutter

- `flutter analyze`: **PASS** (0 issues)
- `flutter build apk --debug`: **PASS**
- `flutter build web --release --base-href=/app/`: **PASS**

### Wniosek

- Bazowy quality gate jest zielony dla backendu i aplikacji Flutter (mobile + web).

---

## 2) Financial Intelligence & Profit Guard

### ProfitAnalysisService — status kalkulacji marży

Stan: **zaimplementowany i aktywny**.

W `ProfitAnalysisService` marża liczona jest na bazie netto:

- cena sprzedaży brutto -> netto przez `toNetFromGross()`,
- marża kwotowa: `saleNet - purchasePriceNet`,
- marża procentowa: `marginAmount / saleNet * 100`,
- break-even brutto: `toGrossFromNet(purchasePriceNet, vatRate)`.

To jest poprawny kierunek dla e-commerce, gdzie `purchasePriceNet` i VAT muszą być rozdzielone.

### Cron Profit Guard (03:00)

Stan: **zarejestrowany**.

- Harmonogram: `@Cron('0 3 * * *', { timeZone: 'Europe/Warsaw' })`
- Rejestracja providera: `ProfitGuardCron` w `FinancialIntelligenceModule`
- Scheduler globalny: `ScheduleModule.forRoot()` w `AppModule`

### AiProposals — zapis i relacja z produktami

Stan: **spójny**.

- tabela: `ai_proposals`
- model: `AiProposal`
- relacja: `productId -> products.id` (`ON DELETE SET NULL`)
- statusy: `PENDING | ACCEPTED | REJECTED`
- użycie:
  - Profit Guard generuje/aktualizuje propozycje,
  - Owner Dashboard konsumuje `PENDING` oraz historię `ACCEPTED/REJECTED`.

---

## 3) Hype Maker & Social Integration

### SocialMediaIntegrator — architektura mocków

Stan: **wdrożony**.

Mapowane platformy (`SocialPlatform`):

- `INSTAGRAM`
- `FACEBOOK`
- `GOOGLE_ADS`

`SocialMediaService`:

- pobiera klucze z `.env`,
- zapisuje konfigurację do `social_configs`,
- tworzy rekord kampanii w `marketing_campaigns` (`MOCK_SENT`),
- loguje mock do konsoli + `AuditLog`.

### Flow po akcji APPROVE_PROPOSAL

W praktyce trigger jest w `FinancialIntelligenceService.acceptAndLaunchMarketing(...)`:

1. Aktualizacja produktu (`PROMO`, cena sugerowana, `isFeatured=true`).
2. Aktualizacja `AiProposal` do `ACCEPTED` + metadane akceptacji.
3. Generacja draftu marketingowego (`MarketingAutomationService`).
4. Wywołanie `HypeMakerService.runForApprovedProposal(...)`.
5. Hype Maker:
   - generuje copy przez OpenAI (`gpt-4o`, fallback lokalny),
   - wysyła PUSH segmentowy (Firebase),
   - wywołuje `postToInstagram`, `postToFacebook`, `triggerGoogleAdsUpdate`,
   - zapisuje audyt kampanii pod `HYPE_MAKER_AI`.
6. Błąd Hype Makera nie blokuje core flow Ownera (graceful fallback + audit failure event).

### MarketingCampaign — czy obsługuje wiele wersji treści?

Aktualnie model:

- `target`, `content`, `platform`, `status`, `externalId`.

Interpretacja:

- wiele wersji kanałowych jest wspierane przez **wiele rekordów** (oddzielnie IG/FB/Ads),
- model **nie** ma jeszcze osobnych kolumn typu `pushContent`, `facebookCaption`, `instagramCaption`, `adsHeadline`.

Wniosek: architektura działa dla MVP, ale pod AI Images + campaign preview warto dodać bardziej granularny model treści per kanał/format.

---

## 4) Infrastructure & Assets

### Storage pod assety (AI obrazy)

Stan: **brak dedykowanego modułu storage**.

- Nie znaleziono modułu backendowego dla Supabase Storage/S3/local media manager.
- Repo ma katalog `secrets/` (placeholder), ale brak produkcyjnego pipeline uploadu assetów kampanii.

Rekomendacja:

- dodać `AssetStorageModule` (abstrakcja + provider `local/supabase/s3`),
- zapisywać metadane wygenerowanych obrazów w DB (URL, hash, prompt, model, owner).

### Firebase integration

Stan: **częściowo gotowe do testów**.

- gotowe topici:
  - Owner: `FIREBASE_OWNER_TOPIC` (domyślnie `owner`),
  - segment lojalnościowy: `${FIREBASE_LOYALTY_TOPIC_PREFIX}_${segment}` (np. `loyalty_vintage`).
- brak dedykowanego, jawnego topicu `customers` w kodzie backendu.

Wniosek: owner + segment loyalty są gotowe; globalny broadcast do `customers` wymaga dodania osobnego flow/topicu.

---

## 5) Open Items & Risks

### TODO/FIXME po Hype Maker

- W backend `src/` nie ma nowych aktywnych `TODO/FIXME` bezpośrednio po wdrożeniu Hype Maker.
- Ryzyko pozostaje funkcjonalne, nie syntaktyczne: integracje social są w trybie mock.

### Dummy Data coverage

Stan: **niepełne pokrycie ścieżek marketingu**.

- `dev-mock` pokrywa autoryzację/profilowanie ról,
- ścieżki marketingowe bazują na realnych tabelach i mock-publisherach backendowych,
- brak pełnego end-to-end dummy środowiska dla social APIs + storage assetów obrazów.

### Kluczowe ryzyka architektoniczne

1. Brak modułu storage pod obrazki AI i ich wersjonowanie.
2. Brak realnych integracji social (na razie mock dispatch).
3. `MarketingCampaign` ma pojedyncze pole `content` (ograniczone pod preview wielokanałowy).
4. Brak telemetry skuteczności kampanii (delivery/open/click/conversion pipeline).

---

## 6) Identity

### Google Login + bootstrap

Stan: **wdrożone**.

- UI: przycisk `Zaloguj przez Google` na ekranie logowania Customer App.
- OAuth: `signInWithOAuth(OAuthProvider.google)`.
- Post-auth sync: `SupabaseAuthSync` wykrywa `signedIn` przez Google.
- Bootstrap profilu: `AuthSession` wywołuje `POST /auth/profile/bootstrap-google`.

Wniosek: ścieżka identity dla Google OAuth jest kompletna technicznie i gotowa do dalszych testów E2E.

---

## 7) Readiness Pod AI Images + Campaign Preview UI

Ocena: **średnio-wysoka gotowość backendowa**, **średnia gotowość produktowa**.

Co jest gotowe:

- stabilny core FI/Profit Guard/Hype Maker,
- działający trigger po `APPROVE_PROPOSAL`,
- audytowalność działań AI,
- green build/lint gates.

Co trzeba dowieźć przed modułem obrazów AI:

1. Storage abstraction + persystencja assetów.
2. Rozszerzenie modelu kampanii o struktury treści per kanał/format.
3. Telemetria kampanii i status delivery.
4. Integracja real API social (poza mock).
