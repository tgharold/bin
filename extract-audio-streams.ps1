<#
.SYNOPSIS

Extract audio tracks from video files in a directory.

.DESCRIPTION

Scans all files in the provided directory (no child folders) and pulls out the audio tracks.

.PARAMETER InputPath

Specifies the path to the input files.

.PARAMETER InputPath

Specifies the path where the output files will be placed.

.INPUTS

None. You cannot pipe objects in.

.OUTPUTS

None. Only debug/verbose/host level output.

.EXAMPLE

PS> ./extract-audio-streams.ps1 "/Users/user/Downloads/" "/Users/user/Downloads/Audio/" 

.EXAMPLE

PS> ./extract-audio-streams.ps1 "/Users/user/Downloads/" "/Users/user/Music/" -Sample 5 -Verbose -Debug

Sample only 5 randomly selected files from the input directory.  Print all verbose/debug level statements to the console.

#>

param (
    [Parameter(Position = 0, Mandatory = $True)]
    [ValidateNotNullorEmpty()]
    [string]
    $InputPath, 

    [Parameter(Position = 1, Mandatory = $True)]
    [ValidateNotNullorEmpty()]
    [string]
    $OutputPath, 

    [parameter(Mandatory=$false)]
    [ValidateRange(1, [int]::MaxValue)]
    [int]
    $Sample,

    [parameter(Mandatory=$false)]
    [switch]
    $JSON
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
    if (!(Test-Path $FilePath)) {
        Write-Error "$($ParameterName): '$($FilePath)' does not exist."
        exit 1
    }
}

function Get-MediaMetadata {
    param (
        [Parameter(Mandatory = $true)]
        [string]$filePath
    )

    Test-CommandExistsOrStop $FFProbeCommand
    
    Write-Debug "Get-MediaMetadata: $($filePath)"

    if (!(Test-Path -LiteralPath $filePath)) {
        Write-Error "File '$($filePath)' does not exist!"
        exit 1
    }

    try {
        $json = & $FFProbeCommand -pretty -v quiet -print_format json -show_error -show_chapters -show_format -show_streams "$filePath"
        $metadata = $json | ConvertFrom-Json -Depth 10
        return $metadata
    }
    catch {
        return $null
    }
}

function Get-OutputFileExtension {
    param (
        [Parameter(Mandatory = $true)]
        [string]$codecName
    )
    Switch ($codecName)
    {
        'aac' { return 'm4a' }
        'mp3' { return 'mp3' }
        'opus' { return 'opus' }
        'vorbis' { return 'ogg' }
    }
    return 'unknown'
}

#--------------------------------------------------------------

Write-Host "Validating that the InputPath exists..."
Test-PathOrStop -ParameterName "InputPath" -FilePath $InputPath

Write-Host "Validating that the OutputPath exists..."
Test-PathOrStop -ParameterName "OutputPath" -FilePath $OutputPath

Write-Host "Validating that the ffmpeg tooling is installed..."
$FFProbeCommand = 'ffprobe'
Test-CommandExistsOrStop $FFProbeCommand
$FFMPEGCommand = 'ffmpeg'
Test-CommandExistsOrStop $FFMPEGCommand

$fileList = Get-ChildItem $InputPath -File
Write-Host "Found $($fileList.Count) files."

if ($Sample) {
    Write-Host "Sampling only $($Sample) files."
    $fileList = $fileList | Get-Random -Count $Sample
}

foreach ($file in $fileList) {
    Write-Verbose "-----"
    Write-Verbose "File: $($file.Name)"
    $mediaMetadata = Get-MediaMetadata $file.FullName

    if ($null -ne $mediaMetadata) {
        Write-Host $baseFileName

        if ($JSON) {
        $jsonFileName = [System.IO.Path]::ChangeExtension($baseFileName, "json")
        $jsonFileName = Join-Path -Path $OutputPath -ChildPath $jsonFileName
            Write-Verbose "JSON path: $($jsonFileName)"
        $mediaMetadata | ConvertTo-Json -depth 10 | Out-File -Encoding utf8NoBOM -LiteralPath $jsonFileName
        }
    
        $streams = $mediaMetadata.streams
        Write-Verbose "Found $($streams.Count) streams."
        $audioStreams = $streams | Where-Object -Property codec_type -EQ 'audio'
        Write-Verbose "Found $($audioStreams.Count) audio streams."

        # Notes:
        # - Try to put -ss -t before the -i mp3. When -ss used as an output option (after -i), 
        # ffmpeg would discard input until the timestamps reach position. https://superuser.com/a/1542741
        # - Extract single frame
        # ffmpeg -i input_video.mp4 -ss 00:00:05 -vframes 1 frame_out.jpg
        $thumbnailFileName = [System.IO.Path]::ChangeExtension($baseFileName, '.jpg')
        $thumbnailFileName = Join-Path -Path $OutputPath -ChildPath $thumbnailFileName
        if (!(Test-Path -PathType Leaf -LiteralPath $thumbnailFileName)) {
            Write-Verbose "Extract single frame to $($thumbnailFileName)"
            $thumbnailWidth = "600"
            $thumbnailHeight = "600"
            # Pad the image: pad=$($thumbnailWidth):$($thumbnailHeight):-1:-1:$($paddingColor)
            #$paddingColor = "000000"
            & $FFMPEGCommand -v warning -stats -ss 00:00:15 -i "$($file.FullName)" -frames:v 1 -an -update true -vf "thumbnail,scale=$($thumbnailWidth):$($thumbnailHeight):force_original_aspect_ratio=decrease,setsar=1" "$($thumbnailFileName)"
        } else {
            Write-Verbose "Single frame image exists: $($thumbnailFileName)"
        }

        foreach ($stream in $audioStreams) {
            Write-Debug "  audio stream($($stream.index)): $($stream.codec_name) codec_type=$($stream.codec_type) bit_rate=$($stream.bit_rate) sample_rate=$($stream.sample_rate)"

            $streamFileName = $baseFileName
            $fileExtension = Get-OutputFileExtension($stream.codec_name)
            if ($audioStreams.Count -gt 0) { $streamFileName = $streamFileName + "-$($stream.index)" }
            $outputFileName = [System.IO.Path]::ChangeExtension($streamFileName, $fileExtension)
            $outputFileName = Join-Path -Path $OutputPath -ChildPath $outputFileName

            if (!(Test-Path -PathType Leaf -LiteralPath $outputFileName)) {
                $streamIndex = $stream.index
                if (![int]::TryParse($streamIndex, [ref]$null)) {
                    Write-Error "streamIndex ($(streamIndex)) is not a number!"
                    exit 1
                }
                $streamIndex = [int]$streamIndex
                if ($streamIndex -lt 0 -or $streamIndex -gt 255) {
                    Write-Error "streamIndex ($(streamIndex)) is out of range!"
                    exit 1
                }        
        
                Write-Verbose "Extract stream ($($streamIndex)) to $($outputFileName)"
                & $FFMPEGCommand -v quiet -stats -i "$($file.FullName)" -map "0:$($streamIndex)" -c copy "$($outputFileName)"

            } else {
                Write-Verbose "Skipping, file exists: $($outputFileName)"
            }
        }
    }
}

Write-Verbose "-----"
Write-Host "Finished."
