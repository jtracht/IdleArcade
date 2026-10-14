#!/usr/bin/env python3
"""
Milestone P4-M3 Verification Suite: NPCs, Quests, Collectibles, and Gated Zones.
================================================================================
Target: Godot 4.3 IdleArcade - Milestone P4-M3 (3D World Interactions)

Validates:
  1. File presence and scene architecture layout.
  2. Collectible3D contracts (Area3D, spinning/bobbing, pickup radius, special buffs, GameState hook).
  3. ZoneGate3D contracts (StaticBody3D, level clearance & energy check, collision disabling, signals).
  4. NPC3D & DialoguePanel contracts (billboard labels, quest markers, interaction area, input isolation).
  5. GameState campus quest state machine (start, advance, complete, signals, JSON serialization).
  6. Main3D campus integration (NPCs, gates, collectibles, quest tracker, dialogue panel instanced).
  7. Regression safety (M1, M2, and Phase 2 Nakama autoloads preserved).

Executable via: python tests/test_p4_m3_verify.py
"""

import os
import re
import sys
from pathlib import Path

def run_verification():
    print("=====================================================================")
    print("[VERIFY] Milestone P4-M3: 3D Interactions, Quests & Gated Zones Suite")
    print("=====================================================================")

    base_dir = Path(__file__).resolve().parent.parent
    scripts_dir = base_dir / "scripts"
    scenes_dir = base_dir / "scenes"
    tests_dir = base_dir / "tests"

    pass_count = 0
    fail_count = 0

    def assert_test(cond: bool, desc: str):
        nonlocal pass_count, fail_count
        if cond:
            print(f"  [PASS] {desc}")
            pass_count += 1
        else:
            print(f"  [FAIL] {desc}")
            fail_count += 1

    # =========================================================================
    # 1. File Existence & Architecture Layout
    # =========================================================================
    print("\n--- 1. File Existence & Architecture Layout ---")
    files_to_check = [
        scripts_dir / "collectible_3d.gd",
        scenes_dir / "collectible_3d.tscn",
        scripts_dir / "zone_gate_3d.gd",
        scenes_dir / "zone_gate_3d.tscn",
        scripts_dir / "npc_3d.gd",
        scenes_dir / "npc_3d.tscn",
        scripts_dir / "dialogue_panel.gd",
        scenes_dir / "dialogue_panel.tscn",
        scripts_dir / "quest_tracker.gd",
        scenes_dir / "quest_tracker.tscn",
        scripts_dir / "main_3d.gd",
        scenes_dir / "main_3d.tscn",
        scripts_dir / "avatar_3d.gd",
        scenes_dir / "avatar_3d.tscn",
        scripts_dir / "autoload" / "game_state.gd",
        scenes_dir / "main.tscn",
        base_dir / "project.godot"
    ]

    for f in files_to_check:
        rel = f.relative_to(base_dir).as_posix()
        assert_test(f.is_file(), f"{rel} exists")

    # =========================================================================
    # 2. Collectible3D Contracts
    # =========================================================================
    print("\n--- 2. Collectible3D Interface Contracts ---")
    collect_gd = (scripts_dir / "collectible_3d.gd").read_text(encoding="utf-8")
    collect_tscn = (scenes_dir / "collectible_3d.tscn").read_text(encoding="utf-8")

    assert_test("extends Area3D" in collect_gd, "collectible_3d.gd extends Area3D")
    assert_test("class_name Collectible3D" in collect_gd, "collectible_3d.gd defines class_name Collectible3D")
    assert_test("signal collected" in collect_gd, "collectible_3d.gd declares collected signal")
    assert_test("func collect(" in collect_gd, "collectible_3d.gd implements collect() method")
    assert_test("get_effective_pickup_radius" in collect_gd, "collectible_3d.gd scales with GameState.get_effective_pickup_radius")
    assert_test("collect_3d_item" in collect_gd, "collectible_3d.gd connects to GameState.collect_3d_item")
    assert_test("apply_speed_boost" in collect_gd, "collectible_3d.gd supports coffee speed boost")
    assert_test('groups=["collectibles"]' in collect_tscn or 'add_to_group("collectibles")' in collect_gd, "collectible is in 'collectibles' group")
    assert_test("CollisionShape3D" in collect_tscn, "collectible_3d.tscn has CollisionShape3D")

    # =========================================================================
    # 3. ZoneGate3D Contracts
    # =========================================================================
    print("\n--- 3. ZoneGate3D Interface Contracts ---")
    gate_gd = (scripts_dir / "zone_gate_3d.gd").read_text(encoding="utf-8")
    gate_tscn = (scenes_dir / "zone_gate_3d.tscn").read_text(encoding="utf-8")

    assert_test("extends StaticBody3D" in gate_gd, "zone_gate_3d.gd extends StaticBody3D")
    assert_test("class_name ZoneGate3D" in gate_gd, "zone_gate_3d.gd defines class_name ZoneGate3D")
    assert_test("signal gate_unlocked" in gate_gd, "zone_gate_3d.gd declares gate_unlocked signal")
    assert_test("func attempt_unlock(" in gate_gd, "zone_gate_3d.gd implements attempt_unlock()")
    assert_test("func open_gate(" in gate_gd, "zone_gate_3d.gd implements open_gate()")
    assert_test("get_idle_level" in gate_gd, "zone_gate_3d.gd checks idle level clearance")
    assert_test("unlock_zone" in gate_gd, "zone_gate_3d.gd calls GameState.unlock_zone")
    assert_test("disabled" in gate_gd, "zone_gate_3d.gd disables collision on gate open")
    assert_test("InteractionArea" in gate_tscn, "zone_gate_3d.tscn contains InteractionArea")
    assert_test("PromptLabel3D" in gate_tscn, "zone_gate_3d.tscn contains PromptLabel3D")

    # =========================================================================
    # 4. NPC3D & DialoguePanel Contracts
    # =========================================================================
    print("\n--- 4. NPC3D & DialoguePanel Contracts ---")
    npc_gd = (scripts_dir / "npc_3d.gd").read_text(encoding="utf-8")
    npc_tscn = (scenes_dir / "npc_3d.tscn").read_text(encoding="utf-8")
    dialogue_gd = (scripts_dir / "dialogue_panel.gd").read_text(encoding="utf-8")
    dialogue_tscn = (scenes_dir / "dialogue_panel.tscn").read_text(encoding="utf-8")

    assert_test("extends CharacterBody3D" in npc_gd, "npc_3d.gd extends CharacterBody3D")
    assert_test("class_name NPC3D" in npc_gd, "npc_3d.gd defines class_name NPC3D")
    assert_test("func interact(" in npc_gd, "npc_3d.gd implements interact()")
    assert_test("NameLabel3D" in npc_tscn, "npc_3d.tscn has billboard NameLabel3D")
    assert_test("PromptLabel3D" in npc_tscn, "npc_3d.tscn has PromptLabel3D")
    assert_test("QuestMarkerLabel3D" in npc_tscn, "npc_3d.tscn has QuestMarkerLabel3D")
    assert_test("InteractionArea" in npc_tscn, "npc_3d.tscn has InteractionArea")

    assert_test("class_name DialoguePanel" in dialogue_gd, "dialogue_panel.gd defines class_name DialoguePanel")
    assert_test("set_input_enabled(false)" in dialogue_gd, "DialoguePanel halts avatar input on open")
    assert_test("set_input_enabled(true)" in dialogue_gd, "DialoguePanel restores avatar input on close")
    assert_test("start_campus_quest" in dialogue_gd, "DialoguePanel connects to GameState.start_campus_quest")
    assert_test("complete_campus_quest" in dialogue_gd, "DialoguePanel connects to GameState.complete_campus_quest")
    assert_test("AcceptButton" in dialogue_tscn, "dialogue_panel.tscn contains AcceptButton")
    assert_test("CompleteButton" in dialogue_tscn, "dialogue_panel.tscn contains CompleteButton")

    # =========================================================================
    # 5. GameState Campus Quest Integration
    # =========================================================================
    print("\n--- 5. GameState Campus Quest Integration ---")
    gs_gd = (scripts_dir / "autoload" / "game_state.gd").read_text(encoding="utf-8")

    assert_test("signal campus_quest_updated" in gs_gd, "game_state.gd declares campus_quest_updated")
    assert_test("signal campus_quest_completed" in gs_gd, "game_state.gd declares campus_quest_completed")
    assert_test("var campus_quests" in gs_gd, "game_state.gd declares campus_quests")
    assert_test("func get_campus_quest_status(" in gs_gd, "game_state.gd implements get_campus_quest_status()")
    assert_test("func start_campus_quest(" in gs_gd, "game_state.gd implements start_campus_quest()")
    assert_test("func advance_campus_quest(" in gs_gd, "game_state.gd implements advance_campus_quest()")
    assert_test("func complete_campus_quest(" in gs_gd, "game_state.gd implements complete_campus_quest()")
    assert_test('"campus_quests": campus_quests.duplicate(true)' in gs_gd, "save_to_disk() serializes campus_quests")
    assert_test('data.get("campus_quests"' in gs_gd, "load_from_disk() deserializes campus_quests")

    # =========================================================================
    # 6. Main3D Campus Integration
    # =========================================================================
    print("\n--- 6. Main3D Campus Integration ---")
    main3d_gd = (scripts_dir / "main_3d.gd").read_text(encoding="utf-8")
    main3d_tscn = (scenes_dir / "main_3d.tscn").read_text(encoding="utf-8")

    assert_test("dialogue_panel" in main3d_gd, "main_3d.gd references dialogue_panel")
    assert_test("quest_tracker" in main3d_gd, "main_3d.gd references quest_tracker")
    assert_test("close_dialogue" in main3d_gd, "main_3d.gd handles ESC to dismiss dialogue")
    assert_test('res://scenes/npc_3d.tscn' in main3d_tscn, "main_3d.tscn instances npc_3d.tscn")
    assert_test('res://scenes/collectible_3d.tscn' in main3d_tscn, "main_3d.tscn instances collectible_3d.tscn")
    assert_test('res://scenes/zone_gate_3d.tscn' in main3d_tscn, "main_3d.tscn instances zone_gate_3d.tscn")
    assert_test('res://scenes/quest_tracker.tscn' in main3d_tscn, "main_3d.tscn instances quest_tracker.tscn")
    assert_test('res://scenes/dialogue_panel.tscn' in main3d_tscn, "main_3d.tscn instances dialogue_panel.tscn")
    assert_test('NPC_Alex' in main3d_tscn, "main_3d.tscn has NPC_Alex")
    assert_test('NPC_Bob' in main3d_tscn, "main_3d.tscn has NPC_Bob")
    assert_test('Gate_ServerRoom' in main3d_tscn, "main_3d.tscn has Gate_ServerRoom")
    assert_test('Gate_LabRoom' in main3d_tscn, "main_3d.tscn has Gate_LabRoom")

    # =========================================================================
    # 7. Regression Safety Oracle
    # =========================================================================
    print("\n--- 7. Regression Safety Oracle ---")
    proj_godot = (base_dir / "project.godot").read_text(encoding="utf-8")

    assert_test('run/main_scene="res://scenes/main.tscn"' in proj_godot, "project.godot main_scene preserved")
    assert_test('GameState="*res://scripts/autoload/game_state.gd"' in proj_godot, "GameState autoload singleton intact")
    assert_test('Nakama="*res://addons/com.heroiclabs.nakama/Nakama.gd"' in proj_godot, "Nakama autoload singleton intact")
    assert_test('NakamaManager="*res://scripts/autoload/nakama_manager.gd"' in proj_godot, "NakamaManager autoload singleton intact")

    print("\n=====================================================================")
    print(f"[VERIFY] P4-M3 Results: {pass_count} passed, {fail_count} failed")
    print("=====================================================================")

    if fail_count == 0:
        print(">>> ALL P4-M3 3D INTERACTION & QUEST VERIFICATIONS PASSED! <<<")
        return 0
    else:
        print(f">>> VERIFICATION FAILED WITH {fail_count} ERRORS! <<<")
        return 1

if __name__ == "__main__":
    sys.exit(run_verification())
