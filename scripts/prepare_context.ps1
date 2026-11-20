[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)]
    [string]$Query,

    [string]$Root = (Get-Location).Path,
    [string]$SourceDir = "src",
    [int]$MaxFiles = 8,
    [int]$MaxMatchesPerFile = 3,
    [string]$OutputPath
)

$ErrorActionPreference = "Stop"

function Normalize-Text([string]$Value) {
    $Value = $Value.ToLowerInvariant()
    $Value = $Value -replace '[áàâãä]', 'a'
    $Value = $Value -replace '[éèêë]', 'e'
    $Value = $Value -replace '[íìîï]', 'i'
    $Value = $Value -replace '[óòôõö]', 'o'
    $Value = $Value -replace '[úùûü]', 'u'
    $Value = $Value -replace 'ç', 'c'
    return $Value
}

$stop = @(
    "faz","fazer","meu","minha","minhas","meus","um","uma","o","a","os","as",
    "de","da","do","das","dos","que","com","para","por","no","na","nos","nas",
    "e","ou","em","ao","aos","se","como","agora","quero","preciso","pode",
    "the","a","an","and","or","to","of","for","in","on","with","my","make",
    "add","change","update","please","can","you"
)

$aliases = @{
    "aura" = @("aura","auras")
    "click" = @("click","clicks","clique","cliques","clickvalue","clickpower")
    "vida" = @("vida","health","hp","maxhealth","max_health")
    "armadura" = @("armadura","armor","armour","defesa","defense")
    "acrescentar" = @("acrescentar","adicionar","add","increase","grant","give")
    "multiplicador" = @("multiplicador","multiplier","bonus","boost")
    "velocidade" = @("velocidade","speed","walkspeed")
    "impressora" = @("impressora","printer","printing")
    "missao" = @("missao","mission","quest")
    "inimigo" = @("inimigo","enemy","npc","bandido")
    "recompensa" = @("recompensa","reward","drop","money")
}

if (-not (Test-Path -LiteralPath $Root -PathType Container)) {
    throw "Root não existe: $Root"
}
$rootPath = (Resolve-Path -LiteralPath $Root).Path
$scanPath = Join-Path $rootPath $SourceDir
if (-not (Test-Path -LiteralPath $scanPath -PathType Container)) {
    $scanPath = $rootPath
}

$normalizedQuery = Normalize-Text $Query
$rawTerms = [regex]::Matches($normalizedQuery, '[a-z0-9_]{2,}') |
    ForEach-Object { $_.Value } |
    Select-Object -Unique

$terms = New-Object System.Collections.Generic.List[string]
foreach ($term in $rawTerms) {
    if ($stop -notcontains $term -and -not $terms.Contains($term)) {
        $terms.Add($term)
    }
}
if ($terms.Count -eq 0) {
    throw "Não consegui extrair palavras-chave úteis da solicitação."
}

$searchTerms = New-Object System.Collections.Generic.List[string]
foreach ($term in $terms) {
    if ($aliases.ContainsKey($term)) {
        foreach ($alias in $aliases[$term]) {
            if (-not $searchTerms.Contains($alias)) { $searchTerms.Add($alias) }
        }
    }
    if (-not $searchTerms.Contains($term)) { $searchTerms.Add($term) }
}

$extensions = @(".lua",".luau",".json",".toml",".yaml",".yml",".md",".txt",".js",".ts",".tsx",".jsx",".py",".cs",".cpp",".h")
$skip = @(".git","node_modules","Packages","target","bin","obj",".venv","venv","__pycache__","graphify-out")
$files = Get-ChildItem -LiteralPath $scanPath -File -Recurse -ErrorAction SilentlyContinue |
    Where-Object {
        $relative = $_.FullName.Substring($scanPath.Length).TrimStart('\')
        $parts = $relative -split '[\\/]'
        $blocked = $false
        foreach ($part in $parts) {
            if ($skip -contains $part) { $blocked = $true; break }
        }
        ($extensions -contains $_.Extension.ToLowerInvariant()) -and (-not $blocked)
    }

$ranked = foreach ($file in $files) {
    try {
        $content = Get-Content -LiteralPath $file.FullName -Raw -ErrorAction Stop
    } catch { continue }

    $normPath = Normalize-Text ($file.FullName.Substring($rootPath.Length))
    $normContent = Normalize-Text $content
    $score = 0
    $matched = New-Object System.Collections.Generic.List[string]

    foreach ($term in $searchTerms) {
        $escaped = [regex]::Escape((Normalize-Text $term))
        $pathHits = [regex]::Matches($normPath, $escaped).Count
        $bodyHits = [regex]::Matches($normContent, $escaped).Count
        if (($pathHits + $bodyHits) -gt 0) {
            $score += ($pathHits * 8) + [Math]::Min($bodyHits, 12)
            if (-not $matched.Contains($term)) { $matched.Add($term) }
        }
    }

    if ($score -gt 0) {
        $lines = Get-Content -LiteralPath $file.FullName -ErrorAction SilentlyContinue
        $snippets = New-Object System.Collections.Generic.List[string]
        for ($i = 0; $i -lt $lines.Count; $i++) {
            $lineNorm = Normalize-Text $lines[$i]
            $hit = $false
            foreach ($term in $searchTerms) {
                if ($lineNorm.Contains((Normalize-Text $term))) { $hit = $true; break }
            }
            if ($hit -and $snippets.Count -lt $MaxMatchesPerFile) {
                $start = [Math]::Max(0, $i - 1)
                $end = [Math]::Min($lines.Count - 1, $i + 1)
                $snippetLines = @()
                for ($j = $start; $j -le $end; $j++) {
                    $snippetLines += ("{0}: {1}" -f ($j + 1), $lines[$j])
                }
                $snippets.Add(($snippetLines -join "`n"))
                $i = $end
            }
        }

        [pscustomobject]@{
            Score = $score
            Path = $file.FullName.Substring($rootPath.Length).TrimStart('\')
            Matches = ($matched -join ", ")
            Snippets = @($snippets)
        }
    }
}

$ranked = @($ranked | Sort-Object Score -Descending | Select-Object -First $MaxFiles)
$intent = ($terms -join " + ").ToUpperInvariant()
$report = New-Object System.Collections.Generic.List[string]
$report.Add("# $intent | CONTEXTO LOCALIZADO")
$report.Add("")
$report.Add(("Termos: {0}" -f ($terms -join ", ")))
$report.Add(("Arquivos encontrados: {0} | Diretório pesquisado: {1}" -f $ranked.Count, $scanPath))
$report.Add("")
$report.Add("> Ranking lexical é apenas uma pista. Confirme referências, chamadas e dependências antes de editar.")
$report.Add("")

if ($ranked.Count -eq 0) {
    $report.Add("Nenhum arquivo correspondeu aos termos. Amplie a busca com sinônimos ou confira o diretório.")
} else {
    $n = 0
    foreach ($item in $ranked) {
        $n++
        $report.Add(("## {0}. {1} (score {2})" -f $n, $item.Path, $item.Score))
        $report.Add(("Correspondências: {0}" -f $item.Matches))
        foreach ($snippet in $item.Snippets) {
            $report.Add('```text')
            $report.Add($snippet)
            $report.Add('```')
        }
        $report.Add("")
    }
}

$reportText = $report -join "`r`n"
$approxTokens = [Math]::Ceiling($reportText.Length / 4)
$report.Add(("Estimativa grosseira do relatório: ~{0} tokens (caracteres/4; não é medição do tokenizer)." -f $approxTokens))
$finalText = $report -join "`r`n"

if ($OutputPath) {
    $outDir = Split-Path -Parent $OutputPath
    if ($outDir -and -not (Test-Path -LiteralPath $outDir)) {
        New-Item -ItemType Directory -Path $outDir -Force | Out-Null
    }
    Set-Content -LiteralPath $OutputPath -Value $finalText -Encoding UTF8
    Write-Output "Relatório salvo em: $OutputPath"
}
Write-Output $finalText
