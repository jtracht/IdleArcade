extends Control
class_name PitchStageMinigame

## PitchStageMinigame Modal Overlay (res://scripts/ui/pitch_stage_minigame.gd)
## Interactive QTE & Buzzword Matching Minigame for the PitchStage station (Milestone M2).
## Features 4 Investor Archetypes, 3 rotating buzzwords per round, 5.0s countdown timer,
## consecutive streak calculation, and scaling instant grants:
##   grant = max(1000.0, current_rps * 15.0 * (1.0 + streak * 0.5))
## Strict pointer isolation (mouse_filter = STOP) and touch targets >= 56px.

signal pitch_completed(streak: int, grant_awarded: float)
signal closed()
signal buzzword_selected(buzzword: String, is_correct: bool, current_streak: int)
signal round_started(round_index: int, investor_type: String)

# Configuration & Tunables
@export var round_time_limit: float = 5.0
@export var total_rounds: int = 3
@export var base_min_grant: float = 1000.0
@export var end_on_wrong_choice: bool = false

# The 4 Verified Investor Archetypes & Matching Keyword Matrix
const INVESTOR_PROFILES: Dictionary = {
	"Tech VC": {
		"category": "AI_DEEPTECH",
		"avatar": "🤖",
		"title": "Frontier AI & Autonomous Systems VC",
		"demand": "\"We only back 100x frontier models and autonomous neural infrastructure.\"",
		"matching_keywords": [
			"AI Synergy", "Neural Cloud", "Quantum Tensor", "Deep Reasoning",
			"AGI Alignment", "Autonomous Agents", "Transformer Mesh"
		]
	},
	"Crypto Baron": {
		"category": "WEB3_BLOCKCHAIN",
		"avatar": "🪙",
		"title": "Sovereign Web3 & Decentralized Protocol Fund",
		"demand": "\"Show me trustless decentralization and provable on-chain cryptography.\"",
		"matching_keywords": [
			"Blockchain Cloud", "Zero-Knowledge Proofs", "Decentralized Hash", "Smart Tokenomics",
			"Web3 Liquidity", "DeFi Staking", "Consensus Protocol"
		]
	},
	"Growth Hacker": {
		"category": "VIRAL_GROWTH",
		"avatar": "🚀",
		"title": "Hyper-Scale Viral Angel",
		"demand": "\"I need exponential organic adoption and unstoppable product loops.\"",
		"matching_keywords": [
			"Viral Retention", "Growth Flywheel", "Hyper-Funnel", "Gamified Onboarding",
			"Product-Led Growth", "Viral Loops", "Network Effects"
		]
	},
	"Enterprise Titan": {
		"category": "ENTERPRISE_INFRA",
		"avatar": "🏢",
		"title": "Global Enterprise Infrastructure Fund",
		"demand": "\"Enterprise clients demand five-nines uptime, SOC2, and zero trust architecture.\"",
		"matching_keywords": [
			"Zero Trust SLA", "Kubernetes Mesh", "Fault-Tolerant Cluster", "Mission-Critical Ops",
			"SOC2 Compliance", "Multi-Region Cloud", "Disaster Recovery"
		]
	}
}

# Node References
@onready var backdrop: ColorRect = get_node_or_null("DimBackdrop")
@onready var close_button: Button = get_node_or_null("%CloseButton")
@onready var round_label: Label = get_node_or_null("%RoundLabel")
@onready var streak_label: Label = get_node_or_null("%StreakLabel")
@onready var investor_avatar_label: Label = get_node_or_null("%InvestorAvatarLabel")
@onready var investor_name_label: Label = get_node_or_null("%InvestorNameLabel")
@onready var investor_category_label: Label = get_node_or_null("%InvestorCategoryLabel")
@onready var investor_demand_label: Label = get_node_or_null("%InvestorDemandLabel")
@onready var timer_progress_bar: ProgressBar = get_node_or_null("%TimerProgressBar")
@onready var timer_label: Label = get_node_or_null("%TimerLabel")
@onready var feedback_label: Label = get_node_or_null("%FeedbackLabel")

# Button Option Nodes
@onready var buzzword_btn_0: Button = get_node_or_null("%BuzzwordButton0")
@onready var buzzword_btn_1: Button = get_node_or_null("%BuzzwordButton1")
@onready var buzzword_btn_2: Button = get_node_or_null("%BuzzwordButton2")

var stage_ref: Node = null
var current_round: int = 0
var current_streak: int = 0
var time_remaining: float = 5.0
var is_active: bool = false
var is_completed: bool = false
var active_investor_type: String = "Tech VC"
var current_buzzwords: Array[String] = []
var current_correct_buzzword: String = ""
var round_investors_sequence: Array[String] = []

func _ready() -> void:
	# Enforce pointer isolation
	mouse_filter = Control.MOUSE_FILTER_STOP
	if backdrop != null:
		backdrop.mouse_filter = Control.MOUSE_FILTER_STOP

	# Configure and connect close button
	if close_button != null:
		close_button.mouse_filter = Control.MOUSE_FILTER_STOP
		close_button.custom_minimum_size.x = maxf(close_button.custom_minimum_size.x, 56.0)
		close_button.custom_minimum_size.y = maxf(close_button.custom_minimum_size.y, 56.0)
		if not close_button.pressed.is_connected(close_minigame):
			close_button.pressed.connect(close_minigame)

	# Configure and connect buzzword option buttons
	var btns: Array[Button] = _get_buttons_list()
	for i in range(btns.size()):
		var btn = btns[i]
		if btn != null:
			btn.mouse_filter = Control.MOUSE_FILTER_STOP
			btn.custom_minimum_size.y = maxf(btn.custom_minimum_size.y, 56.0)
			var idx: int = i
			if not btn.pressed.is_connected(func(): _on_buzzword_button_pressed(idx)):
				btn.pressed.connect(func(): _on_buzzword_button_pressed(idx))

	if timer_progress_bar != null:
		timer_progress_bar.min_value = 0.0
		timer_progress_bar.max_value = round_time_limit
		timer_progress_bar.value = round_time_limit

	_reset_minigame_state()

func _gui_input(event: InputEvent) -> void:
	# Block pointer events from reaching 3D campus world
	accept_event()

func _unhandled_input(event: InputEvent) -> void:
	if not visible or not is_active or is_completed:
		return
	if event is InputEventKey and event.is_pressed() and not event.is_echo():
		if event.keycode == KEY_1:
			simulate_buzzword_choice(0)
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_2:
			simulate_buzzword_choice(1)
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_3:
			simulate_buzzword_choice(2)
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_ESCAPE:
			close_minigame()
			get_viewport().set_input_as_handled()

func _process(delta: float) -> void:
	if not is_active or is_completed:
		return

	var safe_delta: float = minf(0.1, maxf(0.0, delta))
	time_remaining = maxf(0.0, time_remaining - safe_delta)

	_update_timer_display()

	if time_remaining <= 0.0:
		_on_timeout()

## Opens modal and binds reference to 3D PitchStage station.
func open_minigame(p_stage_ref: Node = null) -> void:
	stage_ref = p_stage_ref
	_reset_minigame_state()
	visible = true
	is_active = true
	is_completed = false
	_setup_round(0)

## Closes modal, cleans up resources, and restores campus locomotion.
func close_minigame() -> void:
	is_active = false
	closed.emit()
	visible = false
	queue_free()

## Programmatic query: checks if modal is accepting choices.
func can_pitch() -> bool:
	return is_active and not is_completed

## Returns string key of active investor profile.
func get_active_investor_type() -> String:
	return active_investor_type

## Returns the current 3 buzzword options presented to player.
func get_current_buzzwords() -> Array[String]:
	return current_buzzwords.duplicate()

## Returns active streak count.
func get_current_streak() -> int:
	return current_streak

## Returns current round index (0 to total_rounds - 1).
func get_current_round() -> int:
	return current_round

## Tests whether a buzzword matches an investor archetype thesis.
func is_buzzword_matching(buzzword: String, investor_type: String) -> bool:
	if not INVESTOR_PROFILES.has(investor_type):
		return false
	var keywords: Array = INVESTOR_PROFILES[investor_type].get("matching_keywords", [])
	return buzzword in keywords

## Calculates instant scaling grant based on streak and current RPS.
func calculate_grant(streak: int = -1, p_rps: float = -1.0) -> float:
	var use_streak: int = current_streak if streak < 0 else streak
	var gs = get_node_or_null("/root/GameState")
	var rps: float = p_rps
	if rps < 0.0:
		if gs != null and gs.has_method("get_effective_passive_rps"):
			rps = gs.get_effective_passive_rps()
		else:
			rps = 0.0

	var base_grant: float = base_min_grant
	if gs != null and gs.has_method("get_idle_level"):
		base_grant += float(gs.get_idle_level()) * 100.0

	var streak_multiplier: float = 1.0 + float(use_streak) * 0.5
	var rps_component: float = rps * 15.0 * streak_multiplier
	var total_grant: float = maxf(base_min_grant, roundf(base_grant + rps_component))
	return total_grant

## Programmatic test hook: simulates player picking buzzword option at index (0, 1, or 2).
func simulate_buzzword_choice(index: int) -> bool:
	if not is_active or is_completed:
		return false
	if index < 0 or index >= current_buzzwords.size():
		return false

	var chosen_word: String = current_buzzwords[index]
	var is_match: bool = is_buzzword_matching(chosen_word, active_investor_type)

	buzzword_selected.emit(chosen_word, is_match, current_streak)

	if is_match:
		current_streak += 1
		_play_feedback_juice(true)
		if feedback_label != null:
			feedback_label.text = ">> MATCH! %s ACCEPTS '%s'! (STREAK: %d) <<" % [
				active_investor_type, chosen_word, current_streak
			]
			feedback_label.modulate = Color(0.2, 1.0, 0.5)
	else:
		current_streak = 0
		_play_feedback_juice(false)
		if feedback_label != null:
			feedback_label.text = ">> REJECTED! '%s' REJECTED BY %s (STREAK RESET) <<" % [
				chosen_word, active_investor_type
			]
			feedback_label.modulate = Color(1.0, 0.4, 0.4)

	current_round += 1
	_update_streak_and_round_labels()

	if is_match or not end_on_wrong_choice:
		if current_round >= total_rounds:
			complete_pitch(current_streak > 0)
		else:
			_setup_round(current_round)
	else:
		complete_pitch(false)

	return is_match

## Completes pitch session, computes scaling grant, and emits signals.
func complete_pitch(success: bool = true) -> void:
	if is_completed:
		return
	is_completed = true
	is_active = false

	var final_grant: float = calculate_grant(current_streak)

	_disable_buttons()

	if feedback_label != null:
		if success and current_streak > 0:
			feedback_label.text = ">>> PITCH FUNDED! %d-STREAK GRANT: +%d ENERGY <<<" % [
				current_streak, int(final_grant)
			]
			feedback_label.modulate = Color(1.0, 0.85, 0.2)
		else:
			feedback_label.text = ">>> PITCH CLOSED! GRANT AWARDED: +%d ENERGY <<<" % int(final_grant)
			feedback_label.modulate = Color(0.7, 0.9, 1.0)

	# Standalone execution: credit GameState directly if stage_ref is not handling it
	if stage_ref == null:
		var gs = get_node_or_null("/root/GameState")
		if gs != null:
			if gs.has_method("earn_energy"):
				gs.earn_energy(final_grant)
			else:
				gs.energy += final_grant

	pitch_completed.emit(current_streak, final_grant)

	# 2D celebratory confetti burst and triumph feedback on winning pitch
	if success and current_streak > 0:
		var confetti_cls = load("res://scripts/vfx/confetti_burst.gd")
		if confetti_cls != null and confetti_cls.has_method("spawn_burst_2d"):
			confetti_cls.spawn_burst_2d(self, size * 0.5, 45)

		var am_win = get_node_or_null("/root/AudioManager")
		if am_win != null and am_win.has_method("play_sfx_victory_jingle"):
			am_win.play_sfx_victory_jingle()
		var hm_win = get_node_or_null("/root/HapticsManager")
		if hm_win != null and hm_win.has_method("vibrate_success"):
			hm_win.vibrate_success()

## Programmatic test hook for B6 countdown expiration.
func simulate_timeout() -> void:
	time_remaining = 0.0
	_on_timeout()

func _on_timeout() -> void:
	if not is_active or is_completed:
		return

	current_streak = 0
	_play_feedback_juice(false)

	if feedback_label != null:
		feedback_label.text = ">> TIME EXPIRED! %s WALKED AWAY (STREAK RESET) <<" % active_investor_type
		feedback_label.modulate = Color(1.0, 0.4, 0.4)

	_update_streak_and_round_labels()
	complete_pitch(false)

func _on_buzzword_button_pressed(index: int) -> void:
	simulate_buzzword_choice(index)

func _reset_minigame_state() -> void:
	current_round = 0
	current_streak = 0
	is_completed = false
	is_active = true

	# Generate randomized sequence of distinct investor types for the 3 rounds
	var all_investors: Array = INVESTOR_PROFILES.keys()
	all_investors.shuffle()
	round_investors_sequence.clear()
	for i in range(mini(total_rounds, all_investors.size())):
		round_investors_sequence.append(str(all_investors[i]))
	while round_investors_sequence.size() < total_rounds:
		round_investors_sequence.append("Tech VC")

	_enable_buttons()
	_update_streak_and_round_labels()

func _setup_round(round_idx: int) -> void:
	if round_idx < round_investors_sequence.size():
		active_investor_type = round_investors_sequence[round_idx]
	else:
		active_investor_type = "Tech VC"

	var profile: Dictionary = INVESTOR_PROFILES[active_investor_type]
	var matching_pool: Array = profile.get("matching_keywords", []).duplicate()
	matching_pool.shuffle()
	current_correct_buzzword = str(matching_pool[0]) if matching_pool.size() > 0 else "AI Synergy"

	# Select 2 distractors from other investor profiles
	var distractor_pool: Array[String] = []
	for inv_name in INVESTOR_PROFILES:
		if inv_name != active_investor_type:
			var other_keywords: Array = INVESTOR_PROFILES[inv_name].get("matching_keywords", [])
			for kw in other_keywords:
				var kw_str: String = str(kw)
				if not is_buzzword_matching(kw_str, active_investor_type):
					distractor_pool.append(kw_str)

	distractor_pool.shuffle()
	var picked_distractors: Array[String] = []
	for d in distractor_pool:
		if d not in picked_distractors:
			picked_distractors.append(d)
			if picked_distractors.size() >= 2:
				break

	while picked_distractors.size() < 2:
		picked_distractors.append("Blockchain Cloud" if active_investor_type != "Crypto Baron" else "Viral Retention")

	current_buzzwords = [current_correct_buzzword, picked_distractors[0], picked_distractors[1]]
	current_buzzwords.shuffle()

	# Update visual cards
	if investor_avatar_label != null:
		investor_avatar_label.text = str(profile.get("avatar", "💼"))
	if investor_name_label != null:
		investor_name_label.text = active_investor_type
	if investor_category_label != null:
		investor_category_label.text = str(profile.get("category", "VENTURE_CAPITAL"))
	if investor_demand_label != null:
		investor_demand_label.text = str(profile.get("demand", "\"Make your pitch!\""))

	var btns: Array[Button] = _get_buttons_list()
	for i in range(btns.size()):
		var btn = btns[i]
		if btn != null and i < current_buzzwords.size():
			btn.text = "%d. %s" % [i + 1, current_buzzwords[i]]
			btn.disabled = false

	time_remaining = round_time_limit
	_update_timer_display()
	_update_streak_and_round_labels()

	if feedback_label != null:
		feedback_label.text = "SELECT THE MATCHING PROMISE FOR %s" % active_investor_type.to_upper()
		feedback_label.modulate = Color(0.8, 0.9, 1.0)

	round_started.emit(current_round, active_investor_type)

func _update_timer_display() -> void:
	if timer_progress_bar != null:
		timer_progress_bar.value = time_remaining
	if timer_label != null:
		timer_label.text = "%.1fs remaining" % maxf(0.0, time_remaining)
		if time_remaining <= 1.5:
			timer_label.modulate = Color(1.0, 0.3, 0.3)
		else:
			timer_label.modulate = Color(1.0, 0.85, 0.3)

func _update_streak_and_round_labels() -> void:
	if round_label != null:
		round_label.text = "ROUND %d / %d" % [mini(current_round + 1, total_rounds), total_rounds]
	if streak_label != null:
		var mult: float = 1.0 + float(current_streak) * 0.5
		streak_label.text = "STREAK: %d (%.1fx)" % [current_streak, mult]
		if current_streak > 0:
			streak_label.modulate = Color(0.2, 1.0, 0.5)
		else:
			streak_label.modulate = Color(0.7, 0.8, 0.9)

func _get_buttons_list() -> Array[Button]:
	var list: Array[Button] = []
	if buzzword_btn_0 != null: list.append(buzzword_btn_0)
	if buzzword_btn_1 != null: list.append(buzzword_btn_1)
	if buzzword_btn_2 != null: list.append(buzzword_btn_2)
	return list

func _disable_buttons() -> void:
	for btn in _get_buttons_list():
		if btn != null:
			btn.disabled = true

func _enable_buttons() -> void:
	for btn in _get_buttons_list():
		if btn != null:
			btn.disabled = false

func _play_feedback_juice(is_success: bool) -> void:
	var am = get_node_or_null("/root/AudioManager")
	if am != null:
		if am.has_method("play_sfx_qte_chime"):
			am.play_sfx_qte_chime(is_success)
		elif am.has_method("play_sfx_click"):
			am.play_sfx_click()

	var hm = get_node_or_null("/root/HapticsManager")
	if hm != null:
		if is_success:
			if hm.has_method("vibrate_button"): hm.vibrate_button()
		else:
			if hm.has_method("vibrate_error"): hm.vibrate_error()

	var tree = get_tree()
	if tree != null and tree.root != null:
		var m3d = tree.root.find_child("Main3D", true, false)
		if m3d != null and m3d.has_method("add_screen_shake"):
			m3d.add_screen_shake(0.20 if is_success else 0.10)
