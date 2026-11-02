# Deployment choices for Nia

Kijani Kiosk now has two ways to deliver the payments service. Blue and green delivery keeps two complete copies of the service available and changes which copy receives visitors. Containers package the same service into a consistent unit that can be started, stopped, and replaced on a managed cluster. The evidence supporting this choice is strongest for the first approach today: our staged test records must be collected on the actual staging and cluster environments. The container image was measured locally, while the automatic recovery measurement remains pending because this workspace has not yet been connected to Kubernetes.

The commercial question is recovery confidence, not fashion. The first approach gives an explicit return path: the current version remains live while the next version is prepared. The second gives the platform a standard replacement mechanism: the desired number of copies is declared, and the system works to keep that number available. Both can reduce customer impact, but they recover in different ways and require different operational habits.

| Concern | Blue/green approach | Container approach |
|---|---|---|
| Deployment mechanism | One copy is active and the other is ready; a switch changes visitor routing. | A versioned package is placed onto managed machines and started as two copies. |
| Rollback mechanism | The monitor detects failures and returns visitor routing to the previously active copy. | A damaged copy is removed and replaced by a known package, with running copies preserving service. |
| Failure recovery | The route can return to the known good copy, subject to health checks and state confirmation. | The platform detects an unhealthy or deleted copy and creates a replacement. |
| Scaling | Capacity is increased by preparing additional service capacity and routing visitors appropriately. | Desired capacity can be described once and distributed across available machines. |

Our local production image measures 239 MB and the comparable unrefined image measures 269 MB, so the production package is 30 MB smaller. That is a meaningful storage and transfer improvement, though it is not the same as a measured customer recovery result. The reduction also reflects a two-part build: software is compiled in a temporary environment, while the final package receives only the runtime files and a dedicated service account.

The blue and green approach is also directly responsible for the rollback objective. It provides an understandable pause point: both versions exist, traffic remains observable, and the previous state can be restored. The remaining measurement is whether the complete fault-to-recovery cycle stays below ninety seconds. The demonstration script and evidence file deliberately leave the actual number as pending until a real controlled fault is introduced.

For container recovery, the specific self-healing result is also pending. The requirement is to delete one copy and measure the time until a replacement is running, then compare that result against the traffic-switch result. We should not report a substitute from a container restart; it would not prove the cluster replacement behavior. A reliable board number is the timestamped deletion-to-replacement result from the live cluster.

Container delivery improves repeatability and replacement, but it does not automatically provide a zero-downtime deployment strategy, proven application recovery, secret handling, or business policy. The next orchestration project adds more detailed readiness decisions, controlled release sequencing, and stronger automation around application health. It may also add automatic scaling, but any claim about that benefit should still be tied to measured demand.

## What is still required before the board decision

Complete the staged traffic switch and controlled fault, record the exact rollback time, and place the current production package on the private registry. Then run the two-copy deployment on the cluster, delete one copy, and record the timestamped replacement. Those two numbers, together with the image-size evidence, will give Nia a defensible comparison rather than an estimate. The complete decision should combine customer impact, recovery speed, operating effort, and the cost of retaining two deployment approaches.

In summary, blue and green offers a highly visible rollback boundary today. Containers offer a consistent package and machine-level replacement path for the future. The decision should adopt both only after the evidence is complete: one demonstrates rapid return to service, the other demonstrates that damaged instances can be recreated without direct intervention.