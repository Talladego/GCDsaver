# GCDsaver – Future Enhancements

1. **Multi-target ability handling**
   - Support abilities that can affect multiple target types (self, friendly, hostile) differently.
   - Allow configuration of which side(s) should be checked for an ability (e.g. only hostile, self + hostile, only friendly).
   - Improve internal target-selection logic to handle dual-purpose and context-sensitive abilities more accurately.

2. **Richer configuration UI**
   - Add a drag-and-drop interface to configure abilities: drag abilities from the hotbars into a configuration list.
   - Provide an overview / summary view listing all abilities that currently have checks configured.
   - Allow per-ability editing (stack count, immunity type, target side) from the UI instead of only shift-click cycling.

3. **Additional check types**
   - Extend beyond Immovable / Unstoppable / stack-count checks.
   - Add condition types based on player/target state, such as health-percent thresholds.
   - Explore integrating additional condition types inspired by `NerfedButtons` (now present in the workspace), such as positional, resource-based, or buff/debuff presence checks.
   - Keep the check system extensible so new condition types can be added without changing core logic.
