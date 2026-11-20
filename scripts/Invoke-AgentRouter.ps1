[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)][ValidateNotNullOrEmpty()][string]$Query,
    [string]$ProjectRoot = (Get-Location).Path,
    [ValidateRange(1,30)][int]$MaxSeedFiles = 10,
    [ValidateRange(100,300000)][int]$MaxScanFiles = 100000,
    [ValidateRange(10,100000)][int]$MaxScanDirectories = 20000,
    [ValidateRange(1,20)][int]$MaxSeedsPerDomain = 5,
    [string]$DiscoveryTerms = '',
    [ValidateRange(1048576,268435456)][long]$MaxContentBytes = 67108864,
    [ValidateRange(100,20000)][int]$MaxContentFiles = 8000
)
$ErrorActionPreference = 'Stop'
$timer = [Diagnostics.Stopwatch]::StartNew()
$stageWatch = [Diagnostics.Stopwatch]::StartNew()

function Normalize-Text([string]$Value) {
    if ([string]::IsNullOrWhiteSpace($Value)) { return '' }
    $value = [regex]::Replace($Value, '([a-z0-9])([A-Z])', '$1 $2')
    $decomposed = $value.ToLowerInvariant().Normalize([Text.NormalizationForm]::FormD)
    $builder = New-Object Text.StringBuilder
    foreach ($character in $decomposed.ToCharArray()) {
        if ([Globalization.CharUnicodeInfo]::GetUnicodeCategory($character) -ne [Globalization.UnicodeCategory]::NonSpacingMark) {
            [void]$builder.Append($character)
        }
    }
    return [regex]::Replace($builder.ToString(), '[^a-z0-9_]+', ' ').Trim()
}
function Test-ReparseFree([string]$Path) {
    $current = $Path
    while ($current) {
        try {
            $attributes = [IO.File]::GetAttributes($current)
            if (($attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) { return $false }
        } catch { return $false }
        if ($current.TrimEnd('\','/') -ieq $ProjectRoot.TrimEnd('\','/')) { break }
        $parent = Split-Path -Parent $current
        if (-not $parent -or $parent -ieq $current) { return $false }
        $current = $parent
    }
    return $true
}
function Get-Domain([string]$RelativePath) {
    $parts = $RelativePath.Replace('\','/').Split('/')
    if ($parts.Count -ge 2) { return $parts[0] }
    return 'Root'
}

if (-not (Test-Path -LiteralPath $ProjectRoot -PathType Container)) { throw "ProjectRoot not found: $ProjectRoot" }
$ProjectRoot = [IO.Path]::GetFullPath((Get-Item -LiteralPath $ProjectRoot -Force).FullName).TrimEnd('\','/')
if (-not (Test-ReparseFree $ProjectRoot)) { throw 'ProjectRoot or one of its ancestors is a reparse point; refusing to scan.' }

$stopWords = @(
'a','an','and','are','as','at','be','by','for','from','how','i','in','into','is','it','me','my','of','on','or','our','please','the','this','to','with','you','your',
'o','a','os','as','um','uma','uns','umas','de','do','da','dos','das','no','na','nos','nas','em','por','para','com','ao','aos','e','ou','que','se','como','meu','minha','meus','minhas','seu','sua','isso','esse','essa','sobre','entre','usando',
'add','change','create','fix','implement','make','modify','update','remove','build','write','code','file','files','project','task','please','want','need','quero','preciso','fazer','criar','corrigir','alterar','mudar','implementar','adicionar','remover','projeto','codigo','arquivo','arquivos',
'roblox','script','scripts','sistema','system','feature','funcionalidade','novo','nova','novos','novas','atual','atualizar','todos','todas','cada','sem','com','para'
)
$queryText = Normalize-Text $Query
$queryTerms = @([regex]::Matches($queryText, '[a-z0-9_]{2,}') | ForEach-Object { $_.Value } | Where-Object { $_ -notin $stopWords } | Select-Object -Unique -First 12)
if ($queryTerms.Count -eq 0) { throw 'No useful search terms. Pass distinctive names or concepts in -Query.' }
$documentationRequested = @($queryTerms | Where-Object { $_ -in @('docs','documentation','readme','guide','manual','changelog','specification','architecture','design','adr') }).Count -gt 0
$taskText = ($DiscoveryTerms.ToLowerInvariant() -replace '[^a-z0-9_]+',' ')
$discoveryNoise = @('action','save','owned','equipped','nosave','use','item','player','data','state')
$taskTerms = @([regex]::Matches($taskText,'[a-z0-9_]{2,}') | ForEach-Object { $_.Value } | Where-Object { $_ -notin $stopWords -and $_ -notin $discoveryNoise } | Select-Object -Unique -First 24)
$terms = @($queryTerms + $taskTerms | Select-Object -Unique -First 36)

# Compile the scanner once per PowerShell process. The hot file walk and matching run in .NET,
# avoiding thousands of PowerShell pipeline/function calls on medium and large repositories.
if (-not ('TokenOptimizer07.FastFileScanner' -as [type])) {
$scannerSource = @'
using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
namespace TokenOptimizer07 {
    public sealed class Candidate {
        public string Path { get; set; }
        public int Score { get; set; }
        public string Domain { get; set; }
        public string[] Hits { get; set; }
        public string Extension { get; set; }
    }
    public sealed class ScanResult {
        public List<Candidate> Candidates { get; set; }
        public int ScannedFiles { get; set; }
        public int ScannedDirectories { get; set; }
        public int EligibleFiles { get; set; }
        public int ContentScannedFiles { get; set; }
        public long ContentBytes { get; set; }
        public bool Truncated { get; set; }
        public bool ContentTruncated { get; set; }
    }
    public static class FastFileScanner {
        private static bool ContainsToken(string text, string token) {
            int index = text.IndexOf(token, StringComparison.OrdinalIgnoreCase);
            while (index >= 0) {
                bool left = index == 0 || !(Char.IsLetterOrDigit(text[index - 1]) || text[index - 1] == '_') || (index > 0 && Char.IsLower(text[index - 1]) && Char.IsUpper(text[index]));
                int end = index + token.Length;
                bool right = end >= text.Length || !(Char.IsLetterOrDigit(text[end]) || text[end] == '_') || (end < text.Length && end > index && Char.IsLower(text[end - 1]) && Char.IsUpper(text[end]));
                if (left && right) return true;
                index = text.IndexOf(token, index + 1, StringComparison.OrdinalIgnoreCase);
            }
            return false;
        }
        public static ScanResult Scan(string root, string[] pathTerms, string[] contentTerms, int maxFiles, int maxDirectories, bool includeDocs, long maxContentBytes, int maxContentFiles) {
            var result = new ScanResult { Candidates = new List<Candidate>() };
            var extensions = new HashSet<string>(StringComparer.OrdinalIgnoreCase) {
                ".lua",".luau",".py",".pyi",".js",".jsx",".mjs",".cjs",".ts",".tsx",".vue",".svelte",
                ".java",".kt",".kts",".cs",".fs",".go",".rs",".rb",".php",".swift",".scala",
                ".c",".h",".cc",".cpp",".hpp",".hh",".hxx",".m",".mm",
                ".html",".htm",".css",".scss",".sass",".less",
                ".json",".jsonc",".yaml",".yml",".toml",".xml",".sql",".proto",".graphql",".gql",
                ".sh",".bash",".zsh",".ps1",".psm1",".psd1",".bat",".cmd",".md",".mdx",".rst",".txt"
            };
            var blocked = new HashSet<string>(StringComparer.OrdinalIgnoreCase) {
                ".git",".hg",".svn",".vs",".idea",".vscode-test","node_modules",".venv","venv","env","__pycache__",
                "bin","obj","dist","build","target","out","coverage",".next",".nuxt",".svelte-kit",
                ".pytest_cache",".mypy_cache",".ruff_cache",".tox","vendor","pods","generated","graphify-out","graphify",".graphify","tokenoptimizer",
                "_backup","_backups","backup","backups","_legacy","legacy","archived","archive","archives","disabled","_legado","legado"
            };
            var stack = new Stack<string>();
            stack.Push(root);
            var prefix = root.TrimEnd(Path.DirectorySeparatorChar, Path.AltDirectorySeparatorChar) + Path.DirectorySeparatorChar;
            while (stack.Count > 0) {
                if (result.ScannedDirectories >= maxDirectories || result.ScannedFiles >= maxFiles) {
                    result.Truncated = true;
                    break;
                }
                var directory = stack.Pop();
                string[] files;
                try {
                    var attrs = File.GetAttributes(directory);
                    if ((attrs & FileAttributes.ReparsePoint) != 0) continue;
                    files = Directory.GetFiles(directory);
                    Array.Sort(files, StringComparer.OrdinalIgnoreCase);
                    result.ScannedDirectories++;
                } catch { continue; }

                foreach (var file in files) {
                    if (result.ScannedFiles >= maxFiles) { result.Truncated = true; break; }
                    result.ScannedFiles++;
                    var extension = Path.GetExtension(file);
                    if (!extensions.Contains(extension)) continue;
                    var fileName = Path.GetFileName(file);
                    var lowerName = fileName.ToLowerInvariant();
                    if (lowerName.EndsWith(".bak") || lowerName.EndsWith(".disabled") || lowerName.EndsWith(".old") ||
                        lowerName.EndsWith(".tmp") || lowerName.EndsWith(".swp") || lowerName.EndsWith(".meta.json") || lowerName.Contains("graphify_obsidian_manifest")) continue;
                    if (!includeDocs && (extension.Equals(".md",StringComparison.OrdinalIgnoreCase) || extension.Equals(".mdx",StringComparison.OrdinalIgnoreCase) || extension.Equals(".rst",StringComparison.OrdinalIgnoreCase) || extension.Equals(".txt",StringComparison.OrdinalIgnoreCase))) continue;
                    var relative = file.Substring(prefix.Length).Replace(Path.DirectorySeparatorChar, '/').Replace(Path.AltDirectorySeparatorChar, '/');
                    if (String.IsNullOrWhiteSpace(relative) || relative.Contains(":")) continue;
                    result.EligibleFiles++;
                    var stem = Path.GetFileNameWithoutExtension(file);
                    var hits = new List<string>();
                    var score = 0;
                    var pathScore = 0;
                    bool isCode = !(extension.Equals(".json",StringComparison.OrdinalIgnoreCase) || extension.Equals(".jsonc",StringComparison.OrdinalIgnoreCase) || extension.Equals(".yaml",StringComparison.OrdinalIgnoreCase) || extension.Equals(".yml",StringComparison.OrdinalIgnoreCase) || extension.Equals(".toml",StringComparison.OrdinalIgnoreCase) || extension.Equals(".xml",StringComparison.OrdinalIgnoreCase) || extension.Equals(".sql",StringComparison.OrdinalIgnoreCase) || extension.Equals(".proto",StringComparison.OrdinalIgnoreCase) || extension.Equals(".graphql",StringComparison.OrdinalIgnoreCase) || extension.Equals(".gql",StringComparison.OrdinalIgnoreCase));
                    foreach (var term in pathTerms) {
                        if (String.IsNullOrWhiteSpace(term)) continue;
                        bool nameHit = stem.IndexOf(term, StringComparison.OrdinalIgnoreCase) >= 0;
                        bool pathHit = !nameHit && relative.IndexOf(term, StringComparison.OrdinalIgnoreCase) >= 0;
                        if (nameHit || pathHit) {
                            if (!hits.Contains(term)) hits.Add(term);
                            int pathWeight = isCode ? (nameHit ? 50 : 24) : (nameHit ? 30 : 12);
                            score += pathWeight;
                            pathScore += pathWeight;
                        }
                    }
                    // Content discovery catches relevant files with generic filenames/folders.
                    // It is bounded by total bytes, file count, per-file size and line count.
                    try {
                        var fileInfo = new FileInfo(file);
                        if (result.ContentScannedFiles < maxContentFiles && fileInfo.Length <= 1048576 && result.ContentBytes + fileInfo.Length <= maxContentBytes) {
                            using (var reader = new StreamReader(file, true)) {
                                string line;
                                int lineNumber = 0;
                                var contentHits = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
                                while ((line = reader.ReadLine()) != null && lineNumber++ < 20000) {
                                    if (line.IndexOf('\0') >= 0) break;
                                    string trimmed = line.TrimStart();
                                    if (trimmed.StartsWith("--", StringComparison.Ordinal) || trimmed.StartsWith("//", StringComparison.Ordinal) || trimmed.StartsWith("# ", StringComparison.Ordinal) || trimmed.StartsWith("/*", StringComparison.Ordinal) || trimmed.StartsWith("<!--", StringComparison.Ordinal)) continue;
                                    foreach (var term in contentTerms) {
                                        if (String.IsNullOrWhiteSpace(term) || contentHits.Contains(term)) continue;
                                        if (ContainsToken(line, term)) contentHits.Add(term);
                                    }
                                }
                                if (lineNumber > 20000) result.ContentTruncated = true;
                                result.ContentScannedFiles++;
                                result.ContentBytes += fileInfo.Length;
                                int coreContentHits = 0;
                                int longestCoreHit = 0;
                                foreach (var term in contentHits) {
                                    if (!hits.Contains(term)) hits.Add(term);
                                    string low = term.ToLowerInvariant();
                                    bool remoteNoise = low.Contains("serverevent") || low.Contains("clientevent") || low.Contains("fireserver") || low.Contains("fireclient");
                                    bool core = low.EndsWith("async") || low == "equip" || low == "unequip" || low.Contains("bindtoclose") || (!remoteNoise && low.Length >= 9 && low != "playeradded" && low != "playerremoving");
                                    if (core) { coreContentHits++; longestCoreHit = Math.Max(longestCoreHit, low.Length); }
                                    bool lifecycle = low.EndsWith("async") || low == "equip" || low == "unequip" || low.Contains("bindtoclose");
                                    score += lifecycle ? 44 : (core ? 30 : (remoteNoise ? 5 : 8));
                                }
                                if (pathScore == 0 && coreContentHits < 2 && !(coreContentHits == 1 && longestCoreHit >= 14)) score = 0;
                            }
                        } else {
                            result.ContentTruncated = true;
                        }
                    } catch { }
                    if (score > 0) {
                        int slash = relative.LastIndexOf('/');
                        string domain = slash < 0 ? "Root" : relative.Substring(0, slash);
                        result.Candidates.Add(new Candidate {
                            Path = relative, Score = score, Domain = domain,
                            Hits = hits.ToArray(), Extension = extension.ToLowerInvariant()
                        });
                    }
                }
                if (result.Truncated) break;

                try {
                    var children = Directory.GetDirectories(directory);
                    Array.Sort(children, StringComparer.OrdinalIgnoreCase);
                    for (int childIndex = children.Length - 1; childIndex >= 0; childIndex--) {
                        var child = children[childIndex];
                        var name = Path.GetFileName(child);
                        string lowerDirectory = name.ToLowerInvariant();
                        if (blocked.Contains(name) || lowerDirectory.StartsWith("src_backup_") || lowerDirectory.EndsWith("_backup") || lowerDirectory.EndsWith("_backups") || lowerDirectory.EndsWith("_legacy")) continue;
                        try {
                            if ((File.GetAttributes(child) & FileAttributes.ReparsePoint) != 0) continue;
                            stack.Push(child);
                        } catch { }
                    }
                } catch { }
            }
            return result;
        }
    }
}
'@
    $cacheDirectory = Join-Path $env:LOCALAPPDATA 'TokenOptimizer\0.7.3'
    New-Item -ItemType Directory -Path $cacheDirectory -Force | Out-Null
    $cacheAssembly = Join-Path $cacheDirectory 'FastFileScanner-0.7.3-r5.dll'
    if (-not [IO.File]::Exists($cacheAssembly)) {
        $temporaryAssembly = Join-Path $cacheDirectory ('FastFileScanner-' + [guid]::NewGuid().ToString('N') + '.dll')
        Add-Type -TypeDefinition $scannerSource -Language CSharp -OutputAssembly $temporaryAssembly -OutputType Library -ErrorAction Stop
        Move-Item -LiteralPath $temporaryAssembly -Destination $cacheAssembly -Force
    }
    [void][Reflection.Assembly]::LoadFrom($cacheAssembly)
}
$assemblyLoadMs = $stageWatch.ElapsedMilliseconds
$stageWatch.Restart()

$scan = [TokenOptimizer07.FastFileScanner]::Scan($ProjectRoot,[string[]]$queryTerms,[string[]]$terms,$MaxScanFiles,$MaxScanDirectories,[bool]$documentationRequested,$MaxContentBytes,$MaxContentFiles)
$scanMs = $stageWatch.ElapsedMilliseconds
$stageWatch.Restart()
$ordered = @($scan.Candidates | Sort-Object -Property @{Expression={$_.Score};Descending=$true},@{Expression={$_.Path};Descending=$false})
$selected = New-Object 'System.Collections.Generic.List[object]'
$remainingCandidates = New-Object 'System.Collections.Generic.List[object]'
foreach ($candidate in $ordered) { $remainingCandidates.Add($candidate) }
$domainCounts = @{}
$coveredTerms = @{}
# Greedy set cover across candidate files: select high-value files that add new task terms,
# while retaining a per-directory cap so a single folder cannot dominate the evidence pack.
while ($selected.Count -lt $MaxSeedFiles -and $remainingCandidates.Count -gt 0) {
    $bestCandidate = $null
    $bestValue = [double]::NegativeInfinity
    foreach ($candidate in $remainingCandidates) {
        $domain = $candidate.Domain
        if ($domainCounts.ContainsKey($domain) -and $domainCounts[$domain] -ge $MaxSeedsPerDomain) { continue }
        $newTerms = 0
        foreach ($hit in $candidate.Hits) { if (-not $coveredTerms.ContainsKey($hit)) { $newTerms++ } }
        $domainBonus = if (-not $domainCounts.ContainsKey($domain)) { 18 } else { 0 }
        $value = $candidate.Score + ($newTerms * 90) + $domainBonus
        if ($value -gt $bestValue -or ($value -eq $bestValue -and $candidate.Path -lt $bestCandidate.Path)) {
            $bestCandidate = $candidate
            $bestValue = $value
        }
    }
    if ($null -eq $bestCandidate) { break }
    $selected.Add($bestCandidate)
    $domain = $bestCandidate.Domain
    if (-not $domainCounts.ContainsKey($domain)) { $domainCounts[$domain] = 0 }
    $domainCounts[$domain]++
    foreach ($hit in $bestCandidate.Hits) { $coveredTerms[$hit] = $true }
    [void]$remainingCandidates.Remove($bestCandidate)
}
$rankMs = $stageWatch.ElapsedMilliseconds
$stageWatch.Restart()
$unselectedCandidateCount = [Math]::Max(0,($ordered.Count - $selected.Count))
$eligibleUnrankedCount = [Math]::Max(0,($scan.EligibleFiles - $ordered.Count))
if ($selected.Count -eq 0) {
    throw "No source/config/documentation paths matched: $($terms -join ', '). Use more distinctive file or subsystem names, or check ProjectRoot."
}

$outDir = Join-Path $ProjectRoot 'TokenOptimizer'
New-Item -ItemType Directory -Path $outDir -Force | Out-Null
$stamp = (Get-Date).ToString('yyyyMMdd-HHmmss-fff')
$planPath = Join-Path $outDir "AgentPlan-0.7.3-$stamp.md"
$report = New-Object 'System.Collections.Generic.List[string]'
$report.Add('# TOKENOPTIMIZER 0.7.3 | COVERAGE-AWARE ROUTING PLAN')
$report.Add('')
$report.Add("Intent: $($terms -join ' + ')")
$report.Add("Project root: $ProjectRoot")
$report.Add("Eligible source files: $($scan.EligibleFiles) | ranked candidates: $($ordered.Count) | eligible but unranked by lexical relevance: $eligibleUnrankedCount | selected: $($selected.Count) | ranked but not selected (MaxSeedFiles): $unselectedCandidateCount | Domains: $($domainCounts.Count)")
$report.Add("Discovery: $($scan.ScannedFiles) files / $($scan.ScannedDirectories) directories visited | eligible: $($scan.EligibleFiles) | metadata truncated: $($scan.Truncated)")
$report.Add("Content discovery: $($scan.ContentScannedFiles) files | size budget accounted: $($scan.ContentBytes) bytes | content truncated: $($scan.ContentTruncated) | task terms: $($taskTerms -join ', ')")
$report.Add("Router time: $($timer.ElapsedMilliseconds) ms | bounded source-content discovery enabled")
$report.Add('')
$report.Add('> Candidate discovery uses file/path metadata plus bounded lexical content matching. Candidate ranking is not proof of imports, call graphs or runtime dependencies.')
foreach ($domain in ($selected | ForEach-Object { $_.Domain } | Select-Object -Unique | Sort-Object)) {
    $report.Add('')
    $report.Add("## Domain: $domain")
    foreach ($candidate in ($selected | Where-Object { $_.Domain -eq $domain })) {
        $report.Add("- [seed] $($candidate.Path) | score $($candidate.Score) | hits: $($candidate.Hits -join ', ')")
    }
}
$report.Add('')
$report.Add('## Limits')
$report.Add("- Maximum selected files: $MaxSeedFiles; maximum scanned files: $MaxScanFiles; maximum directories: $MaxScanDirectories.")
$report.Add('- Dependencies, build outputs, caches, backups, generated folders and reparse points are excluded by default.')
$report.Add("- Content discovery limits: $MaxContentFiles files, 1 MiB per file, $MaxContentBytes total file-size budget and 20,000 lines/file. Any metadata/content truncation is reported; scan completeness is never assumed.")
$report.Add('- The router does not execute project code, spawn agents, edit project source or claim runtime dependencies.')
$tempPath = "$planPath.tmp"
[IO.File]::WriteAllText($tempPath,($report -join [Environment]::NewLine),(New-Object Text.UTF8Encoding($false)))
Move-Item -LiteralPath $tempPath -Destination $planPath -Force
$planWriteMs = $stageWatch.ElapsedMilliseconds
$timer.Stop()
Write-Output ("TOKENOPTIMIZER 0.7.3 | ranked={0} seeds={1} unselected={2} eligibleUnranked={3} scanned={4} dirs={5} eligible={6} contentFiles={7} sizeBudget={8} time={9}ms truncated={10} contentTruncated={11} stages=load:{12}/scan:{13}/rank:{14}/plan:{15}" -f $ordered.Count,$selected.Count,$unselectedCandidateCount,$eligibleUnrankedCount,$scan.ScannedFiles,$scan.ScannedDirectories,$scan.EligibleFiles,$scan.ContentScannedFiles,$scan.ContentBytes,$timer.ElapsedMilliseconds,$scan.Truncated,$scan.ContentTruncated,$assemblyLoadMs,$scanMs,$rankMs,$planWriteMs)
Write-Output "PLAN=$planPath"
