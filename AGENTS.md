# PowerShell Project Rules

These rules apply to the `ozzygit/M365-SysAdmin-Automation` repository. Universal behavior is defined in the user-level `AGENTS.md`.

## Project scope

- This repository contains PowerShell automation for Microsoft 365, Microsoft Entra ID, Active Directory, Intune, SharePoint, Exchange Online, and Windows endpoints.
- Target PowerShell 7 unless a script explicitly requires Windows PowerShell 5.1 compatibility.
- Save new PowerShell scripts to this repository root (not to the user's Documents\PowerShell-Output folder).
- Save generated CSV, TXT, MD, DOCX, and similar outputs outside the repository using the runtime-resolved Documents folder.

## PowerShell implementation

- Use `[CmdletBinding()]` and a typed `param()` block for production scripts and reusable functions.
- Use approved verbs and singular nouns for new functions.
- Use `[CmdletBinding(SupportsShouldProcess)]` and `$PSCmdlet.ShouldProcess()` for state-changing operations.
- Set `#Requires -Version` to the actual dependency minimum. ExchangeOnlineManagement 3.10.0 requires PowerShell 7.6 or later under PowerShell Core; Windows PowerShell 5.1 is unaffected. Do not auto-install modules.
- Use `#Requires -Modules` only when eager module import is safe. Follow the Graph/EXO exception below.
- Set `$ErrorActionPreference = 'Stop'` in critical scripts.
- Return structured `[PSCustomObject]` data. Reserve `Write-Host` for interactive progress and status.
- Use timestamped output filenames and `Export-Csv -NoTypeInformation -Encoding UTF8`.
- Use functions for reusable or complex logic. Keep the main execution flow linear.
- Wrap collection results in `@()` where zero, one, or many values are possible.
- Do not declare `[switch]` parameters with a default of `$true`. For default-on behavior, detect whether the caller supplied the switch through `$PSBoundParameters` so `-SwitchName:$false` remains supported.
- PowerShell control-flow blocks such as `if`, `foreach`, `switch`, `try`, and `catch` do not create child scopes.
- Without strict mode, property access on `$null` returns `$null`, and `@($null.Property)` is an empty array. Verify behavior under the script's actual strict-mode setting before reporting a null-reference defect.

## Data accuracy and evidence semantics

- Match external API and CSV field names to their documented or empirically observed spelling and casing.
- For D7/D30/D90/D180 comparisons, use the inclusive calendar window `refreshDate.Date.AddDays(-(periodDays - 1))` and compare `.Date -ge`.
- A positive provisioning hint can prove that a resource exists. Its absence cannot prove non-provisioning when the authoritative lookup is unavailable. Return `Unknown` and mark coverage incomplete.
- Emit zero only when collection succeeded and found no items. Emit null when the value is unavailable because collection was missing, partial, or failed. Interpret counts with their coverage status.
- Never substitute a fallback timestamp or zero merely to populate an empty cell.
- Before adding a repeated permission check, trace startup preconditions and required-permission gates.
- Interpret `Get-ADTrust` output with `ForestTransitive = True` as a forest trust; `TrustType = Uplevel` is valid and does not need to display `Forest`.
- For audit records about child resources, map the documented parent identifier, such as Planner `PlanId`, before treating the parent workload as completely measured.
- Delegated Graph access is limited by the signed-in user's resource access. Tenant-wide Planner and SharePoint inventories must mark inaccessible groups as partial coverage and must not claim app-only equivalence.
- Complete tenant-wide SharePoint site enumeration requires an app registration using application `Sites.Read.All` or a more privileged approved application permission. Delegated authentication cannot enumerate every site and must not be used when complete site inventory is required.

## Error handling and recovery

- Use `try/catch/finally` around operations that need source-specific reporting or cleanup.
- Every catch must report or log the original error unless it is an explicitly documented, safe best-effort operation whose failure does not affect correctness.
- Read and diagnose the complete error before changing code. Do not retry blindly or suppress symptoms.
- If a correction is proven and requires no user action, apply it and rerun the current verification gate without requesting routine approval.
- Ask the user when authentication, tenant configuration, permissions, destructive action, or another user decision is required.
- A child-process worker must persist unhandled error details for its parent before exiting. Do not reduce failures to an exit code alone.

## Incremental verification

- Divide non-trivial changes into small logical batches. Do not combine schema, collector, validation, and documentation work in one unverified batch.
- Before writing a non-trivial multiline or quote-sensitive PowerShell change, apply it to an in-memory candidate and parse the complete candidate with `[System.Management.Automation.Language.Parser]::ParseInput()`.
- After each batch, parse the actual file with `[System.Management.Automation.Language.Parser]::ParseFile()`, run relevant PSScriptAnalyzer rules, and run focused behavior tests.
- Do not start the next batch until the current batch passes.
- If parser errors cascade, inspect the earliest changed string, here-string, or script block. Prove the proposed fix against an in-memory candidate before editing.
- Parse temporary PowerShell test files before executing them.
- Keep verification code explicit: use scriptblock filters, named loop variables, and confirmed output properties instead of compressed one-liners.
- Never report completion from a plausible diff alone. Run the changed path safely when authentication and permissions allow it.

## Runtime and module selection

- Resolve PowerShell 7 in this order: `pwsh.exe`, then `C:\Program Files\PowerShell\7\pwsh.exe`.
- Scripts that import ExchangeOnlineManagement 3.10.0 under PowerShell Core must require and run PowerShell 7.6 or later.
- Use `powershell.exe` only for scripts explicitly documented as Windows PowerShell 5.1 compatible. Never bypass a script's `#Requires` version.
- Verify every required tool and module before use. Do not install or update software without explicit approval.

## Secrets and repository visibility

- Never commit secrets, tokens, passwords, private keys, identifiers, or certificate private-key material.

## Microsoft Graph dependency preload

For scripts that preload shared DLLs from the installed `Microsoft.Graph.Authentication` module before importing other modules:

- In PowerShell 7, preload only `Dependencies` and `Dependencies\Core`.
- Never load `Dependencies\Desktop`; its .NET Framework assemblies are incompatible with .NET Core and can cause `System.Net.Http.WinHttpHandler` manifest errors.
- Do not try to solve this conflict by changing Graph module versions. Exclude the Desktop dependency path.

## Graph and Exchange Online process isolation

Do not run interactive Exchange Online authentication and `Microsoft.Graph.Authentication` in the same process.

- Loading Graph before or after Exchange Online can trigger the MSAL/WAM failures tracked in microsoftgraph/msgraph-sdk-powershell issues 3394 and 3576.
- Keep Exchange Online work in an isolated child `pwsh` process that never imports Graph.
- Do not list `Microsoft.Graph.Authentication` in `#Requires -Modules` for a script whose EXO child executes the same file. `#Requires` imports modules before the worker branch runs.
- Check Graph module availability at runtime and import it only in the parent process.

## EXO worker authentication

- Spawn the EXO worker with its own console. Do not use `Start-Process -NoNewWindow`; WAM requires a valid parent window handle.
- Before WAM authentication, make a best-effort call to `SetForegroundWindow(GetConsoleWindow())` so the account picker is visible.
- Use normal browser/WAM authentication when interactive authentication is requested. Use device code only when explicitly requested.
- Graph and EXO are isolated and therefore require separate interactive prompts.
- Inspect installed cmdlet parameters before forwarding authentication options. Microsoft.Graph.Authentication 2.38.1 uses `Connect-MgGraph -UseDeviceCode`; ExchangeOnlineManagement 3.10.0 uses `Connect-ExchangeOnline -Device`.
- An explicit interactive switch overrides default certificate and client-secret parameters.
- Before using a custom app for delegated authentication, verify both public-client redirect configuration and the requested delegated permissions with admin consent. Application roles do not satisfy delegated scopes.
- Do not use `Connect-ExchangeOnline -DisableWAM` as the primary fix for the verified process-conflict issue.
- Preserve child error details in a temporary error file and include them in the parent exception.

## Graph context interpretation

- Certificate contexts report `AuthType = 'AppOnly'` and populate `.Scopes` with app roles.
- Delegated contexts populate `.Scopes` with delegated scopes.
- It is valid to test `.Scopes` for a named permission. Use `AuthType`, not a non-empty `.Scopes` collection, when distinguishing delegated from app-only authentication.