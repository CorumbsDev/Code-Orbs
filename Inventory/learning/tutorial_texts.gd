class_name TutorialTexts
## Textos do onboarding. Constantes = chaves em user:// (learning_prefs).

const KEY_PHASE_BINARY := "phase_binary_v1"
const KEY_PHASE_BACKPACK := "phase_backpack_v1"
const KEY_PHASE_CONVERSION := "phase_conversion_v1"
const KEY_GLOSSARY := "glossary_v1"
const KEY_RAW_KNAPSACK := "raw_knapsack_phase_intro"
const KEY_TYPE_BOX := "type_box_phase_intro"


static func title_for(key: String) -> String:
	# Sem "Fase N —": o número vem da posição na sequência (PhaseRunner).
	match key:
		KEY_PHASE_BINARY:
			return "Binário"
		KEY_PHASE_BACKPACK:
			return "Mochila (bytes)"
		KEY_PHASE_CONVERSION:
			return "Decimal → binário"
		KEY_GLOSSARY:
			return "Glossário rápido"
		KEY_RAW_KNAPSACK:
			return "Mochila + Tipagem (RAW)"
		KEY_TYPE_BOX:
			return "Caixas de Tipagem"
		_:
			return "Ajuda"


static func body_for(key: String) -> String:
	match key:
		KEY_PHASE_BINARY:
			return (
				"[b]Objetivo:[/b] complete o número binário arrastando um bit (0 ou 1) para o espaço central.\n\n"
				+ "[b]Bit:[/b] dígito em base 2 (0 ou 1).\n\n"
				+ "[b]Como jogar:[/b] use a ação [b]select_item[/b] (mouse) para pegar um orb, arraste e solte no slot vazio. "
				+ "Ao soltar, o jogo mostra o valor em decimal e uma linha explicando a conversão posição a posição.\n\n"
				+ "Você pode trocar o bit e ver o resultado de novo."
			)
		KEY_PHASE_BACKPACK:
			return (
				"[b]Objetivo:[/b] encher a [b]mochila do desafio[/b] até o limite de [b]bytes[/b].\n\n"
				+ "[b]Modelo de pesos:[/b] 1 “palavra” = [b]4 bytes[/b]. "
				+ "Assim: [b]1 INT = 4[/b], [b]1 FLOAT = 4[/b], [b]1 DOUBLE = 8[/b] (ocupa 2 palavras), [b]1 FP8 = 1[/b] (cabem 4 FP8 numa palavra).\n\n"
				+ "[b]Pool:[/b] área com itens para arrastar para a mochila.\n\n"
				+ "[b]Como jogar:[/b] clique em um INT do pool e arraste para um slot vazio da mochila.\n\n"
				+ "[b]Cheio:[/b] quando a soma dos bytes na mochila atinge exatamente o máximo."
			)
		KEY_PHASE_CONVERSION:
			return (
				"[b]Objetivo:[/b] representar o decimal indicado em [b]3 bits[/b] (esquerda = bit mais significativo).\n\n"
				+ "[b]Como jogar:[/b] arraste 0 ou 1 do pool para os três slots. "
				+ "Quando estiverem preenchidos, o jogo confere o valor e mostra a soma 2²+2¹+2⁰."
			)
		KEY_GLOSSARY:
			return "Use o botão Glossário no menu principal para ver definições dos termos usados no projeto."
		KEY_RAW_KNAPSACK:
			return (
				"[b]Objetivo:[/b] encher a mochila até o limite de bytes, mas os valores chegam [b]sem tipo (RAW)[/b].\n\n"
				+ "[b]1)[/b] Pegue um valor do pool (cinza, sem tipo).\n"
				+ "[b]2)[/b] Solte numa [b]estação de tipagem[/b] (Int, Float, etc.). Se o valor não couber no tipo, a conversão falha.\n"
				+ "[b]3)[/b] Arraste o orbe tipado para a mochila. Cada tipo ocupa bytes diferentes.\n\n"
				+ "RAW não pode ir direto para a mochila — é o desafio extra desta fase."
			)
		KEY_TYPE_BOX:
			return (
				"[b]Objetivo:[/b] usar todos os orbes da bancada, posicionando e tipando cada um nas [b]caixas de tipagem[/b] correspondentes.\n\n"
				+ "[b]1)[/b] Arraste cada orbe da bancada para uma das caixas: [b]Int[/b], [b]Short[/b], [b]Float[/b], [b]Double[/b], etc.\n"
				+ "[b]2)[/b] Cada caixa representa um tipo de dado — escolha o tipo compatível com o valor.\n"
				+ "[b]3)[/b] A fase é concluída quando todos os orbes da bancada forem posicionados nas caixas!"
			)
		_:
			return ""
