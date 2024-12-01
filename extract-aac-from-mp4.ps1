<#
.SYNOPSIS

Performs monthly data updates.

.DESCRIPTION

The Update-Month.ps1 script updates the registry with new data generated
during the past month and generates a report.

.PARAMETER InputPath
Specifies the path to the CSV-based input file.

.INPUTS

None. You cannot pipe objects to Update-Month.ps1.

.OUTPUTS

None. Update-Month.ps1 does not generate any output.

.EXAMPLE

PS> .\Update-Month.ps1

.EXAMPLE

PS> .\Update-Month.ps1 -inputpath C:\Data\January.csv

.EXAMPLE

PS> .\Update-Month.ps1 -inputpath C:\Data\January.csv 
#>

param (
    [Parameter(Position = 0, Mandatory = $True)]
    [ValidateNotNullorEmpty()]
    [string]
    $ProcessingPath, 

    [parameter(Mandatory=$false)]
    [ValidateRange(1, [int]::MaxValue)]
    [int]
    $Sample
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
    if (!(Test-Path $ProcessingPath)) {
        Write-Error "$($ParameterName): '$($ProcessingPath)' does not exist."
        exit 1
    }
}

function Get-MP4Metadata {
    param (
        [Parameter(Mandatory = $true)]
        [string]$filePath
    )

    Test-CommandExistsOrStop $FFProbeCommand
    
    Write-Verbose "Get-MP4Metadata: $($filePath)"
    if (!(Test-Path -Path $filePath -PathType Leaf)) {
        Write-Error "File '$($filePath)' does not exist!"
        exit 1
    }

    $json = & $FFProbeCommand -pretty -v quiet -print_format json -show_error -show_chapters -show_format -show_streams "$filePath"
    $metadata = $json | ConvertFrom-Json -Depth 10
    return $metadata
}

#--------------------------------------------------------------

Write-Host "Validating that the processing path exists..."
Test-PathOrStop -ParameterName "ProcessingPath" -FilePath $ProcessingPath

Write-Host "Validating that the ffmpeg tooling is installed..."
$FFProbeCommand = 'ffprobe'
Test-CommandExistsOrStop $FFProbeCommand
$FFMPEGCommand = 'ffmpeg'
Test-CommandExistsOrStop $FFMPEGCommand

$MP4FileList = Get-ChildItem $ProcessingPath -Filter *.mp4
Write-Host "Found $($MP4FileList.Count) *.mp4 files."

if ($Sample) {
    Write-Host "Sampling only $($Sample) files."
    $MP4FileList = $MP4FileList | Get-Random -Count $Sample
}

foreach ($mp4File in $MP4FileList) {
    Write-Verbose "-----"

    Write-Verbose "File: $($mp4File.Name)"
    $mp4Metadata = Get-MP4Metadata $mp4File.FullName
    #Write-Host $mp4Metadata
    $jsonFile = [System.IO.Path]::ChangeExtension($mp4File, "json")
    Write-Verbose "Create JSON file."
    $mp4Metadata | Out-File -Encoding utf8NoBOM -FilePath $jsonFile

    #Write-Host ($mp4Metadata | Format-Table | Out-String)
    #$mp4Metadata | Get-Member -MemberType NoteProperty

    $streams = $mp4Metadata.streams
    Write-Verbose "Found $($streams.Count) streams."
    $audioStreams = $streams | Where-Object -Property codec_type -EQ 'audio'
    Write-Verbose "Found $($audioStreams.Count) audio streams."
    foreach ($stream in $audioStreams) {
        Write-Debug "  audio stream($($stream.index)): $($stream.codec_name) codec_type=$($stream.codec_type) bit_rate=$($stream.bit_rate) sample_rate=$($stream.sample_rate)"
    }

    $aacStreams = $audioStreams | Where-Object -Property codec_name -EQ 'aac'
    if ($aacStreams.Count -EQ 1) {
        $aacStream = $aacStreams[0]
        #Write-Host $aacStream
        $aacFilePath = [System.IO.Path]::ChangeExtension($mp4File, ".m4a")
        Write-Host $aacFilePath

        if (!(Test-Path -PathType Leaf -Path $aacFilePath)) {

            $streamIndex = $aacStream.index
            if (![int]::TryParse($streamIndex, [ref]$null)) {
                Write-Error "streamIndex ($(streamIndex)) is not a number!"
                exit 1
            }
            $streamIndex = [int]$streamIndex
            if ($streamIndex -lt 0 -or $streamIndex -gt 255) {
                Write-Error "streamIndex ($(streamIndex)) is out of range!"
                exit 1
            }
    
            Write-Verbose "Extract stream ($($streamIndex)) to $($aacFilePath)"
            & $FFMPEGCommand -v quiet -stats -i "$($mp4File.FullName)" -map "0:$($streamIndex)" -c copy "$($aacFilePath)"
    
            # ffmpeg -i input-video.avi -vn -acodec copy output-audio.aac
            # ffmpeg -i input.mkv -map 0:a:3 -c copy output.m4a
        }
        else {
            Write-Verbose "Skipping, file exists."
        }
    }
    elseif ($aacStreams -GT 1) {
        Write-Host "Multiple streams found."
        foreach($aacStream in $aacStreams) {
            Write-Host $aacStream
            $aacFilePath = [System.IO.Path]::ChangeExtension($mp4File, ".$($aacStream.index).m4a")
            Write-Host $aacFilePath
        }
    }
    else {
        Write-Verbose "No AAC streams found."
    }
}

Write-Verbose "-----"
Write-Host "Finished."
