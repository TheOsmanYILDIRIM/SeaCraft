#!/usr/bin/env python3
from pathlib import Path
import sys
def main():
    log = Path(sys.argv[1]).read_text(encoding="utf-8", errors="replace")
    names = ["test_prg05_faction_reputation_and_hostility", "test_prg05_market_atomic_trade_price_and_lost_ack",
             "test_prg05_convoy_outpost_pvp_diminishing_and_events", "test_prg05_persistence_v5_migration_and_invalid_rejection",
             "test_prg05_reputation_controls_runtime_combat_hostility",
             "test_prg05_lan_host_intent_limits_price_and_identity_spoof",
             "test_prg05_ai03_world_convoy_outcome_to_live_market_is_authoritative_and_persistent",
             "test_prg05_ai04_far_world_arrival_and_sinking_settle_economy_once",
             "test_prg05_market_panel_mobile_intents_are_bounded_and_price_untrusted",
             "test_prg05_ai04_scheduler_dispatches_trade_once_and_restores_ledger",
             "test_prg05_ai04_scheduler_combat_loss_precedes_market_delivery",
             "test_prg05_lan_market_sector_range_and_authoritative_position_gate",
             "test_prg05_bounty_combat_proof_reward_and_intel_save_resume",
             "test_prg05_bounty_invalid_proofs_expiry_hostility_and_lan_spoof",
             "test_prg05_local_company_crew_payroll_persists_and_migrates_v1",
             "test_prg05_company_rejects_spoofed_roles_and_atomic_insufficient_wages"]
    markers = ["PRG05_FACTION_REPUTATION_OK", "PRG05_TRADE_ATOMIC_OK", "PRG05_CONVOY_OUTPOST_PVP_OK",
               "PRG05_PERSISTENCE_V5_OK", "PRG05_RUNTIME_DIPLOMACY_OK", "PRG05_LAN_HOST_GUARD_OK", "PRG05_CONVOY_WORLD_BRIDGE_OK", "PRG05_FAR_WORLD_BRIDGE_OK", "PRG05_MOBILE_MARKET_INTENT_OK",
               "PRG05_AI04_SCHEDULER_DELIVERY_OK", "PRG05_AI04_SCHEDULER_LOSS_OK",
               "PRG05_LAN_MARKET_ACCESS_GUARD_OK",
               "PRG05_BOUNTY_INTEL_COMBAT_SAVE_OK", "PRG05_BOUNTY_PROOF_GUARD_OK", "PRG05_COMPANY_CREW_PAYROLL_SAVE_OK",
               "PRG05_COMPANY_CREW_HOST_GUARD_OK"]
    if "res://tests/unit/test_prg05_economy.gd" not in log:
        raise SystemExit("PRG-05 GUT script not executed")
    for row in names + markers:
        if row not in log:
            raise SystemExit("PRG-05 missing " + row)
    print(f"PRG05_VERIFIER_OK tests={len(names)} markers={len(markers)}")
if __name__ == "__main__":
    main()
