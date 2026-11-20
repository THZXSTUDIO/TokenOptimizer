[CmdletBinding()]
param()
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$router = Join-Path $root 'scripts\Invoke-AgentRouter.ps1'
$slicer = Join-Path $root 'scripts\Invoke-ContextSlice.ps1'
$tempRoot = Join-Path (Join-Path $env:USERPROFILE 'Documents') ('TokenOptimizer-0.7-tests-' + [guid]::NewGuid().ToString('N'))
$project = Join-Path $tempRoot 'UniversalProject'
$passed = 0
$failed = 0

function Assert-True([bool]$Condition,[string]$Message) {
    if (-not $Condition) { throw "ASSERT FAILED: $Message" }
}
function Assert-Contains([string]$Text,[string]$Value,[string]$Message) {
    if (-not $Text.Contains($Value)) { throw "ASSERT FAILED: $Message | missing: $Value" }
}
function Assert-NotContains([string]$Text,[string]$Value,[string]$Message) {
    if ($Text.Contains($Value)) { throw "ASSERT FAILED: $Message | unexpected: $Value" }
}
function Pass([string]$Name) {
    $script:passed++
    Write-Output "PASS | $Name"
}

try {
    $dirs = @(
        'apps\web\src\auth flow',
        'services\Auth',
        'services\Inventory',
        'python',
        'go\internal\auth',
        'docs',
        'node_modules\fake-package',
        'src_backup_2026',
        'generated',
        'misc\handlers',
        'TokenOptimizer'
    )
    foreach ($dir in $dirs) { New-Item -ItemType Directory -Path (Join-Path $project $dir) -Force | Out-Null }

    $ts = Join-Path $project 'apps\web\src\auth flow\LoginForm.tsx'
    $cs = Join-Path $project 'services\Auth\AuthService.cs'
    $inventory = Join-Path $project 'services\Inventory\InventoryService.luau'
    $py = Join-Path $project 'python\auth_service.py'
    $go = Join-Path $project 'go\internal\auth\handler.go'
    $doc = Join-Path $project 'docs\auth-flow.md'
    $dependency = Join-Path $project 'node_modules\fake-package\AuthService.ts'
    $backup = Join-Path $project 'src_backup_2026\InventoryService.py'
    $generated = Join-Path $project 'generated\AuthRecord.cs'
    $genericDb = Join-Path $project 'misc\handlers\StoreCoordinator.luau'
    $remoteNoise = Join-Path $project 'misc\handlers\RemoteNoise.luau'
    $visualCatalog = Join-Path $project 'misc\handlers\VisualCatalog.luau'

    @'
export async function LoginUser(token: string) {
    return authService.Authenticate(token);
}
const UNRELATED_SECRET_MARKER = "never include this in model context";
'@ | Set-Content -LiteralPath $ts -Encoding UTF8
    @'
public sealed class AuthService {
    public bool Authenticate(string token) {
        return tokenService.ValidateToken(token);
    }
}
const string UNRELATED_SECRET_MARKER = "never include this in model context";
'@ | Set-Content -LiteralPath $cs -Encoding UTF8
    @'
-- COMMENT_ONLY_MARKER action equip unequip must not be selected as code evidence
local HEADER_ONLY_MARKER = "DataStoreService is declared near the top"
local DataStoreService = game:GetService("DataStoreService")
local store = DataStoreService:GetDataStore("Inventory")

local function loadPlayer(player)
    local LOAD_LIFECYCLE_MARKER = store:GetAsync("User_" .. player.UserId)
    return LOAD_LIFECYCLE_MARKER
end

local function savePlayer(player)
    local SAVE_LIFECYCLE_MARKER = store:UpdateAsync("User_" .. player.UserId, function(old)
        return old
    end)
    return SAVE_LIFECYCLE_MARKER
end

local function handleEquipment(action)
    if action == "equip" then
        local EQUIP_ACTION_MARKER = true
    elseif action == "unequip" then
        local UNEQUIP_ACTION_MARKER = true
    end
end
local function validateRequest(st, owned, now)
    if not st.loaded then error("LOAD_GUARD_MARKER") end
    if not owned or owned.Value <= 0 then error("OWNERSHIP_GUARD_MARKER") end
    if now - (st.last or 0) < 0.3 then error("RATE_GUARD_MARKER") end
    st.noSave = true -- NOSAVE_GUARD_MARKER
end
game:BindToClose(function()
    local CLOSE_LIFECYCLE_MARKER = true
end)
Players.PlayerAdded:Connect(function() local PLAYER_ADDED_MARKER = true end)
Players.PlayerRemoving:Connect(function() local PLAYER_REMOVING_MARKER = true end)
'@ | Set-Content -LiteralPath $inventory -Encoding UTF8

    @'
def ValidateToken(token: str) -> bool:
    return token.startswith("auth_")

UNRELATED_SECRET_MARKER = "never include this in model context"
'@ | Set-Content -LiteralPath $py -Encoding UTF8
    @'
package auth

func HandleToken(token string) bool {
    return token != ""
}

// UNRELATED_SECRET_MARKER must never be emitted.
'@ | Set-Content -LiteralPath $go -Encoding UTF8
    '# AUTH FLOW DOC' | Set-Content -LiteralPath $doc -Encoding UTF8
    'export class AuthService {}' | Set-Content -LiteralPath $dependency -Encoding UTF8
    'class InventoryService: pass' | Set-Content -LiteralPath $backup -Encoding UTF8
    'class AuthRecord {}' | Set-Content -LiteralPath $generated -Encoding UTF8
    @'
local function loadAccount(player)
    return accountStore:GetAsync("User_" .. player.UserId)
end
local function saveAccount(player)
    return accountStore:UpdateAsync("User_" .. player.UserId, function(old)
        return old
    end)
end
'@ | Set-Content -LiteralPath $genericDb -Encoding UTF8
    @'
local remote = game:GetService("ReplicatedStorage").RemoteEvent
remote.OnServerEvent:Connect(function(player, payload)
    print(player.Name, payload)
end)
'@ | Set-Content -LiteralPath $remoteNoise -Encoding UTF8
    @'
local armorModels = ServerStorage:FindFirstChild("EquipmentModels")
local icons = ReplicatedStorage:FindFirstChild("InventoryIcons")
return armorModels, icons
'@ | Set-Content -LiteralPath $visualCatalog -Encoding UTF8

    $before = @($ts,$cs,$py,$go,$genericDb,$remoteNoise,$visualCatalog | ForEach-Object { (Get-FileHash -LiteralPath $_ -Algorithm SHA256).Hash })

    $tokens=$null; $errors=$null
    [System.Management.Automation.Language.Parser]::ParseFile($router,[ref]$tokens,[ref]$errors) | Out-Null
    Assert-True ($errors.Count -eq 0) 'Universal router parses on Windows PowerShell 5.1.'
    Pass 'Router PowerShell 5.1 syntax'

    $tokens=$null; $errors=$null
    [System.Management.Automation.Language.Parser]::ParseFile($slicer,[ref]$tokens,[ref]$errors) | Out-Null
    Assert-True ($errors.Count -eq 0) 'Universal slicer parses on Windows PowerShell 5.1.'
    Pass 'Slicer PowerShell 5.1 syntax'

    $routeOutput = @(& $router -Query 'AUTH LOGIN TOKEN VALIDATION' -ProjectRoot $project -MaxSeedFiles 12)
    $routeText = $routeOutput -join [Environment]::NewLine
    $planPath = [regex]::Match($routeText,'(?m)^PLAN=(.+)$').Groups[1].Value.Trim()
    Assert-True ([IO.File]::Exists($planPath)) 'Router creates a readable plan under the project root.'
    $planText = [IO.File]::ReadAllText($planPath)
    Assert-Contains $planText 'LoginForm.tsx' 'TypeScript/React files are discoverable.'
    Assert-Contains $planText 'AuthService.cs' 'C# files are discoverable.'
    Assert-Contains $planText 'auth_service.py' 'Python files are discoverable.'
    Assert-Contains $planText 'handler.go' 'Go files are discoverable.'
    Assert-NotContains $planText 'node_modules' 'Dependencies are excluded.'
    Assert-NotContains $planText 'src_backup_2026' 'Backup source trees are excluded.'
    Assert-NotContains $planText 'AuthRecord.cs' 'Generated code directories are excluded.'
    Assert-NotContains $planText 'auth-flow.md' 'Documentation is not included in normal code routing.'
    Pass 'Universal multi-language discovery and default exclusions'

    $contentRouteOutput = @(& $router -Query 'AUTH LOGIN' -DiscoveryTerms 'GetAsync UpdateAsync Inventory Equipment' -ProjectRoot $project -MaxSeedFiles 12)
    $contentRouteText = $contentRouteOutput -join [Environment]::NewLine
    $contentPlanPath = [regex]::Match($contentRouteText,'(?m)^PLAN=(.+)$').Groups[1].Value.Trim()
    $contentPlan = [IO.File]::ReadAllText($contentPlanPath)
    Assert-Contains $contentPlan 'StoreCoordinator.luau' 'Content discovery finds a relevant file with a generic filename and directory.'
    Assert-Contains $contentPlan 'VisualCatalog.luau' 'Content discovery recognizes separate CamelCase components in identifiers.'
    Assert-Contains $contentRouteText 'contentFiles=' 'Router reports the number of files content-scanned.'
    $noiseRouteOutput = @(& $router -Query 'INVENTORY EQUIPMENT' -DiscoveryTerms 'OnServerEvent FireServer' -ProjectRoot $project -MaxSeedFiles 12)
    $noiseRouteText = $noiseRouteOutput -join [Environment]::NewLine
    $noisePlanPath = [regex]::Match($noiseRouteText,'(?m)^PLAN=(.+)$').Groups[1].Value.Trim()
    $noisePlan = [IO.File]::ReadAllText($noisePlanPath)
    Assert-NotContains $noisePlan 'RemoteNoise.luau' 'A generic remote-event file is not promoted by event names alone.'
    $visualPlan = Join-Path (Join-Path $project 'TokenOptimizer') 'visual-plan.md'
    @'
# CamelCase component test
- [seed] misc/handlers/VisualCatalog.luau | score 10
'@ | Set-Content -LiteralPath $visualPlan -Encoding UTF8
    $visualOutput = @(& $slicer -PlanPath $visualPlan -ProjectRoot $project -Terms 'Inventory Equipment' -MaxFiles 1 -MaxSnippetsPerFile 2 -ContextLines 1 -MaxLinesPerFile 12 -MaxTotalLines 12)
    $visualText = $visualOutput -join [Environment]::NewLine
    Assert-Contains $visualText 'EquipmentModels' 'Slicer matches the first CamelCase identifier component.'
    Assert-Contains $visualText 'InventoryIcons' 'Slicer matches the second CamelCase identifier component.'
    Pass 'Bounded content discovery finds generic-name files, handles CamelCase, and filters event noise'

    $sliceOutput = @(& $slicer -PlanPath $planPath -ProjectRoot $project -Symbols 'LoginUser,Authenticate,ValidateToken,HandleToken' -MaxFiles 12 -MaxSnippetsPerFile 2 -ContextLines 1 -MaxLinesPerFile 14 -MaxTotalLines 60)
    $sliceText = $sliceOutput -join [Environment]::NewLine
    Assert-Contains $sliceText 'LoginUser' 'TypeScript symbol is extracted.'
    Assert-Contains $sliceText 'Authenticate' 'C# symbol is extracted.'
    Assert-Contains $sliceText 'ValidateToken' 'Python symbol is extracted.'
    Assert-Contains $sliceText 'HandleToken' 'Go symbol is extracted.'
    Assert-Contains $sliceText (([string][char]96 * 3) + 'tsx') 'TSX uses the correct code fence.'
    Assert-Contains $sliceText (([string][char]96 * 3) + 'csharp') 'C# uses the correct code fence.'
    Assert-Contains $sliceText (([string][char]96 * 3) + 'python') 'Python uses the correct code fence.'
    Assert-Contains $sliceText (([string][char]96 * 3) + 'go') 'Go uses the correct code fence.'
    Assert-Contains $sliceText 'auth flow' 'Paths containing spaces are handled.'
    Assert-NotContains $sliceText 'UNRELATED_SECRET_MARKER' 'Unrelated far-away lines never enter the context pack.'
    Assert-Contains $sliceText 'lines=' 'The slicer reports emitted line count.'
    Pass 'Universal symbol extraction, language fences, spaces and bounded context'

    $rankPlan = Join-Path (Join-Path $project 'TokenOptimizer') 'rank-plan.md'
    @'
# Ranked candidates
- [seed] apps/web/src/auth flow/LoginForm.tsx | score 1 | hits: login
- [seed] services/Auth/AuthService.cs | score 99 | hits: auth
'@ | Set-Content -LiteralPath $rankPlan -Encoding UTF8
    $rankOutput = @(& $slicer -PlanPath $rankPlan -ProjectRoot $project -Symbols 'Authenticate' -MaxFiles 1 -MaxLinesPerFile 8 -MaxTotalLines 8 -ContextLines 0)
    $rankText = $rankOutput -join [Environment]::NewLine
    Assert-Contains $rankText 'AuthService.cs' 'Highest-scored seed is inspected first.'
    Assert-NotContains $rankText 'LoginForm.tsx' 'Lower-scored seed remains outside the file budget.'
    Pass 'Relevance score ordering is applied before the file budget'

    $balancedPlan = Join-Path (Join-Path $project 'TokenOptimizer') 'balanced-plan.md'
    @'
# Balanced evidence test
- [seed] apps/web/src/auth flow/LoginForm.tsx | score 100
- [seed] services/Auth/AuthService.cs | score 90
'@ | Set-Content -LiteralPath $balancedPlan -Encoding UTF8
    $balancedOutput = @(& $slicer -PlanPath $balancedPlan -ProjectRoot $project -Symbols 'LoginUser,Authenticate' -MaxFiles 2 -MaxSnippetsPerFile 2 -ContextLines 2 -MaxLinesPerFile 20 -MaxTotalLines 8)
    $balancedText = $balancedOutput -join [Environment]::NewLine
    Assert-Contains $balancedText 'opened=2 matched=2' 'Every allowed candidate is inspected before applying the output budget.'
    Assert-Contains $balancedText 'LoginForm.tsx' 'First matched file receives a fair excerpt allocation.'
    Assert-Contains $balancedText 'AuthService.cs' 'Second matched file receives a fair excerpt allocation.'
    Pass 'Output budget is distributed after inspecting every allowed candidate'

    $priorityPlan = Join-Path (Join-Path $project 'TokenOptimizer') 'priority-plan.md'
    @'
# Lifecycle priority test
- [seed] services/Inventory/InventoryService.luau | score 100
'@ | Set-Content -LiteralPath $priorityPlan -Encoding UTF8
    $priorityOutput = @(& $slicer -PlanPath $priorityPlan -ProjectRoot $project -Symbols 'loadPlayer,savePlayer' -Terms 'DataStoreService' -MaxFiles 1 -MaxSnippetsPerFile 2 -ContextLines 1 -MaxLinesPerFile 16 -MaxTotalLines 16)
    $priorityText = $priorityOutput -join [Environment]::NewLine
    Assert-Contains $priorityText 'LOAD_LIFECYCLE_MARKER' 'Exact load symbols outrank generic header terms.'
    Assert-Contains $priorityText 'SAVE_LIFECYCLE_MARKER' 'Exact save symbols outrank generic header terms.'
    Assert-NotContains $priorityText 'HEADER_ONLY_MARKER' 'Low-priority header matches do not crowd out lifecycle evidence.'
    Pass 'Specific lifecycle identifiers outrank generic early-file matches'

    $termsOutput = @(& $slicer -PlanPath $priorityPlan -ProjectRoot $project -Terms 'DataStoreService GetAsync UpdateAsync' -MaxFiles 1 -MaxSnippetsPerFile 2 -ContextLines 1 -MaxLinesPerFile 16 -MaxTotalLines 16)
    $termsText = $termsOutput -join [Environment]::NewLine
    Assert-Contains $termsText 'LOAD_LIFECYCLE_MARKER' 'Terms-only mode finds the load API after its declaration.'
    Assert-Contains $termsText 'SAVE_LIFECYCLE_MARKER' 'Terms-only mode finds the save API after repeated generic declarations.'
    Assert-NotContains $termsText 'HEADER_ONLY_MARKER' 'Terms-only mode does not let the first generic hit crowd out lifecycle APIs.'
    Pass 'Terms-only extraction preserves distinct load and save API evidence'

    $actionsOutput = @(& $slicer -PlanPath $priorityPlan -ProjectRoot $project -Terms 'action equip unequip' -MaxFiles 1 -MaxSnippetsPerFile 4 -ContextLines 1 -MaxLinesPerFile 20 -MaxTotalLines 20)
    $actionsText = $actionsOutput -join [Environment]::NewLine
    Assert-Contains $actionsText 'EQUIP_ACTION_MARKER' 'Terms-only action extraction finds the equip branch.'
    Assert-Contains $actionsText 'UNEQUIP_ACTION_MARKER' 'Terms-only action extraction finds the unequip branch.'
    Assert-NotContains $actionsText 'COMMENT_ONLY_MARKER' 'Comment-only mentions do not crowd out executable branches.'
    Pass 'Action-term extraction skips comments and preserves equip/unequip branches'

    $coverageOutput = @(& $slicer -PlanPath $priorityPlan -ProjectRoot $project -Terms 'Inventory Equipment Consumable DataStoreService GetAsync UpdateAsync PlayerAdded PlayerRemoving BindToClose OnServerEvent FireServer equip unequip loaded owned cooldown noSave' -MaxFiles 1 -MaxSnippetsPerFile 16 -ContextLines 1 -MaxLinesPerFile 60 -MaxTotalLines 60)
    $coverageText = $coverageOutput -join [Environment]::NewLine
    Assert-Contains $coverageText 'LOAD_LIFECYCLE_MARKER' 'Critical load evidence survives competing domain terms.'
    Assert-Contains $coverageText 'SAVE_LIFECYCLE_MARKER' 'Critical save evidence survives competing domain terms.'
    Assert-Contains $coverageText 'EQUIP_ACTION_MARKER' 'Equip branch survives competing domain terms and line limits.'
    Assert-Contains $coverageText 'UNEQUIP_ACTION_MARKER' 'Unequip branch survives competing domain terms and line limits.'
    Assert-Contains $coverageText 'LOAD_GUARD_MARKER' 'Loaded-state validation is preserved beside the event handler.'
    Assert-Contains $coverageText 'OWNERSHIP_GUARD_MARKER' 'Ownership validation is preserved despite earlier Owned declarations.'
    Assert-Contains $coverageText 'RATE_GUARD_MARKER' 'Rate-limit validation is preserved when cooldown is requested.'
    Assert-Contains $coverageText 'NOSAVE_GUARD_MARKER' 'Save protection is preserved when a load failure must not overwrite existing data.'
    Assert-Contains $coverageText 'CLOSE_LIFECYCLE_MARKER' 'Server shutdown persistence is preserved alongside player-removal saving.'
    Assert-Contains $coverageText 'PLAYER_ADDED_MARKER' 'Player initialization is preserved in lifecycle-oriented extraction.'
    Assert-Contains $coverageText 'PLAYER_REMOVING_MARKER' 'Player departure cleanup is preserved in lifecycle-oriented extraction.'
    Pass 'Priority-first range allocation preserves load/save, action and validation evidence'

    $docsOutput = @(& $router -Query 'AUTH DOCS' -ProjectRoot $project -MaxSeedFiles 12)
    $docsText = $docsOutput -join [Environment]::NewLine
    $docsPlanPath = [regex]::Match($docsText,'(?m)^PLAN=(.+)$').Groups[1].Value.Trim()
    $docsPlan = [IO.File]::ReadAllText($docsPlanPath)
    Assert-Contains $docsPlan 'auth-flow.md' 'Documentation can be explicitly requested.'
    Pass 'Opt-in documentation routing'

    $maliciousPlan = Join-Path (Join-Path $project 'TokenOptimizer') 'malicious-plan.md'
    @'
# malicious path test
- [seed] apps/web/src/auth flow/LoginForm.tsx | score 10
- [seed] ../outside.py | score 999
- [seed] C:/Windows/System32/secret.cs | score 999
- [seed] node_modules/fake-package/AuthService.ts | score 999
- [seed] src_backup_2026/InventoryService.py | score 999
'@ | Set-Content -LiteralPath $maliciousPlan -Encoding UTF8
    $safeOutput = @(& $slicer -PlanPath $maliciousPlan -ProjectRoot $project -Symbols 'LoginUser' -MaxFiles 10 -MaxTotalLines 20)
    $safeText = $safeOutput -join [Environment]::NewLine
    Assert-Contains $safeText 'LoginUser' 'Valid in-root paths remain usable.'
    Assert-NotContains $safeText 'Windows/System32' 'Absolute paths are rejected.'
    Assert-NotContains $safeText 'outside.py' 'Traversal paths are rejected.'
    Assert-NotContains $safeText 'node_modules' 'Blocked dependency paths are rejected by the slicer.'
    Assert-NotContains $safeText 'src_backup_2026' 'Backup source trees are rejected even if manually inserted into a plan.'
    Pass 'Traversal, absolute path, dependency and backup-path rejection'

    $entry = Join-Path $root 'scripts\Invoke-TokenOptimizer.ps1'
    $integrated = @(& $entry -Query 'AUTH LOGIN TOKEN VALIDATION' -ProjectRoot $project -Symbols 'LoginUser,Authenticate,ValidateToken,HandleToken' -MaxTotalLines 20)
    $integratedText = $integrated -join [Environment]::NewLine
    Assert-Contains $integratedText 'TOKENOPTIMIZER UNIVERSAL 0.7.3 |' 'Unified entry runs the coverage-aware router.'
    Assert-Contains $integratedText 'TOKENOPTIMIZER SLICES UNIVERSAL 0.7.3 |' 'Unified entry automatically runs the bounded slicer when symbols are supplied.'
    Pass 'Single-entry route plus optional evidence slicing'

    $after = @($ts,$cs,$py,$go,$genericDb,$remoteNoise,$visualCatalog | ForEach-Object { (Get-FileHash -LiteralPath $_ -Algorithm SHA256).Hash })
    Assert-True (($before -join ',') -eq ($after -join ',')) 'Source files remain unchanged.'
    Pass 'Source integrity (read-only)'

    Write-Output ''
    Write-Output "RESULT: $passed passed | $failed failed"
    if ($failed -gt 0) { exit 1 }
} catch {
    $failed++
    Write-Output "FAIL | $($_.Exception.Message)"
    Write-Output $_.ScriptStackTrace
    Write-Output ''
    Write-Output "RESULT: $passed passed | $failed failed"
    exit 1
} finally {
    if (Test-Path -LiteralPath $tempRoot) {
        Remove-Item -LiteralPath $tempRoot -Recurse -Force -ErrorAction SilentlyContinue
    }
}
