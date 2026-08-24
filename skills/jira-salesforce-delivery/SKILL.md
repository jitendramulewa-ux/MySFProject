---
name: jira-salesforce-delivery
description: Deliver a Salesforce Jira story end to end by reading its requirements and subtasks, editing the current SFDX project, deploying with specified Apex tests, verifying acceptance criteria, and updating Jira. Use for explicit requests to implement, deploy, verify, or complete Jira stories in this Salesforce workspace.
---

# Jira Salesforce Delivery

Complete the requested Jira story with compact context and auditable evidence.

An explicit invocation such as `$jira-salesforce-delivery KAN-123` authorizes these in-scope actions for that story: read Jira, edit the current repository, deploy to the configured Salesforce org, create rollback-only verification data, and comment on or transition the story and its subtasks according to verified results. It does not authorize metadata deletion, deployment to another org, destructive data changes, broad permission grants, or unrelated Jira edits.

## Stable project context

- Jira site: `https://infobeans-team-f3ruyumb.atlassian.net`
- Jira cloud ID: `76fae9c3-4c08-4079-a3f9-00cd6a821a10`
- Default Salesforce target org: `orgfarm-be325a30c4-dev-ed`
- Verification user: `jitendra.mulewa.3551f693dbf4@agentforce.com`
- Salesforce project marker: `sfdx-project.json`
- Deterministic runner: `scripts/Invoke-JiraSalesforceDelivery.ps1`

## Workflow

1. Fetch the requested story and direct subtasks once. Request only `summary`, `description`, `status`, `issuetype`, `subtasks`, and comments that contain requirements or deployment evidence. Do not print complete connector payloads.
2. Translate the story and subtask descriptions into a concise acceptance checklist. Treat ambiguous business behavior as a blocker; do not invent it.
3. Inspect only relevant Salesforce source. Preserve unrelated working-tree changes.
4. Implement the smallest complete change. Every Apex class must have its matching `.cls-meta.xml`. Prefer scoped permission sets over broad profile changes.
5. Identify the relevant source paths and Apex test classes. If acceptance criteria are not fully covered by tests, create one temporary Anonymous Apex verification file whose test records are enclosed by a savepoint and rollback.
6. Run the deterministic runner from the project root:

   ```powershell
   powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "& {
     & '.\scripts\Invoke-JiraSalesforceDelivery.ps1' `
       -StoryKey 'KAN-123' `
       -SourcePath @('force-app/main/default/classes') `
       -TestClass @('FeatureServiceTest') `
       -VerificationFile 'scripts/apex/kan123Verification.apex'
   }"
   ```

   The process-scoped bypass is required by this Windows workspace and must not be replaced with a persistent machine-level execution-policy change.

   Omit `-VerificationFile` only when the specified Apex tests directly prove every acceptance criterion. Delete temporary verification files after execution.
7. Read only the runner's compact JSON. If deployment or verification fails, fix in-scope implementation errors and retry at most twice. Stop after the third failed deployment attempt and report the exact blocker.
8. Transition only verified subtasks to Done. Add one concise Jira comment to the story or implementation task containing the deployment ID, deployed components, test count, failures, coverage, and verification result. Do not mark failed or unverified work complete.
9. Report the outcome briefly. Include Jira status, deployment ID, test/coverage totals, remaining blockers, and uncommitted files.

## Interaction boundary

Do not pause for safe reads, in-scope edits, deployment to the configured org, rollback-only verification, or Jira transitions/comments covered by the explicit invocation. Pause only for missing authentication, another target org, destructive action, broader permissions, a materially ambiguous business requirement, or expansion beyond the requested story.

Keep model context small: use filtered queries, suppress raw CLI logs, batch independent Jira transitions, and avoid rereading unchanged issue or repository data.
