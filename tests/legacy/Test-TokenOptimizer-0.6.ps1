[CmdletBinding()]
param()
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$router = Join-Path $root 'scripts\Invoke-AgentRouter.ps1'
$slicer = Join-Path $root 'scripts\Invoke-ContextSlice.ps1'
$tempRoot = Join-Path (Join-Path $env:USERPROFILE 'Documents') ('TokenOptimizer-0.6-tests-' + [guid]::NewGuid().ToString('N'))
$project = Join-Path $tempRoot 'Project'
$source = Join-Path $project 'src'
$planDir = Join-Path $project 'TokenOptimizer'
$planPath = Join-Path $planDir 'AgentPlan-0.6-test.md'
$passed = 0
$failed = 0

function Assert-True([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw "ASSERT FAILED: $Message" }
}
function Assert-Contains([string]$Text, [string]$Value, [string]$Message) {
    if (-not $Text.Contains($Value)) { throw "ASSERT FAILED: $Message | missing: $Value" }
}
function Assert-NotContains([string]$Text, [string]$Value, [string]$Message) {
    if ($Text.Contains($Value)) { throw "ASSERT FAILED: $Message | unexpected: $Value" }
}
function Pass([string]$Name) {
    $script:passed++
    Write-Output "PASS | $Name"
}

try {
    New-Item -ItemType Directory -Path $planDir -Force | Out-Null
    New-Item -ItemType Directory -Path (Join-Path $source 'Systems\Inventory') -Force | Out-Null
    New-Item -ItemType Directory -Path (Join-Path $source 'Other') -Force | Out-Null

    $inventoryPath = Join-Path $source 'Systems\Inventory\InventoryService.luau'
    $equipmentPath = Join-Path $source 'Systems\Inventory\EquipmentService.luau'
    $unlistedPath = Join-Path $source 'Other\Unlisted.luau'
    $inventoryText = @'
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local InventoryUseItem = ReplicatedStorage:WaitForChild("InventoryUseItem")
local DataStoreService = game:GetService("DataStoreService")
local Store = DataStoreService:GetDataStore("Inventory")
InventoryUseItem.OnServerEvent:Connect(function(player, item)
    -- validate the requested item on server
    print("inventory", player, item)
end)
local UNRELATED_SECRET_MARKER = "do-not-send-this-to-model"
'@
    $equipmentText = @'
local EquipmentInventory = {}
local EquipmentEquip = game:GetService("ReplicatedStorage"):WaitForChild("EquipmentEquip")
EquipmentEquip.OnServerEvent:Connect(function(player, item)
    print("equipment", player, item)
end)
local EQUIPMENT_UNRELATED_MARKER = "must-not-be-dumped"
'@
    $unlistedText = @'
local InventoryUseItem = "this file is not in the routing plan"
'@
    Set-Content -LiteralPath $inventoryPath -Value $inventoryText -Encoding UTF8
    Set-Content -LiteralPath $equipmentPath -Value $equipmentText -Encoding UTF8
    Set-Content -LiteralPath $unlistedPath -Value $unlistedText -Encoding UTF8

    $plan = @'
# Test plan
- [neighbor] src/Systems/Inventory/EquipmentService.luau
- [seed] src/Systems/Inventory/InventoryService.luau
- [seed] src/../outside.lua
- [seed] C:/outside.lua
'@
    Set-Content -LiteralPath $planPath -Value $plan -Encoding UTF8
    $beforeInventory = (Get-FileHash -LiteralPath $inventoryPath -Algorithm SHA256).Hash
    $beforeEquipment = (Get-FileHash -LiteralPath $equipmentPath -Algorithm SHA256).Hash

    $tokens = $null; $parseErrors = $null
    [System.Management.Automation.Language.Parser]::ParseFile($router, [ref]$tokens, [ref]$parseErrors) | Out-Null
    Assert-True ($parseErrors.Count -eq 0) 'Router must parse on Windows PowerShell 5.1.'
    Pass 'Router syntax'

    $tokens = $null; $parseErrors = $null
    [System.Management.Automation.Language.Parser]::ParseFile($slicer, [ref]$tokens, [ref]$parseErrors) | Out-Null
    Assert-True ($parseErrors.Count -eq 0) ("Slicer syntax: " + (($parseErrors | ForEach-Object Message) -join '; '))
    Pass 'Context slicer syntax'

    $sliceArgs = @{
        PlanPath = $planPath
        ProjectRoot = $project
        Symbols = 'InventoryUseItem,EquipmentInventory'
        MaxFiles = 2
        MaxSnippetsPerFile = 3
        ContextLines = 1
        MaxLinesPerFile = 8
        MaxTotalLines = 12
        IncludeRobloxEdges = $true
    }
    $output = @(& $slicer @sliceArgs)
    $text = $output -join [Environment]::NewLine
    Assert-Contains $text 'InventoryUseItem.OnServerEvent' 'Exact server event excerpt should be returned.'
    Assert-Contains $text 'EquipmentEquip.OnServerEvent' 'Selected neighbor excerpt should be returned only if symbol family matches.'
    Assert-NotContains $text 'UNRELATED_SECRET_MARKER' 'Unrelated far-away source line must not enter the snippet pack.'
    Assert-NotContains $text 'must-not-be-dumped' 'Unrelated equipment lines must not be dumped.'
    Assert-NotContains $text 'Unlisted.luau' 'Files absent from the plan must never be opened or emitted.'
    Assert-NotContains $text 'outside.lua' 'Traversal entries must be rejected.'
    Pass 'Selected-plan files only and bounded relevant snippets'

    $shortArgs = @{
        PlanPath = $planPath
        ProjectRoot = $project
        Symbols = 'InventoryUseItem,EquipmentInventory'
        MaxFiles = 1
        MaxSnippetsPerFile = 2
        ContextLines = 1
        MaxLinesPerFile = 6
        MaxTotalLines = 6
        IncludeRobloxEdges = $true
    }
    $shortText = (@(& $slicer @shortArgs) -join [Environment]::NewLine)
    Assert-Contains $shortText 'InventoryService.luau' 'Seeds must be prioritized over neighbors.'
    Assert-NotContains $shortText 'EquipmentService.luau' 'MaxFiles must cap the number of opened candidates.'
    Assert-Contains $shortText 'lines=6' 'Global line budget must be enforced.'
    Pass 'Seed priority and hard total-line budget'

    $rankPlanPath = Join-Path $planDir 'AgentPlan-score-test.md'
    $rankPlan = @'
# Score-order test
- [seed] src/Systems/Inventory/InventoryService.luau | score 3 | hits: inventory
- [seed] src/Systems/Inventory/EquipmentService.luau | score 99 | hits: equipment
'@
    Set-Content -LiteralPath $rankPlanPath -Value $rankPlan -Encoding UTF8
    $rankArgs = @{
        PlanPath = $rankPlanPath
        ProjectRoot = $project
        Symbols = 'EquipmentInventory'
        MaxFiles = 1
        MaxSnippetsPerFile = 2
        ContextLines = 1
        MaxLinesPerFile = 6
        MaxTotalLines = 6
    }
    $rankText = (@(& $slicer @rankArgs) -join [Environment]::NewLine)
    Assert-Contains $rankText 'EquipmentService.luau' 'Highest-scored seed must be inspected first.'
    Assert-NotContains $rankText 'InventoryService.luau' 'Lower-scored seed must remain outside the file budget.'
    Pass 'Seed candidates are opened by score, not report domain order'

    $noneArgs = @{
        PlanPath = $planPath
        ProjectRoot = $project
        Symbols = 'NoSuchIdentifier'
        MaxFiles = 2
        MaxTotalLines = 12
    }
    $noneText = (@(& $slicer @noneArgs) -join [Environment]::NewLine)
    Assert-Contains $noneText 'No selected source file contained' 'No-match must fail visibly without widening to src.'
    Pass 'No-match does not trigger broad source scan'

    # Prove the router skips filename fallback when Graphify already yields
    # the configured minimum number of valid seed candidates.
    $healthDir = Join-Path $source 'Systems\Health'
    $auraDir = Join-Path $source 'Systems\Aura'
    $equipmentDir = Join-Path $source 'Systems\Equipment'
    $sharedDir = Join-Path $source 'Shared'
    New-Item -ItemType Directory -Path $healthDir,$auraDir,$equipmentDir,$sharedDir -Force | Out-Null
    Set-Content -LiteralPath (Join-Path $healthDir 'HealthService.luau') -Value 'local HealthService = {}' -Encoding UTF8
    Set-Content -LiteralPath (Join-Path $auraDir 'AuraService.luau') -Value 'local AuraService = {}' -Encoding UTF8
    Set-Content -LiteralPath (Join-Path $equipmentDir 'EquipmentService.luau') -Value 'local EquipmentService = {}' -Encoding UTF8
    Set-Content -LiteralPath (Join-Path $sharedDir 'ShopConfig.luau') -Value 'local ShopConfig = {}' -Encoding UTF8

    $graphPath = Join-Path $tempRoot 'graph.json'
    $graph = @{
        nodes = @(
            @{ id='inventory'; source_file='src/Systems/Inventory/InventoryService.luau'; label='InventoryService' },
            @{ id='equipment'; source_file='src/Systems/Equipment/EquipmentService.luau'; label='EquipmentService' },
            @{ id='health'; source_file='src/Systems/Health/HealthService.luau'; label='HealthService' },
            @{ id='aura'; source_file='src/Systems/Aura/AuraService.luau'; label='AuraService' },
            @{ id='shop'; source_file='src/Shared/ShopConfig.luau'; label='ShopConfig' }
        )
        links = @(
            @{ source='inventory'; target='shop'; relation='calls' },
            @{ source='equipment'; target='shop'; relation='uses' }
        )
    }
    $graph | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $graphPath -Encoding UTF8
    $routeOutput = @(& $router -Query 'INVENTORY EQUIPMENT HEALTH AURA' -ProjectRoot $project -GraphPath $graphPath)
    $routeText = $routeOutput -join [Environment]::NewLine
    Assert-Contains $routeText 'fallback=0/0 truncated=False' 'Graph-backed routing with enough seeds must skip the full src fallback walk.'
    Assert-Contains $routeText 'seeds=4 neighbors=1' 'Graph seed selection and one-hop neighbor must remain correct.'
    Pass 'Lazy fallback is skipped when Graphify seeds are sufficient'

    $afterInventory = (Get-FileHash -LiteralPath $inventoryPath -Algorithm SHA256).Hash
    $afterEquipment = (Get-FileHash -LiteralPath $equipmentPath -Algorithm SHA256).Hash
    Assert-True ($beforeInventory -eq $afterInventory) 'Inventory source must remain unchanged.'
    Assert-True ($beforeEquipment -eq $afterEquipment) 'Equipment source must remain unchanged.'
    Pass 'Source integrity (read-only)'

    Write-Output ''
    Write-Output "RESULT: $passed passed | $failed failed"
    if ($failed -gt 0) { exit 1 }
} catch {
    $failed++
    Write-Output "FAIL | $($_.Exception.Message)"
    Write-Output ($_.InvocationInfo.PositionMessage)
    Write-Output ($_.Exception.ToString())
    Write-Output $_.ScriptStackTrace
    Write-Output ''
    Write-Output "RESULT: $passed passed | $failed failed"
    exit 1
} finally {
    if (Test-Path -LiteralPath $tempRoot) {
        Remove-Item -LiteralPath $tempRoot -Recurse -Force -ErrorAction SilentlyContinue
    }
}
