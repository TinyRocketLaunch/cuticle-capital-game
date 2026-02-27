extends Control

const SAVE_PATH := "user://savegame.json"
const TELEMETRY_PATH := "user://telemetry.jsonl"

var economy: Dictionary = {}
var state: Dictionary = {
    "cash": 0.0,
    "debt": 0.0,
    "reputation": 0,
    "location_tier": 0,
    "total_services": 0,
    "lifetime_cash_earned": 0.0,
    "customer_queue": 0,
    "demand_progress": 0.0,
    "selected_service_id": "",
    "assistant_hired": false,
    "upgrade_levels": {},
    "missions_claimed": {},
    "daily_streak": 0,
    "last_login_day": "",
    "last_login_day_index": -1,
    "last_timestamp": 0
}

var service_running := false
var service_progress := 0.0
var service_duration_current := 1.0
var current_service_id := ""

var assistant_running := false
var assistant_progress := 0.0
var assistant_duration_current := 1.0
var assistant_service_id := ""

var autosave_elapsed := 0.0

var ui: Dictionary = {}
var upgrade_row_by_id: Dictionary = {}
var mission_row_by_id: Dictionary = {}
var service_option_ids: Array[String] = []

var session_start_timestamp := 0
var session_start_services := 0
var session_start_lifetime_earned := 0.0
var session_elapsed_sec := 0.0
var queue_full_seconds := 0.0


func _ready() -> void:
    if not _load_economy_config():
        push_error("Failed to load economy config.")
        return
    _normalize_economy_config()
    _initialize_state_from_config()
    _build_ui()
    _load_save()
    _init_session_metrics()
    _apply_daily_login_reward()
    _refresh_derived_stats()
    _refresh_ui()


func _process(delta: float) -> void:
    session_elapsed_sec += delta
    _process_queue_demand(delta)
    _process_manual_service(delta)
    _process_assistant_service(delta)
    _process_passive_income(delta)
    if int(state["customer_queue"]) >= _compute_queue_capacity():
        queue_full_seconds += delta

    autosave_elapsed += delta
    if autosave_elapsed >= float(economy["save"]["autosave_interval_sec"]):
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


func _normalize_economy_config() -> void:
    if not economy.has("services") and economy.has("service"):
        var legacy: Dictionary = economy["service"]
        economy["services"] = [{
            "id": "manicure",
            "name": String(legacy.get("name", "Basic Manicure")),
            "duration_sec": float(legacy.get("duration_sec", 6.0)),
            "payout": float(legacy.get("payout", 14.0)),
            "reputation_gain": int(legacy.get("reputation_gain", 1)),
            "unlock": {"type": "always"}
        }]

    if not economy.has("queue"):
        economy["queue"] = {
            "base_capacity": 4,
            "base_demand_per_sec": 0.3,
            "reputation_demand_scale": 0.01
        }

    if not economy.has("staff"):
        economy["staff"] = {
            "assistant": {
                "hire_cost": 900,
                "wage_per_sec": 0.12,
                "payout_mult": 0.72,
                "speed_mult": 0.9
            }
        }

    if not economy.has("missions"):
        economy["missions"] = []

    for location: Dictionary in economy["locations"]:
        if not location.has("queue_capacity_bonus"):
            location["queue_capacity_bonus"] = 0


func _initialize_state_from_config() -> void:
    var starting: Dictionary = economy["starting_state"]
    state["cash"] = float(starting["cash"])
    state["debt"] = float(starting["debt"])
    state["reputation"] = int(starting["reputation"])
    state["location_tier"] = int(starting["location_tier"])
    state["total_services"] = 0
    state["lifetime_cash_earned"] = 0.0
    state["customer_queue"] = 0
    state["demand_progress"] = 0.0
    state["assistant_hired"] = false
    state["upgrade_levels"] = {}
    state["missions_claimed"] = {}
    state["daily_streak"] = 0
    state["last_login_day"] = ""
    state["last_login_day_index"] = -1
    state["last_timestamp"] = Time.get_unix_time_from_system()

    for upgrade: Dictionary in economy["upgrades"]:
        state["upgrade_levels"][String(upgrade["id"])] = 0

    for mission: Dictionary in economy["missions"]:
        state["missions_claimed"][String(mission["id"])] = false

    state["selected_service_id"] = _get_default_unlocked_service_id()

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
    right.custom_minimum_size = Vector2(470, 0)
    right.size_flags_vertical = Control.SIZE_EXPAND_FILL
    right.add_theme_constant_override("separation", 10)
    split.add_child(right)

    ui["title"] = Label.new()
    ui["title"].text = "Cuticle Capital"
    ui["title"].add_theme_font_size_override("font_size", 36)
    left.add_child(ui["title"])

    ui["subtitle"] = Label.new()
    ui["subtitle"].text = "From bedroom debt to salon owner"
    left.add_child(ui["subtitle"])

    ui["cash"] = Label.new()
    left.add_child(ui["cash"])

    ui["debt"] = Label.new()
    left.add_child(ui["debt"])

    ui["rep"] = Label.new()
    left.add_child(ui["rep"])

    ui["location"] = Label.new()
    left.add_child(ui["location"])

    ui["services"] = Label.new()
    left.add_child(ui["services"])

    ui["passive"] = Label.new()
    left.add_child(ui["passive"])

    ui["queue"] = Label.new()
    left.add_child(ui["queue"])

    ui["demand"] = Label.new()
    left.add_child(ui["demand"])

    ui["assistant_status"] = Label.new()
    left.add_child(ui["assistant_status"])

    ui["kpi_income"] = Label.new()
    left.add_child(ui["kpi_income"])

    ui["kpi_spm"] = Label.new()
    left.add_child(ui["kpi_spm"])

    ui["kpi_queue_pressure"] = Label.new()
    left.add_child(ui["kpi_queue_pressure"])

    var service_row := HBoxContainer.new()
    service_row.add_theme_constant_override("separation", 8)
    left.add_child(service_row)

    var service_label := Label.new()
    service_label.text = "Service:"
    service_row.add_child(service_label)

    ui["service_select"] = OptionButton.new()
    ui["service_select"].item_selected.connect(_on_service_option_selected)
    service_row.add_child(ui["service_select"])

    ui["service_button"] = Button.new()
    ui["service_button"].text = "Start Service"
    ui["service_button"].custom_minimum_size = Vector2(280, 56)
    ui["service_button"].pressed.connect(_on_service_pressed)
    left.add_child(ui["service_button"])

    ui["progress"] = ProgressBar.new()
    ui["progress"].custom_minimum_size = Vector2(430, 30)
    ui["progress"].max_value = 1.0
    left.add_child(ui["progress"])

    var debt_row := HBoxContainer.new()
    debt_row.add_theme_constant_override("separation", 8)
    left.add_child(debt_row)

    ui["pay_debt"] = Button.new()
    ui["pay_debt"].text = "Pay $50 Debt"
    ui["pay_debt"].pressed.connect(_on_pay_debt_pressed)
    debt_row.add_child(ui["pay_debt"])

    ui["location_button"] = Button.new()
    ui["location_button"].text = "Unlock Next Location"
    ui["location_button"].pressed.connect(_on_unlock_location_pressed)
    debt_row.add_child(ui["location_button"])

    ui["hire_assistant"] = Button.new()
    ui["hire_assistant"].pressed.connect(_on_hire_assistant_pressed)
    left.add_child(ui["hire_assistant"])

    var mission_header := Label.new()
    mission_header.text = "Objectives"
    mission_header.add_theme_font_size_override("font_size", 22)
    right.add_child(mission_header)

    var mission_scroll := ScrollContainer.new()
    mission_scroll.custom_minimum_size = Vector2(430, 180)
    mission_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
    mission_scroll.size_flags_stretch_ratio = 1.0
    right.add_child(mission_scroll)

    var mission_list := VBoxContainer.new()
    mission_list.add_theme_constant_override("separation", 6)
    mission_scroll.add_child(mission_list)

    for mission: Dictionary in economy["missions"]:
        var panel := PanelContainer.new()
        mission_list.add_child(panel)

        var row := VBoxContainer.new()
        row.add_theme_constant_override("separation", 3)
        panel.add_child(row)

        var title := Label.new()
        title.text = String(mission["title"])
        row.add_child(title)

        var progress := Label.new()
        progress.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
        row.add_child(progress)

        var claim := Button.new()
        claim.text = "Claim"
        claim.pressed.connect(_on_claim_mission_pressed.bind(String(mission["id"])))
        row.add_child(claim)

        mission_row_by_id[String(mission["id"])] = {
            "progress": progress,
            "claim": claim
        }

    var upgrade_header := Label.new()
    upgrade_header.text = "Upgrades"
    upgrade_header.add_theme_font_size_override("font_size", 22)
    right.add_child(upgrade_header)

    var upgrade_scroll := ScrollContainer.new()
    upgrade_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
    upgrade_scroll.size_flags_stretch_ratio = 2.0
    right.add_child(upgrade_scroll)

    var upgrade_list := VBoxContainer.new()
    upgrade_list.name = "UpgradeList"
    upgrade_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    upgrade_list.add_theme_constant_override("separation", 6)
    upgrade_scroll.add_child(upgrade_list)

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

    ui["message"] = Label.new()
    ui["message"].autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    right.add_child(ui["message"])


func _on_service_option_selected(index: int) -> void:
    if index < 0 or index >= service_option_ids.size():
        return
    state["selected_service_id"] = service_option_ids[index]
    _refresh_derived_stats()
    _refresh_ui()


func _on_service_pressed() -> void:
    if service_running:
        return
    if int(state["customer_queue"]) <= 0:
        _set_message("No waiting clients. Build demand first.")
        return

    var service_id: String = String(state.get("selected_service_id", ""))
    if not _is_service_unlocked(service_id):
        _set_message("Selected service is still locked.")
        return

    _start_manual_service(service_id)


func _start_manual_service(service_id: String) -> void:
    service_running = true
    service_progress = 0.0
    current_service_id = service_id
    service_duration_current = _compute_service_duration(service_id)
    state["customer_queue"] = maxi(0, int(state["customer_queue"]) - 1)
    _set_message("Started %s." % _service_name(service_id))


func _process_manual_service(delta: float) -> void:
    if not service_running:
        return
    service_progress += delta
    if service_progress >= service_duration_current:
        _complete_manual_service()


func _complete_manual_service() -> void:
    service_running = false
    service_progress = 0.0

    var payout := _compute_service_payout(current_service_id)
    state["cash"] = float(state["cash"]) + payout
    state["lifetime_cash_earned"] = float(state["lifetime_cash_earned"]) + payout
    state["reputation"] = int(state["reputation"]) + _service_reputation_gain(current_service_id)
    state["total_services"] = int(state["total_services"]) + 1
    _log_telemetry_event("service_complete", {
        "service_id": current_service_id,
        "source": "player",
        "payout": payout,
        "total_services": int(state["total_services"]),
        "queue": int(state["customer_queue"])
    })
    _set_message("%s complete: +$%s" % [_service_name(current_service_id), _fmt_money(payout)])
    _refresh_derived_stats()
    _refresh_ui()


func _process_assistant_service(delta: float) -> void:
    if not bool(state.get("assistant_hired", false)):
        assistant_running = false
        assistant_progress = 0.0
        return

    if assistant_running:
        assistant_progress += delta
        if assistant_progress >= assistant_duration_current:
            _complete_assistant_service()
        return

    if int(state["customer_queue"]) <= 0:
        return

    var service_id := _pick_assistant_service_id()
    if service_id == "":
        return

    assistant_running = true
    assistant_progress = 0.0
    assistant_service_id = service_id
    assistant_duration_current = _compute_service_duration(service_id) / maxf(float(economy["staff"]["assistant"]["speed_mult"]), 0.25)
    state["customer_queue"] = maxi(0, int(state["customer_queue"]) - 1)


func _complete_assistant_service() -> void:
    assistant_running = false
    assistant_progress = 0.0

    var payout := _compute_service_payout(assistant_service_id) * float(economy["staff"]["assistant"]["payout_mult"])
    state["cash"] = float(state["cash"]) + payout
    state["lifetime_cash_earned"] = float(state["lifetime_cash_earned"]) + payout
    state["reputation"] = int(state["reputation"]) + maxi(1, int(round(_service_reputation_gain(assistant_service_id) * 0.5)))
    state["total_services"] = int(state["total_services"]) + 1
    _log_telemetry_event("service_complete", {
        "service_id": assistant_service_id,
        "source": "assistant",
        "payout": payout,
        "total_services": int(state["total_services"]),
        "queue": int(state["customer_queue"])
    })
    _set_message("Assistant completed %s: +$%s" % [_service_name(assistant_service_id), _fmt_money(payout)])
    _refresh_derived_stats()
    _refresh_ui()


func _process_queue_demand(delta: float) -> void:
    var max_queue: int = _compute_queue_capacity()
    if int(state["customer_queue"]) >= max_queue:
        state["demand_progress"] = minf(float(state.get("demand_progress", 0.0)), 0.999)
        return

    var demand_rate: float = _compute_demand_per_sec()
    state["demand_progress"] = float(state.get("demand_progress", 0.0)) + demand_rate * delta
    var spawn_count: int = int(floor(float(state["demand_progress"])))
    if spawn_count <= 0:
        return

    var queue_room: int = max_queue - int(state["customer_queue"])
    var accepted: int = mini(spawn_count, queue_room)
    state["customer_queue"] = int(state["customer_queue"]) + accepted
    state["demand_progress"] = float(state["demand_progress"]) - float(spawn_count)


func _process_passive_income(delta: float) -> void:
    var passive: float = _compute_passive_income_per_sec()
    if passive > 0.0:
        state["cash"] = float(state["cash"]) + passive * delta
        state["lifetime_cash_earned"] = float(state["lifetime_cash_earned"]) + passive * delta

    if bool(state.get("assistant_hired", false)):
        var wage_cost: float = float(economy["staff"]["assistant"]["wage_per_sec"]) * delta
        state["cash"] = maxf(0.0, float(state["cash"]) - wage_cost)


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
    _log_telemetry_event("location_unlock", {
        "location_id": String(next_location["id"]),
        "cash_after": float(state["cash"]),
        "debt_after": float(state["debt"]),
        "total_services": int(state["total_services"])
    })
    _set_message("Unlocked: %s" % String(next_location["name"]))
    _refresh_ui()
    _save_game()

func _on_hire_assistant_pressed() -> void:
    if bool(state.get("assistant_hired", false)):
        _set_message("Assistant already hired.")
        return

    var cost: float = float(economy["staff"]["assistant"]["hire_cost"])
    if float(state["cash"]) < cost:
        _set_message("Need $%s to hire assistant." % _fmt_money(cost))
        return

    state["cash"] = float(state["cash"]) - cost
    state["assistant_hired"] = true
    _log_telemetry_event("assistant_hired", {
        "hire_cost": cost,
        "cash_after": float(state["cash"]),
        "total_services": int(state["total_services"])
    })
    _set_message("Assistant hired. They will auto-serve queued clients.")
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
    _log_telemetry_event("upgrade_purchase", {
        "upgrade_id": upgrade_id,
        "new_level": level + 1,
        "cost": cost,
        "cash_after": float(state["cash"]),
        "total_services": int(state["total_services"])
    })
    _set_message("Purchased %s Lv %d" % [String(upgrade["title"]), level + 1])
    _refresh_derived_stats()
    _refresh_ui()
    _save_game()


func _on_claim_mission_pressed(mission_id: String) -> void:
    var mission := _find_mission_by_id(mission_id)
    if mission.is_empty():
        return
    if bool(state["missions_claimed"].get(mission_id, false)):
        _set_message("Objective already claimed.")
        return
    if not _is_mission_complete(mission):
        _set_message("Objective requirements not met yet.")
        return

    var rewards: Dictionary = mission["rewards"]
    var cash_reward: float = float(rewards.get("cash", 0.0))
    var rep_reward: int = int(rewards.get("reputation", 0))
    state["cash"] = float(state["cash"]) + cash_reward
    state["lifetime_cash_earned"] = float(state["lifetime_cash_earned"]) + cash_reward
    state["reputation"] = int(state["reputation"]) + rep_reward
    state["missions_claimed"][mission_id] = true
    _log_telemetry_event("mission_claimed", {
        "mission_id": mission_id,
        "cash_reward": cash_reward,
        "rep_reward": rep_reward,
        "cash_after": float(state["cash"])
    })
    _set_message("Objective claimed: +$%s, +%d rep" % [_fmt_money(cash_reward), rep_reward])
    _refresh_ui()
    _save_game()


func _find_upgrade_by_id(id: String) -> Dictionary:
    for upgrade: Dictionary in economy["upgrades"]:
        if String(upgrade["id"]) == id:
            return upgrade
    return {}


func _find_service_by_id(id: String) -> Dictionary:
    for service: Dictionary in economy["services"]:
        if String(service["id"]) == id:
            return service
    return {}


func _find_mission_by_id(id: String) -> Dictionary:
    for mission: Dictionary in economy["missions"]:
        if String(mission["id"]) == id:
            return mission
    return {}


func _upgrade_cost(upgrade: Dictionary, level: int) -> float:
    return float(upgrade["base_cost"]) * pow(float(upgrade["cost_multiplier"]), level)


func _service_name(service_id: String) -> String:
    var service := _find_service_by_id(service_id)
    if service.is_empty():
        return "Service"
    return String(service["name"])


func _service_reputation_gain(service_id: String) -> int:
    var service := _find_service_by_id(service_id)
    if service.is_empty():
        return 1
    return int(service.get("reputation_gain", 1))


func _get_effect_sum(effect_key: String) -> float:
    var value := 0.0
    for upgrade: Dictionary in economy["upgrades"]:
        var id: String = String(upgrade["id"])
        var level: int = int(state["upgrade_levels"].get(id, 0))
        if level <= 0:
            continue
        value += float(upgrade["effects"].get(effect_key, 0.0)) * level
    return value


func _compute_service_payout(service_id: String) -> float:
    var service := _find_service_by_id(service_id)
    if service.is_empty():
        return 0.0
    var payout: float = float(service["payout"])
    var mult: float = 1.0 + _get_effect_sum("service_payout_mult")
    return payout * maxf(mult, 0.2)

func _compute_service_duration(service_id: String) -> float:
    var service := _find_service_by_id(service_id)
    if service.is_empty():
        return 2.0

    var base: float = float(service["duration_sec"])
    var duration_mult: float = 1.0 + _get_effect_sum("service_duration_mult")
    var throughput: float = 1.0 + _get_effect_sum("throughput_mult")
    return maxf(1.0, (base * maxf(duration_mult, 0.25)) / maxf(throughput, 0.35))


func _compute_passive_income_per_sec() -> float:
    var per_sec: float = _get_effect_sum("auto_income_per_sec")
    var locations: Array = economy["locations"]
    var loc: Dictionary = locations[int(state["location_tier"])]
    per_sec += float(loc.get("passive_income_bonus", 0.0))
    return per_sec


func _compute_queue_capacity() -> int:
    var locations: Array = economy["locations"]
    var loc: Dictionary = locations[int(state["location_tier"])]
    var cap: float = float(economy["queue"]["base_capacity"])
    cap += _get_effect_sum("queue_capacity_bonus")
    cap += float(loc.get("queue_capacity_bonus", 0.0))
    return maxi(1, int(round(cap)))


func _compute_demand_per_sec() -> float:
    var demand: float = float(economy["queue"]["base_demand_per_sec"])
    demand += _get_effect_sum("demand_per_sec_bonus")
    demand += float(state["reputation"]) * float(economy["queue"].get("reputation_demand_scale", 0.0))
    return maxf(0.01, demand)


func _refresh_derived_stats() -> void:
    var selected: String = String(state.get("selected_service_id", ""))
    if selected == "" or not _is_service_unlocked(selected):
        selected = _get_default_unlocked_service_id()
        state["selected_service_id"] = selected
    service_duration_current = _compute_service_duration(selected)


func _refresh_runtime_ui() -> void:
    if not ui.has("progress"):
        return

    ui["progress"].value = 0.0 if not service_running else clampf(service_progress / maxf(service_duration_current, 0.1), 0.0, 1.0)
    ui["cash"].text = "Cash: $%s" % _fmt_money(float(state["cash"]))
    ui["debt"].text = "Debt: $%s" % _fmt_money(float(state["debt"]))
    ui["rep"].text = "Reputation: %d" % int(state["reputation"])
    ui["passive"].text = "Passive Income: $%s/sec" % _fmt_money(_compute_passive_income_per_sec())
    ui["queue"].text = "Queue: %d / %d" % [int(state["customer_queue"]), _compute_queue_capacity()]
    ui["demand"].text = "Demand Rate: %.2f clients/sec" % _compute_demand_per_sec()
    ui["kpi_income"].text = "Session Income: $%s" % _fmt_money(_session_income())
    ui["kpi_spm"].text = "Services/Min: %.2f" % _services_per_minute()
    ui["kpi_queue_pressure"].text = "Queue Pressure: %.0f%%" % (_queue_pressure_ratio() * 100.0)

    if bool(state.get("assistant_hired", false)):
        if assistant_running:
            var pct: float = clampf(assistant_progress / maxf(assistant_duration_current, 0.1), 0.0, 1.0) * 100.0
            ui["assistant_status"].text = "Assistant: Busy (%d%%)" % int(round(pct))
        else:
            ui["assistant_status"].text = "Assistant: Waiting for queued clients"
    else:
        ui["assistant_status"].text = "Assistant: Not hired"

    var selected_service: String = String(state.get("selected_service_id", ""))
    var start_text := "Serve %s" % _service_name(selected_service)
    ui["service_button"].text = "In Service..." if service_running else start_text
    ui["service_button"].disabled = service_running or int(state["customer_queue"]) <= 0 or not _is_service_unlocked(selected_service)


func _refresh_ui() -> void:
    _refresh_service_options()
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

    var assistant_cost: float = float(economy["staff"]["assistant"]["hire_cost"])
    if bool(state.get("assistant_hired", false)):
        ui["hire_assistant"].disabled = true
        ui["hire_assistant"].text = "Assistant Hired"
    else:
        ui["hire_assistant"].disabled = float(state["cash"]) < assistant_cost
        ui["hire_assistant"].text = "Hire Assistant ($%s)" % _fmt_money(assistant_cost)

    for upgrade: Dictionary in economy["upgrades"]:
        var id: String = String(upgrade["id"])
        var level: int = int(state["upgrade_levels"].get(id, 0))
        var cost: float = _upgrade_cost(upgrade, level)
        var row: Dictionary = upgrade_row_by_id[id]
        row["level"].text = "Lv %d" % level
        row["buy"].text = "Buy ($%s)" % _fmt_money(cost)
        row["buy"].disabled = float(state["cash"]) < cost

    for mission: Dictionary in economy["missions"]:
        var id: String = String(mission["id"])
        if not mission_row_by_id.has(id):
            continue

        var row: Dictionary = mission_row_by_id[id]
        var claimed: bool = bool(state["missions_claimed"].get(id, false))
        var progress_text: String = _mission_progress_text(mission)
        if claimed:
            row["progress"].text = "%s (claimed)" % progress_text
            row["claim"].disabled = true
            row["claim"].text = "Claimed"
        else:
            var complete: bool = _is_mission_complete(mission)
            row["progress"].text = progress_text
            row["claim"].disabled = not complete
            row["claim"].text = "Claim" if complete else "Locked"


func _refresh_service_options() -> void:
    var select: OptionButton = ui["service_select"]
    select.clear()
    service_option_ids.clear()

    var selected_id: String = String(state.get("selected_service_id", ""))
    var selected_idx := -1

    for service: Dictionary in economy["services"]:
        var id: String = String(service["id"])
        if not _is_service_unlocked(id):
            continue
        var idx: int = select.item_count
        select.add_item(String(service["name"]))
        service_option_ids.append(id)
        if id == selected_id:
            selected_idx = idx

    if service_option_ids.is_empty():
        state["selected_service_id"] = ""
        return

    if selected_idx < 0:
        selected_idx = 0
        state["selected_service_id"] = service_option_ids[0]

    select.select(selected_idx)


func _pick_assistant_service_id() -> String:
    var best_id := ""
    var best_value := -INF
    for service: Dictionary in economy["services"]:
        var id: String = String(service["id"])
        if not _is_service_unlocked(id):
            continue
        var score: float = _compute_service_payout(id) / _compute_service_duration(id)
        if score > best_value:
            best_value = score
            best_id = id
    return best_id


func _get_default_unlocked_service_id() -> String:
    for service: Dictionary in economy["services"]:
        var id: String = String(service["id"])
        if _is_service_unlocked(id):
            return id
    return String((economy["services"][0] as Dictionary)["id"])


func _is_service_unlocked(service_id: String) -> bool:
    var service := _find_service_by_id(service_id)
    if service.is_empty():
        return false

    if not service.has("unlock"):
        return true

    var unlock: Dictionary = service["unlock"]
    var unlock_type: String = String(unlock.get("type", "always"))
    var value: int = int(unlock.get("value", 0))

    match unlock_type:
        "always":
            return true
        "total_services":
            return int(state.get("total_services", 0)) >= value
        "reputation":
            return int(state.get("reputation", 0)) >= value
        "location_tier":
            return int(state.get("location_tier", 0)) >= value
        _:
            return true


func _mission_progress_value(mission: Dictionary) -> int:
    var condition: Dictionary = mission["condition"]
    var condition_type: String = String(condition.get("type", "total_services"))

    match condition_type:
        "total_services":
            return int(state.get("total_services", 0))
        "reputation":
            return int(state.get("reputation", 0))
        "cash":
            return int(floor(float(state.get("cash", 0.0))))
        "debt_paid":
            var starting_debt: float = float(economy["starting_state"].get("debt", 0.0))
            return int(round(starting_debt - float(state.get("debt", 0.0))))
        _:
            return 0

func _is_mission_complete(mission: Dictionary) -> bool:
    var condition: Dictionary = mission["condition"]
    var target: int = int(condition.get("target", 0))
    return _mission_progress_value(mission) >= target


func _mission_progress_text(mission: Dictionary) -> String:
    var condition: Dictionary = mission["condition"]
    var target: int = int(condition.get("target", 0))
    var progress: int = _mission_progress_value(mission)
    return "Progress: %d / %d" % [mini(progress, target), target]


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

    for key in (parsed as Dictionary).keys():
        state[key] = parsed[key]

    if not state.has("upgrade_levels"):
        state["upgrade_levels"] = {}
    for upgrade: Dictionary in economy["upgrades"]:
        var upgrade_id: String = String(upgrade["id"])
        if not state["upgrade_levels"].has(upgrade_id):
            state["upgrade_levels"][upgrade_id] = 0

    if not state.has("missions_claimed"):
        state["missions_claimed"] = {}
    for mission: Dictionary in economy["missions"]:
        var mission_id: String = String(mission["id"])
        if not state["missions_claimed"].has(mission_id):
            state["missions_claimed"][mission_id] = false

    if not state.has("customer_queue"):
        state["customer_queue"] = 0
    if not state.has("demand_progress"):
        state["demand_progress"] = 0.0
    if not state.has("selected_service_id"):
        state["selected_service_id"] = _get_default_unlocked_service_id()
    if not state.has("assistant_hired"):
        state["assistant_hired"] = false
    if not state.has("lifetime_cash_earned"):
        state["lifetime_cash_earned"] = float(state.get("cash", 0.0))

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
    state["lifetime_cash_earned"] = float(state["lifetime_cash_earned"]) + gain
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
    state["lifetime_cash_earned"] = float(state["lifetime_cash_earned"]) + reward
    state["last_login_day"] = today
    state["last_login_day_index"] = today_day_index
    _set_message("Daily reward: +$%s (streak %d)" % [_fmt_money(reward), int(state["daily_streak"])])


func _set_message(text: String) -> void:
    if ui.has("message"):
        ui["message"].text = text


func _init_session_metrics() -> void:
    session_start_timestamp = int(Time.get_unix_time_from_system())
    session_start_services = int(state.get("total_services", 0))
    session_start_lifetime_earned = float(state.get("lifetime_cash_earned", 0.0))
    session_elapsed_sec = 0.0
    queue_full_seconds = 0.0
    _log_telemetry_event("session_start", {
        "cash": float(state["cash"]),
        "debt": float(state["debt"]),
        "services": int(state["total_services"]),
        "location_tier": int(state["location_tier"])
    })


func _session_income() -> float:
    return maxf(0.0, float(state.get("lifetime_cash_earned", 0.0)) - session_start_lifetime_earned)


func _services_per_minute() -> float:
    if session_elapsed_sec <= 1.0:
        return 0.0
    var delta_services: int = int(state.get("total_services", 0)) - session_start_services
    return float(delta_services) * 60.0 / session_elapsed_sec


func _queue_pressure_ratio() -> float:
    if session_elapsed_sec <= 0.1:
        return 0.0
    return clampf(queue_full_seconds / session_elapsed_sec, 0.0, 1.0)


func _log_telemetry_event(event_name: String, payload: Dictionary) -> void:
    var log_entry := {
        "ts": int(Time.get_unix_time_from_system()),
        "event": event_name,
        "payload": payload
    }
    var file: FileAccess = FileAccess.open(TELEMETRY_PATH, FileAccess.READ_WRITE)
    if file == null:
        file = FileAccess.open(TELEMETRY_PATH, FileAccess.WRITE)
        if file == null:
            return
    else:
        file.seek_end()
    file.store_line(JSON.stringify(log_entry))
