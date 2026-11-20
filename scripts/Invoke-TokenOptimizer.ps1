[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)][ValidateNotNullOrEmpty()][string]$Query,
    [string]$ProjectRoot = (Get-Location).Path,
    [ValidateRange(1,30)][int]$MaxSeedFiles = 24,
    [ValidateRange(100,300000)][int]$MaxScanFiles = 100000,
    [ValidateRange(10,100000)][int]$MaxScanDirectories = 20000,
    [ValidateRange(1,20)][int]$MaxSeedsPerDomain = 5,
    [ValidateRange(1048576,268435456)][long]$MaxContentBytes = 67108864,
    [ValidateRange(100,20000)][int]$MaxContentFiles = 8000,
    [string]$Symbols = '',
    [string]$Terms = '',
    [ValidateRange(1,30)][int]$MaxFiles = 24,
    [ValidateRange(1,16)][int]$MaxSnippetsPerFile = 16,
    [ValidateRange(0,5)][int]$ContextLines = 1,
    [ValidateRange(4,120)][int]$MaxLinesPerFile = 60,
    [ValidateRange(1,600)][int]$MaxTotalLines = 400,
    [switch]$IncludeCommonEdges,
    [switch]$IncludeRobloxEdges
)
$ErrorActionPreference = 'Stop'
$engine = Join-Path $PSScriptRoot 'Invoke-AgentRouter.ps1'
$slicer = Join-Path $PSScriptRoot 'Invoke-ContextSlice.ps1'
if (-not (Test-Path -LiteralPath $engine -PathType Leaf)) { throw "Routing engine not found: $engine" }

$routeParameters = @{
    Query=$Query; ProjectRoot=$ProjectRoot; MaxSeedFiles=$MaxSeedFiles
    MaxScanFiles=$MaxScanFiles; MaxScanDirectories=$MaxScanDirectories
    MaxSeedsPerDomain=$MaxSeedsPerDomain; DiscoveryTerms=$Terms
    MaxContentBytes=$MaxContentBytes; MaxContentFiles=$MaxContentFiles
}
$routeOutput = @(& $engine @routeParameters)
if (-not $?) { throw 'TokenOptimizer routing failed.' }
Write-Output $routeOutput

# When the caller already knows exact identifiers, route and slice in one invocation.
# Otherwise the agent reads the plan, chooses evidence-backed symbols, then runs the slicer.
if (-not [string]::IsNullOrWhiteSpace($Symbols) -or -not [string]::IsNullOrWhiteSpace($Terms)) {
    $planLine = $routeOutput | Where-Object { ([string]$_) -match '^PLAN=' } | Select-Object -First 1
    if (-not $planLine) { throw 'Router did not return a PLAN path; cannot continue to slicing.' }
    $planPath = ([string]$planLine).Substring(5).Trim()
    if (-not (Test-Path -LiteralPath $slicer -PathType Leaf)) { throw "Context slicer not found: $slicer" }
    $sliceParameters = @{
        PlanPath=$planPath; ProjectRoot=$ProjectRoot; Symbols=$Symbols; Terms=(($Query + ' ' + $Terms).Trim())
        MaxFiles=$MaxFiles; MaxSnippetsPerFile=$MaxSnippetsPerFile
        ContextLines=$ContextLines; MaxLinesPerFile=$MaxLinesPerFile
        MaxTotalLines=$MaxTotalLines
    }
    if ($IncludeCommonEdges) { $sliceParameters.IncludeCommonEdges = $true }
    if ($IncludeRobloxEdges) { $sliceParameters.IncludeRobloxEdges = $true }
    & $slicer @sliceParameters
    if (-not $?) { throw 'TokenOptimizer source slicing failed.' }
}
