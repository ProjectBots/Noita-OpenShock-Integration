[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$Destination
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Get-RepoRoot {
    if ($PSScriptRoot) {
        return (Resolve-Path -LiteralPath $PSScriptRoot).Path
    }

    if ($PSCommandPath) {
        return (Resolve-Path -LiteralPath (Split-Path -Parent $PSCommandPath)).Path
    }

    if ($MyInvocation.PSScriptRoot) {
        return (Resolve-Path -LiteralPath $MyInvocation.PSScriptRoot).Path
    }

    throw 'Unable to determine repo root (script root unknown).'
}

function Get-RelativePath {
    param(
        [Parameter(Mandatory = $true)][string]$BasePath,
        [Parameter(Mandatory = $true)][string]$FullPath
    )

    $base = (Resolve-Path -LiteralPath $BasePath).Path
    $full = (Resolve-Path -LiteralPath $FullPath).Path

    if (-not $base.EndsWith([IO.Path]::DirectorySeparatorChar)) {
        $base = $base + [IO.Path]::DirectorySeparatorChar
    }

    $baseUri = [Uri]::new($base)
    $fullUri = [Uri]::new($full)
    $relative = [Uri]::UnescapeDataString($baseUri.MakeRelativeUri($fullUri).ToString())

    # Normalize to forward slashes for matching.
    return ($relative -replace '\\', '/')
}

function Get-IgnorePatterns {
    param(
        [Parameter(Mandatory = $true)][string]$RepoRoot
    )

    $copyIgnore = Join-Path $RepoRoot '.copyignore'
    $gitIgnore = Join-Path $RepoRoot '.gitignore'

    $ignorePath = $null
    if (Test-Path -LiteralPath $copyIgnore) {
        $ignorePath = $copyIgnore
    }
    elseif (Test-Path -LiteralPath $gitIgnore) {
        $ignorePath = $gitIgnore
    }

    [string[]]$patterns = @(
        # Hard default: never copy git metadata.
        '.git/'
    )

    if (-not $ignorePath) {
        return $patterns
    }

    Get-Content -LiteralPath $ignorePath | ForEach-Object {
        $line = $_.Trim()
        if (-not $line) { return }
        if ($line.StartsWith('#')) { return }
        if ($line.StartsWith('!')) {
            throw "Negation patterns ('!') are not supported: $line"
        }

        $line = $line -replace '\\', '/'
        $patterns += $line
    }

    return $patterns
}

function Test-Excluded {
    param(
        [Parameter(Mandatory = $true)][string]$RelativePath,
        [Parameter(Mandatory = $true)][bool]$IsDirectory,
        [Parameter(Mandatory = $true)][string[]]$Patterns
    )

    # Normalize relative path.
    $rel = $RelativePath.TrimStart('./')

    foreach ($pattern in $Patterns) {
        $p = $pattern.Trim()
        if (-not $p) { continue }

        $p = $p.TrimStart('./')

        $isDirPattern = $p.EndsWith('/')
        $pNoSlash = if ($isDirPattern) { $p.TrimEnd('/') } else { $p }

        if ($isDirPattern) {
            # Directory pattern matches directory itself and anything under it.
            if ($rel -eq $pNoSlash -or $rel.StartsWith($pNoSlash + '/')) {
                return $true
            }
            continue
        }

        if ($pNoSlash.Contains('/')) {
            # Path-qualified pattern.
            if ($rel -like $pNoSlash) { return $true }
        }
        else {
            # Filename-only pattern.
            $leaf = Split-Path -Leaf $rel
            if ($leaf -like $pNoSlash) { return $true }
        }
    }

    return $false
}

$repoRoot = Get-RepoRoot
$repoName = Split-Path -Leaf $repoRoot

$repoRootFull = [IO.Path]::GetFullPath($repoRoot)

if ([IO.Path]::IsPathRooted($Destination)) {
    $destinationFull = [IO.Path]::GetFullPath($Destination)
}
else {
    # Interpret relative destinations as relative to the repo root (not the current working directory).
    $destinationFull = [IO.Path]::GetFullPath((Join-Path $repoRootFull $Destination))
}

# Prevent copying into the repo (would recurse or overwrite in surprising ways).
if ($destinationFull.StartsWith($repoRootFull, [System.StringComparison]::OrdinalIgnoreCase)) {
    throw "Destination must be outside the repo root. Repo: '$repoRootFull' Destination: '$destinationFull'"
}

New-Item -ItemType Directory -Path $destinationFull -Force | Out-Null

# Empty destination first to avoid deprecated files causing issues.
$destinationRoot = [IO.Path]::GetPathRoot($destinationFull)
if ($destinationRoot -and ($destinationRoot.TrimEnd('\') + '\') -ieq ($destinationFull.TrimEnd('\') + '\')) {
    throw "Refusing to empty a drive/root destination: '$destinationFull'"
}

if (-not (Test-Path -LiteralPath $destinationFull -PathType Container)) {
    throw "Destination exists but is not a directory: '$destinationFull'"
}

Write-Host "Emptying destination folder: '$destinationFull'"
Get-ChildItem -LiteralPath $destinationFull -Force | Remove-Item -Recurse -Force

$patterns = Get-IgnorePatterns -RepoRoot $repoRoot

Write-Host "Copying '$repoName' to '$destinationFull'"
Write-Host "Using ignore patterns: $($patterns.Count)" 

$dirsQueue = New-Object System.Collections.Generic.Queue[string]
$dirsQueue.Enqueue($repoRootFull)

[int]$copied = 0
[int]$excludedFiles = 0
[int]$excludedDirs = 0

while ($dirsQueue.Count -gt 0) {
    $currentDir = $dirsQueue.Dequeue()

    Get-ChildItem -LiteralPath $currentDir -Force | ForEach-Object {
        $item = $_
        $rel = Get-RelativePath -BasePath $repoRootFull -FullPath $item.FullName

        if ($item.PSIsContainer) {
            if (Test-Excluded -RelativePath $rel -IsDirectory $true -Patterns $patterns) {
                $excludedDirs++
                return
            }
            $dirsQueue.Enqueue($item.FullName)
            return
        }

        if (Test-Excluded -RelativePath $rel -IsDirectory $false -Patterns $patterns) {
            $excludedFiles++
            return
        }

        $destPath = Join-Path $destinationFull ($rel -replace '/', '\\')
        $destDir = Split-Path -Parent $destPath
        if (-not (Test-Path -LiteralPath $destDir)) {
            New-Item -ItemType Directory -Path $destDir -Force | Out-Null
        }

        Copy-Item -LiteralPath $item.FullName -Destination $destPath -Force
        $copied++
    }
}

Write-Host "Done." 
Write-Host "Copied files: $copied" 
Write-Host "Excluded dirs: $excludedDirs" 
Write-Host "Excluded files: $excludedFiles" 
