# Code Orbs — Arquitetura e Validação das 12 Fases

> Escopo analisado: scripts `.gd` em `Inventory/` + `project.godot`. Cenas `.tscn`, `.godot/`, `addons/`, `android/`, QR vendor (`qr/vendor/*`) e `Achievements/achievement_analyzer.gd` **não** foram lidos em detalhe.
> Números de linha são aproximados (±3). Nenhum código foi alterado.

---

## 1. Visão Geral e Autoloads

Godot 4.4 (GL Compatibility). Cena principal: `Inventory/fases/main_menu.tscn`.

| Autoload | Script | O que gerencia |
|---|---|---|
| `DataHandler` | `Data/data_handler.gd` | Catálogo de orbes por ID (`item_data`: `item_number_5`, etc.) + merge de `Data/Item_data.json`; `get_item_bytes()`; chama `randomize()`. Fachada para `ConfigGenerator`. |
| `LearningPrefs` | `learning/learning_prefs.gd` | Flags de tutoriais já vistos (`has_seen_tutorial`, `mark_tutorial_seen`). |
| `PhaseRunner` | `fases/phase_runner.gd` | **Orquestrador da sequência**: guarda os passos, troca de cena, entrega o config à cena via `take_*_config_if_any()`, valida `is_phase_success()` ao avançar. |
| `OrbUI` | `ui/orb_ui.gd` | Singleton do popup de detalhe de orbe (`show_detail`/`hide_detail`). |
| `AchievementManager` | `Achievements/achievement_manager.gd` | Conquistas (save em `user://achievements.json`). Recebe eventos via `note_runtime_event("overflow"\|"underflow"\|"forced_cast"\|...)` e `on_phase_completed(step, scene)`. |
| `AchievementOverlay` | `Achievements/achievement_overlay.gd` | Escuta `AchievementManager.achievement_unlocked` e instancia o popup. |
| `BGMManager` | `bgm_manager.gd` | Música de fundo. |

Não-autoload mas global por `class_name`: `TypeConversionSystem`, `MemoryLayout`, `OrbValueFormat`, `ConfigGenerator`, `SequenceFileManager`, `TutorialTexts`, etc. (estáticos, sem estado).

---

## 2. Responsabilidade por Arquivo

### 2.1 Dados de fase (Resources)

- **`phase_sequence_list.gd` (`PhaseSequenceList`)** — `@export steps: Array[PhaseSequenceStep]`; `to_runtime_array()`. É o "arquivo de fases" (`.tres`).
- **`phase_sequence_step.gd` (`PhaseSequenceStep`)**
  - `enum Kind { MOCHILA, BINARIO, TYPE_BOX, RAW_MOCHILA, CONVERSAO }`.
  - `@export`: `kind`, `config_mochila`, `config_binario`, `config_type_box`, `config_raw_mochila`, `config_conversao`, `use_custom_tutorial`, `custom_tutorial_title`, `custom_tutorial_text`.
  - Constantes `BINARY_PHASES_ENABLED` e `CONVERSION_PHASES_ENABLED` = `false` (esses dois tipos estão **desligados**; `filter_playable_steps()` os remove).
- **`phase_config.gd` (`PhaseConfig`, tipo MOCHILA)** — `@export`: `capacity_bytes`, `slot_bytes` (4 ou 1), `grid_columns`, `backpack_slot_count`, `pool_slot_count`, `pool_grid_columns`, `spawn_int_min/max`, `initial_backpack_items` / `initial_backpack_csv` (lista de orbes iniciais — **vão para a bancada**, apesar do nome), `initial_pool_items`, `random_pool`, `min_bytes_random_pool`, `use_converter`, `allow_float/double/short/fp8/fp16/calc`, `fp8_exp_bits/mant_bits`, `fp16_exp_bits/mant_bits`, `allow_fp_customization`, `star2_max_moves`, `star3_best_solution_csv`. Métodos: `apply_constraints()`, `clamp_int_value()`, `get_backpack_entry_list()`.
- **`type_box_phase_config.gd` (`TypeBoxPhaseConfig`)** — `capacity_bytes`, `slot_bytes`, `initial_raw_values`, `randomize_values`, `box_slot_count`, `allow_int/short/float/double/fp8/fp16`, bits FP, `star2_max_moves`, `star3_best_solution_csv`, `expected_solution_types`.
- **`raw_knapsack_phase_config.gd` (`RawKnapsackPhaseConfig`)** — mochila + estações de tipagem: `capacity_bytes`, `slot_bytes`, `grid_columns`, `backpack_slot_count`, `pool_slot_count`, `initial_raw_values`, `randomize_values`, `allow_*`, bits FP, `star2_max_moves`, `star3_best_solution_csv`. (Sem `expected_solution_types`.)
- `binary_phase_config.gd` / `conversion_phase_config.gd` — fases binárias (desligadas).

### 2.2 Orquestração e persistência

- **`phase_runner.gd` (autoload)**
  - Estado: `_steps`, `_idx`, `_active`, `_pending_*` (um por tipo de config + tutorial).
  - `begin_with_steps()` → `_go_step()` faz `config.duplicate(true)` em `_pending_*` e `change_scene_to_file()` conforme `step.kind`.
  - `advance_from_phase()` chama `current_scene.is_phase_success()`; se falso emite `phase_advance_blocked(reason)`; se ok chama `AchievementManager.on_phase_completed()` e vai ao próximo.
  - Cenas: `phase2.tscn` (MOCHILA), `type_box_phase.tscn`, `raw_knapsack_phase.tscn`, `binary_phase.tscn`, `conversion_phase.tscn`.
- **`sequence_file_manager.gd`** — CRUD de `.tres` em `user://sequences`; `get_play_steps()` usa a **primeira sequência em ordem alfabética**; se não houver, copia `res://Inventory/fases/scenarios/sequencia_base.tres` (`BUNDLED_PEDAGOGICAL_SEQUENCE`) para `user://`.
- **`main_menu.gd`** — `_on_comecar_pressed()` → `SequenceFileManager.get_play_steps()` → `_with_all_conversions()` → `PhaseRunner.begin_with_steps()`. Abre editor, glossário, conquistas.
- **`sequence_csv_codec.gd` / `qr/sequence_qr_codec.gd` / `qr/sequence_qr_dialog.gd`** — exporta/importa sequência como CSV (colunas fixas) e QR (`COB1:` + vendor `qr_code.gd`).
- **`config_generator.gd` (`ConfigGenerator`)** — fábrica estática de configs (`generate_knapsack_config`, `generate_type_box_config`, `generate_raw_knapsack_config`, `generate_sequence`...). Usada por `generator_phase*.gd` e `SequenceFileManager`.

### 2.3 Criador de Fases (editor)

- **`sequence_editor.gd` (~1400 linhas, 37 `@onready`)** — árvore de sequências/fases, formulário de parâmetros, preview de grids, tutorial customizado, salvar, **jogar** (`_on_btn_jogar_pressed` → `PhaseRunner.begin_with_steps`), export/import CSV (`_build_sequence_csv`, `_import_sequence_from_csv`) e QR. Escuta sinais de dezenas de controles; não emite sinais próprios.
- **`mochila_config_panel.gd`, `typebox_config_panel.gd`, `raw_config_panel.gd`, `conversion_config_panel.gd`, `binary_config_panel.gd`** — `RefCounted`; `show_data(step)` / `apply_to_step(step)` / `get_visibility_rules()` mapeiam UI ↔ Resource. Recebem um `Dictionary` de nós da UI.

### 2.4 Cenas de jogo (hierarquia `phase_base`)

- **`phase_base.gd` (`extends Control`, 615 linhas)** — base de todas as fases jogáveis.
  - Responsabilidades: input/drag de orbes (`_process`, `_pick_item`, `_place_item`, `_on_slot_entered`), contagem de `moves_count`, validação de capacidade da mochila, ferramentas (`calculator`, `converter`, `inspect_slot`), botão "Próxima", overlay de vitória e **cálculo de estrelas** (`_show_victory_overlay`, `_check_star3_solution`, `_item_to_csv_string`), tutorial, hover bar.
  - Refs: `backpack_grid`, `pool_grid` (`InventoryGrid`), `converter_slot`, `calc_slot_1/2/result`, `calc_op_btn`, `inspect_slot`, `item_held`, `current_slot`.
  - Comunicação: conecta `slot_entered/slot_exited/item_changed` dos grids (`setup_grids`), escuta `PhaseRunner.phase_advance_blocked`, instancia `VictoryOverlay` (escuta `advance_requested` → `PhaseRunner.advance_from_phase()`). Subclasses sobrescrevem `is_phase_success()`, `_get_phase_config()`, `_tutorial_intro_id()`.
- **`phase_2.gd` (MOCHILA)** — `@export var config: PhaseConfig` (injetado por `PhaseRunner.take_backpack_config_if_any()`). Cria grids em runtime, **monta em código a UI de Conversor e Calculadora/Inspetor** (`_initialize_game`, `_create_calculator_ui`), parseia entradas (`_make_item_from_entry`: `"5_i"`, `"3.14_f"`, `"2.5_D"`, `"100_s"` ou IDs do `DataHandler`), gera extras de bancada (`_generate_extra_pool_items`). Vitória (`is_phase_success`): `moves_count>0` **e** mochila com bytes **exatamente** = `capacity_bytes` (+ bancada vazia via `_update_next_button_state` da base).
- **`type_box_phase.gd` (TYPE_BOX)** — orbes `RAW` na bancada → arrastar para **Caixas por tipo** (`_create_boxes`, `type_boxes`, `all_slots`). `_place_item` chama `check_degradation`; **qualquer** aviso = "FALHA NA CONVERSÃO" e o orbe não é colocado (`_square_peg_triggered`). Capacidade global em bytes (`global_capacity`). Vitória: todos tipados + `used == capacity` + `_solution_types_valid()` (confronta `expected_solution_types`). Estrela 1 perdida se `_has_integer_in_float_box()`.
- **`raw_knapsack_phase.gd` (RAW_MOCHILA)** — fluxo "tipar numa estação → colocar na mochila" (`_place_on_type_station`, `_place_on_backpack`). Aviso de degradação também bloqueia. Sem conversor/calculadora/inspetor. Vitória: pendentes=0, bytes == capacidade, sem RAW na mochila.
- `binary_phase.gd`, `conversion_phase.gd` — desligadas. `generator_phase.gd` / `generator_phase_new.gd` — tela de geração aleatória (duplicadas). `inventory_menu.gd` + `controlador.gd` (+ `Controlador.py`) — sandbox legado de expressões via Python externo.

### 2.5 Ferramentas e regras de tipos

- **`type_conversion_system.gd` (`TypeConversionSystem`, estático)** — prioridade de promoção (`priority_for_data_type`: Double 100 > Float 90 > FP16 80 > FP8 70 > Int 60 > Short 50), `get_type_string`, `value_for_conversion`, `apply_target_type_to_item`, **`check_degradation(target, valor, config)`** → `{has_warning, message, degraded_value}`, e a simulação de FP customizado (`float_to_custom_fp_bits`, `custom_fp_bits_to_float`).
- **`converter_tool.gd` (`ConverterTool`)** — `OptionButton` + slot; `convert_with_dialog()` (orbe solto no slot) e `_on_type_changed()` (troca do dropdown). Mostra `ConfirmationDialog` quando há aviso; notifica `AchievementManager` pelo **prefixo da mensagem** (`"Overflow"`, `"Underflow"`, `"Perda de precisão"`).
- **`calculator_tool.gd` (`CalculatorTool`)** — dois slots + `+`/`-`; `check_calculator()` promove tipo por prioridade, soma/subtrai em float64, passa por `check_degradation`, consome os dois orbes e instancia o resultado.
- **`inspector_modal.gd`** — mostra bits (int 32/16, float 8/23, double 11/52, FP8/FP16 customizável); `config.allow_fp_customization` libera sliders de expoente.
- **`memory_layout.gd`** — slot de 4 B vs 1 B (células). **`inventory_grid.gd`** — grid de slots (`@export capacity_bytes, slot_bytes, number_of_slots, grid_columns`; sinais `slot_entered`, `slot_exited`, `item_changed`; `total_bytes_used`, `can_place_item`, `place_item`).
- **`slot.gd`** — `TextureRect`; sinais `slot_entered/exited/item_changed`; `items_stored`, `item_stored`, `States`.

### 2.6 Orbes

- **`item.gd`** — `Node2D`. `enum DataType {INT, FLOAT, STRING, OPERATOR, DOUBLE, BINARY, SHORT_INT, FP8, FP16, RAW}`. Campos de valor **separados por tipo** (`value`, `value_float`, `value_double`, `value_short`), `fp_exp_bits/fp_mant_bits`. Sinais `mouse_entered_item`, `mouse_exited_item`. Delega a `ItemData` (valores/bytes) e `ItemVisuals`.
- **`item_data.gd`** — `set_value_by_type` (**não quantiza nada**, só atribui em float64/int64), `get_size_bytes` (Double 8, Float 4, Int 4, Short 2, FP16 2, FP8 1, RAW 0).
- **`orb_value_format.gd`** — textos/labels (compactação, `inf`/`nan` tratados).

### 2.7 UI auxiliar
`victory_overlay.gd` (sinal `advance_requested`), `tutorial_overlay.gd` (sinal `closed`), `tutorial_texts.gd`, `orb_hover_bar.gd`, `orb_detail_popup.gd`, `phase_info_bar.gd`, `panel_zone_header.gd`, `panel_art_loader.gd`, `glossary_screen.gd`.

---

## 3. Fluxo do Criador de Fases

1. **Definição = `Resource`.** Uma sequência é um `PhaseSequenceList` (`.tres`) → `Array[PhaseSequenceStep]` → cada step aponta para **um** config Resource conforme `kind`. Não há JSON/Dictionary para fases (JSON só em `Item_data.json` e glossário).
2. **Origem dos arquivos:** `res://Inventory/fases/scenarios/*.tres` (empacotados; `sequencia_base.tres` é o padrão) e `user://sequences/*.tres` (editor). O jogo lê **somente `user://`** (primeiro arquivo alfabético); o bundled só é copiado se `user://` estiver vazio.
3. **Editor** (`sequence_editor.gd` + `*_config_panel.gd`) edita os Resources e salva via `SequenceFileManager.save_sequence` (`ResourceSaver`). "Jogar" chama `PhaseRunner.begin_with_steps(steps)`.
4. **Runtime:** `PhaseRunner._go_step()` → `duplicate(true)` do config em `_pending_*` → `change_scene_to_file()`. A cena, no `_ready()`, faz `PhaseRunner.take_*_config_if_any()` (consome o pending), chama `config.apply_constraints()` e monta tudo **proceduralmente** (grids, caixas, ferramentas).
5. **Parâmetros hoje aceitos:** listados em 2.1 (capacidade, slots, tipos liberados, bits FP, calculadora, conversor, orbes iniciais por atalho `valor_tipo`, pool aleatório, metas de estrelas por movimentos e por solução CSV, tutorial customizado).
6. **Atalhos de orbe aceitos em `PhaseConfig`:** `i` (Int), `f` (Float), `d`/`D` (Double), `s` (Short) e IDs do `DataHandler`. **Não há atalho para FP8/FP16.** No Type Box/Raw os valores são strings numéricas puras (`"5"`, `"3.14"`).
7. **Serialização CSV/QR é com perdas:** `_build_sequence_csv()` (editor ~l.1129-1192) não exporta `star2_max_moves`, `star3_best_solution_csv`, `expected_solution_types`, `allow_int`, `initial_pool_items`, conteúdo de `random_pool` (só o tamanho) nem tutorial. Para fases curadas, usar `.tres`.

---

## 4. Pontos Críticos (Code Smells)

| Arquivo | Problema |
|---|---|
| `fases/sequence_editor.gd` (~1400 l.) | God Object: UI do editor + preview + I/O de arquivos + CSV/QR + regras de limite de orbes. |
| `fases/phase_base.gd` (615 l.) | Input + capacidade + ferramentas + vitória/estrelas + tutorial no mesmo script. |
| `fases/phase_2.gd` (443 l.) | Setup de grids + construção da UI de Conversor/Calculadora/Inspetor em código + parser de entradas + geração aleatória. |
| `fases/type_box_phase.gd`, `raw_knapsack_phase.gd` (~575 l. cada) | Duplicam pick/place/vitória/estrelas da base (`_show_victory_overlay` existe na base e no type box com regras divergentes). |
| `fases/type_conversion_system.gd` | Mistura tabela de tipos, simulação IEEE, política de degradação e aplicação ao item; resultado só em `String` (consumidores fazem parse de prefixo de mensagem). |
| `phase_config.gd` / `type_box_phase_config.gd` / `raw_knapsack_phase_config.gd` | Campos `allow_*`/bits FP/estrelas triplicados; sem classe base. |
| `main_menu.gd -> _with_all_conversions()` | Sobrescreve silenciosamente o config da fase ao jogar (ver Matriz). |
| `Items/item.gd` + `item_data.gd` + `item_visuals.gd` | Valor por tipo em 4 campos paralelos; dados, visual e preview misturados. |
| Legado | `old_sequence_editor.gd` (raiz), `inventory_menu.gd`, `controlador.gd`/`Controlador.py`, `generator_phase.gd` vs `generator_phase_new.gd`, `phase_base_backup.tscn`. |

---

## 5. Matriz de Compatibilidade das Fases

Legenda: ✅ pronto · 🟡 parcial · ❌ ausente. IDs `A#` referem-se à seção 5.2.

### 5.1 [PRONTO] — o que o código atual já faz

| Fase | Já suportado nativamente |
|---|---|
| **F1** | Kind `TYPE_BOX` com caixas Int/Float; orbes `RAW` vindos de `initial_raw_values`; `expected_solution_types` + `_solution_types_valid()` (`type_box_phase.gd`); estrelas por movimentos/solução. ✅ base / ❌ detalhes (A10, A11). |
| **F2** | `box_slot_count = 1` limita 1 orbe por tipo; caixas para Short/Int/FP8/FP16/Float/Double (`_create_boxes`). FP8/FP16 rejeitam valores sem representação exata (`check_degradation`). ✅ base / 🟡 Float vs Double (A7, A10). |
| **F3** | Mochila de bytes com capacidade validada em `phase_base._on_slot_entered` (l.393-398); Conversor (`use_converter`, `allow_short`) com aviso **"Perda de precisão: parte decimal descartada"** em `check_degradation` (Int/Short, l.70-102). `star3_best_solution_csv` (`"8.5_f,5_s"`) já **tira a 3ª estrela** se o jogador truncar. 🟡 |
| **F4** | `check_degradation("Short")` detecta **Overflow** (>32767) com mensagem `"Overflow..."` + conquista `overflow`; valor saturado em 32767. Inspetor mostra 16 bits. 🟡 (sem penalidade formal; ver A6) |
| **F5** | Calculadora (`allow_calc`) com **promoção de tipo** por prioridade (`calculator_tool.gd` l.51-54: Short+Float→Float, +Double→Double); bytes por tipo (`item_data.get_size_bytes`). ✅ (atenção A1: "sem conversor" não é respeitado hoje). |
| **F6** | Short+Short = 38000 dispara aviso `"Overflow"` (`check_calculator` → `check_degradation("Short")`). Conversão Short→Int via Conversor funciona; Int+Short promove para Int sem aviso. ✅ (comportamento é **saturação**, não wrap; A17 opcional). |
| **F7** | 4.5f+3.5f=8.0 (float64 exato), convertido a Short **sem aviso** (`trunc == valor`). Converter 4.5 direto a Short avisa. ✅ (penalidade formal A6). |
| **F8** | Inspetor exibe bits float (8/23) e double (11/52). 🟡 (arredondamento não existe — A7a) |
| **F9** | FP16 (5/10): 500000 → `Inf` (exp estoura, `float_to_custom_fp_bits` l.164-166); máximo 65504 correto. Aviso aparece e jogador pode "Prosseguir". 🟡 |
| **F10** | FP8 (4/3 default): 0.00008 vira **0.0** (flush-to-zero, l.167-169) com aviso. Sliders de bits (`allow_fp_customization`) permitem salvar o valor com mais expoente. 🟡 |
| **F11** | Conversor em lote para FP8/FP16/Short; capacidade em bytes (7 B); preview de tipagem. 🟡 |
| **F12** | Capacidade 15 B, Conversor + Calculadora + Inspetor no mesmo `phase_2`; objetivo multi-item via `star3_best_solution_csv` (igualdade de multiconjunto). 🟡 |

### 5.2 [AJUSTE NECESSÁRIO] — o que programar/adaptar

| ID | Fases | Arquivo → função (linhas ≈) | Ajuste |
|---|---|---|---|
| **A1** | F3-F7 | `fases/main_menu.gd` → `_with_all_conversions()` (88-104) | Força `use_converter/allow_float/double/short/fp8/fp16 = true` em **todo** passo MOCHILA ao jogar. Inviabiliza "F5 sem conversor", "F3/F4 só Short/Float". Remover ou tornar opt-in (ex.: `PhaseConfig.respect_tool_flags`). |
| **A2** | F3, F4, F8-F10 | `fases/phase_2.gd` → `_initialize_game` (78-154) e `_create_calculator_ui` (273-299) | Inspetor (`inspect_slot`) só nasce se `allow_calc`. Criar `allow_inspector` (novo `@export` em `PhaseConfig`) e construir o painel de inspeção fora de `_create_calculator_ui`. Também: "Float" no dropdown depende de `use_converter`, mas Short/Double/FP8/FP16 aparecem só com `allow_*`, mesmo com `use_converter=false` — esclarecer semântica (`use_converter` ≈ liga o painel). |
| **A3** | F3-F7, F11, F12 | `phase_2.gd` → `_initialize_game` (163-166) + `_generate_extra_pool_items` (378-400) | Se os orbes fixos somam menos que `capacity_bytes`, o jogo **injeta orbes aleatórios** (inclusive floats `x.5`). Fases determinísticas (F6: 2+2=4 B < capacidade) quebram. Adicionar `PhaseConfig.fixed_pool_only` e pular a geração. |
| **A4** | F4, F6, F10, F12 | `phase_2.gd` → `_make_item_from_entry` (307-347) | (a) Entrada `"_i"` é limitada por `config.clamp_int_value` (padrão **0..99**): `15000_i`, `50000_i`, `-18_i` seriam cortados — só usar clamp no sorteio, não em valores explícitos (ou setar `spawn_int_min/max` em cada fase). (b) Não há atalho FP8/FP16 (necessário p/ "0.00008 fp16" na F10): adicionar sufixos (`_h` FP16, `_q` FP8, ou `_fp16/_fp8`), pré-quantizar o valor com `TypeConversionSystem` e aplicar bits via `apply_fp_bits_from_config`. Hoje `phase_base._item_to_csv_string` já emite `fp8/fp16`, mas o parser não os lê. |
| **A5** | F3, F11, F12 | `phase_2.gd` → `is_phase_success` (427-434); `phase_base.gd` → `_update_next_button_state` (345-369) | Regra única: bytes **== capacidade** e bancada vazia. Fases do tipo "cabe ≤ N bytes" (F3: double 8.5 + int 5 → float+short = 6 B ≠ 8 B) não vencem. Adicionar `PhaseConfig.win_mode` (`EXACT_FILL`/`FIT_WITHIN`) e, para F12, uma lista de **objetivos** (ver A9). |
| **A6** | F3, F4, F6, F7, F10 | `converter_tool.gd` → `convert_with_dialog` (53-83) / `_on_type_changed` (85-123); `calculator_tool.gd` → `check_calculator` (42-122); `phase_base.gd` → `_show_victory_overlay` (237-269) | Não existe contador de degradações: o jogador pode "Prosseguir" e nada penaliza (só conquistas). Criar `phase_base.register_degradation(kind, info)` chamado após o `res == true` nos três pontos, guardar `degradation_events`, e em `_show_victory_overlay` perder estrela (ex.: s1/s3) conforme novos campos de config (`penalize_truncation`, `fail_on_overflow`, `fail_on_underflow`). A F7 ("sem Truncamento") e F3 dependem disso; a F10 ("falha se zerar") também. |
| **A7** | F2, F8, F9, F10, F12 | `type_conversion_system.gd` → `check_degradation` (70-142) e `float_to_custom_fp_bits` (144-176) | (a) **Float** (104-112): só checa faixa; não arredonda a float32. Para F8 (`16777219 → 16777220`) e F12 aplicar round-to-nearest-even via `PackedByteArray.encode_float/decode_float` e emitir aviso de precisão. (b) **FP8/FP16** (114-140): qualquer diferença vira `"Perda de precisão"`; classificar **Overflow** (resultado Inf) e **Underflow** (resultado 0 com origem ≠ 0) com mensagens iniciadas em `"Overflow"`/`"Underflow"` (os consumidores `_notify_*_warning` e o achievement dependem do prefixo). (c) Retornar também `kind` (enum/string), `abs_error`, `rel_error` no Dictionary, em vez de depender de `message`. (d) Quantização FP hoje **trunca** a mantissa (l.171-174); trocar por round-to-nearest-even (com carry para o expoente) — ex.: Euler→FP16 dá 2.7168 (trunc) vs 2.7188 (RN). Subnormais hoje são zerados (aceitável p/ F10; documentar). |
| **A8** | F5, F11, F12 | `calculator_tool.gd` → `check_calculator` (48-49, 53-62) e `type_conversion_system.priority_for_data_type` (11-18) | (a) l.48-49: para FP8/FP16 usa `float(item.value)` (int truncado) em vez de `TypeConversionSystem.value_for_conversion()` — resultado errado com frações. (b) **Absorção de mantissa (F12)**: depois de A7a, detectar quando `result_exato != result_arredondado` e `|menor operando| > 0` e emitir `kind="absorption"` com mensagem própria. (c) A tabela dá FP8(70)/FP16(80) > Int(60): `int + fp16 → fp16` (pode estourar). Confirmar se é a intenção pedagógica. |
| **A9** | F9, F11, F12 | `phase_base.gd` (novo `_evaluate_goals()`), `item.gd` (novo `source_value`), configs | **Tolerância de erro inexistente.** Único caso é `type_box_phase._raw_values_match` (447-452) fixo em `1e-4` relativo (Pi→FP16 = 3.1406 erra 3e-4 → reprovaria). Criar em `PhaseConfig`: `error_tolerance_abs/rel`, `max_total_error`, `goals: Array[Dictionary]` (`{type, value, tol}`); guardar o valor original do orbe (`source_value`) e propagá-lo em `apply_target_type_to_item` e na calculadora; `is_phase_success` consulta `_evaluate_goals()`. Mostrar o "medidor de erro" em `_update_hint` (`phase_base` 593-602) / `phase_info_bar.gd`. |
| **A10** | F1, F2 | `type_box_phase.gd` → `is_phase_success` (416-429), `_place_item` (295-300), `_update_bytes_label` (381-386), `_has_integer_in_float_box` (523-536) usado em `_show_victory_overlay` (541) | (a) **F1 sem bytes**: `used == capacity` é obrigatório e a UI sempre mostra "x / y bytes". Adicionar `TypeBoxPhaseConfig.use_byte_limit` (default true) e ocultar/ignorar capacidade quando false. (b) **A penalidade de estrela 1 conflita com F1:** `5.0` e `0.0` são corretamente Float, mas `_has_integer_in_float_box` (usa `roundf`) os pune. Trocar por checagem baseada na literal/`expected_solution_types`. (c) F2: exige capacidade exata somando os 6 tipos; usar `use_byte_limit=false` ou capacidade = soma. |
| **A11** | F1 | `item.gd` (novo `raw_literal`, `raw_index`), `type_box_phase.gd` → `_populate_pool` (171-187) / `_solution_types_valid` (471-503), `raw_knapsack_phase.gd` → `_populate_raw_pool` (185-196), `orb_value_format.gd` → `_compact_for_type` (RAW) | RAW guarda só `float("5")` = `float("5.0")` = 5.0: os dois orbes ficam **indistinguíveis** e o validador casa por (tipo, valor), aceitando a troca. Guardar a literal original (`"5"` vs `"5.0"`) para exibição e o índice do orbe para casar com `expected_solution_types[i]`. |
| **A12** | F2 | `type_conversion_system.check_degradation` ramo `"Float"` | Sem checagem de precisão, valores só-Double passam na caixa Float sem aviso (só a validação de `expected_solution_types` os pega, com hint genérico). Resolvido com A7a. |
| **A13** | todas | `sequence_editor.gd` → `_build_sequence_csv` (1129-1192) / `_import_sequence_from_csv` (1195-1337); `*_config_panel.gd` | Exportação/QR perde estrelas, `expected_solution_types`, `allow_int`, `initial_pool_items`, `random_pool` e qualquer campo novo (A2-A11). Os painéis do editor também não expõem esses campos. Curar as 12 fases como `.tres` e, se quiser editor/QR, estender colunas + painéis. |
| **A14** | todas | `sequence_file_manager.gd` → `_find_default_sequence` (44-49), `_create_base_sequence` (60-70), const `BUNDLED_PEDAGOGICAL_SEQUENCE` | O jogo roda a 1ª sequência **de `user://`**; um `Sequencia_Base.tres` antigo já copiado ofusca o bundled. Apontar a constante para o novo `.tres` das 12 fases e prever migração/limpeza do arquivo em `user://`. |
| **A15** | F11, F12 | `phase_base.gd` → `is_phase_success`/`_update_next_button_state` | Orbes esquecidos nos slots do conversor/calculadora/inspeção não contam como "bancada" nem bloqueiam vitória; considerar incluí-los em `pool_items`. |
| **A16** | F11 | `phase_base._check_star3_solution` (274-301) / `_item_to_csv_string` (303-333) | Compara `str(float)` exato; para FP8/FP16/Float quantizados é frágil (ex.: `"3.140625_fp16"`). Preferir comparação por tolerância/objetivo (A9). |
| **A17** | F4, F6 (opcional) | `check_degradation` ramos Int/Short (78-102) | Overflow **satura** (32767) em vez de dar a volta (wrap complemento de 2: 38000 → −27536). Se a didática pedir wrap, adicionar `overflow_mode`. |

### 5.3 Resumo por fase

| Fase | Veredito | Bloqueadores |
|---|---|---|
| F1 | ❌ não vence como especificada | A10, A11 |
| F2 | 🟡 funciona com capacidade = soma dos bytes | A7a/A12, A10c |
| F3 | 🟡 | A1, A2, A3, A5, A6 |
| F4 | 🟡 | A1, A2, A4, A6 |
| F5 | 🟡 | A1 (conversor forçado), A3 |
| F6 | 🟡 | A1, A3, A4, A6 |
| F7 | 🟡 | A3, A6 |
| F8 | ❌ | A7a, A2 |
| F9 | 🟡 | A7b/d, A9 |
| F10 | ❌ | A4b, A6/A9, A2, A7b |
| F11 | ❌ | A9, A5, A3, A4b |
| F12 | ❌ | A7a, A8b, A9, A5 |

**Ordem sugerida:** A1 → A7 (base numérica) → A6/A9 (regras de vitória e tolerância) → A2/A3/A4/A5 → A10/A11 → A13/A14.
