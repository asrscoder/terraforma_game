# Combat System Design (draft)

Status: design locked, ready to implement. Ground combat foundation only (naval/air deferred).

## 1. Trigger

- Manually triggered by the player: kingdom vs kingdom war.
- All of the attacker's soldiers march on the defender's capital village.

## 2. Resolution model

- HP/damage over time. Units walk into range, swing, HP drops, retreat at low HP.
- Ranged units fire from range; melee units close in.
- Instant-hit ranged (no projectiles) for v1; projectiles later.

## 3. Weapons (era-gated)

Data table `scr_weapon_stats(weapon_id)` -> { damage, range, cooldown, is_ranged }.

| Era | Melee | Ranged | Ratio (melee:ranged) |
|-----|-------|--------|----------------------|
| 1   | Club (range 1) | Sling (range 4) | 3:1 |
| 2   | Sword (range 1) | Bow (range 6) | 1:1 |
| 3   | Spear (range 2) | Crossbow (range 7) | 1:2 |
| 4   | (future) | (future) | TBD |

- Soldiers get a loadout at spawn/upgrade time based on era + ratio (configurable in scr_era_rules).
- Non-soldiers (villager/farmer/miner/builder/leader) do not fight; they are never targeted and stay housed in their buildings.

## 4. Unit stats (added to scr_apply_unit_type for "soldier")

- hp, hp_max, atk, def, range, attack_cooldown, attack_timer, weapon, retreat_threshold (e.g. 0.2).

## 5. Engagement flow

1. Player triggers war: attacker soldiers path to target capital village centre.
2. On arrival / contact: soldiers engage nearest enemy soldier within range.
3. Each tick: if target in range, decrement attack_timer; on 0, apply damage = max(1, atk - def), reset timer.
4. Watchtowers auto-attack enemies in radius (garrison bonus).
5. Retreat when HP < retreat_threshold * hp_max (path back to source or nearest friendly village).
6. Death: remove unit from member_ids, building residents, decrement counts; scr_assign_roles rebalances next scan.

## 6. Capture

- Capture condition: all defender soldiers + barracks + town hall + watchtowers destroyed.
- On capture: village transfers to attacker — buildings, civilians, and resources stay; only kingdom_id changes.
- Surviving defender soldiers convert to the attacker's kingdom.
- Attacker survivors garrison the village (or return home).

## 7. Performance

- Combat tick budgeted like the pathfinder (per-frame cap).
- Only process units with an active engagement or within combat radius.

## 8. Rules

- No cooldown: can attack multiple kingdoms at once.

## 9. Deferred (v2+)

- Naval/air combat.
- Projectiles & line of sight.
- Walls/fortifications beyond watchtowers.
- Morale, terrain bonuses, formations.