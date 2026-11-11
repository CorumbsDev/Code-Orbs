extends AcceptDialog

## Diálogo de compartilhamento por QR (tudo 100% dentro do jogo).
## No modo Importar: abre a câmera nativamente dentro do jogo (se disponível) e possui o botão «Colar Código» (Ctrl+C).

@onready var qr_image: TextureRect = %QrImage
@onready var status_label: Label = %StatusLabel
@onready var payload_edit: TextEdit = %PayloadEdit
@onready var btn_paste: Button = get_node_or_null("%BtnPastePayload")
@onready var btn_copy: Button = %BtnCopyPayload
@onready var btn_import: Button = %BtnImportPayload

signal import_requested(csv_text: String)

var _payload: String = ""
var _mode: String = "export"
var _camera_active: bool = false
var _poll_accum: float = 0.0
var _active_feed: CameraFeed = null


func _ready() -> void:
	ok_button_text = "Fechar"
	if btn_paste:
		btn_paste.icon = UiIcons.get_icon("paste")
		if not btn_paste.pressed.is_connected(_on_paste_pressed):
			btn_paste.pressed.connect(_on_paste_pressed)
	if btn_copy:
		btn_copy.icon = UiIcons.get_icon("copy")
		if not btn_copy.pressed.is_connected(_on_copy_pressed):
			btn_copy.pressed.connect(_on_copy_pressed)
	if btn_import:
		btn_import.icon = UiIcons.get_icon("play")
		if not btn_import.pressed.is_connected(_on_import_pressed):
			btn_import.pressed.connect(_on_import_pressed)
	if not visibility_changed.is_connected(_on_visibility_changed):
		visibility_changed.connect(_on_visibility_changed)
	set_process(false)


func setup_export(payload: String, texture: ImageTexture, info: String = "") -> void:
	_stop_camera()
	_mode = "export"
	_payload = payload
	title = "QR da Sequência"
	size = Vector2i(600, 560)
	if qr_image:
		qr_image.custom_minimum_size = Vector2(280, 280)
		qr_image.texture = texture
		qr_image.visible = true
	if payload_edit:
		payload_edit.text = payload
		payload_edit.editable = false
		payload_edit.custom_minimum_size = Vector2(0, 80)
	if status_label:
		status_label.text = info if not info.is_empty() else "Aponte a câmera do celular ou use Copiar payload."
	if btn_paste:
		btn_paste.visible = false
	if btn_import:
		btn_import.visible = false
	if btn_copy:
		btn_copy.visible = true


func setup_import() -> void:
	_stop_camera()
	_mode = "import"
	_payload = ""
	title = "Importar via QR Code"
	size = Vector2i(560, 420)
	if qr_image:
		qr_image.custom_minimum_size = Vector2(240, 180)
		qr_image.texture = null
		qr_image.visible = false
	if payload_edit:
		payload_edit.text = ""
		payload_edit.editable = true
		payload_edit.custom_minimum_size = Vector2(0, 140)
		payload_edit.placeholder_text = "Clique em «Colar Código» para colar o código do Ctrl+C (COB1:...)"
	if status_label:
		status_label.text = "Clique em «Colar Código» para pegar o código copiado (Ctrl+C) e depois em «Importar»."
	if btn_paste:
		btn_paste.visible = true
	if btn_import:
		btn_import.visible = true
	if btn_copy:
		btn_copy.visible = false
	call_deferred("_try_start_in_game_camera")


func _on_visibility_changed() -> void:
	if not visible:
		_stop_camera()


func _try_start_in_game_camera() -> void:
	if _mode != "import" or not visible:
		return

	# 1) Na Web, tenta abrir a câmera dentro do próprio canvas do jogo (sem abrir outra janela).
	# Se não houver câmera ou permissão, qr_image permanece oculto.
	if OS.has_feature("web"):
		_start_web_in_game_camera()
		return

	# 2) No Desktop/Mobile nativo, verifica se há CameraFeed nativo suportado pela Godot.
	# Se não houver câmera nativa disponível, não abre nada e mantém apenas o campo + botão Colar Código.
	if "monitoring_feeds" in CameraServer:
		CameraServer.set("monitoring_feeds", true)
	if CameraServer.get_feed_count() > 0:
		_active_feed = CameraServer.get_feed(0)
		if _active_feed != null:
			_active_feed.feed_is_active = true
			var cam_tex := CameraTexture.new()
			cam_tex.camera_feed_id = _active_feed.get_id()
			cam_tex.camera_is_active = true
			if qr_image:
				qr_image.texture = cam_tex
				qr_image.visible = true
			size = Vector2i(560, 520)
			_camera_active = true
			if status_label:
				status_label.text = "Aponte o QR Code para a câmera ou clique em «Colar Código» (Ctrl+C)."


func _start_web_in_game_camera() -> void:
	var js := """
	(function() {
		window._codeOrbsQrState = window._codeOrbsQrState || {
			active: false,
			result: "",
			error: "",
			frameB64: "",
			video: null,
			canvas: null,
			ctx: null,
			stream: null,
			timer: null
		};
		var st = window._codeOrbsQrState;
		st.result = "";
		st.error = "";
		st.frameB64 = "";

		if (!navigator.mediaDevices || !navigator.mediaDevices.getUserMedia) {
			st.error = "no_camera";
			st.active = false;
			return;
		}

		if (!window.jsQR && !window._jsQrLoading) {
			window._jsQrLoading = true;
			var s = document.createElement('script');
			s.src = 'https://cdn.jsdelivr.net/npm/jsqr@1.4.0/dist/jsQR.min.js';
			document.head.appendChild(s);
		}

		navigator.mediaDevices.getUserMedia({
			video: { facingMode: { ideal: "environment" }, width: { ideal: 320 }, height: { ideal: 240 } },
			audio: false
		}).then(function(stream) {
			st.stream = stream;
			var v = document.createElement('video');
			v.setAttribute('playsinline', 'true');
			v.muted = true;
			v.srcObject = stream;
			v.play();
			st.video = v;
			var c = document.createElement('canvas');
			c.width = 240;
			c.height = 180;
			st.canvas = c;
			st.ctx = c.getContext('2d', { willReadFrequently: true });
			st.active = true;

			var detector = null;
			if ('BarcodeDetector' in window) {
				try { detector = new BarcodeDetector({ formats: ['qr_code'] }); } catch (e) {}
			}

			if (st.timer) clearInterval(st.timer);
			st.timer = setInterval(function() {
				if (!st.active || !st.video || st.video.readyState < 2) return;
				st.ctx.drawImage(st.video, 0, 0, st.canvas.width, st.canvas.height);
				try {
					var dataUrl = st.canvas.toDataURL('image/jpeg', 0.6);
					var comma = dataUrl.indexOf(',');
					if (comma > 0) st.frameB64 = dataUrl.substring(comma + 1);
				} catch (e) {}

				if (window.jsQR) {
					try {
						var imgData = st.ctx.getImageData(0, 0, st.canvas.width, st.canvas.height);
						var code = window.jsQR(imgData.data, imgData.width, imgData.height);
						if (code && code.data) {
							st.result = code.data;
							return;
						}
					} catch (e) {}
				}
				if (detector) {
					detector.detect(st.canvas).then(function(barcodes) {
						if (barcodes && barcodes.length > 0 && barcodes[0].rawValue) {
							st.result = barcodes[0].rawValue;
						}
					}).catch(function() {});
				}
			}, 140);
		}).catch(function() {
			st.error = "no_camera";
			st.active = false;
		});
	})();
	"""
	JavaScriptBridge.eval(js, true)
	_camera_active = true
	_poll_accum = 0.0
	set_process(true)


func _stop_camera() -> void:
	_camera_active = false
	set_process(false)
	if _active_feed != null:
		_active_feed.feed_is_active = false
		_active_feed = null
	if qr_image and _mode == "import":
		qr_image.texture = null
		qr_image.visible = false
	if OS.has_feature("web"):
		var js_stop := """
		(function() {
			var st = window._codeOrbsQrState;
			if (!st) return;
			st.active = false;
			if (st.timer) { clearInterval(st.timer); st.timer = null; }
			if (st.stream) {
				try { st.stream.getTracks().forEach(function(t) { t.stop(); }); } catch (e) {}
				st.stream = null;
			}
			if (st.video) {
				try { st.video.pause(); st.video.srcObject = null; } catch (e) {}
				st.video = null;
			}
		})();
		"""
		JavaScriptBridge.eval(js_stop, true)


func _process(delta: float) -> void:
	if not visible or _mode != "import":
		set_process(false)
		return
	_poll_accum += delta
	if _poll_accum < 0.14:
		return
	_poll_accum = 0.0

	if OS.has_feature("web") and _camera_active:
		var err_str: String = str(JavaScriptBridge.eval("(window._codeOrbsQrState && window._codeOrbsQrState.error) || ''", true))
		if not err_str.is_empty():
			_stop_camera()
			return

		var b64_frame: String = str(JavaScriptBridge.eval("(window._codeOrbsQrState && window._codeOrbsQrState.frameB64) || ''", true))
		if not b64_frame.is_empty() and qr_image:
			var raw_jpg: PackedByteArray = Marshalls.base64_to_raw(b64_frame)
			if not raw_jpg.is_empty():
				var img := Image.new()
				if img.load_jpg_from_buffer(raw_jpg) == OK:
					if not qr_image.visible:
						qr_image.visible = true
						size = Vector2i(560, 520)
						if status_label:
							status_label.text = "Aponte a câmera para o QR Code ou clique em «Colar Código» (Ctrl+C)."
					qr_image.texture = ImageTexture.create_from_image(img)

		var scanned: String = str(JavaScriptBridge.eval("(window._codeOrbsQrState && window._codeOrbsQrState.result) || ''", true)).strip_edges()
		if not scanned.is_empty():
			JavaScriptBridge.eval("if (window._codeOrbsQrState) window._codeOrbsQrState.result = '';", true)
			_on_qr_code_detected(scanned)


func _on_qr_code_detected(scanned_text: String) -> void:
	_stop_camera()
	if payload_edit:
		payload_edit.text = scanned_text
	var decoded: Dictionary = SequenceQrCodec.decode_payload(scanned_text)
	if decoded.get("ok", false):
		import_requested.emit(str(decoded.get("csv", "")))
		hide()
	else:
		if status_label:
			status_label.text = "QR lido, mas formato inválido: " + str(decoded.get("error", "?"))


func _on_paste_pressed() -> void:
	var clip: String = DisplayServer.clipboard_get().strip_edges()
	if clip.is_empty():
		if status_label:
			status_label.text = "Nada encontrado no Ctrl+C (área de transferência vazia)."
		return
	if payload_edit:
		payload_edit.text = clip
	if status_label:
		status_label.text = "Código colado do Ctrl+C! Clique em «Importar» para concluir."


func _on_copy_pressed() -> void:
	var t: String = _payload if not _payload.is_empty() else (payload_edit.text if payload_edit else "")
	if t.strip_edges().is_empty():
		if status_label:
			status_label.text = "Nada para copiar."
		return
	DisplayServer.clipboard_set(t)
	if status_label:
		status_label.text = "Payload copiado (Ctrl+C). Use «Colar Código» no outro jogo."


func _on_import_pressed() -> void:
	var raw: String = payload_edit.text if payload_edit else ""
	var decoded: Dictionary = SequenceQrCodec.decode_payload(raw)
	if not decoded.get("ok", false):
		if status_label:
			status_label.text = "Erro: " + str(decoded.get("error", "?"))
		return
	_stop_camera()
	import_requested.emit(str(decoded.get("csv", "")))
	hide()
