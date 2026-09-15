# Few-shot pool (Billyy Human, eligible only)

Pointers to on-disk SLAL + gold. **Do not duplicate** JSON bodies here.

Eligibility (this prototype):

- Billyy Human registrar
- Not listed in [animations-broken.md](animations-broken.md)
- Non-empty `description` for **every** SLAL stage `1..N`
- At least one `{{sl.actors.N}}` token in the gold text

The complete-and-tokened set is **5 files** (under 6). Use **all of them** as few-shot. Rank is closeness to SLAL name/tags/flags (least invented pose/prop first). LLM few-shot still imitates gold **style and detail**; templates stay SLAL-honest ([templates.md](templates.md)).

SLAL pack file: `../Billyy's SLAL Animations 10.5/SLAnims/json/Billyy_Human.json`

Gold root: `SKSE/Plugins/SkyrimNet_SexLab/animations/`

| Rank | Registrar | SLAL `name` | Gold file | SLAL stages | Notes |
|-----:|-----------|-------------|-----------|------------:|-------|
| 1 | `B_B_CGAnal` | Billyy Cowgirl Anal | [GoodProvider/B_B_CGAnal.json](../SKSE/Plugins/SkyrimNet_SexLab/animations/GoodProvider/B_B_CGAnal.json) | 5 | Gold matches laying cowgirl anal |
| 2 | `B_B_FMast3` | Billyy F Masturbation 3 | [GoodProvider/B_B_FMast3.json](../SKSE/Plugins/SkyrimNet_SexLab/animations/GoodProvider/B_B_FMast3.json) | 5 | Solo masturbation; gold is all standing (tags also list Kneeling) |
| 3 | `B_B_MatingP1` | Billyy Mating Press | [GoodProvider/B_B_MatingP1.json](../SKSE/Plugins/SkyrimNet_SexLab/animations/GoodProvider/B_B_MatingP1.json) | 5 | Mating press; extra pose detail vs tags |
| 4 | `B_B_SpankDog` | Billyy Spanking Doggy | [GoodProvider/B_B_SpankDog.json](../SKSE/Plugins/SkyrimNet_SexLab/animations/GoodProvider/B_B_SpankDog.json) | 5 | Act matches; OTK/finger-bite is not in SLAL |
| 5 | `B_B_KneFF` | Billyy Kneeling Facefuck | [Token/B_B_KneFF.json](../SKSE/Plugins/SkyrimNet_SexLab/animations/Token/B_B_KneFF.json) | 5 | Complete labels; pronouns and a stage-5 actor-index typo |

Held out of this pool: `B_B_FMast4` (all five stages, no actor tokens) — [animations-broken.md](animations-broken.md). Sparse Human matches — [animations-sparse.md](animations-sparse.md). Label gaps — [animations-todo.md](animations-todo.md).
