extends Control

const SAVE_PATH := "user://savegame.json"

var economy: Dictionary = {}
var state: Dictionary = {
    "cash": 0.0,
    "debt": 0.0,
    "reputation": 0,
    "location_tier": 0,
    "total_services": 0,
    "upgrade_levels": {},
    "daily_streak": 0,
    "last_login_day": "",
    "last_login_day_index": -1,
    "last_timestamp": 0
}

var service_running := false
var service_progress := 0.0
var service_duration_current := 1.0
var autosave_elapsed := 0.0

var ui: Dictionary = {}
var upgrade_row_by_id: Dictionary = {}

func _ready() -> void:
    var ok := _load_economy_config()
    if not ok:
        push_error("Failed to load economy config.")
        return
    _initialize_state_from_config()
    _build_ui()
    _load_save()
    _apply_daily_login_reward()
    _refresh_derived_stats()
    _refresh_ui()

func _process(delta: float) -> void:
    if service_running:
        service_progress += delta
        if service_progress >= service_duration_current:
            _complete_service()
    var passive: float = _compute_passive_income_per_sec()
    if passive > 0.0:
        state.cash += passive * delta
    autosave_elapsed += delta
    if autosave_elapsed >= float(economy.save.autosave_interval_sec):
        autosave_elapsed = 0.0
        _save_game()
    _refresh_runtime_ui()

func _notification(what: int) -> void:
    if what == NOTIFICATION_WM_CLOSE_REQUEST:
        _save_game()

func _load_economy_config() -> bool:
    if not FileAccess.file_exists("res://data/economy.json"):
        return false
    var file: FileAccess = FileAccess.open("res://data/economy.json", FileAccess.READ)
    if file == null:
        return false
    var parsed: Variant = JSON.parse_string(file.get_as_text())
    if typeof(parsed) != TYPE_DICTIONARY:
        return false
    economy = parsed
    return true

func _initialize_state_from_config() -> void:
    var starting: Dictionary = economy["starting_state"]
    state["cash"] = float(starting["cash"])
    state["debt"] = float(starting["debt"])
    state["reputation"] = int(starting["reputation"])
    state["location_tier"] = int(starting["location_tier"])
    state["total_services"] = 0
    state["upgrade_levels"] = {}
    state["daily_streak"] = 0
    state["last_login_day"] = ""
    state["last_login_day_index"] = -1
    state["last_timestamp"] = Time.get_unix_time_from_system()
    for upgrade: Dictionary in economy["upgrades"]:
        state["upgrade_levels"][upgrade["id"]] = 0

func _build_ui() -> void:
    var root := MarginContainer.new()
    root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    root.add_theme_constant_override("margin_left", 18)
    root.add_theme_constant_override("margin_top", 18)
    root.add_theme_constant_override("margin_right", 18)
    root.add_theme_constant_override("margin_bottom", 18)
    add_child(root)

    var split := HBoxContainer.new()
    split.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    split.size_flags_vertical = Control.SIZE_EXPAND_FILL
    split.add_theme_constant_override("separation", 20)
    root.add_child(split)

    var left := VBoxContainer.new()
    left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    left.size_flags_vertical = Control.SIZE_EXPAND_FILL
    left.add_theme_constant_override("separation", 10)
    split.add_child(left)

    var right := VBoxContainer.new()
    right.custom_minimum_size = Vector2(430, 0)
    right.size_flags_vertical = Control.SIZE_EXPAND_FILL
    right.add_theme_constant_override("separation", 8)
    split.add_child(right)

    ui.title = Label.new()
    ui.title.text = "Cuticle Capital"
    ui.title.add_theme_font_size_override("font_size", 36)
    left.add_child(ui.title)

    ui.subtitle = Label.new()
    ui.subtitle.text = "From bedroom debt to salon owner"
    left.add_child(ui.subtitle)

    ui.cash = Label.new()
    left.add_child(ui.cash)

    ui.debt = Label.new()
    left.add_child(ui.debt)

    ui.rep = Label.new()
    left.add_child(ui.rep)

    ui.location = Label.new()
    left.add_child(ui.location)

    ui.services = Label.new()
    left.add_child(ui.services)

    ui.passive = Label.new()
    left.add_child(ui.passive)

    ui.service_button = Button.new()
    ui.service_button.text = "Start Service"
    ui.service_button.custom_minimum_size = Vector2(260, 56)
    ui.service_button.pressed.connect(_on_service_pressed)
    left.add_child(ui.service_button)

    ui.progress = ProgressBar.new()
    ui.progress.custom_minimum_size = Vector2(430, 30)
    ui.progress.max_value = 1.0
    left.add_child(ui.progress)

    var debt_row := HBoxContainer.new()
    left.add_child(debt_row)

    ui.pay_debt = Button.new()
    ui.pay_debt.text = "Pay $50 Debt"
    ui.pay_debt.pressed.connect(_on_pay_debt_pressed)
    debt_row.add_child(ui.pay_debt)

    ui.location_button = Button.new()
    ui.location_button.text = "Unlock Next Location"
    ui.location_button.pressed.connect(_on_unlock_location_pressed)
    debt_row.add_child(ui.location_button)

    var upgrade_header := Label.new()
    upgrade_header.text = "Upgrades"
    upgrade_header.add_theme_font_size_override("font_size", 22)
    right.add_child(upgrade_header)

    var scroll := ScrollContainer.new()
    scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
    right.add_child(scroll)

    var upgrade_list := VBoxContainer.new()
    upgrade_list.name = "UpgradeList"
    upgrade_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    upgrade_list.add_theme_constant_override("separation", 6)
    scroll.add_child(upgrade_list)

    for upgrade: Dictionary in economy["upgrades"]:
        var panel := PanelContainer.new()
        upgrade_list.add_child(panel)

        var row := VBoxContainer.new()
        row.add_theme_constant_override("separation", 3)
        panel.add_child(row)

        var name := Label.new()
        name.text = String(upgrade["title"])
        row.add_child(name)

        var desc := Label.new()
        desc.text = String(upgrade["description"])
        desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
        row.add_child(desc)

        var action_row := HBoxContainer.new()
        row.add_child(action_row)

        var level := Label.new()
        level.text = "Lv 0"
        action_row.add_child(level)

        var buy := Button.new()
        buy.text = "Buy"
        buy.pressed.connect(_on_buy_upgrade_pressed.bind(String(upgrade["id"])))
        action_row.add_child(buy)

        upgrade_row_by_id[String(upgrade["id"])] = {
            "level": level,
            "buy": buy
        }

    ui.message = Label.new()
    ui.message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    right.add_child(ui.message)

func _on_service_pressed() -> void:
    if service_running:
        return
    service_running = true
    service_progress = 0.0
    service_duration_current = _compute_service_duration()
    ui.service_button.disabled = true
    _set_message("Service started.")

func _complete_service() -> void:
    service_running = false
    service_progress = 0.0
    ui.service_button.disabled = false

    var payout := _compute_service_payout()
    state["cash"] = float(state["cash"]) + payout
    state["reputation"] = int(state["reputation"]) + int(economy["service"]["reputation_gain"])
    state["total_services"] = int(state["total_services"]) + 1
    _set_message("Service complete: +$%s" % _fmt_money(payout))
    _refresh_ui()

func _on_pay_debt_pressed() -> void:
    var payment: float = minf(50.0, float(state["cash"]))
    if payment <= 0.0:
        _set_message("Not enough cash to pay debt.")
        return
    if float(state["debt"]) <= 0.0:
        _set_message("Debt is already paid.")
        return
    payment = minf(payment, float(state["debt"]))
    state["cash"] = float(state["cash"]) - payment
    state["debt"] = float(state["debt"]) - payment
    _set_message("Debt payment made: $%s" % _fmt_money(payment))
    _refresh_ui()
    _save_game()

func _on_unlock_location_pressed() -> void:
    var next_idx: int = int(state["location_tier"]) + 1
    var locations: Array = economy["locations"]
    if next_idx >= locations.size():
        _set_message("All planned locations in MVP are unlocked.")
        return
    var next_location: Dictionary = locations[next_idx]
    if float(state["cash"]) < float(next_location["unlock_cost"]):
        _set_message("Need $%s to unlock %s." % [_fmt_money(float(next_location["unlock_cost"])), String(next_location["name"])])
        return
    if float(state["debt"]) > float(next_location["required_debt"]):
        _set_message("Pay debt to $%s or below before moving." % _fmt_money(float(next_location["required_debt"])))
        return
    state["cash"] = float(state["cash"]) - float(next_location["unlock_cost"])
    state["location_tier"] = next_idx
    state["reputation"] = int(state["reputation"]) + 10
    _set_message("Unlocked: %s" % String(next_location["name"]))
    _refresh_ui()
    _save_game()

func _on_buy_upgrade_pressed(upgrade_id: String) -> void:
    var upgrade := _find_upgrade_by_id(upgrade_id)
    if upgrade.is_empty():
        return
    var level: int = int(state["upgrade_levels"].get(upgrade_id, 0))
    var cost: float = _upgrade_cost(upgrade, level)
    if float(state["cash"]) < cost:
        _set_message("Not enough cash for %s." % String(upgrade["title"]))
        return
    state["cash"] = float(state["cash"]) - cost
    state["upgrade_levels"][upgrade_id] = level + 1
    state["reputation"] = int(state["reputation"]) + int(upgrade["effects"].get("reputation_bonus", 0))
    _set_message("Purchased %s Lv %d" % [String(upgrade["title"]), level + 1])
    _refresh_derived_stats()
    _refresh_ui()
    _save_game()

func _find_upgrade_by_id(id: String) -> Dictionary:
    for upgrade: Dictionary in economy["upgrades"]:
        if String(upgrade["id"]) == id:
            return upgrade
    return {}

func _upgrade_cost(upgrade: Dictionary, level: int) -> float:
    return float(upgrade["base_cost"]) * pow(float(upgrade["cost_multiplier"]), level)

func _compute_service_payout() -> float:
    var payout: float = float(economy["service"]["payout"])
    var mult: float = 1.0
    for upgrade: Dictionary in economy["upgrades"]:
        var level: int = int(state["upgrade_levels"].get(String(upgrade["id"]), 0))
        if level <= 0:
            continue
        mult += float(upgrade["effects"].get("service_payout_mult", 0.0)) * level
    return payout * maxf(mult, 0.2)

func _compute_service_duration() -> float:
    var base: float = float(economy["service"]["duration_sec"])
    var mult: float = 1.0
    for upgrade: Dictionary in economy["upgrades"]:
        var level: int = int(state["upgrade_levels"].get(String(upgrade["id"]), 0))
        if level <= 0:
            continue
        mult += float(upgrade["effects"].get("service_duration_mult", 0.0)) * level
    return maxf(1.2, base * maxf(mult, 0.2))

func _compute_passive_income_per_sec() -> float:
    var per_sec: float = 0.0
    for upgrade: Dictionary in economy["upgrades"]:
        var level: int = int(state["upgrade_levels"].get(String(upgrade["id"]), 0))
        if level <= 0:
            continue
        per_sec += float(upgrade["effects"].get("auto_income_per_sec", 0.0)) * level
    var locations: Array = economy["locations"]
    var loc: Dictionary = locations[int(state["location_tier"])]
    per_sec += float(loc["passive_income_bonus"])
    return per_sec

func _refresh_derived_stats() -> void:
    service_duration_current = _compute_service_duration()

func _refresh_runtime_ui() -> void:
    if not ui.has("progress"):
        return
    ui["progress"].value = 0.0 if not service_running else clampf(service_progress / service_duration_current, 0.0, 1.0)
    ui["service_button"].text = "In Service..." if service_running else "Start Service"
    ui["cash"].text = "Cash: $%s" % _fmt_money(float(state["cash"]))
    ui["debt"].text = "Debt: $%s" % _fmt_money(float(state["debt"]))
    ui["rep"].text = "Reputation: %d" % int(state["reputation"])
    ui["passive"].text = "Passive Income: $%s/sec" % _fmt_money(_compute_passive_income_per_sec())

func _refresh_ui() -> void:
    _refresh_runtime_ui()
    var locations: Array = economy["locations"]
    var current_location: Dictionary = locations[int(state["location_tier"])]
    ui["location"].text = "Location: %s" % String(current_location["name"])
    ui["services"].text = "Services Completed: %d" % int(state["total_services"])

    var next_idx: int = int(state["location_tier"]) + 1
    if next_idx < locations.size():
        var next_location: Dictionary = locations[next_idx]
        ui["location_button"].disabled = float(state["cash"]) < float(next_location["unlock_cost"]) or float(state["debt"]) > float(next_location["required_debt"])
        ui["location_button"].text = "Unlock %s ($%s)" % [String(next_location["name"]), _fmt_money(float(next_location["unlock_cost"]))]
    else:
        ui["location_button"].disabled = true
        ui["location_button"].text = "All MVP Locations Unlocked"

    for upgrade: Dictionary in economy["upgrades"]:
        var id: String = String(upgrade["id"])
        var level: int = int(state["upgrade_levels"].get(id, 0))
        var cost: float = _upgrade_cost(upgrade, level)
        var row: Dictionary = upgrade_row_by_id[id]
        row["level"].text = "Lv %d" % level
        row["buy"].text = "Buy ($%s)" % _fmt_money(cost)
        row["buy"].disabled = float(state["cash"]) < cost

func _fmt_money(value: float) -> String:
    return "%.2f" % value

func _save_game() -> void:
    state["last_timestamp"] = Time.get_unix_time_from_system()
    var file: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
    if file == null:
        _set_message("Save failed.")
        return
    file.store_string(JSON.stringify(state))

func _load_save() -> void:
    if not FileAccess.file_exists(SAVE_PATH):
        return
    var file: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.READ)
    if file == null:
        return
    var parsed: Variant = JSON.parse_string(file.get_as_text())
    if typeof(parsed) != TYPE_DICTIONARY:
        return

    # Merge known keys to allow forward-compatible save evolution.
    for key in (parsed as Dictionary).keys():
        state[key] = parsed[key]

    if not state.has("upgrade_levels"):
        state["upgrade_levels"] = {}
    for upgrade: Dictionary in economy["upgrades"]:
        var upgrade_id: String = String(upgrade["id"])
        if not state["upgrade_levels"].has(upgrade_id):
            state["upgrade_levels"][upgrade_id] = 0

    _apply_offline_progress()

func _apply_offline_progress() -> void:
    var last_ts: int = int(state.get("last_timestamp", Time.get_unix_time_from_system()))
    var now: int = int(Time.get_unix_time_from_system())
    var raw_elapsed: int = now - last_ts
    var cap: int = int(economy["save"]["offline_progress_cap_sec"])
    var elapsed: int = maxi(0, mini(raw_elapsed, cap))
    if elapsed <= 0:
        return
    var passive: float = _compute_passive_income_per_sec()
    if passive <= 0.0:
        return
    var gain: float = passive * elapsed
    state["cash"] = float(state["cash"]) + gain
    _set_message("Offline income: +$%s for %ds away." % [_fmt_money(gain), elapsed])

func _apply_daily_login_reward() -> void:
    var today: String = Time.get_date_string_from_system()
    var today_day_index: int = int(Time.get_unix_time_from_system() / 86400)
    var last_day_index: int = int(state.get("last_login_day_index", -1))
    if last_day_index == today_day_index:
        return

    if last_day_index == today_day_index - 1:
        state["daily_streak"] = int(state.get("daily_streak", 0)) + 1
    else:
        state["daily_streak"] = 1

    var capped_steps: int = mini(int(state["daily_streak"]) - 1, int(economy["daily_login"]["max_streak_bonus_steps"]) - 1)
    var reward: float = float(economy["daily_login"]["base_reward"]) + float(economy["daily_login"]["streak_increment"]) * maxi(capped_steps, 0)
    state["cash"] = float(state["cash"]) + reward
    state["last_login_day"] = today
    state["last_login_day_index"] = today_day_index
    _set_message("Daily reward: +$%s (streak %d)" % [_fmt_money(reward), int(state["daily_streak"])])

func _set_message(text: String) -> void:
    if ui.has("message"):
        ui["message"].text = text
