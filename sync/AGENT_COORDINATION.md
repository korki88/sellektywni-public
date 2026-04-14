# Koordynacja agentów AI i pracy równoległej

Cel: żeby **wiele osób / agentów** uzupełniało projekt **bez nadpisywania się** i z jasnym śladem w repo.

## 1. Unikalny identyfikator agenta (`AGENT_ID`)

Każdy agent (lub ludzki deweloper prowadzący automatyzację) powinien mieć **jeden stały identyfikator**, np.:

- `cursor-sellekt-7f3a91c2` (ten repozytorium — pierwsza rejestracja w tym dokumencie),
- albo `dev-jan-mobile`, `copilot-session-2026-04`, itd.

**Wymagania:**

- Unikalność w zespole (nie kopiuj identyfikatora innego agenta).
- Używaj go konsekwentnie w **`sync/WORKLOG.md`** jako prefiks: `[agent:cursor-sellekt-7f3a91c2] …`
- Opcjonalnie w **message commit**: `[agent:cursor-sellekt-7f3a91c2] opis zmiany`

## 2. Gałęzie Git — kto gdzie pracuje

| Strategia | Gałąź | Kiedy |
|-----------|--------|--------|
| **Integracja wspólna** | `main-home` | Wspólny branch do którego **trafiają ukończone** paczki (tak robi obecny agent, jeśli nie uzgodniono inaczej). |
| **Izolacja równoległa** | `agent/<AGENT_ID>/main` lub `feature/<AGENT_ID>-<krótki-slug>` | Gdy dwie osoby/agent mogą dotykać tych samych plików — **najpierw osobna gałąź**, potem merge / PR do `main-home`. |

**Zasady:**

- Przed długą sesją: `git fetch` + upewnij się, że nie pracujesz na przestarzałym stanie.
- Unikaj force-push do gałęzi współdzielonych.
- Konflikty rozwiązuj lokalnie; jeśli zmiana dotyka tego samego obszaru co inny agent — wpisz to w `WORKLOG.md`.

## 3. Unikalne „namespace” w kodzie i sync

- Nowe pliki tymczasowe / notatki: preferuj folder z prefiksem lub `sync/scratch/<AGENT_ID>/` (jeśli dodasz taki katalog — **dodaj do `.gitignore`** jeśli nie ma być w repo).
- Konfiguracja tylko dla jednego środowiska: dokumentuj w `sync/LOCAL_ARTIFACTS.md`, nie commituj sekretów.

## 4. Rejestr agentów (uzupełniaj przy pierwszej sesji)

| AGENT_ID | Domyślny branch push | Uwagi |
|----------|----------------------|--------|
| `cursor-sellekt-7f3a91c2` | `main-home` | Wdrożenie: analityka `/staff/analytics/*`, UI pomocy, filtr zamówień, dokumentacja koordynacji. |

**Kolejni agenci:** dopisz **nowy wiersz** z własnym `AGENT_ID` i preferowaną gałęzią (np. `agent/mój-id/main`).

## 5. Powiązane pliki

- Kontekst projektu: [AGENT.md](AGENT.md), [RULES.md](RULES.md), [WORKLOG.md](WORKLOG.md)
- Reguła Cursor: `../.cursor/rules/agent-coordination.mdc`
