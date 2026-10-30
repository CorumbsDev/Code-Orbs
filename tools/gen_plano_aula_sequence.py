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
			"[b]Alinhamento do Aprendizado[/b]\n"
			"Entender que números matematicamente iguais (como 5 e 5.0) são tratados como estruturas físicas diferentes pelo computador, e que até o valor nulo (0.0) ocupa espaço e exige um tipo.\n\n"
			"[b]Nova Mecânica — Caixas Coletoras e Inspecionador[/b]\n"
			"Apresentação da Bancada, do Inspecionador e das Caixas de Tipagem (Int com 2 espaços e Float com 4 espaços).\n\n"
			"[b]Texto de Guia para o Aluno[/b]\n"
			"Bem-vindo ao Code Orbs! Na matemática do dia a dia, escrever 5 ou 5.0 dá exatamente no mesmo, mas dentro da memória do computador eles possuem estruturas completamente diferentes.\n\n"
			"[b]Como jogar:[/b] À direita, na Bancada, estão 6 Orbes esperando classificação (5, -18, 5.0, 0.25, 0.0 e 10.5). À esquerda estão duas Caixas Coletoras: uma para números inteiros (Int, com 2 espaços) e outra para números com vírgula ou ponto flutuante (Float, com 4 espaços).\n\n"
			"[b]Ferramenta Nova — Inspecionador:[/b] Antes de mover um Orbe, você pode arrastá-lo até o Inspecionador para abrir um \"raio-X\" dos seus bits internos. Repare no que acontece se você tentar colocar o 5.0 na caixa Int e observe como até o zero (0.0) tem estrutura e precisa de um tipo para existir na máquina!"
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
			"[b]Alinhamento do Aprendizado[/b]\n"
			"Descobrir que \"inteiro\" e \"ponto flutuante\" não são tipos únicos, mas famílias com diferentes tamanhos de fôrma e cores na memória.\n\n"
			"[b]Nova Mecânica — Trava de 1 Orbe por Tipo[/b]\n"
			"Expansão para 6 Caixas de Tipo (short int, int, fp8, fp16, float e double), onde cada caixa aceita apenas 1 único Orbe.\n\n"
			"[b]Texto de Guia para o Aluno[/b]\n"
			"Você já sabe separar inteiros de números com ponto decimal, mas por que a programação tem tantos nomes diferentes para guardar números?\n\n"
			"[b]Nova Regra — Limite por Tipo:[/b] Os 6 Orbes na bancada são os mesmos da fase anterior, mas agora você tem 6 caixas diferentes à esquerda (short int, int, fp8, fp16, float e double). Cada caixa possui apenas 1 espaço e trava assim que recebe um Orbe!\n\n"
			"[b]Seu Objetivo:[/b] Distribua os 2 inteiros (5 e -18) e os 4 decimais (5.0, 0.25, 0.0 e 10.5) entre todas as 6 caixas. Veja como cada tipo veste o Orbe com uma cor própria — na próxima fase você descobrirá o peso real que cada cor tem na memória!"
		),
		typebox(
			{"int": 1, "short": 1, "float": 1, "double": 1, "fp8": 1, "fp16": 1},
			["5", "-18", "5.0", "0.25", "0.0", "10.5"],
		),
	),
	(
		"Está Apertado",
		(
			"[b]Alinhamento do Aprendizado[/b]\n"
			"Compreender a memória RAM como um espaço físico finito em bytes, identificar bits ociosos (zeros à esquerda) e realizar reduções seguras de tipo (downcasting) sem perder precisão.\n\n"
			"[b]Nova Mecânica — A Mochila e o Conversor[/b]\n"
			"Substituição das caixas pela Mochila (Memória RAM) medida em bytes/slots e liberação da ferramenta Conversor.\n\n"
			"[b]Texto de Guia para o Aluno[/b]\n"
			"As caixas saíram de cena para dar lugar à Mochila, que representa a Memória RAM do seu computador! Aqui o espaço é rígido: sua Mochila tem apenas 8 bytes (8 espaços de 1 byte cada).\n\n"
			"Na bancada você recebeu 3 Orbes já tipados: 10 em short (2 bytes), 5 em int (4 bytes) e 8.5 em double (8 bytes). Juntos eles pesam 14 bytes e não cabem na Mochila!\n\n"
			"[b]Ferramenta Nova — O Conversor:[/b] Use o Inspecionador para ver quantos bits zerados estão sobrando dentro do 5 (int) e do 8.5 (double). Depois, coloque-os no Conversor para mudar seus tipos para tamanhos menores. Mas atenção: se você converter o 8.5 para um tipo inteiro (int ou short), a parte .5 será cortada e você perderá 1 estrela de precisão!"
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
			"[b]Alinhamento do Aprendizado[/b]\n"
			"Perceber que reduzir tipos economiza memória, mas esbarra no limite físico de bits que cada tipo suporta, conhecendo o fenômeno do Overflow (estouro de capacidade).\n\n"
			"[b]Nova Mecânica — Alerta de Overflow Estático[/b]\n"
			"Demonstração do limite de 16 bits em complemento de 2 (32.767 no short int).\n\n"
			"[b]Texto de Guia para o Aluno[/b]\n"
			"Na fase passada, encolher tipos para short int (2 bytes) salvou o seu espaço na Mochila. Mas por que não guardamos todos os números inteiros do mundo em apenas 2 bytes?\n\n"
			"Você tem três Orbes do tipo int (4 bytes cada): 15.000, 32.000 e 50.000, somando 12 bytes para uma Mochila de 8 bytes.\n\n"
			"[b]O que observar:[/b] Tente passar os três Orbes pelo Conversor para short int e veja o que acontece quando um número passa de 32.767 (o limite máximo de 16 bits com sinal). Use o Inspecionador para ver o bit de sinal sendo invadido pelo Overflow e descubra quais Orbes podem encolher e qual precisa continuar com 4 bytes!"
		),
		mochila(
			8,
			"15000_i, 32000_i, 50000_i",
			allow_short=True,
			star3="15000_s, 32000_s, 50000_i",
		),
	),
	(
		"Conversão pela Adição",
		(
			"[b]Alinhamento do Aprendizado[/b]\n"
			"Aprender como o computador promove e transforma tipos automaticamente durante uma operação matemática (coerção/promoção de tipos).\n\n"
			"[b]Nova Mecânica — A Calculadora e o Limite de Usos[/b]\n"
			"O Conversor é desativado e entra a Calculadora com limite de apenas 1 uso.\n\n"
			"[b]Texto de Guia para o Aluno[/b]\n"
			"O Conversor foi desligado nesta fase! Para colocar os dados de 100 (short, 2B), 0.25 (float, 4B) e 10.5 (double, 8B) dentro da Mochila, você terá que fundir Orbes somando seus valores.\n\n"
			"[b]Ferramenta Nova — Calculadora (Uso Limitado):[/b] A Calculadora permite somar dois Orbes, mas atenção: nesta fase ela possui apenas 1 uso disponível!\n\n"
			"[b]Como funciona a soma de tipos diferentes:[/b] Quando você junta dois Orbes de tipos diferentes na Calculadora, a máquina promove o resultado para o tipo mais forte (ou para a estrutura escolhida na operação). Se o resultado virar um double, ele consumirá 8 bytes sozinho; se forçar um decimal a virar short, você perderá as casas depois da vírgula. Planeje bem o seu único cálculo antes de somar!"
		),
		mochila(
			8,
			"100_s, 0.25_f, 10.5_d",
			allow_calc=True,
			star3="100.25_f, 10.5_f",
		),
	),
	(
		"A Soma Explosiva",
		(
			"[b]Alinhamento do Aprendizado[/b]\n"
			"Compreender que duas variáveis perfeitamente válidas podem causar um Overflow em tempo de execução quando somadas, e que a Calculadora herda o tipo dos operandos para guardar o resultado.\n\n"
			"[b]Nova Mecânica — Overflow na Calculadora[/b]\n"
			"Estouro aritmético ao somar tipos pequenos e promoção de tipo ao operar com um tipo maior (int).\n\n"
			"[b]Texto de Guia para o Aluno[/b]\n"
			"Individualmente, os números 20.000 e 18.000 cabem sem nenhum problema dentro de um short int (2 bytes), já que ambos são menores que o limite de 32.767. Mas o que acontece quando você resolve somar os dois?\n\n"
			"[b]Seu Objetivo:[/b] Na bancada você tem 20.000 (short, 2B), 18.000 (short, 2B) e 50.000 (int, 4B), totalizando 8 bytes para uma Mochila de apenas 6 bytes.\n\n"
			"[b]Dica de Estratégia:[/b] Se você somar os dois short int direto na Calculadora (20.000 + 18.000), ela tentará guardar 38.000 dentro de 2 bytes, provocando um Overflow Aritmético (a soma explosiva)! Como o Conversor não está disponível nesta fase, use a Calculadora combinando os valores com o Orbe de 50.000 (int) para que a conta caiba nos 6 bytes da Mochila!"
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
			"[b]Alinhamento do Aprendizado[/b]\n"
			"Diferenciar o erro de Truncamento (decepar uma fração ativa ao converter para inteiro) de uma conversão limpa feita após eliminar a parte fracionária pela soma.\n\n"
			"[b]Nova Mecânica[/b]\n"
			"Combinação estratégica de soma de frações (float + float) seguida de redução para inteiro (short int).\n\n"
			"[b]Texto de Guia para o Aluno[/b]\n"
			"Quando você joga um número com vírgula (como 4.5 ou 3.5) direto no Conversor para um tipo inteiro (short int), o computador não arredonda o valor: ele faz um Truncamento, cortando a parte .5 a frio e tirando suas estrelas de precisão!\n\n"
			"[b]Seu Objetivo:[/b] Você precisa guardar na Mochila de 6 bytes o valor 2.25 e a soma de 4.5 + 3.5.\n\n"
			"[b]Dica de Estratégia:[/b] Em vez de converter os números antes da hora, use a Calculadora primeiro para somar 4.5 + 3.5. Quando o resultado virar um número redondo terminado em .0, veja como o Conversor permite transformá-lo em um inteiro pequeno de 2 bytes sem perder nenhum valor!"
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
			"[b]Alinhamento do Aprendizado[/b]\n"
			"Conhecer a norma IEEE 754 (Sinal, Expoente e Mantissa) e descobrir que o tipo float (4 bytes), apesar de alcançar números na casa dos bilhões, possui apenas 23 bits de mantissa e perde precisão em números ímpares acima de 16.777.216 (2^24).\n\n"
			"[b]Nova Mecânica — Inspeção de Mantissa IEEE 754[/b]\n"
			"Identificação de arredondamento forçado ao converter double para float.\n\n"
			"[b]Texto de Guia para o Aluno[/b]\n"
			"Muita gente acha que o float (4 bytes) só serve para números pequenos e o double (8 bytes) para números gigantes. Na verdade, o float alcança bilhões, mas tem um ponto fraco escondido: seus 23 bits de Mantissa só conseguem guardar cerca de 7 dígitos com precisão exata!\n\n"
			"[b]Seu Objetivo:[/b] Você tem dois Orbes double (8 bytes cada) na bancada (16.777.219.0 e 1.024.5), somando 16 bytes para uma Mochila de 12 bytes. Apenas um deles precisa ser reduzido para float (4 bytes).\n\n"
			"[b]O que observar:[/b] Teste converter o 16.777.219.0 para float e abra o Inspecionador. Veja como os 23 bits da mantissa esgotam sua capacidade e mudam o final do seu número para 16.777.220.0 sozinho! Descubra qual dos dois Orbes pode encolher sem sofrer distorção."
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
			"[b]Alinhamento do Aprendizado[/b]\n"
			"Compreender o trade-off (compromisso) entre economia de memória e precisão usando o formato FP16 (2 bytes), diferenciando o arredondamento leve da mantissa (10 bits) do estouro do expoente (5 bits) para Infinito (Inf).\n\n"
			"[b]Nova Mecânica — Tipo FP16 e Margem de Tolerância[/b]\n"
			"Liberação do tipo amarelo fp16 no Conversor e introdução de tolerância de arredondamento (0.1%) na Mochila.\n\n"
			"[b]Texto de Guia para o Aluno[/b]\n"
			"Em placas de vídeo e sensores, muitas vezes vale a pena aceitar um pequeníssimo arredondamento nas últimas casas decimais para gastar metade da memória RAM.\n\n"
			"[b]Novo Tipo Liberado — FP16 (2 bytes):[/b] O Orbe amarelo FP16 ocupa metade do espaço de um float, dividindo seus bits em apenas 5 bits de Expoente (alcance máximo de 65.504) e 10 bits de Mantissa (precisão).\n\n"
			"[b]Seu Objetivo:[/b] Comprima dois dos três Orbes float da bancada (3.1415926, 2.7182818 e 500.000.0) para caberem nos 8 bytes da Mochila. Veja que a Mochila aceita o pequeno arredondamento nas últimas casas de Pi e Euler (dentro da tolerância de 0.1%), mas observe o que acontece com o Expoente se você tentar colocar 500.000.0 em um fp16!"
		),
		mochila(
			8,
			"3.1415926_f, 2.7182818_f, 500000.0_f",
			allow_float=True,
			allow_fp16=True,
			error_tol=0.001,
			star3="3.1415926_fp16, 2.7182818_fp16, 500000.0_f",
		),
	),
	(
		"O Abismo do Underflow",
		(
			"[b]Alinhamento do Aprendizado[/b]\n"
			"Conhecer o extremo da compactação com o FP8 (1 byte) e experimentar o fenômeno do Underflow — quando um número muito próximo de zero não alcança o expoente mínimo do tipo e colapsa para 0.0.\n\n"
			"[b]Nova Mecânica — Tipo FP8 e Proibição de Zerar[/b]\n"
			"Liberação do tipo branco fp8 (1 byte) e regra de falha caso um Orbe sofra Underflow para zero.\n\n"
			"[b]Texto de Guia para o Aluno[/b]\n"
			"Você já viu números explodirem por serem grandes demais (Overflow). Agora vai conhecer o perigo oposto: o Underflow, que acontece quando uma fração é tão pequenininha e próxima de zero que o tipo de dado não consegue enxergá-la e apaga seu valor para 0.0!\n\n"
			"[b]Novo Tipo Liberado — FP8 (1 byte):[/b] O Orbe branco FP8 consome apenas 1 único byte de memória, mas possui apenas 4 bits de expoente e 3 bits de mantissa.\n\n"
			"[b]Seu Objetivo:[/b] Você tem 4 Orbes em fp16 (1.5, 2.25, 0.5 e 0.00008) e uma Mochila minúscula de 5 bytes. Use o Conversor para reduzir o que for seguro para fp8, mas atenção à regra da fase: é proibido deixar qualquer Orbe colapsar para 0.0!"
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
			"[b]Alinhamento do Aprendizado[/b]\n"
			"Aplicar a técnica de quantização de dados (usada em modelos de Inteligência Artificial) analisando a representação binária de um lote de números para escolher entre fp8, fp16 e short int.\n\n"
			"[b]Nova Mecânica[/b]\n"
			"Triagem simultânea de dízimas binárias, frações exatas de base 2 e inteiros em ponto flutuante.\n\n"
			"[b]Texto de Guia para o Aluno[/b]\n"
			"Hora de pensar como um engenheiro otimizando um modelo de Inteligência Artificial! Na bancada existem 5 Orbes do tipo float que pesam 20 bytes no total (1.25, 3.5, 3.33333, 120.0 e 1000.0), mas sua Mochila só tem 7 bytes!\n\n"
			"[b]Dica de Inspecionador:[/b] Nem todo número com vírgula se comporta igual em binário:\n"
			"- Frações como .25 e .5 são potências exatas de base 2 e cabem em FP8 (1 byte) sem perder nada!\n"
			"- Dízimas como 3.33333 se deformam inteiras nos 3 bits do fp8 e pedem o cuidado do FP16 (2 bytes).\n"
			"- E cuidado com o 1000.0: ele passa do limite máximo do fp8 (448), mas será que ele precisa mesmo de ponto flutuante?"
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
			"[b]Alinhamento do Aprendizado[/b]\n"
			"Consolidar todo o domínio sobre memória RAM evitando simultaneamente Overflow aritmético, Underflow e a Absorção de Mantissa.\n\n"
			"[b]Nova Mecânica — Absorção de Mantissa na Calculadora[/b]\n"
			"Quando um número pequeno (1.0) é somado a um número muito grande (16.777.216.0) em float e desaparece por falta de bits na mantissa.\n\n"
			"[b]Texto de Guia para o Aluno[/b]\n"
			"Chegou o desafio final da Mochila com o seu Arsenal Completo liberado! Você tem 6 Orbes na bancada e precisa entregar 4 resultados finais ocupando exatamente os 15 bytes da Mochila:\n\n"
			"1. A soma de 30.000 + 10.000: Cuidado para não estourar o limite do short na Calculadora!\n"
			"2. A soma de 16.777.216.0 + 1.0: Experimente somar os dois direto como float e veja um fenômeno novo — a Absorção de Mantissa (o + 1.0 é completamente engolido porque os 23 bits do float não alcançam essa diferença!). Promova-os antes de somar!\n"
			"3. O valor 0.0005 comprimido: Reduza o tamanho dele sem deixá-lo sofrer Underflow para 0.0.\n"
			"4. O valor 1.5 na menor fôrma possível: Economize cada byte para fechar a conta em 15 bytes cravados!"
		),
		mochila(
			15,
			"30000_s, 10000_s, 16777216.0_f, 1.0_f, 0.0005_d, 1.5_d",
			allow_float=True,
			allow_double=True,
			allow_short=True,
			allow_fp8=True,
			allow_fp16=True,
			allow_calc=True,
			calc_max_uses=2,
			forbid_underflow=True,
			required="40000,16777217,0.0005,1.5",
			pool_slots=14,
		),
	),
	(
		"Primeira Declaração",
		(
			"[b]Alinhamento do Aprendizado[/b]\n"
			"Simular a declaração de variáveis do zero: analisar valores brutos e escolher seus tipos pensando antecipadamente no limite da memória RAM.\n\n"
			"[b]Nova Mecânica — Modalidade Híbrida e Estações de Tipagem[/b]\n"
			"Os Orbes nascem brutos e cinzas (RAW, sem tipo) e devem passar pelas Estações de Tipagem no centro da tela antes de irem para a Mochila.\n\n"
			"[b]Texto de Guia para o Aluno[/b]\n"
			"Bem-vindo às Fases Híbridas! Aqui você vai agir exatamente como um programador declarando variáveis no código.\n\n"
			"[b]Nova Mecânica — Estações de Tipagem + Mochila:[/b] Repare que os 4 Orbes na bancada (15, -300, 4.5 e 0.5) nasceram brutos (cinzas e sem tipo), mas o destino final deles é uma Mochila de 10 bytes!\n\n"
			"[b]Como jogar:[/b] Para guardar um Orbe bruto na Mochila, você precisa primeiro arrastá-lo até uma das Estações de Tipagem no centro da tela (short int, int, fp16, float ou double) para batizá-lo com um tipo e uma cor. Se você escolher tipos grandes demais sem necessidade (como declarar 15 e -300 como int de 4 bytes), os Orbes vão somar 16 bytes e travar sua Mochila de 10 bytes!"
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
			"[b]Alinhamento do Aprendizado[/b]\n"
			"Realizar o projeto completo de alocação de memória de um sistema, escolhendo 5 tipos diferentes da computação para 5 dados brutos com desperdício zero de RAM.\n\n"
			"[b]Nova Mecânica[/b]\n"
			"Todas as 6 Estações de Tipagem abertas simultaneamente com bloqueio imediato de Overflow, Underflow e perda de precisão.\n\n"
			"[b]Texto de Guia para o Aluno[/b]\n"
			"Este é o seu teste de formatura como Arquiteto de Sistema! Na bancada estão 5 valores brutos de naturezas totalmente diferentes (12, -40.000, 0.25, 0.00008 e 3.1415926), e você tem apenas 13 bytes na Mochila.\n\n"
			"[b]O Desafio:[/b] Todas as 6 Estações de Tipagem estão abertas (short int, int, fp8, fp16, float e double), mas elas bloqueiam qualquer escolha que cause estouro, zeramento ou perda de precisão:\n"
			"- Qual dos dois inteiros cabe em 2 bytes (short) e qual passa do limite de -32.768, exigindo 4 bytes (int)?\n"
			"- Qual decimal é simples o bastante para morar em 1 byte (fp8), qual precisa de fp16 (2 bytes) para não virar zero e qual exige os 23 bits de mantissa de um float (4 bytes)?\n\n"
			"Encontre o tipo ideal de cada número e feche os 13 bytes com perfeição!"
		),
		raw(
			13,
			["12", "-40000", "0.25", "0.00008", "3.1415926"],
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
