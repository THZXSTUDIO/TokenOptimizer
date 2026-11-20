[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$router = Join-Path $PSScriptRoot '..\scripts\Invoke-AgentRouter.ps1'
$router = (Resolve-Path -LiteralPath $router).Path
$tempRoot = Join-Path (Join-Path $env:USERPROFILE 'Documents') ("TokenOptimizer-0.5-tests-" + [guid]::NewGuid().ToString('N'))
$project = Join-Path $tempRoot 'Project'
$source = Join-Path $project 'src'
$graphPath = Join-Path $tempRoot 'graph.json'
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

function New-TestFile([string]$RelativePath, [string]$Text = '-- test fixture') {
    $full = Join-Path $project ($RelativePath.Replace('/','\'))
    $parent = Split-Path -Parent $full
    New-Item -ItemType Directory -Path $parent -Force | Out-Null
    Set-Content -LiteralPath $full -Value $Text -Encoding UTF8

}

function Write-TestGraph($Graph) {
    $Graph | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $graphPath -Encoding UTF8
}

function Invoke-RouterTest([string]$Query, [switch]$Canvas, [int]$MaxFallbackFiles = 20000, [string]$Graph = $graphPath) {
    $args = @{
        Query = $Query
        ProjectRoot = $project
        GraphPath = $Graph
        MaxFallbackFiles = $MaxFallbackFiles
    }
    if ($Canvas) { $args.Canvas = $true }
    $output = @(& $router @args)
    $planLine = @($output | Where-Object { [string]$_ -like 'PLAN=*' } | Select-Object -Last 1)
    Assert-True ($planLine.Count -eq 1) 'Router must return exactly one PLAN path.'
    $planPath = ([string]$planLine[0]).Substring(5)
    Assert-True (Test-Path -LiteralPath $planPath -PathType Leaf) 'Plan file must exist.'
    return [pscustomobject]@{ Output=$output; PlanPath=$planPath; PlanText=(Get-Content -LiteralPath $planPath -Raw) }
}

function Assert-Fails([string]$Name, [scriptblock]$Action, [string]$ExpectedText) {
    $caught = $false
    try {
        & $Action | Out-Null
    } catch {
        $caught = $true
        if ($ExpectedText -and $_.Exception.Message -notmatch [regex]::Escape($ExpectedText)) {
            throw "ASSERT FAILED: $Name produced the wrong error: $($_.Exception.Message)"
        }
    }
    if (-not $caught) { throw "ASSERT FAILED: $Name should have failed safely." }
}

function Pass([string]$Name) {
    $script:passed++
    Write-Output "PASS | $Name"
}

try {
    New-Item -ItemType Directory -Path $source -Force | Out-Null

    New-TestFile 'src/Systems/Aura/AuraEquipService.lua' 'function AuraEquipService.ApplyAura() end'
    New-TestFile 'src/Systems/Click/ClickConnect.lua' 'function ClickConnect.OnClick() end'
    New-TestFile 'src/Systems/Clicker/ClickerService.lua' 'function ClickerService.Run() end'
    New-TestFile 'src/Systems/Power/PowerProgressionService.lua' 'function PowerProgressionService.AddPower() end'
    New-TestFile 'src/Systems/Inventory/InventoryService.lua' 'function InventoryService.Refresh() end'
    New-TestFile 'src/Systems/Money/MoneyService.lua' 'function MoneyService.Add() end'
    New-TestFile 'src/Systems/UI/UIClickSound.lua' 'function UIClickSound.Play() end'
    New-TestFile 'src/_legacy/AuraLegacy.lua' 'function AuraLegacy.Run() end'
    New-TestFile 'outside.lua' 'must never appear in the plan'
    New-TestFile 'src/Systems/DivinoAura/DivinoAuraFactory.lua' 'function DivinoAuraFactory.Create() end'
    New-TestFile 'src/Systems/Backup/AuraBackup.lua' 'must be excluded'
    New-TestFile 'src/Systems/Health/HealthService.lua' 'function HealthService.Add() end'

    $nodes = @(
        @{ id='aura'; source_file='src/Systems/Aura/AuraEquipService.lua'; label='ApplyAura' },
        @{ id='click'; source_file='src/Systems/Click/ClickConnect.lua'; label='OnClick' },
        @{ id='power'; source_file='src/Systems/Power/PowerProgressionService.lua'; label='AddPower' },
        @{ id='inventory'; source_file='src/Systems/Inventory/InventoryService.lua'; label='RefreshInventory' },
        @{ id='money'; source_file='src/Systems/Money/MoneyService.lua'; label='AddMoney' },
        @{ id='ui'; source_file='src/Systems/UI/UIClickSound.lua'; label='PlayClickSound' },
        @{ id='legacy'; source_file='src/_legacy/AuraLegacy.lua'; label='AuraLegacy' },
        @{ id='traversal'; source_file='src/../outside.lua'; label='AuraOutside' },
        @{ id='missing'; source_file='src/Systems/Missing/ClickGhost.lua'; label='ClickGhost' },
        @{ id='health'; source_file='src/Systems/Health/HealthService.lua'; label='HealthService' }
    )
    $links = @(
        @{ source='aura'; target='inventory'; relation='calls' },
        @{ source='inventory'; target='money'; relation='calls' },
        @{ source='click'; target='power'; relation='updates' },
        @{ source='power'; target='ui'; relation='renders' },
        @{ source='aura'; target='traversal'; relation='invalid-path' },
        @{ source='aura'; target='missing'; relation='stale-path' }
    )
    $graph = @{ nodes=$nodes; links=$links }
    Write-TestGraph $graph

    $sourceFiles = @(Get-ChildItem -LiteralPath $source -File -Recurse)
    $beforeHashes = @{}
    foreach ($file in $sourceFiles) { $beforeHashes[$file.FullName] = (Get-FileHash -LiteralPath $file.FullName -Algorithm SHA256).Hash }

    # 1. Parser check using the host's installed Windows PowerShell parser.
    $tokens = $null; $parseErrors = $null
    [System.Management.Automation.Language.Parser]::ParseFile($router, [ref]$tokens, [ref]$parseErrors) | Out-Null
    Assert-True ($parseErrors.Count -eq 0) 'Router syntax must parse on Windows PowerShell 5.1.'
    Pass 'PowerShell 5.1 syntax'

    # 2. Accent normalization, aliases, graph paths, and filename fallback.
    $result = Invoke-RouterTest -Query ([string][char]0x00C1 + 'URA DIVINO CLICK POWER')
    $plan = $result.PlanText
    Assert-Contains $plan 'AuraEquipService.lua' 'Aura seed should be selected.'
    Assert-Contains $plan 'ClickConnect.lua' 'Click seed should be selected.'
    Assert-Contains $plan 'PowerProgressionService.lua' 'Power seed should be selected.'
    Assert-Contains $plan 'DivinoAuraFactory.lua' 'Filename fallback should discover an AST-missing source file.'
    Pass 'Accent normalization, aliases, and filename fallback'

    # 3. One-hop expansion only; it must not recursively add MoneyService.
    Assert-Contains $plan '[neighbor] src/Systems/Inventory/InventoryService.lua' 'Direct graph neighbor should be included.'
    Assert-NotContains $plan 'MoneyService.lua' 'Second-hop neighbor must not be included.'
    Pass 'One-hop-only graph expansion'

    # 4. Reject traversal, missing files, legacy, backups, and irrelevant UI noise.
    Assert-NotContains $plan 'outside.lua' 'src/../ path traversal must be rejected.'
    Assert-NotContains $plan 'AuraLegacy.lua' 'Legacy path must be rejected.'
    Assert-NotContains $plan 'AuraBackup.lua' 'Backup path must be rejected.'
    Assert-NotContains $plan 'UIClickSound.lua' 'Irrelevant UI sound candidate must be filtered.'
    Assert-NotContains $plan 'ClickGhost.lua' 'Stale graph path must be rejected.'
    Pass 'Path containment, stale paths, identifier boundaries, and exclusion filters'

    # UI/audio paths are allowed only when the request explicitly asks for them.
    $uiResult = Invoke-RouterTest -Query 'UI SOUND CLICK'
    Assert-Contains $uiResult.PlanText 'UIClickSound.lua' 'Explicit UI/audio request should bypass the noise filter.'
    Pass 'Explicit UI/audio intent bypasses noise filter'

    # 5. Canvas is optional and its JSON must be parseable.
    $canvasResult = Invoke-RouterTest -Query 'AURA CLICK POWER' -Canvas
    $canvasLine = @($canvasResult.Output | Where-Object { [string]$_ -like 'CANVAS=*' } | Select-Object -Last 1)
    Assert-True ($canvasLine.Count -eq 1) 'Canvas path should be returned only when requested.'
    $canvasPath = ([string]$canvasLine[0]).Substring(7)
    $canvas = Get-Content -LiteralPath $canvasPath -Raw | ConvertFrom-Json
    Assert-True (@($canvas.nodes).Count -gt 0) 'Canvas must contain nodes.'
    Assert-True ($null -ne $canvas.edges) 'Canvas must contain an edges array.'
    Pass 'Optional Canvas JSON'

    # 6. Empty and unrelated queries must fail explicitly rather than emit misleading plans.
    Assert-Fails 'empty/generic query' { Invoke-RouterTest -Query 'please make a change' } 'No distinctive task terms'
    Assert-Fails 'no-match query' { Invoke-RouterTest -Query 'FROBNICATOR' } 'No current src files matched'
    Pass 'Empty-query and no-match handling'

    # 7. Malformed JSON, invalid schema, and duplicate graph IDs must be rejected.
    $badGraph = Join-Path $tempRoot 'bad.json'
    Set-Content -LiteralPath $badGraph -Value '{ not json' -Encoding UTF8
    Assert-Fails 'malformed graph JSON' { Invoke-RouterTest -Query 'AURA CLICK POWER' -Graph $badGraph } 'not valid JSON'
    $schemaGraph = Join-Path $tempRoot 'schema.json'
    @{ nodes=@(@{id='only';source_file='src/Systems/Aura/AuraEquipService.lua';label='Aura'}) } | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $schemaGraph -Encoding UTF8
    Assert-Fails 'missing graph links array' { Invoke-RouterTest -Query 'AURA CLICK POWER' -Graph $schemaGraph } 'must contain nodes and links arrays'
    $scalarGraph = Join-Path $tempRoot 'scalar.json'
    @{ nodes=@(@{id='only';source_file='src/Systems/Aura/AuraEquipService.lua';label='Aura'}); links=@{source='only';target='only'} } | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $scalarGraph -Encoding UTF8
    Assert-Fails 'scalar graph links' { Invoke-RouterTest -Query 'AURA CLICK POWER' -Graph $scalarGraph } 'must contain nodes and links arrays'
    Write-TestGraph @{ nodes=@(@{id='dup';source_file='src/Systems/Aura/AuraEquipService.lua';label='Aura'},@{id='dup';source_file='src/Systems/Click/ClickConnect.lua';label='Click'}); links=@() }
    Assert-Fails 'duplicate graph node IDs' { Invoke-RouterTest -Query 'AURA CLICK POWER' } 'Duplicate Graphify node id'
    Write-TestGraph $graph
    Pass 'Malformed JSON, graph schema, and duplicate-ID rejection'

    # 8. Fallback scan cap must be visible, never silently presented as complete.
    for ($i = 0; $i -lt 110; $i++) {
        New-TestFile ('src/Systems/Filler/Filler{0:D3}.lua' -f $i) 'local filler = true'
    }
    $bounded = Invoke-RouterTest -Query 'AURA CLICK POWER' -MaxFallbackFiles 100
    Assert-Contains $bounded.PlanText 'LIMIT REACHED: results may be incomplete' 'Truncated fallback scan must be disclosed.'
    Pass 'Fallback scan bound and truncation warning'

    # 9. The router must not modify any source fixture.
    foreach ($path in $beforeHashes.Keys) {
        $after = (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash
        Assert-True ($after -eq $beforeHashes[$path]) "Source fixture changed: $path"
    }
    Assert-Contains $plan 'Source contents read: 0' 'Router must report that it did not read source contents.'
    Pass 'Read-only source integrity'

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
