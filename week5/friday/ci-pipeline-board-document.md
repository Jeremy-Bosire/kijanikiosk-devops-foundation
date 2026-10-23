# How KijaniKiosk Checks Every Change Before It Reaches Customers

*Prepared for the board review. Owner: Engineering.*

## Why this matters

KijaniKiosk moves money. One mistake in a fee calculation, or one weak component borrowed from the internet, can cost customers money and us their trust. Until now, deciding whether a change was "ready" depended on developers remembering to run checks on their own laptops, which leaves no record.

We now have an automated quality line. Every time a developer saves a change to our shared code, the same set of checks runs in the same clean, controlled environment, in the same order, every time. Only changes that pass every check become an approved, labelled version that we can later release.

## What happens after a developer saves a change

Within two minutes the system notices the change and starts work, always in an identical, fixed workspace, so a result today means the same as a result next month.

| Step | What it confirms | If it fails |
|---|---|---|
| 1. Style check | The code follows our agreed writing rules and has no obvious slips. | Stops immediately. Nothing else runs. |
| 2. Assemble | The change can be put together into a working product. | Stops. Nothing is tested or saved. |
| 3a. Behaviour tests | Fees, limits and amounts are calculated exactly as intended. | Stops before anything is saved. |
| 3b. Security scan | None of the outside components we rely on has a known serious weakness. | Stops before anything is saved. |
| 4. Package and seal | The finished package contains everything it should, and a unique fingerprint is recorded. | Stops. Nothing is sent to storage. |
| 5. Store | The sealed package is placed in our private, access-controlled storage under a unique label. | The existing version stays untouched. |

Steps 3a and 3b run side by side. A full successful run takes between one and four minutes.

## Why every version has a unique label

Each approved package is labelled with a version number plus a short code that points to the exact change it came from, for example **1.0.0-6ef4eb6**. For a financial services platform this matters in three ways:

- **Traceability.** If a customer reports a problem, we can name the exact change that produced the software they used.
- **No silent replacement.** Our storage refuses to accept a second, different package under a label that already exists. What was approved is what gets released.
- **Safe rollback.** Every previous approved version is kept, so we can return to a known-good one quickly.

## What Happens When Something Goes Wrong

We deliberately broke the process in six different ways to prove how it behaves. In every case the outcome was the same promise: **a change that fails any check never becomes an approved version, and the last good version stays exactly as it was.**

- A careless coding slip stopped the process at the first step within seconds.
- When we changed one fee from KES 7.00 to KES 7.50, the behaviour tests caught it and named the exact wrong figure. The security scan still finished alongside, so the developer saw every problem at once. Nothing was stored.
- When we added an outside component with a publicly known weakness, everything else passed, but the security scan blocked it.
- When the package was missing part of its contents, the sealing step caught it before it could reach storage.
- When someone tried to store a second package under an existing label, storage refused it.

Each time, the developer receives a failure notice naming the change, the step that failed and a link to the details, and the team is told when the status changes from passing to failing, and back again. The fix is to correct the change and save it again. We confirmed the process returned to passing after every one of the six tests.

## What this does not yet do

This system decides whether a change is fit to release; it does not release it. Approved packages are stored, but putting them in front of customers is still a separate, manual step, planned for the next phase. Failure notices currently appear in the system's own records rather than in email or chat. The quality line runs on a single machine, so it is not yet built to withstand that machine failing, and it has not been tested with forty developers saving changes at once. Our tests cover the core fee and amount logic, not every part of the platform, so passing means "meets the standards we have written down", not "cannot fail".
