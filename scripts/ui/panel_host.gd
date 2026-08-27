extends PanelContainer
class_name PanelHost
## PanelHost — the unified content dispatcher shared by all four UI
## panels (right primary sidebar, left detail sidebar, left popout,
## right popout), replacing the three near-duplicate scripts that used
## to do this job (detail_sidebar.gd, slideout_panel.gd,
## right_slideout_panel.gd) with one that any panel can be an instance
## of just by configuring the @exports.
##
## Two modes:
## - EPHEMERAL — one view at a time, instantiated from view_registry on
##   show(id, data), freed on dismiss/replace. Used by the two popouts
##   and the left detail sidebar.
## - TABS — every registered view lives permanently as a child of an
##   internal TabContainer, only one visible at a time; set_active_tab
##   (id) just switches which. Used by the right primary sidebar.
##
## Slide animation and cross-panel positioning are NOT owned here —
## root_ui.gd continues to coordinate that, since popouts track the
## sidebar next to them and sidebars anchor to the screen edge. What
## this script owns is which view is active and its lifecycle; the
## caller just does visible = true/false (or connects a toggle button)
## and this handles the content dispatch.

enum Mode { EPHEMERAL, TABS }

## EPHEMERAL keeps one dynamically-instantiated view; TABS uses a
## pre-authored TabContainer child. Set in the editor per instance.
@export var mode: Mode = Mode.EPHEMERAL

## EPHEMERAL only. id → PackedScene or Script. show(id) instantiates the
## registered resource (or .new()'s a Script) as the sole current view.
## Kept as Dictionary rather than typed so both resource kinds can live
## in one registry — Phase 2 will move views to .tscn but today most
## are still script-only.
@export var view_registry: Dictionary = {}

## EPHEMERAL only. View id mounted at _ready(). "" means empty by
## default. The default view stays present (silently re-mounted) after
## dismiss(), so an "empty state" hint reappears rather than the panel
## going blank.
@export var default_view_id: String = ""

## TABS only. Ordered list of tab ids, one per TabContainer child in
## the same order as the children. set_active_tab resolves through this.
@export var tab_ids: PackedStringArray = PackedStringArray()

## If set, this host assigns itself to Game.<register_as> in its own
## _enter_tree(), so it's available before sibling nodes that reference
## it in _ready() (detail_sidebar clearing left_popout on startup, etc.).
## Empty means don't self-register — root_ui.gd or the caller can grab a
## reference some other way.
@export var register_as: StringName = ""

## Whether dismiss() also hides the panel (visible=false). Popouts hide
## themselves entirely on dismiss (default true); the detail sidebar,
## which stays visible while the game is running and only ever swaps
## which view is mounted, sets this false so its "Close" button routes
## back to the default (empty) view without collapsing the whole panel.
@export var hide_on_dismiss: bool = true

signal view_changed(view_id: String)

var _content: Control  # VBoxContainer mount for EPHEMERAL; unused for TABS
var _tab_container: TabContainer  # TABS mode's existing scene node
var _current_view_id: String = ""
var _current_view_data: Variant = null
var _current_view: Control = null


func _enter_tree() -> void:
	if register_as != "":
		Game.set(register_as, self)


func _ready() -> void:
	_build_content_structure()
	if mode == Mode.EPHEMERAL and default_view_id != "":
		_mount_default_silently()


## For EPHEMERAL: finds (or builds) a ScrollContainer > VBoxContainer
## as the view mount. For TABS: locates the pre-authored TabContainer.
## Either way, guarantees _content or _tab_container is valid before
## any show() / set_active_tab() call.
func _build_content_structure() -> void:
	if mode == Mode.TABS:
		_tab_container = _find_child_of_type(self, TabContainer)
		if _tab_container == null:
			push_error("PanelHost (TABS mode) needs a TabContainer child in the scene.")
		return

	var scroll: ScrollContainer = _find_child_of_type(self, ScrollContainer)
	if scroll == null:
		scroll = ScrollContainer.new()
		scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
		add_child(scroll)

	var vbox: VBoxContainer = _find_child_of_type(scroll, VBoxContainer)
	if vbox == null:
		vbox = VBoxContainer.new()
		vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		vbox.add_theme_constant_override("separation", 8)
		scroll.add_child(vbox)

	_content = vbox


static func _find_child_of_type(parent: Node, type: Variant) -> Node:
	for child in parent.get_children():
		if is_instance_of(child, type):
			return child
	return null


# --- EPHEMERAL: show / dismiss / toggle ----------------------------------

## Instantiates the view registered under view_id and mounts it as the
## sole content, replacing whatever was there. Data is untyped Variant
## — a single object (AgentData/EventData/etc.) or a Dictionary bundling
## multiple args; view.populate() unpacks whichever shape it expects.
## Always sets visible=true so a caller can just call show_view() without
## also toggling visibility. (Method is named show_view rather than the
## nicer bare `show` because Control.show is a native method we'd
## silently shadow — Godot treats that as an error.)
func show_view(view_id: String, data: Variant = null) -> void:
	if mode != Mode.EPHEMERAL:
		push_error("PanelHost.show_view() is EPHEMERAL only; use set_active_tab() for TABS mode.")
		return
	if not view_registry.has(view_id):
		push_error("PanelHost.show_view(): no view registered for id '%s'" % view_id)
		return

	_mount_view(view_id, data)
	visible = true
	view_changed.emit(view_id)


## Click-same-thing-again-to-close: if the same (view_id, data) is
## already showing, dismiss; otherwise show. Data equality uses hash()
## so callers can pass fresh Dictionaries with the same contents rather
## than needing to hold a reference to the exact same object.
func toggle_showing(view_id: String, data: Variant = null) -> void:
	if is_showing(view_id, data):
		dismiss()
	else:
		show_view(view_id, data)


func is_showing(view_id: String, data: Variant = null) -> bool:
	if not visible or _current_view_id != view_id:
		return false
	return hash(data) == hash(_current_view_data)


## Hides the panel and re-mounts the default view (if one is configured)
## silently underneath, so the next open() call already has the empty-
## state hint visible without the caller having to re-show it.
func dismiss() -> void:
	if mode != Mode.EPHEMERAL:
		return
	if hide_on_dismiss:
		visible = false
	if default_view_id != "":
		_mount_default_silently()
	else:
		_clear_content()


func get_current_view_id() -> String:
	return _current_view_id


func get_current_view_data() -> Variant:
	return _current_view_data


## Re-mounts the current view with the same data. Called by external
## coordinators (root_ui.gd) when a manager signal indicates the view's
## backing data has changed and its rendered content is now stale.
## No-op if nothing is mounted, or if in TABS mode.
func refresh() -> void:
	if mode != Mode.EPHEMERAL or _current_view_id == "":
		return
	_mount_view(_current_view_id, _current_view_data)


func _mount_view(view_id: String, data: Variant) -> void:
	_clear_content()
	_current_view_id = view_id
	_current_view_data = data
	_current_view = _instantiate_view(view_registry[view_id])
	if _current_view == null:
		return
	_content.add_child(_current_view)
	if _current_view.has_method("populate"):
		_current_view.populate(data, dismiss)


func _mount_default_silently() -> void:
	_mount_view(default_view_id, null)


func _clear_content() -> void:
	if _content == null:
		return
	for child in _content.get_children():
		child.queue_free()
	_current_view = null
	_current_view_id = ""
	_current_view_data = null


static func _instantiate_view(resource: Variant) -> Control:
	if resource is PackedScene:
		return (resource as PackedScene).instantiate()
	if resource is Script:
		return (resource as Script).new()
	push_error("PanelHost: registered view must be a PackedScene or Script, got %s" % typeof(resource))
	return null


# --- TABS: set_active_tab / get_active_tab -------------------------------

func set_active_tab(tab_id: String) -> void:
	if mode != Mode.TABS:
		push_error("PanelHost.set_active_tab() is TABS only.")
		return
	var idx: int = tab_ids.find(tab_id)
	if idx == -1:
		push_error("PanelHost.set_active_tab(): unknown tab id '%s'" % tab_id)
		return
	_tab_container.current_tab = idx
	view_changed.emit(tab_id)


func get_active_tab() -> String:
	if mode != Mode.TABS or _tab_container == null:
		return ""
	var idx: int = _tab_container.current_tab
	if idx < 0 or idx >= tab_ids.size():
		return ""
	return tab_ids[idx]
