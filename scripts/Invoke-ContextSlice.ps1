[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)][ValidateNotNullOrEmpty()][string]$PlanPath,
    [string]$Symbols = '',
    [string]$Terms = '',
    [string]$ProjectRoot = (Get-Location).Path,
    [ValidateRange(1,30)][int]$MaxFiles = 24,
    [ValidateRange(1,16)][int]$MaxSnippetsPerFile = 16,
    [ValidateRange(0,5)][int]$ContextLines = 1,
    [ValidateRange(4,120)][int]$MaxLinesPerFile = 60,
    [ValidateRange(1,600)][int]$MaxTotalLines = 400,
    [ValidateRange(100,50000)][int]$MaxScanLinesPerFile = 20000,
    [ValidateRange(65536,4194304)][int]$MaxFileBytes = 1048576,
    [switch]$IncludeCommonEdges,
    [switch]$IncludeRobloxEdges,
    [string]$OutputPath
)
$ErrorActionPreference = 'Stop'
$timer = [Diagnostics.Stopwatch]::StartNew()

$allowedExtensions = @{}
foreach ($extension in @(
'.lua','.luau','.py','.pyi','.js','.jsx','.mjs','.cjs','.ts','.tsx','.vue','.svelte',
'.java','.kt','.kts','.cs','.fs','.go','.rs','.rb','.php','.swift','.scala',
'.c','.h','.cc','.cpp','.hpp','.hh','.hxx','.m','.mm',
'.html','.htm','.css','.scss','.sass','.less',
'.json','.jsonc','.yaml','.yml','.toml','.xml','.sql','.proto','.graphql','.gql',
'.sh','.bash','.zsh','.ps1','.psm1','.psd1','.bat','.cmd','.md','.mdx','.rst','.txt'
)) { $allowedExtensions[$extension] = $true }
$blockedNames = @('.git','.hg','.svn','node_modules','.venv','venv','__pycache__','bin','obj','dist','build','target','out','coverage','vendor','pods','generated','graphify-out','tokenoptimizer')
function Test-SafeRelativePath([string]$Path) {
    if ([string]::IsNullOrWhiteSpace($Path)) { return $false }
    $p = $Path.Trim().Replace('\','/')
    if ($p.StartsWith('/') -or $p -match '^[a-zA-Z]:' -or $p.Contains(':')) { return $false }
    $parts = @($p.Split('/'))
    if ($parts.Count -lt 1 -or ($parts | Where-Object { $_ -eq '' -or $_ -eq '.' -or $_ -eq '..' }).Count -gt 0) { return $false }
    foreach ($part in $parts) {
        $lowerPart = $part.ToLowerInvariant()
        if ($blockedNames -contains $lowerPart) { return $false }
        if ($lowerPart -match '^(src_backup_|backup|backups|_backup|_backups|legacy|_legacy|archived|archive|archives|disabled|_disabled|generated)(_|-|$)') { return $false }
        if ($lowerPart -match '^(bin|obj|dist|build|target|out|coverage)(_|-|$)') { return $false }
    }
    if (-not $allowedExtensions.ContainsKey([IO.Path]::GetExtension($p).ToLowerInvariant())) { return $false }
    if ($p -match '(?i)(\.bak|\.before-[^/]+|\.disabled|\.old|\.tmp|\.swp)$') { return $false }
    return $true
}
function Test-NoReparseAncestors([string]$FullPath,[string]$Root) {
    $current = $FullPath
    while ($current) {
        try {
            $attributes = [IO.File]::GetAttributes($current)
            if (($attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) { return $false }
        } catch { return $false }
        if ($current.TrimEnd('\','/') -ieq $Root.TrimEnd('\','/')) { break }
        $parent = Split-Path -Parent $current
        if (-not $parent -or $parent -ieq $current) { return $false }
        $current = $parent
    }
    return $true
}
function Get-CodeFenceLanguage([string]$Extension) {
    switch ($Extension.ToLowerInvariant()) {
        {$_ -in '.py','.pyi'} { return 'python' }
        {$_ -in '.js','.mjs','.cjs'} { return 'javascript' }
        {$_ -in '.jsx'} { return 'jsx' }
        {$_ -in '.ts'} { return 'typescript' }
        {$_ -in '.tsx'} { return 'tsx' }
        {$_ -in '.cs'} { return 'csharp' }
        {$_ -in '.fs'} { return 'fsharp' }
        {$_ -in '.go'} { return 'go' }
        {$_ -in '.rs'} { return 'rust' }
        {$_ -in '.java'} { return 'java' }
        {$_ -in '.kt','.kts'} { return 'kotlin' }
        {$_ -in '.rb'} { return 'ruby' }
        {$_ -in '.php'} { return 'php' }
        {$_ -in '.swift'} { return 'swift' }
        {$_ -in '.scala'} { return 'scala' }
        {$_ -in '.c','.h'} { return 'c' }
        {$_ -in '.cc','.cpp','.hpp','.hh','.hxx'} { return 'cpp' }
        {$_ -in '.m','.mm'} { return 'objective-c' }
        {$_ -in '.html','.htm'} { return 'html' }
        {$_ -in '.css','.scss','.sass','.less'} { return 'css' }
        {$_ -in '.json','.jsonc'} { return 'json' }
        {$_ -in '.yaml','.yml'} { return 'yaml' }
        {$_ -in '.toml'} { return 'toml' }
        {$_ -in '.xml'} { return 'xml' }
        {$_ -in '.sql'} { return 'sql' }
        {$_ -in '.sh','.bash','.zsh'} { return 'bash' }
        {$_ -in '.ps1','.psm1','.psd1'} { return 'powershell' }
        {$_ -in '.bat','.cmd'} { return 'batch' }
        {$_ -in '.md','.mdx','.rst'} { return 'markdown' }
        {$_ -in '.lua','.luau'} { return 'lua' }
        default { return '' }
    }
}

if (-not (Test-Path -LiteralPath $ProjectRoot -PathType Container)) { throw "ProjectRoot not found: $ProjectRoot" }
$ProjectRoot = [IO.Path]::GetFullPath((Get-Item -LiteralPath $ProjectRoot -Force).FullName).TrimEnd('\','/')
if (-not (Test-Path -LiteralPath $PlanPath -PathType Leaf)) { throw "Plan not found: $PlanPath" }
$PlanPath = [IO.Path]::GetFullPath((Get-Item -LiteralPath $PlanPath -Force).FullName)
$planPrefix = (Join-Path $ProjectRoot 'TokenOptimizer').TrimEnd('\','/') + '\'
if (-not $PlanPath.StartsWith($planPrefix,[StringComparison]::OrdinalIgnoreCase)) { throw 'Plan must be inside ProjectRoot\TokenOptimizer.' }

$symbolsList = @([regex]::Split($Symbols,'[,;|\s]+') | Where-Object { $_ -match '^[A-Za-z_$][A-Za-z0-9_$]{2,}$' } | Select-Object -Unique -First 30)
$termsList = @([regex]::Matches((($Terms.ToLowerInvariant() -replace '[^a-z0-9_]+',' ')),'[a-z0-9_]{2,}') | ForEach-Object Value | Select-Object -Unique -First 20)
if ($symbolsList.Count -eq 0 -and $termsList.Count -eq 0 -and -not $IncludeCommonEdges -and -not $IncludeRobloxEdges) {
    throw 'Provide -Symbols (exact identifiers) or -Terms (distinctive text concepts).'
}
$criticalPatternKeys = @{}
if ($termsList -contains 'equip') { $criticalPatternKeys['CriticalAction:equip'] = $true }
if ($termsList -contains 'unequip') { $criticalPatternKeys['CriticalAction:unequip'] = $true }
if ($termsList -contains 'loaded') { $criticalPatternKeys['CriticalGuard:LoadedState'] = $true }
if ($termsList -contains 'owned') { $criticalPatternKeys['CriticalGuard:Ownership'] = $true }
if ($termsList -contains 'cooldown' -or $termsList -contains 'throttle') { $criticalPatternKeys['CriticalGuard:RateLimit'] = $true }
if ($termsList -contains 'nosave') { $criticalPatternKeys['CriticalGuard:SaveProtection'] = $true }
if ($termsList -contains 'getasync') { $criticalPatternKeys['CriticalStoreAPI:GetAsync'] = $true }
if ($termsList -contains 'updateasync') { $criticalPatternKeys['CriticalStoreAPI:UpdateAsync'] = $true }
if ($termsList -contains 'playeradded') { $criticalPatternKeys['CriticalLifecycle:PlayerAdded'] = $true }
if ($termsList -contains 'playerremoving') { $criticalPatternKeys['CriticalLifecycle:PlayerRemoving'] = $true }
if ($termsList -contains 'bindtoclose') { $criticalPatternKeys['CriticalLifecycle:BindToClose'] = $true }
$alternatives = New-Object 'System.Collections.Generic.List[string]'
$matchRules = New-Object 'System.Collections.Generic.List[object]'
$regexOptions = [Text.RegularExpressions.RegexOptions]::Compiled -bor [Text.RegularExpressions.RegexOptions]::IgnoreCase

foreach ($symbol in $symbolsList) {
    $alternatives.Add([regex]::Escape($symbol))
    $escapedSymbol = [regex]::Escape($symbol)
    $pattern = '(?:(?<![A-Za-z0-9_$])' + $escapedSymbol + '(?=(?-i:[A-Z])|[^A-Za-z0-9_$]|$)|(?<=[a-z])(?-i:[A-Z])' + $escapedSymbol + '(?=(?-i:[A-Z])|[^A-Za-z0-9_$]|$))'
    $matchRules.Add([pscustomobject]@{
        Matcher = [regex]::new($pattern,$regexOptions)
        Priority = 100 + [Math]::Min($symbol.Length,40)
        Kind = 'Symbol'
        Key = $symbol
    })
}
foreach ($term in $termsList) {
    $alternatives.Add([regex]::Escape($term))
    $escapedTerm = [regex]::Escape($term)
    $pattern = '(?:(?<![A-Za-z0-9_$])' + $escapedTerm + '(?=(?-i:[A-Z])|[^A-Za-z0-9_$]|$)|(?<=[a-z])(?-i:[A-Z])' + $escapedTerm + '(?=(?-i:[A-Z])|[^A-Za-z0-9_$]|$))'
    $termPriority = 20 + [Math]::Min($term.Length,30)
    if ($term -match '^(getasync|updateasync|setasync|playeradded|playerremoving|bindtoclose|onserverevent|onclientevent|fireserver|fireclient|invokeserver|invokeclient|savechanges|executereader|sendasync|onmessage)$') {
        $termPriority = 500
    } elseif ($term -match '(?i)(Async|OnServerEvent|OnClientEvent|PlayerAdded|PlayerRemoving|BindToClose|FireServer|FireClient|InvokeServer|InvokeClient|SaveChanges|ExecuteReader|SendAsync|OnMessage|Subscribe|Publish|equip|unequip|owned|equipped|loaded|cooldown|throttle|permission|authorized|quantity|validation)') {
        $termPriority = 140 + [Math]::Min($term.Length,30)
    }
    $matchRules.Add([pscustomobject]@{
        Matcher = [regex]::new($pattern,$regexOptions)
        Priority = $termPriority
        Kind = 'Term'
        Key = $term
    })
    if ($term -match '(?i)(Async|OnServerEvent|OnClientEvent|PlayerAdded|PlayerRemoving|BindToClose|FireServer|FireClient|InvokeServer|InvokeClient|SaveChanges|equip|unequip|owned|equipped|loaded|cooldown|throttle|permission|authorized|quantity|validation)') {
        $criticalPatternKeys['Term:' + $term] = $true
    }
}
if ($IncludeCommonEdges) {
    $edgePattern = '(?<![A-Za-z0-9_$])(?:fetch|axios|HttpClient|WebClient|SaveChanges|ExecuteReader|QueryAsync|UpdateAsync|GetAsync|SetAsync|Publish|Subscribe|SendAsync|OnMessage|listen|emit)(?![A-Za-z0-9_$])'
    $alternatives.Add($edgePattern)
    $matchRules.Add([pscustomobject]@{ Matcher=[regex]::new($edgePattern,$regexOptions); Priority=10 })
}
if ($IncludeRobloxEdges) {
    $edgePattern = '(?<![A-Za-z0-9_$])(?:RemoteEvent|RemoteFunction|BindableEvent|BindableFunction|OnServerEvent|OnClientEvent|OnServerInvoke|OnClientInvoke|FireServer|FireClient|InvokeServer|DataStoreService|GetDataStore|UpdateAsync|SetAsync|GetAsync|PlayerAdded|PlayerRemoving)(?![A-Za-z0-9_$])'
    $alternatives.Add($edgePattern)
    $matchRules.Add([pscustomobject]@{ Matcher=[regex]::new($edgePattern,$regexOptions); Priority=8 })
}
if ($matchRules.Count -eq 0) { throw 'No valid search patterns remain.' }

$planText = [IO.File]::ReadAllText($PlanPath)
$seedPaths = New-Object 'System.Collections.Generic.List[string]'
$neighborPaths = New-Object 'System.Collections.Generic.List[string]'
$seedScores = @{}
foreach ($match in [regex]::Matches($planText,'(?im)^\s*-\s+\[(seed|neighbor)\]\s+(.+?)\s*$')) {
    $kind = $match.Groups[1].Value.ToLowerInvariant()
    $entry = $match.Groups[2].Value.Trim()
    $scoreMatch = [regex]::Match($entry,'\s+\|\s+score\s+(\d+)')
    $score = if ($scoreMatch.Success) { [int]$scoreMatch.Groups[1].Value } else { 0 }
    $relative = [regex]::Replace($entry,'\s+\|\s+score\s+\d+.*$','').Trim().Replace('\','/')
    if (-not (Test-SafeRelativePath $relative)) { continue }
    if ($kind -eq 'seed') {
        if (-not $seedPaths.Contains($relative)) { $seedPaths.Add($relative) }
        $seedScores[$relative] = $score
    } else {
        if (-not $neighborPaths.Contains($relative)) { $neighborPaths.Add($relative) }
    }
}
$candidates = New-Object 'System.Collections.Generic.List[string]'
$orderedSeeds = @($seedPaths | ForEach-Object { [pscustomobject]@{Path=$_;Score=[int]$seedScores[$_]} } | Sort-Object -Property @{Expression={$_.Score};Descending=$true},@{Expression={$_.Path};Descending=$false})
foreach ($seed in $orderedSeeds) { $candidates.Add($seed.Path) }
foreach ($path in $neighborPaths) { if (-not $candidates.Contains($path)) { $candidates.Add($path) } }
if ($candidates.Count -eq 0) { throw 'Plan contains no safe [seed] or [neighbor] paths.' }

$report = New-Object 'System.Collections.Generic.List[string]'
$report.Add('# TOKENOPTIMIZER 0.7.3 | COVERAGE-BALANCED SOURCE EXCERPTS')
$report.Add('')
$report.Add("Plan: $PlanPath")
$unopenedCandidateCount = [Math]::Max(0,($candidates.Count - $MaxFiles))
$report.Add("Candidates: $($candidates.Count) | Files to inspect: $MaxFiles | Patterns: $($alternatives.Count)")
$perFileLineBudget = [Math]::Max(1,[Math]::Min(8,[Math]::Floor($MaxTotalLines / [Math]::Min($candidates.Count,$MaxFiles))))
$report.Add("Coverage baseline: at least $perFileLineBudget lines/matched file where available; remaining lines are allocated by relevance after every allowed candidate is inspected. Only plan-listed paths are opened; no complete file dumps.")
if ($unopenedCandidateCount -gt 0) { $report.Add("NOTICE: $unopenedCandidateCount plan candidates remain unopened because of MaxFiles. Increase MaxFiles or refine the route if they may contain decisive evidence.") }
$report.Add('')
$totalLines = 0
$opened = 0
$matchedFiles = 0
$scanTruncatedFiles = New-Object 'System.Collections.Generic.List[string]'
$stoppedByTotalLineBudget = $false
$filePacks = New-Object 'System.Collections.Generic.List[object]'
$fence = ([string][char]96) * 3

foreach ($relative in ($candidates | Select-Object -First $MaxFiles)) {
    if ($totalLines -ge $MaxTotalLines) { $stoppedByTotalLineBudget = $true; break }
    $fullPath = [IO.Path]::GetFullPath((Join-Path $ProjectRoot $relative.Replace('/',[IO.Path]::DirectorySeparatorChar)))
    $rootPrefix = $ProjectRoot.TrimEnd('\','/') + [IO.Path]::DirectorySeparatorChar
    if (-not $fullPath.StartsWith($rootPrefix,[StringComparison]::OrdinalIgnoreCase)) { continue }
    if (-not [IO.File]::Exists($fullPath)) { continue }
    if (-not (Test-NoReparseAncestors $fullPath $ProjectRoot)) { continue }
    $info = New-Object IO.FileInfo($fullPath)
    if ($info.Length -gt $MaxFileBytes) { $report.Add("SKIP | $relative | exceeds $MaxFileBytes bytes"); continue }

    $opened++
    $lines = New-Object 'System.Collections.Generic.List[string]'
    $hits = New-Object 'System.Collections.Generic.List[object]'
    $seenSymbols = @{}
    $seenTermCounts = @{}
    $reader = [IO.File]::OpenText($fullPath)
    try {
        while (-not $reader.EndOfStream -and $lines.Count -lt $MaxScanLinesPerFile) {
            $line = $reader.ReadLine()
            $lines.Add($line)
            $extension = [IO.Path]::GetExtension($fullPath).ToLowerInvariant()
            $isCommentLine = $false
            switch -Regex ($extension) {
                '^\.(lua|luau|sql)$' { $isCommentLine = $line -match '^\s*--'; break }
                '^\.(py|pyi|sh|bash|zsh|rb|yaml|yml|toml|ps1|psm1|psd1|bat|cmd)$' { $isCommentLine = $line -match '^\s*#\s'; break }
                '^\.(html|htm|xml)$' { $isCommentLine = $line -match '^\s*<!--'; break }
                '^\.(md|mdx|rst|txt)$' { $isCommentLine = $false; break }
                default { $isCommentLine = $line -match '^\s*(//|/\*)' }
            }
            $linePriority = 0
            $matchedPatterns = 0
            $matchedKeys = New-Object 'System.Collections.Generic.List[string]'
            if (-not $isCommentLine) {
                foreach ($rule in $matchRules) {
                    if ($rule.Kind -eq 'Symbol' -and $seenSymbols.ContainsKey($rule.Key)) { continue }
                    if ($rule.Kind -eq 'Term' -and $seenTermCounts.ContainsKey($rule.Key)) {
                        $termCap = if ($criticalPatternKeys.ContainsKey('Term:' + $rule.Key)) { 100 } else { 4 }
                        if ($seenTermCounts[$rule.Key] -ge $termCap) { continue }
                    }
                    if ($rule.Matcher.IsMatch($line)) {
                        $linePriority += $rule.Priority
                        $matchedPatterns++
                        $matchedKeys.Add(($rule.Kind + ':' + $rule.Key))
                        if ($rule.Kind -eq 'Symbol') { $seenSymbols[$rule.Key] = $true }
                        elseif ($rule.Kind -eq 'Term') {
                            if (-not $seenTermCounts.ContainsKey($rule.Key)) { $seenTermCounts[$rule.Key] = 0 }
                            $seenTermCounts[$rule.Key]++
                        }
                    }
                }
                # Promote executable equip/unequip action branches above repetitive setup matches.
                if ($criticalPatternKeys.Count -gt 0 -and $line -match '(?i)\baction\s*==\s*["''](equip|unequip)["'']') {
                    $branchKey = 'CriticalAction:' + $Matches[1].ToLowerInvariant()
                    if ($criticalPatternKeys.ContainsKey($branchKey)) {
                        $linePriority += 1400
                        $matchedPatterns++
                        $matchedKeys.Add($branchKey)
                    }
                }
                if ($criticalPatternKeys.ContainsKey('CriticalGuard:LoadedState') -and $line -match '(?i)\bif\b.*\b(?:not\s+)?\w+\.(?:loaded|ready|isLoaded)\b') {
                    $linePriority += 1300; $matchedPatterns++; $matchedKeys.Add('CriticalGuard:LoadedState')
                }
                if ($criticalPatternKeys.ContainsKey('CriticalGuard:Ownership') -and $line -match '(?i)\bif\b.*\b(?:not\s+)?owned\b.*(?:<=|<|==|~=|!=)') {
                    $linePriority += 1300; $matchedPatterns++; $matchedKeys.Add('CriticalGuard:Ownership')
                }
                if ($criticalPatternKeys.ContainsKey('CriticalGuard:RateLimit') -and $line -match '(?i)\bif\b.*\b(?:now|time|clock)\b.*\b(?:last|lastUse|lastRequest)\b.*[<>]') {
                    $linePriority += 1300; $matchedPatterns++; $matchedKeys.Add('CriticalGuard:RateLimit')
                }
                if ($criticalPatternKeys.ContainsKey('CriticalGuard:SaveProtection') -and $line -match '(?i)\b(?:noSave|no_save|saveDisabled|skipSave)\s*=\s*true\b') {
                    $linePriority += 900; $matchedPatterns++; $matchedKeys.Add('CriticalGuard:SaveProtection')
                }
                if ($criticalPatternKeys.ContainsKey('CriticalStoreAPI:GetAsync') -and $line -match '(?i)\bGetAsync\s*\(') {
                    $linePriority += 1200; $matchedPatterns++; $matchedKeys.Add('CriticalStoreAPI:GetAsync')
                }
                if ($criticalPatternKeys.ContainsKey('CriticalStoreAPI:UpdateAsync') -and $line -match '(?i)\bUpdateAsync\s*\(') {
                    $linePriority += 1200; $matchedPatterns++; $matchedKeys.Add('CriticalStoreAPI:UpdateAsync')
                }
                if ($criticalPatternKeys.ContainsKey('CriticalLifecycle:PlayerAdded') -and $line -match '(?i)\bPlayers\.PlayerAdded\s*:\s*Connect') {
                    $linePriority += 1200; $matchedPatterns++; $matchedKeys.Add('CriticalLifecycle:PlayerAdded')
                }
                if ($criticalPatternKeys.ContainsKey('CriticalLifecycle:PlayerRemoving') -and $line -match '(?i)\bPlayers\.PlayerRemoving\s*:\s*Connect') {
                    $linePriority += 1200; $matchedPatterns++; $matchedKeys.Add('CriticalLifecycle:PlayerRemoving')
                }
                if ($criticalPatternKeys.ContainsKey('CriticalLifecycle:BindToClose') -and $line -match '(?i)\bBindToClose\s*\(') {
                    $linePriority += 1200; $matchedPatterns++; $matchedKeys.Add('CriticalLifecycle:BindToClose')
                }
            }
            if ($linePriority -gt 0) {
                $hits.Add([pscustomobject]@{
                    Line = $lines.Count-1
                    Score = $linePriority
                    Matched = $matchedPatterns
                    Keys = @($matchedKeys.ToArray())
                })
            }
        }
        if (-not $reader.EndOfStream) { $scanTruncatedFiles.Add($relative) }
    } finally { $reader.Dispose() }
    if ($hits.Count -eq 0) { continue }

    $matchedFiles++
    # Greedy set-cover selection: prefer snippets that add still-uncovered task patterns,
    # then use line relevance as the tie-breaker. This avoids repeating one API while
    # dropping a distinct save/load/action branch from the same file.
    $remainingHits = New-Object 'System.Collections.Generic.List[object]'
    foreach ($hit in $hits) { $remainingHits.Add($hit) }
    $selectedHitList = New-Object 'System.Collections.Generic.List[object]'
    $coveredPatternKeys = @{}
    while ($selectedHitList.Count -lt $MaxSnippetsPerFile -and $remainingHits.Count -gt 0) {
        $bestHit = $null
        $bestValue = [double]::NegativeInfinity
        foreach ($candidateHit in $remainingHits) {
            $newCoverage = 0
            foreach ($key in $candidateHit.Keys) {
                if (-not $coveredPatternKeys.ContainsKey($key)) {
                    $newCoverage += if ($criticalPatternKeys.ContainsKey($key)) { 5 } else { 1 }
                }
            }
            $value = ($newCoverage * 100) + $candidateHit.Score
            if ($value -gt $bestValue -or ($value -eq $bestValue -and $candidateHit.Line -lt $bestHit.Line)) {
                $bestHit = $candidateHit
                $bestValue = $value
            }
        }
        if ($null -eq $bestHit) { break }
        $selectedHitList.Add($bestHit)
        foreach ($key in $bestHit.Keys) { $coveredPatternKeys[$key] = $true }
        [void]$remainingHits.Remove($bestHit)
    }
    # Keep greedy relevance order here; final emitted windows are sorted by source line only after
    # the per-file budget has been assigned by range priority.
    $selectedHits = @($selectedHitList.ToArray())
    $windows = New-Object 'System.Collections.Generic.List[object]'
    foreach ($hit in $selectedHits) {
        $isCriticalHit = @($hit.Keys | Where-Object { $criticalPatternKeys.ContainsKey($_) }).Count -gt 0
        $windowPadding = if ($isCriticalHit) { [Math]::Min($ContextLines,1) } else { $ContextLines }
        $windows.Add([pscustomobject]@{
            Start=[Math]::Max(0,$hit.Line-$windowPadding)
            End=[Math]::Min($lines.Count-1,$hit.Line+$windowPadding)
            Score=$hit.Score
            Keys=@($hit.Keys)
        })
    }
    $merged = New-Object 'System.Collections.Generic.List[object]'
    foreach ($window in ($windows | Sort-Object Start,End)) {
        if ($merged.Count -eq 0 -or $window.Start -gt ($merged[$merged.Count-1].End+1)) {
            $merged.Add([pscustomobject]@{Start=$window.Start;End=$window.End;Score=$window.Score;Keys=@($window.Keys)})
        } else {
            if ($window.End -gt $merged[$merged.Count-1].End) { $merged[$merged.Count-1].End = $window.End }
            $merged[$merged.Count-1].Score += $window.Score
            $merged[$merged.Count-1].Keys = @($merged[$merged.Count-1].Keys + $window.Keys | Select-Object -Unique)
        }
    }

    $language = Get-CodeFenceLanguage ([IO.Path]::GetExtension($fullPath))
    $packRanges = New-Object 'System.Collections.Generic.List[object]'
    $packLineCount = 0
    foreach ($range in ($merged | Sort-Object -Property @{Expression={$_.Score};Descending=$true},@{Expression={$_.Start};Descending=$false})) {
        $remainingPack = $MaxLinesPerFile - $packLineCount
        $take = [Math]::Min(($range.End-$range.Start+1),$remainingPack)
        if ($take -le 0) { break }
        $packRanges.Add([pscustomobject]@{Start=$range.Start;End=($range.Start+$take-1);Score=$range.Score;Keys=@($range.Keys)})
        $packLineCount += $take
        if ($packLineCount -ge $MaxLinesPerFile) { break }
    }
    if ($packLineCount -gt 0) {
        $packScore = 0
        foreach ($hit in $selectedHits) { $packScore += $hit.Score }
        $filePacks.Add([pscustomobject]@{
            Path=$relative
            Language=$language
            Lines=[string[]]$lines.ToArray()
            Ranges=@($packRanges.ToArray() | Sort-Object -Property @{Expression={$_.Start};Descending=$false})
            LineCount=$packLineCount
            Score=$packScore
            Excerpts=$selectedHits.Count
        })
    }
}
if ($filePacks.Count -gt 0) {
    # Every matched file gets a minimum evidence floor. Remaining lines are assigned by
    # diminishing-return relevance so primary services receive deeper context without
    # allowing one file to starve all other files.
    $orderedPacks = @($filePacks | Sort-Object -Property @{Expression={$_.Score};Descending=$true},@{Expression={$_.Path};Descending=$false})
    $allocations = @{}
    $remainingBudget = $MaxTotalLines
    $baseQuota = [Math]::Min(8,[Math]::Floor($MaxTotalLines / $orderedPacks.Count))
    foreach ($pack in $orderedPacks) {
        $allocation = [Math]::Min($pack.LineCount,$baseQuota)
        $allocations[$pack.Path] = [int]$allocation
        $remainingBudget -= $allocation
    }
    while ($remainingBudget -gt 0) {
        $bestPack = $null
        $bestValue = [double]::NegativeInfinity
        foreach ($pack in $orderedPacks) {
            if ($allocations[$pack.Path] -ge $pack.LineCount) { continue }
            $weight = [Math]::Sqrt([Math]::Max(1.0,[double]$pack.Score))
            $value = $weight / ($allocations[$pack.Path] + 1)
            if ($value -gt $bestValue) { $bestPack = $pack; $bestValue = $value }
        }
        if ($null -eq $bestPack) { break }
        $allocations[$bestPack.Path]++
        $remainingBudget--
    }
    foreach ($pack in $filePacks) {
        $allowedLines = [int]$allocations[$pack.Path]
        if ($allowedLines -le 0) { $stoppedByTotalLineBudget = $true; continue }
        $report.Add("## $($pack.Path)")
        $emitted = 0
        $blocks = 0
        # Apply the global per-file allocation to highest-priority ranges first, then emit
        # the chosen ranges in source order. Do not let early setup lines consume the quota
        # and silently cut off a later action/validation/persistence branch.
        $emitRanges = New-Object 'System.Collections.Generic.List[object]'
        $rangeBudget = $allowedLines
        foreach ($range in ($pack.Ranges | Sort-Object -Property @{Expression={$_.Score};Descending=$true},@{Expression={$_.Start};Descending=$false})) {
            $take = [Math]::Min(($range.End-$range.Start+1),$rangeBudget)
            if ($take -le 0) { break }
            $emitRanges.Add([pscustomobject]@{Start=$range.Start;End=($range.Start+$take-1);Score=$range.Score})
            $rangeBudget -= $take
        }
        foreach ($range in ($emitRanges | Sort-Object -Property @{Expression={$_.Start};Descending=$false})) {
            $report.Add($fence + $pack.Language)
            for ($index=$range.Start; $index -le $range.End; $index++) {
                $sourceLine = $pack.Lines[$index]
                if ($sourceLine.Length -gt 360) { $sourceLine = $sourceLine.Substring(0,360) + ' ... [line clipped]' }
                $report.Add(('{0,5}: {1}' -f ($index+1),$sourceLine))
                $emitted++
            }
            $report.Add($fence)
            $blocks++
        }
        $report.Add("> Match groups selected: $($pack.Excerpts) | blocks emitted: $blocks | lines emitted: $emitted")
        $report.Add('')
        $totalLines += $emitted
        if ($allowedLines -lt $pack.LineCount) { $stoppedByTotalLineBudget = $true }
    }
}
if ($matchedFiles -eq 0) {
    $report.Add('No selected plan file matched the requested identifiers/terms. Refine the symbols or routing query; do not widen to the whole project.')
}
if ($stoppedByTotalLineBudget) {
    $report.Add('NOTICE: MaxTotalLines limited excerpts after every selected candidate had been inspected. The output budget was distributed across matched files; some low-priority context lines were omitted.')
}
if ($scanTruncatedFiles.Count -gt 0) {
    $report.Add("SCAN LIMIT: $($scanTruncatedFiles.Count) selected file(s) exceeded MaxScanLinesPerFile=$MaxScanLinesPerFile; matches beyond that boundary were not inspected.")
    foreach ($path in $scanTruncatedFiles) { $report.Add("- $path") }
}
if ($OutputPath) {
    $outputPrefix = (Join-Path $ProjectRoot 'TokenOptimizer').TrimEnd('\','/') + '\'
    $outputFull = [IO.Path]::GetFullPath($OutputPath)
    if (-not $outputFull.StartsWith($outputPrefix,[StringComparison]::OrdinalIgnoreCase)) { throw 'OutputPath must be inside ProjectRoot\TokenOptimizer.' }
    [IO.File]::WriteAllText($outputFull,($report -join [Environment]::NewLine),(New-Object Text.UTF8Encoding($false)))
}
$timer.Stop()
Write-Output ("TOKENOPTIMIZER SLICES 0.7.3 | candidates={0} opened={1} matched={2} lines={3} perFileBudget={4} time={5}ms" -f $candidates.Count,$opened,$matchedFiles,$totalLines,$perFileLineBudget,$timer.ElapsedMilliseconds)
Write-Output ($report -join [Environment]::NewLine)
