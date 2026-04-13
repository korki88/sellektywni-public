# Pakiet synchronizacji (SELLEKTYWNI.PL)

Ten katalog jest **wersjonowany w Git** i ma umożliwić kontynuację pracy na dowolnym komputerze po samym `git clone` + kroki z [MACHINE_SETUP.md](MACHINE_SETUP.md).

| Plik | Cel |
|------|-----|
| [AGENT.md](AGENT.md) | Pełny kontekst dla agenta AI na drugim komputerze |
| [RULES.md](RULES.md) | Zasady pracy nad repo (w tym aktualizacja WORKLOG) |
| [WORKLOG.md](WORKLOG.md) | Dziennik zadań / decyzji — **aktualizuj po każdym istotnym poleceniu** |
| [MACHINE_SETUP.md](MACHINE_SETUP.md) | Nowa maszyna: Node, Docker, Flutter, baza, seed |
| [LOCAL_ARTIFACTS.md](LOCAL_ARTIFACTS.md) | Co jest tylko lokalnie (nie w repo) i jak to odtworzyć |
| [QUICK_REFERENCE.md](QUICK_REFERENCE.md) | Ściąga poleceń |
| [POLICY-private-and-gitignore.md](POLICY-private-and-gitignore.md) | Repo private + dlaczego nie commitujemy treści z `.gitignore` |
| [templates/](templates/) | Szablony bezpieczne do commitu (np. `dotenv.example`) |
| [scripts/](scripts/) | Bootstrap, dopisywanie wpisu do WORKLOG |

**Uwaga:** Sekretów (prawdziwego `.env` z produkcją) **nie** umieszczaj w repozytorium. Użyj `templates/dotenv.example` → skopiuj do `../.env` lokalnie.
