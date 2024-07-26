function Do-PreProcessing {
    param (
        [Parameter(Mandatory, position=0)]
        [string]$ProgressStatusMessage,

        [Parameter(position=1)]
        [string]$ProgressActivity = "Pre-Processing"
    )

    # We could do Pre-processing on this script file, but by excluding it.. we could possible weird behavior,
    # like future runs of this tool being different then previous ones, as the script has modified it self before one or more times.
    $excludedFiles = @('git\', '.gitignore', '.gitattributes', '.github\CODEOWNERS', 'LICENSE', 'winutil.ps1', 'tools\Do-PreProcessing.ps1', 'docs\changelog.md', '*.png', '*.jpg', '*.jpeg', '*.exe')

    $files = Get-ChildItem $sync.PSScriptRoot -Recurse -Exclude $excludedFiles -Attributes !Directory
    $numOfFiles = $files.Count

    for ($i = 0; $i -lt $numOfFiles; $i++) {
        $file = $files[$i]
        # TODO:
        #   make more formatting rules, and document them in WinUtil Official Documentation
        (Get-Content -Raw "$file").TrimEnd() `
            -replace ('\t', '    ') `
            -replace ('\)\{', ') {') `
            -replace ('\)\r?\n\s*{', ') {') `
            -replace ('Try \{', 'try {') `
            -replace ('try\{', 'try {') `
            -replace ('try\r?\n\s*\{', 'try {') `
            -replace ('}\r?\n\s*catch', '} catch') `
            -replace ('\} Catch', '} catch') `
        | Set-Content "$file"
        Write-Progress -Activity $ProgressActivity -Status "$ProgressStatusMessage - Finished $i out of $numOfFiles" -PercentComplete (($i/$numOfFiles)*100)
    }

    Write-Progress -Activity $ProgressActivity -Status "$ProgressStatusMessage - Finished Task Successfully" -Completed
}