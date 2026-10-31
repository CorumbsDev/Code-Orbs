#!/usr/bin/env python3
"""Gera Inventory/fases/scenarios/sequencia_base.tres com as 14 fases da sequência base."""

from pathlib import Path

OUT = Path(__file__).resolve().parents[1] / "Inventory/fases/scenarios/sequencia_base.tres"

# Ext resources
EXT = {
	"list": ("1_list", "res://Inventory/fases/phase_sequence_list.gd"),
	"step": ("2_step", "res://Inventory/fases/phase_sequence_step.gd"),
	"mochila": ("3_mochila", "res://Inventory/fases/phase_config.gd"),
	"typebox": ("4_typebox", "res://Inventory/fases/type_box_phase_config.gd"),
	"raw": ("5_raw", "res://Inventory/fases/raw_knapsack_phase_config.gd"),
}

KIND = {"MOCHILA": 0, "BINARIO": 1, "TYPE_BOX": 2, "RAW_MOCHILA": 3, "CONVERSAO": 4}

# Células na grade de 1 byte (igual MemoryLayout.slots_occupied).
_TYPE_CELLS = {
	"i": 4,
	"f": 4,
	"d": 8,
	"s": 2,
	"fp16": 2,
	"h": 2,
	"fp8": 1,
	"q": 1,
}


def csv_pool_cells(csv: str) -> int:
	total = 0
	for part in csv.split(","):
		e = part.strip()
		if not e or "_" not in e:
			continue
		type_str = e.rsplit("_", 1)[-1].lower()
		total += _TYPE_CELLS.get(type_str, 4)
	return total


def mochila(
	cap: int,
	csv: str,
	*,
	use_converter=False,
	allow_float=False,
	allow_double=False,
	allow_short=False,
	allow_fp8=False,
	allow_fp16=False,
	allow_calc=False,
	calc_max_uses=1,
	allow_inspector=True,
	forbid_underflow=False,
	forbid_overflow=True,
	error_tol=0.01,
	required="",
	star3="",
	pool_slots=24,
) -> dict:
	# Bancada precisa caber todos os itens iniciais (ex.: short+int+double = 14 células).
	need = csv_pool_cells(csv) + 8
	use_conv = bool(use_converter or allow_float)
	return {
		"kind": "MOCHILA",
		"capacity_bytes": cap,
		"slot_bytes": 1,
		"grid_columns": 4,
		"backpack_slot_count": cap,
		"pool_slot_count": max(pool_slots, need, 24),
		"pool_grid_columns": 8,
		"spawn_int_min": 1,
		"spawn_int_max": 10,
		"initial_backpack_csv": csv,
		"use_converter": use_conv,
		"allow_float": allow_float,
		"allow_double": allow_double,
		"allow_short": allow_short,
		"allow_fp8": allow_fp8,
		"allow_fp16": allow_fp16,
		"allow_calc": allow_calc,
		"calc_max_uses": calc_max_uses,
		"allow_inspector": allow_inspector,
		"forbid_underflow_zero": forbid_underflow,
		"forbid_overflow_inf": forbid_overflow,
		"error_tolerance_rel": error_tol,
		"required_values_csv": required,
		"star3_best_solution_csv": star3,
	}


def typebox(
	slots: dict,
	raws: list[str],
	*,
	expected: list[str] | None = None,
) -> dict:
	return {
		"kind": "TYPE_BOX",
		"capacity_bytes": 64,
		"slot_bytes": 4,
		"initial_raw_values": raws,
		"slots_int": slots.get("int", 0),
		"slots_float": slots.get("float", 0),
		"slots_short": slots.get("short", 0),
		"slots_double": slots.get("double", 0),
		"slots_fp8": slots.get("fp8", 0),
		"slots_fp16": slots.get("fp16", 0),
		"use_byte_limit": False,
		"expected_solution_types": expected or [],
	}


def raw(
	cap: int,
	values: list[str],
	*,
	allow_int=True,
	allow_short=False,
	allow_float=False,
	allow_double=False,
	allow_fp8=False,
	allow_fp16=False,
	slot_bytes=1,
) -> dict:
	return {
		"kind": "RAW_MOCHILA",
		"capacity_bytes": cap,
		"slot_bytes": slot_bytes,
		"grid_columns": 4,
		"backpack_slot_count": cap if slot_bytes == 1 else max(4, (cap + slot_bytes - 1) // slot_bytes),
		"pool_slot_count": max(18, len(values) + 6),
		"pool_grid_columns": 6,
		"initial_raw_values": values,
		"allow_int": allow_int,
		"allow_short": allow_short,
		"allow_float": allow_float,
		"allow_double": allow_double,
		"allow_fp8": allow_fp8,
		"allow_fp16": allow_fp16,
	}


PHASES: list[tuple[str, str, dict]] = [
	(
		"Ponto de Partida Inicial",
		(
			"Bem-vindo ao [b]Code Orbs[/b]! Na matemática do dia a dia, escrever [b]5[/b] ou [b]5.0[/b] dá exatamente no mesmo, mas dentro da memória do computador eles têm estruturas completamente diferentes.\n\n"
			"À direita, na [b]Bancada[/b], há 6 Orbes esperando por você: [b]5[/b], [b]-18[/b], [b]5.0[/b], [b]0.25[/b], [b]0.0[/b] e [b]10.5[/b]. Para começar, arraste cada um para a caixa correspondente à esquerda: a caixa [b]Int[/b] (com 2 espaços) guarda os números inteiros, enquanto a caixa [b]Float[/b] (com 4 espaços) recebe os números com ponto decimal.\n\n"
			"Antes de guardá-los, experimente arrastar um Orbe até o [b]Inspecionador[/b] para abrir um \"raio-X\" dos seus bits internos. Veja o que acontece se você tentar colocar o [b]5.0[/b] na caixa de inteiros e repare como até o próprio zero ([b]0.0[/b]) ocupa espaço e precisa de um tipo para existir na máquina!"
		),
		typebox(
			{"int": 2, "float": 4},
			["5", "-18", "5.0", "0.25", "0.0", "10.5"],
			expected=["int", "int", "float", "float", "float", "float"],
		),
	),
	(
		"Tipos de Dados",
		(
			"Você já sabe separar inteiros de números com ponto decimal, mas já reparou como a programação tem vários nomes diferentes para guardar números? Isso acontece porque \"inteiro\" e \"ponto flutuante\" não são tipos únicos, mas famílias com diferentes tamanhos e cores na memória.\n\n"
			"Os 6 Orbes na bancada são os mesmos de antes ([b]5[/b], [b]-18[/b], [b]5.0[/b], [b]0.25[/b], [b]0.0[/b] e [b]10.5[/b]), mas agora você tem 6 caixas diferentes à esquerda: [b]short int[/b], [b]int[/b], [b]fp8[/b], [b]fp16[/b], [b]float[/b] e [b]double[/b]. Desta vez, cada caixa tem espaço para apenas [b]1 Orbe[/b] e se fecha assim que é preenchida.\n\n"
			"Distribua os 2 inteiros e os 4 decimais entre todas as caixas para avançar. Repare em como cada tipo veste o Orbe com uma cor própria — já na próxima fase, você vai descobrir o peso real que cada uma dessas cores ocupa na memória!"
		),
		typebox(
			{"int": 1, "short": 1, "float": 1, "double": 1, "fp8": 1, "fp16": 1},
			["5", "-18", "5.0", "0.25", "0.0", "10.5"],
		),
	),
	(
		"Está Apertado",
		(
			"As caixas saíram de cena para dar lugar à [b]Mochila[/b], que representa a Memória RAM do seu computador! Aqui o espaço é contado byte a byte: sua Mochila comporta apenas [b]8 bytes[/b] no total.\n\n"
			"Na bancada, você recebeu três Orbes já tipados: [b]10[/b] em [b]short[/b] (2 bytes), [b]5[/b] em [b]int[/b] (4 bytes) e [b]8.5[/b] em [b]double[/b] (8 bytes). Somados, eles ocupam 14 bytes e não cabem todos na Mochila do jeito que estão.\n\n"
			"Para resolver isso, você conta com uma ferramenta nova: o [b]Conversor[/b]. Antes de converter, passe o [b]5[/b] e o [b]8.5[/b] pelo [b]Inspecionador[/b] e veja quantos bits zerados estão sobrando dentro deles. Depois, use o Conversor para mudá-los para tipos menores e encaixar tudo na Mochila. Só tome cuidado para não converter o [b]8.5[/b] para um tipo inteiro ([b]int[/b] ou [b]short[/b]), ou a parte [b].5[/b] será cortada e você perderá precisão!"
		),
		mochila(
			8,
			"10_s, 5_i, 8.5_d",
			allow_float=True,
			allow_double=True,
			allow_short=True,
			star3="10_s, 5_s, 8.5_f",
		),
	),
	(
		"Agora Explodiu",
		(
			"Na fase anterior, encolher números para [b]short int[/b] (2 bytes) salvou espaço na sua Mochila. Mas por que não guardamos todos os números inteiros do mundo em apenas 2 bytes? Porque menos bits também significam um limite muito menor para o valor que cabe ali dentro!\n\n"
			"Na bancada estão três Orbes do tipo [b]int[/b] (4 bytes cada): [b]15.000[/b], [b]50.000[/b] e [b]32.000[/b], somando 12 bytes para uma Mochila de apenas [b]8 bytes[/b].\n\n"
			"Com seus 16 bits, o tipo [b]short int[/b] só consegue contar até [b]32.767[/b]. Experimente levar os Orbes ao [b]Conversor[/b] e observe no [b]Inspecionador[/b] o que acontece quando um valor ultrapassa essa barreira: ocorre um [b]Overflow[/b] (estouro de capacidade), invadindo o bit de sinal! O Orbe muda na hora e ganha uma marca vermelha de aviso. Descubra quais Orbes podem encolher com segurança para 2 bytes e qual deles precisa continuar ocupando 4 bytes."
		),
		mochila(
			8,
			"15000_i, 50000_i, 32000_i",
			allow_short=True,
			star3="15000_s, 32000_s, 50000_i",
		),
	),
	(
		"Conversão pela Adição",
		(
			"O Conversor foi desligado nesta fase! Para guardar os valores da bancada ([b]100[/b] em [b]short[/b] de 2 bytes, [b]0.25[/b] em [b]float[/b] de 4 bytes e [b]10.5[/b] em [b]double[/b] de 8 bytes) na sua Mochila de [b]8 bytes[/b], você terá que fundir Orbes somando seus valores.\n\n"
			"Para isso, entra em ação a [b]Calculadora[/b], que permite somar dois Orbes — mas atenção: nesta fase ela tem apenas [b]2 usos[/b] disponíveis!\n\n"
			"Quando você junta dois Orbes de tipos diferentes na Calculadora, a máquina promove o resultado automaticamente para o tipo mais forte entre eles. Se o resultado virar um [b]double[/b], ele consumirá os 8 bytes da Mochila sozinho; e se um decimal fosse forçado para [b]short[/b], você perderia as casas depois da vírgula. Planeje bem os seus dois cálculos antes de somar!"
		),
		mochila(
			8,
			"100_s, 0.25_f, 10.5_d",
			allow_calc=True,
			calc_max_uses=2,
			star3="110.75_d",
		),
	),
	(
		"A Soma Explosiva",
		(
			"Individualmente, os números [b]20.000[/b] e [b]18.000[/b] cabem sem nenhum problema dentro de um [b]short int[/b] (2 bytes), já que ambos ficam abaixo do limite de [b]32.767[/b]. Mas o que acontece quando você resolve somar os dois?\n\n"
			"Na bancada estão os Orbes [b]20.000[/b] ([b]short[/b], 2 bytes), [b]18.000[/b] ([b]short[/b], 2 bytes) e [b]50.000[/b] ([b]int[/b], 4 bytes), somando 8 bytes para uma Mochila de apenas [b]6 bytes[/b].\n\n"
			"Se você somar os dois [b]short int[/b] direto na Calculadora ([b]20.000 + 18.000[/b]), ela tentará guardar [b]38.000[/b] dentro de apenas 2 bytes, provocando um [b]Overflow Aritmético[/b] — a famosa soma explosiva! Como o Conversor não está disponível aqui, aproveite o Orbe de [b]50.000[/b] ([b]int[/b], 4 bytes) na Calculadora para que a promoção automática de tipo salve a sua conta e tudo caiba nos 6 bytes!"
		),
		mochila(
			6,
			"20000_s, 18000_s, 50000_i",
			allow_calc=True,
		),
	),
	(
		"O Corte Seco",
		(
			"Quando você joga um número com vírgula (como [b]4.5[/b] ou [b]3.5[/b]) direto no Conversor para um tipo inteiro ([b]short int[/b]), o computador não arredonda o valor: ele faz um [b]Truncamento[/b], decepando a parte [b].5[/b] a frio e tirando suas estrelas de precisão!\n\n"
			"Nesta fase, sua Mochila tem [b]6 bytes[/b] e você precisa guardar nela o valor [b]2.25[/b] junto com o resultado da soma de [b]4.5 + 3.5[/b].\n\n"
			"Em vez de converter os números antes da hora, use a [b]Calculadora[/b] primeiro para somar [b]4.5 + 3.5[/b]. Assim que o resultado virar um número inteiro exato terminado em [b].0[/b], passe-o pelo [b]Conversor[/b] e transforme-o em um [b]short int[/b] de 2 bytes sem perder absolutamente nada!"
		),
		mochila(
			6,
			"4.5_f, 3.5_f, 2.25_d",
			allow_float=True,
			allow_double=True,
			allow_short=True,
			allow_calc=True,
			star3="8_s, 2.25_f",
		),
	),
	(
		"A Ilusão do Float",
		(
			"Muita gente imagina que o [b]float[/b] (4 bytes) só serve para números pequenos e o [b]double[/b] (8 bytes) para números gigantes. Na verdade, o [b]float[/b] consegue alcançar a casa dos bilhões, mas esconde um ponto fraco: seus [b]23 bits de Mantissa[/b] só guardam cerca de 7 dígitos com precisão exata!\n\n"
			"Você tem dois Orbes [b]double[/b] (8 bytes cada) na bancada — [b]16.777.219.0[/b] e [b]1.024.5[/b] — somando 16 bytes para uma Mochila de [b]12 bytes[/b]. Isso significa que apenas um deles precisa ser reduzido para [b]float[/b] (4 bytes).\n\n"
			"Experimente converter o [b]16.777.219.0[/b] para [b]float[/b] e observe no [b]Inspecionador[/b] como os 23 bits da mantissa esgotam sua capacidade, arredondando o final do número para [b]16.777.220.0[/b] por conta própria! Veja qual dos dois Orbes pode encolher para 4 bytes sem sofrer nenhuma distorção."
		),
		mochila(
			12,
			"16777219.0_d, 1024.5_d",
			allow_float=True,
			allow_double=True,
			star3="16777219.0_d, 1024.5_f",
		),
	),
	(
		"Espremendo a Mantissa",
		(
			"Em placas de vídeo e sensores, muitas vezes vale a pena aceitar um pequeníssimo arredondamento nas últimas casas decimais em troca de economizar metade da memória RAM. É aí que entra um novo tipo no seu Conversor: o Orbe amarelo [b]FP16[/b] (meia precisão, de [b]2 bytes[/b]), que divide seu espaço em apenas [b]5 bits de Expoente[/b] (alcance máximo de [b]65.504[/b]) e [b]10 bits de Mantissa[/b].\n\n"
			"Seu desafio é comprimir dois dos três Orbes [b]float[/b] da bancada ([b]3.14159[/b], [b]2.71828[/b] e [b]500.000.0[/b]) para que todos caibam nos [b]8 bytes[/b] da Mochila.\n\n"
			"Repare que a Mochila aceita o leve arredondamento nas últimas casas de Pi e do número de Euler (dentro da margem de tolerância de [b]0.1%[/b]). Mas veja no Conversor o que acontece com os 5 bits de Expoente se você tentar espremer [b]500.000.0[/b] dentro de um [b]fp16[/b]!"
		),
		mochila(
			8,
			"3.14159_f, 2.71828_f, 500000.0_f",
			allow_float=True,
			allow_fp16=True,
			error_tol=0.001,
			star3="3.14159_fp16, 2.71828_fp16, 500000.0_f",
		),
	),
	(
		"O Abismo do Underflow",
		(
			"Você já viu números explodirem quando são grandes demais para o tipo ([b]Overflow[/b]). Agora vai conhecer o perigo oposto: o [b]Underflow[/b], que acontece quando uma fração é tão pequenininha e próxima de zero que o tipo de dado não consegue representá-la e colapsa seu valor para [b]0.0[/b]!\n\n"
			"Para testar esse limite, o Conversor liberou o Orbe branco [b]FP8[/b] ([b]1 byte[/b]), um formato ultracompacto que conta com apenas [b]4 bits de Expoente[/b] e [b]3 bits de Mantissa[/b].\n\n"
			"Na bancada há quatro Orbes em [b]fp16[/b] ([b]1.5[/b], [b]2.25[/b], [b]0.5[/b] e [b]0.00008[/b]) para uma Mochila minúscula de [b]5 bytes[/b]. Reduza para [b]fp8[/b] tudo o que for seguro para economizar espaço, mas cuidado: nesta fase é proibido deixar qualquer Orbe zerar por Underflow!"
		),
		mochila(
			5,
			"1.5_fp16, 2.25_fp16, 0.5_fp16, 0.00008_fp16",
			allow_fp8=True,
			allow_fp16=True,
			forbid_underflow=True,
			star3="1.5_fp8, 2.25_fp8, 0.5_fp8, 0.00008_fp16",
		),
	),
	(
		"Quantização em Lote",
		(
			"Hora de pensar como um engenheiro otimizando um modelo de Inteligência Artificial! Na bancada estão cinco Orbes do tipo [b]float[/b] que pesam 20 bytes juntos ([b]1.25[/b], [b]3.5[/b], [b]3.33333[/b], [b]120.0[/b] e [b]1000.0[/b]), mas sua Mochila tem apenas [b]7 bytes[/b] de espaço.\n\n"
			"Use o [b]Inspecionador[/b] e o [b]Conversor[/b] para escolher o tipo ideal de cada número, lembrando que nem todo valor com vírgula se comporta igual em binário: frações como [b].25[/b] e [b].5[/b] são potências exatas de base 2 e cabem perfeitamente em [b]fp8[/b] (1 byte) sem perder nada, enquanto dízimas como [b]3.33333[/b] se deformam nos 3 bits do fp8 e pedem a precisão do [b]fp16[/b] (2 bytes).\n\n"
			"E fique de olho no [b]1000.0[/b]: ele passa do limite máximo do fp8 (448), mas será que um número terminado em [b].0[/b] precisa mesmo continuar em ponto flutuante?"
		),
		mochila(
			7,
			"1.25_f, 3.5_f, 3.33333_f, 120.0_f, 1000.0_f",
			allow_float=True,
			allow_short=True,
			allow_fp8=True,
			allow_fp16=True,
			error_tol=0.02,
			star3="1.25_fp8, 3.5_fp8, 3.33333_fp16, 120.0_fp8, 1000.0_s",
		),
	),
	(
		"O Mestre dos Dados",
		(
			"Chegou o desafio final da Mochila com todo o seu arsenal liberado! Você tem cinco Orbes na bancada e precisa entregar quatro resultados finais ocupando exatamente os [b]15 bytes[/b] da Mochila.\n\n"
			"O [b]40.000[/b] já nasceu como [b]int[/b] e não cabe em um short, então deixe-o como está. Já na soma de [b]16.777.216.0 + 1.0[/b], experimente observar um fenômeno novo: se você somá-los direto como [b]float[/b], ocorre a [b]Absorção de Mantissa[/b] — o [b]+ 1.0[/b] é completamente engolido porque os 23 bits do float não alcançam essa diferença, então promova um deles com o [b]Conversor[/b] antes de calcular! Atenção: a Calculadora só tem [b]1 uso[/b] nesta fase.\n\n"
			"Por fim, comprima o [b]0.0005[/b] sem deixá-lo cair em Underflow para [b]0.0[/b] e coloque o [b]1.5[/b] na menor fôrma possível para fechar a conta nos 15 bytes cravados!"
		),
		mochila(
			15,
			"40000_i, 16777216.0_f, 1.0_f, 0.0005_d, 1.5_d",
			allow_float=True,
			allow_double=True,
			allow_short=True,
			allow_fp8=True,
			allow_fp16=True,
			allow_calc=True,
			calc_max_uses=1,
			forbid_underflow=True,
			required="40000,16777217,0.0005,1.5",
			pool_slots=14,
		),
	),
	(
		"Primeira Declaração",
		(
			"Bem-vindo às Fases Híbridas! A partir de agora, você vai agir exatamente como um programador declarando variáveis do zero no código.\n\n"
			"Repare que os quatro Orbes na bancada ([b]15[/b], [b]-300[/b], [b]4.5[/b] e [b]0.5[/b]) nasceram brutos — cinzas e sem nenhum tipo definido —, mas precisam ser guardados em uma Mochila de [b]10 bytes[/b].\n\n"
			"Antes de levar um Orbe bruto até a Mochila, arraste-o para uma das [b]Estações de Tipagem[/b] no centro da tela ([b]short int[/b], [b]int[/b], [b]fp16[/b], [b]float[/b] ou [b]double[/b]) para batizá-lo com um tipo e uma cor. Escolha com sabedoria: se você usar tipos grandes demais sem necessidade — como declarar [b]15[/b] e [b]-300[/b] como [b]int[/b] de 4 bytes —, os Orbes vão passar do limite e travar sua Mochila!"
		),
		raw(
			10,
			["15", "-300", "4.5", "0.5"],
			allow_int=True,
			allow_short=True,
			allow_float=True,
			allow_double=True,
			allow_fp16=True,
			slot_bytes=4,
		),
	),
	(
		"O Arquiteto de Sistema",
		(
			"Este é o seu teste de formatura como Arquiteto de Sistema! Na bancada estão cinco valores brutos de naturezas totalmente diferentes ([b]17[/b], [b]-40.000[/b], [b]0.25[/b], [b]0.0078125[/b] e [b]3.14159[/b]), e você dispõe de exatamente [b]13 bytes[/b] na Mochila.\n\n"
			"Todas as seis [b]Estações de Tipagem[/b] estão abertas ([b]short int[/b], [b]int[/b], [b]fp8[/b], [b]fp16[/b], [b]float[/b] e [b]double[/b]), mas elas bloqueiam imediatamente qualquer escolha que provoque estouro, zeramento por underflow ou perda de precisão.\n\n"
			"Analise cada número com calma: descubra qual dos dois inteiros cabe em 2 bytes ([b]short[/b]) e qual ultrapassa o limite de [b]-32.768[/b] exigindo 4 bytes ([b]int[/b]); depois, veja qual decimal é simples o bastante para morar em 1 byte ([b]fp8[/b]), qual precisa de [b]fp16[/b] (2 bytes) para não virar zero e qual exige os 23 bits de mantissa de um [b]float[/b] (4 bytes). Encontre o tipo ideal para cada um e feche os 13 bytes com perfeição!"
		),
		raw(
			13,
			["17", "-40000", "0.25", "0.0078125", "3.14159"],
			allow_int=True,
			allow_short=True,
			allow_float=True,
			allow_double=True,
			allow_fp8=True,
			allow_fp16=True,
			slot_bytes=4,
		),
	),
]


def emit_bool(v: bool) -> str:
	return "true" if v else "false"


def emit_packed_strings(vals: list[str]) -> str:
	inner = ", ".join(f'"{v}"' for v in vals)
	return f"PackedStringArray({inner})"


def emit_mochila(rid: str, cfg: dict) -> str:
	lines = [
		f'[sub_resource type="Resource" id="{rid}"]',
		f'script = ExtResource("{EXT["mochila"][0]}")',
		f'capacity_bytes = {cfg["capacity_bytes"]}',
		f'slot_bytes = {cfg["slot_bytes"]}',
		f'grid_columns = {cfg["grid_columns"]}',
		f'backpack_slot_count = {cfg["backpack_slot_count"]}',
		f'pool_slot_count = {cfg["pool_slot_count"]}',
		f'pool_grid_columns = {cfg["pool_grid_columns"]}',
		f'spawn_int_min = {cfg["spawn_int_min"]}',
		f'spawn_int_max = {cfg["spawn_int_max"]}',
		"initial_backpack_items = PackedStringArray()",
		f'initial_backpack_csv = "{cfg["initial_backpack_csv"]}"',
		"initial_pool_items = PackedStringArray()",
		"random_pool = PackedStringArray()",
		"min_bytes_random_pool = 0",
		f'use_converter = {emit_bool(cfg["use_converter"])}',
		f'allow_float = {emit_bool(cfg["allow_float"])}',
		f'allow_double = {emit_bool(cfg["allow_double"])}',
		f'allow_short = {emit_bool(cfg["allow_short"])}',
		f'allow_fp8 = {emit_bool(cfg["allow_fp8"])}',
		f'allow_fp16 = {emit_bool(cfg["allow_fp16"])}',
		f'allow_calc = {emit_bool(cfg["allow_calc"])}',
		f'calc_max_uses = {cfg["calc_max_uses"]}',
		"fp8_exp_bits = 4",
		"fp8_mant_bits = 3",
		"fp16_exp_bits = 5",
		"fp16_mant_bits = 10",
		"allow_fp_customization = false",
		"respect_tool_flags = true",
		f'allow_inspector = {emit_bool(cfg["allow_inspector"])}',
		"fixed_pool_only = true",
		"win_mode = 0",
		"penalize_truncation_and_overflow = true",
		f'forbid_underflow_zero = {emit_bool(cfg["forbid_underflow_zero"])}',
		f'forbid_overflow_inf = {emit_bool(cfg["forbid_overflow_inf"])}',
		f'error_tolerance_rel = {cfg["error_tolerance_rel"]}',
		f'required_values_csv = "{cfg["required_values_csv"]}"',
		"star2_max_moves = 0",
		f'star3_best_solution_csv = "{cfg["star3_best_solution_csv"]}"',
		"",
	]
	return "\n".join(lines)


def emit_typebox(rid: str, cfg: dict) -> str:
	si = cfg["slots_int"]
	sf = cfg["slots_float"]
	ss = cfg["slots_short"]
	sd = cfg["slots_double"]
	s8 = cfg["slots_fp8"]
	s16 = cfg["slots_fp16"]
	active = sum(1 for x in (si, sf, ss, sd, s8, s16) if x > 0)
	box = max(si, sf, ss, sd, s8, s16, 1)
	exp = cfg["expected_solution_types"]
	lines = [
		f'[sub_resource type="Resource" id="{rid}"]',
		f'script = ExtResource("{EXT["typebox"][0]}")',
		f'capacity_bytes = {cfg["capacity_bytes"]}',
		f'slot_bytes = {cfg["slot_bytes"]}',
		f'initial_raw_values = {emit_packed_strings(cfg["initial_raw_values"])}',
		"randomize_values = false",
		f"box_slot_count = {box}",
		f"slots_int = {si}",
		f"slots_float = {sf}",
		f"slots_short = {ss}",
		f"slots_double = {sd}",
		f"slots_fp8 = {s8}",
		f"slots_fp16 = {s16}",
		f"grid_rows = {max(1, active)}",
		f"max_int_per_row = {si}",
		f"max_float_per_row = {sf}",
		f"max_short_per_row = {ss}",
		f"max_double_per_row = {sd}",
		f"max_fp8_per_row = {s8}",
		f"max_fp16_per_row = {s16}",
		f"allow_int = {emit_bool(si > 0)}",
		f"allow_short = {emit_bool(ss > 0)}",
		f"allow_float = {emit_bool(sf > 0)}",
		f"allow_double = {emit_bool(sd > 0)}",
		f"allow_fp8 = {emit_bool(s8 > 0)}",
		f"allow_fp16 = {emit_bool(s16 > 0)}",
		"fp8_exp_bits = 4",
		"fp8_mant_bits = 3",
		"fp16_exp_bits = 5",
		"fp16_mant_bits = 10",
		"star2_max_moves = 0",
		f'star3_best_solution_csv = "{", ".join(exp)}"',
		f'use_byte_limit = {emit_bool(cfg["use_byte_limit"])}',
		f"expected_solution_types = {emit_packed_strings(exp)}",
		"",
	]
	return "\n".join(lines)


def emit_raw(rid: str, cfg: dict) -> str:
	lines = [
		f'[sub_resource type="Resource" id="{rid}"]',
		f'script = ExtResource("{EXT["raw"][0]}")',
		f'capacity_bytes = {cfg["capacity_bytes"]}',
		f'slot_bytes = {cfg["slot_bytes"]}',
		f'grid_columns = {cfg["grid_columns"]}',
		f'backpack_slot_count = {cfg["backpack_slot_count"]}',
		f'pool_slot_count = {cfg["pool_slot_count"]}',
		f'pool_grid_columns = {cfg["pool_grid_columns"]}',
		f'initial_raw_values = {emit_packed_strings(cfg["initial_raw_values"])}',
		"randomize_values = false",
		f'allow_int = {emit_bool(cfg["allow_int"])}',
		f'allow_short = {emit_bool(cfg["allow_short"])}',
		f'allow_float = {emit_bool(cfg["allow_float"])}',
		f'allow_double = {emit_bool(cfg["allow_double"])}',
		f'allow_fp8 = {emit_bool(cfg["allow_fp8"])}',
		f'allow_fp16 = {emit_bool(cfg["allow_fp16"])}',
		"fp8_exp_bits = 4",
		"fp8_mant_bits = 3",
		"fp16_exp_bits = 5",
		"fp16_mant_bits = 10",
		"star2_max_moves = 0",
		'star3_best_solution_csv = ""',
		"",
	]
	return "\n".join(lines)


def emit_step(rid: str, kind: int, cfg_key: str, cfg_id: str, title: str, body: str) -> str:
	field = {
		KIND["MOCHILA"]: "config_mochila",
		KIND["TYPE_BOX"]: "config_type_box",
		KIND["RAW_MOCHILA"]: "config_raw_mochila",
	}[kind]
	# Escapa aspas no tutorial
	body_esc = body.replace('"', '\\"')
	title_esc = title.replace('"', '\\"')
	return "\n".join(
		[
			f'[sub_resource type="Resource" id="{rid}"]',
			f'script = ExtResource("{EXT["step"][0]}")',
			f"kind = {kind}",
			f"{field} = SubResource(\"{cfg_id}\")",
			"use_custom_tutorial = true",
			f'custom_tutorial_title = "{title_esc}"',
			f'custom_tutorial_text = "{body_esc}"',
			"",
		]
	)


def main() -> None:
	parts: list[str] = []
	step_ids: list[str] = []
	sub_count = 0

	for i, (title, body, cfg) in enumerate(PHASES, start=1):
		cfg_id = f"cfg_{i}"
		step_id = f"step_{i}"
		kind_name = cfg["kind"]
		kind = KIND[kind_name]
		if kind_name == "MOCHILA":
			parts.append(emit_mochila(cfg_id, cfg))
		elif kind_name == "TYPE_BOX":
			parts.append(emit_typebox(cfg_id, cfg))
		else:
			parts.append(emit_raw(cfg_id, cfg))
		parts.append(emit_step(step_id, kind, kind_name, cfg_id, title, body))
		step_ids.append(step_id)
		sub_count += 2

	load_steps = 5 + sub_count  # 5 ext + subs
	header = [
		f'[gd_resource type="Resource" script_class="PhaseSequenceList" load_steps={load_steps} format=3]',
		"",
		f'[ext_resource type="Script" path="{EXT["list"][1]}" id="{EXT["list"][0]}"]',
		f'[ext_resource type="Script" path="{EXT["step"][1]}" id="{EXT["step"][0]}"]',
		f'[ext_resource type="Script" path="{EXT["mochila"][1]}" id="{EXT["mochila"][0]}"]',
		f'[ext_resource type="Script" path="{EXT["typebox"][1]}" id="{EXT["typebox"][0]}"]',
		f'[ext_resource type="Script" path="{EXT["raw"][1]}" id="{EXT["raw"][0]}"]',
		"",
	]
	steps_arr = ", ".join(f'SubResource("{sid}")' for sid in step_ids)
	footer = [
		"[resource]",
		f'script = ExtResource("{EXT["list"][0]}")',
		f'steps = Array[ExtResource("{EXT["step"][0]}")]([{steps_arr}])',
		"",
	]
	text = "\n".join(header) + "\n".join(parts) + "\n".join(footer)
	OUT.write_text(text, encoding="utf-8")
	print(f"Wrote {OUT} with {len(PHASES)} phases ({OUT.stat().st_size} bytes)")


if __name__ == "__main__":
	main()
