import re

class GeradorCodigoPython:
    def __init__(self):
        self.operadores = {
            '+': 'soma',
            '-': 'subtração',
            '*': 'multiplicação',
            '/': 'divisão',
            '//': 'divisão_inteira',
            '%': 'módulo',
            '**': 'potência',
            '==': 'igual',
            '!=': 'diferente',
            '>': 'maior',
            '<': 'menor',
            '>=': 'maior_igual',
            '<=': 'menor_igual',
            'and': 'e_lógico',
            'or': 'ou_lógico',
            'not': 'não_lógico'
        }

    def detectar_tipo(self, valor: str):
        """Detecta o tipo do valor e retorna tipo e valor convertido"""
        valor = valor.strip()
        if '.' in valor and valor.replace('.', '').replace('-', '').isdigit():
            return 'float', float(valor)
        if valor.replace('-', '').isdigit():
            return 'int', int(valor)
        return 'str', valor

    def gerar_codigo(self, expressao: str, incluir_texto=False):
        """Gera código Python com múltiplos valores"""
        tokens = re.findall(r"[A-Za-z0-9_.]+|[+\-*/%]|//|\*\*|and|or|not|==|!=|>=|<=|>|<", expressao, flags=re.IGNORECASE)

        valores = []
        variaveis = []
        expr_final = ""

        # Substitui valores literais por variáveis dinamicamente
        var_index = 1
        for t in tokens:
            if re.fullmatch(r"[+\-*/%]|//|\*\*|and|or|not|==|!=|>=|<=|>|<", t, flags=re.IGNORECASE):
                expr_final += f" {t} "
            else:
                tipo, val = self.detectar_tipo(t)
                nome_var = f"valor{var_index}"
                var_index += 1
                variaveis.append((nome_var, tipo, val))
                expr_final += f" {nome_var} "

        # Monta linhas de código
        codigo_linhas = ["# Código gerado automaticamente\n"]
        for nome_var, tipo, val in variaveis:
            if tipo == "str":
                codigo_linhas.append(f'{nome_var}: {tipo} = "{val}"')
            else:
                codigo_linhas.append(f"{nome_var}: {tipo} = {val}")

        codigo_linhas.append(f"\nresultado = {expr_final.strip()}")

        if incluir_texto and len(variaveis) >= 2:
            operandos_str = " e ".join([f"{{{v[0]}}}" for v in variaveis])
            codigo_linhas.append(f'print(f"O resultado da expressão com {operandos_str} é {{resultado}}")')
        else:
            codigo_linhas.append("print(resultado)")

        return "\n".join(codigo_linhas)

    def executar_codigo(self, codigo: str):
        """Executa o código gerado"""
        try:
            namespace = {}
            exec(codigo, namespace)
        except Exception as e:
            print(f"Erro ao executar código: {e}")

def main():
    gerador = GeradorCodigoPython()
    print("=== GERADOR DE CÓDIGO PYTHON (multi valores) ===")
    while True:
        expressao = input("Digite a expressão (ou 'sair' para terminar): ").strip()
        if expressao.lower() == 'sair':
            break
        incluir_texto = input("Incluir texto descritivo? (s/n): ").lower() == 's'
        codigo = gerador.gerar_codigo(expressao, incluir_texto)
        print("\n--- CÓDIGO GERADO ---")
        print(codigo)
        print("--- FIM DO CÓDIGO ---\n")

        print("--- RESULTADO DA EXECUÇÃO ---")
        gerador.executar_codigo(codigo)
        print("--- FIM DA EXECUÇÃO ---\n")

        salvar = input("Salvar em arquivo? (s/n): ").lower() == 's'
        if salvar:
            nome = input("Nome do arquivo (Enter para 'codigo_gerado.py'): ").strip() or "codigo_gerado.py"
            with open(nome, 'w', encoding='utf-8') as f:
                f.write(codigo)
            print(f"Arquivo '{nome}' criado com sucesso!")
        print("-" * 50)

if __name__ == "__main__":
    main()
