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

function Test-PathOrStop {
    param (
        [Parameter(Mandatory = $true)]
        [string]$ParameterName,
        [Parameter(Mandatory = $true)]
        [string]$FilePath
    )
    if (!(Test-Path $InputPath)) {
        Write-Error "$($ParameterName): '$($InputPath)' does not exist."
        exit 1
    }
}

function Get-MP4Metadata {
    param (
        [Parameter(Mandatory = $true)]
        [string]$FilePath
    )

    Test-CommandExistsOrStop $FFProbeCommand
    $json = & $FFProbeCommand -v quiet -print_format json -show_format -show_streams $FilePath 

    $metadata = ConvertFrom-Json $json

    return $metadata
}

#--------------------------------------------------------------

Write-Host "Validating that the paths exist..."
Test-PathOrStop -ParameterName "InputPath" -FilePath $InputPath
Test-PathOrStop -ParameterName "OutPutPath" -FilePath $OutPutPath

Write-Host "Validating that the ffmpeg tooling is installed..."
$FFProbeCommand = 'ffprobe'
Test-CommandExistsOrStop $FFProbeCommand
$FFMPEGCommand = 'ffmpeg'
Test-CommandExistsOrStop $FFMPEGCommand

$MP4FileList = Get-ChildItem $InputPath -Filter *.mp4
Write-Host "Found $($MP4FileList.Count) *.mp4 files."


