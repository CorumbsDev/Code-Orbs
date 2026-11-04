class_name VerScriptButton
extends Object
## Oculta `TopBar/BtnVerScript` durante as fases (o código agora só é liberado
## ao terminar todas as fases, na tela de Coleção de Estrelas).

const BTN_NAME := "BtnVerScript"


static func ensure_on(root: Node) -> void:
	if root == null or not is_instance_valid(root):
		return
	var top := root.get_node_or_null("TopBar")
	if top == null:
		return
	var btn := top.get_node_or_null(BTN_NAME) as Button
	if btn != null:
		btn.visible = false
