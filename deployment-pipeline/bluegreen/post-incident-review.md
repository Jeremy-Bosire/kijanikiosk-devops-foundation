# Post-incident review: wrong-environment deployment

## 1. Incident summary
Nia requested a production demonstration, but the delivery pipeline ran against the wrong environment during the investor walkthrough and made staging unavailable for 48 seconds. The response restored normal service, but the event exposed a configuration gap that could place customer traffic at risk.

## 2. Timeline
- Walkthrough began: time not retained in the narrative; marked estimated at the start of the scheduled investor demonstration.
- Pipeline triggered: estimated within one minute of the walkthrough beginning.
- Wrong environment targeted: immediately after triggering, when the pipeline selected the staging path from unvalidated configuration.
- Error detected: approximately 09:16, based on the narrative that errors appeared within one minute of the trigger; exact seconds unavailable.
- Resolved: approximately 48 seconds after staging unavailability began, reconstructed from the recorded unavailability duration.
- Normal service confirmed: immediately after the environment was corrected and the health response returned normally.

## 3. Root cause
The configuration gap allowed environment selection without proving that the requested target matched deployment evidence. Why was the wrong environment selected? Because a shared pipeline variable supplied an ambiguous target. Why was that variable ambiguous? Because no approved value set distinguished staging from production. Why was the pipeline allowed to use it? Because validation happened late and checked syntax rather than authorization. Why did validation not stop the run? Because no hard target-policy gate existed before deployment commands. The structural finding is that environment identity and release promotion were not enforced as separate, protected inputs.

## 4. Contributing factors
The walkthrough pressure reduced review time, the pipeline reused configuration across environments, and operators lacked a visible confirmation of the selected target before traffic changed. The health check was useful after impact but did not prevent the initial routing mistake.

## 5. What went well
The team detected the availability loss quickly, restored service within the recorded 48-second incident, and retained enough evidence to reconstruct the event and scope the resulting controls.

## 6. Action items
1. **Owner: Release engineering lead — within 2 weeks:** Add a target allowlist that permits only named environments and reject configuration outside the allowlist before any deployment action.
2. **Owner: Platform engineering lead — within 3 weeks:** Add a pre-deployment policy gate that compares the pipeline identity, environment, and artifact digest, returning the same explicit approval result for every promotion.
3. **Owner: Site reliability lead — within 4 weeks:** Require a human-readable active-target confirmation and protected health evidence in the deployment record before accepting a traffic switch.
4. **Owner: Engineering manager — within 30 days:** Add a rehearsed wrong-target drill to release qualification and require a clean rollback demonstration before production approval.
