<#
.SYNOPSIS

Performs monthly data updates.

.DESCRIPTION

The Update-Month.ps1 script updates the registry with new data generated
during the past month and generates a report.

.PARAMETER InputPath
Specifies the path to the CSV-based input file.

.PARAMETER OutputPath
Specifies the name and path for the CSV-based output file. By default,
MonthlyUpdates.ps1 generates a name from the date and time it runs, and
saves the output in the local directory.

.INPUTS

None. You cannot pipe objects to Update-Month.ps1.

.OUTPUTS

None. Update-Month.ps1 does not generate any output.

.EXAMPLE

PS> .\Update-Month.ps1

.EXAMPLE

PS> .\Update-Month.ps1 -inputpath C:\Data\January.csv

.EXAMPLE

PS> .\Update-Month.ps1 -inputpath C:\Data\January.csv -outputPath `
C:\Reports\2009\January.csv
#>

param (
    [Parameter(Position = 0, Mandatory = $True)][ValidateNotNullorEmpty()][string]$InputPath, 
    [Parameter(Position = 1, Mandatory = $True)][ValidateNotNullorEmpty()][string]$OutPutPath
)

if (!(Test-Path $InputPath)) {
    Write-Error "InputPath '$($InputPath)' does not exist."
    exit 1
}

if (!(Test-Path $OutPutPath)) {
    Write-Error "OutPutPath '$($OutPutPath)' does not exist."
    exit 1
}

Function Test-CommandExistsOrStop {
    Param (
        $command
        )
    $oldPreference = $ErrorActionPreference
    $ErrorActionPreference = ‘stop’
    try {
        if (Get-Command $command) { 
            RETURN
        }
    }
    Catch { 
        Write-Error "The command '$command' does not exist."
        exit 1
    }
    Finally { 
        $ErrorActionPreference = $oldPreference 
    }
}

#--------------------------------------------------------------

Write-Host "Validating that the ffmpeg tooling is installed..."
$ffprobe = 'ffprobe'
Test-CommandExistsOrStop $ffprobe
$ffmpeg = 'ffmpeg'
Test-CommandExistsOrStop $ffmpeg

