# Demo script

[Stage direction: Demonstrate the blue and green environments on screen.]

Today we are showing two important protections: safe traffic change and automatic recovery. First, the current version continues to serve customers while the new version waits ready.

[Stage direction: Trigger the deployment and show the traffic switch to the new version.]

A new release is prepared and receives its own health check before visitors are moved to it. Once the checks pass, traffic moves without interruption.

[Stage direction: Stop the new application service to create the controlled fault.]

We now introduce a simple fault that represents the new version failing its health check. Nobody changes anything at the console.

[Stage direction: The automated monitor detects the failure and switches traffic back.]

The system notices repeated failures and starts recovery itself. The earlier version becomes the live version again before a person needs to respond.

[Stage direction: Show the confirmed healthy version and the rollback evidence.]

The rollback was confirmed in **ACTUAL_SECONDS seconds**, faster than ninety seconds and far faster than the four minutes the earlier manual process took.

[Stage direction: Close by connecting the result to customer and board risk.]

This means fewer failed payment requests, less interruption for customers, and an evidence trail showing exactly when recovery happened. The automatic result is the difference between hope and control.

*Spoken content: 208 words; replace ACTUAL_SECONDS only after the live rollback evidence is recorded.*
