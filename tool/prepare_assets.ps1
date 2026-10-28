$ErrorActionPreference = 'Stop'

Add-Type -AssemblyName System.IO.Compression.FileSystem

function Assert-WavFile {
    param([Parameter(Mandatory)][string]$Path)

    $stream = [System.IO.File]::OpenRead($Path)
    try {
        if ($stream.Length -lt 44) {
            throw "WAV inválido o incompleto: $Path"
        }

        $reader = [System.IO.BinaryReader]::new($stream)
        $riff = [System.Text.Encoding]::ASCII.GetString($reader.ReadBytes(4))
        [void]$reader.ReadUInt32()
        $wave = [System.Text.Encoding]::ASCII.GetString($reader.ReadBytes(4))
        if ($riff -ne 'RIFF' -or $wave -ne 'WAVE') {
            throw "La muestra no tiene cabecera RIFF/WAVE: $Path"
        }
    }
    finally {
        $stream.Dispose()
    }
}

function Write-SyntheticWav {
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][string]$Kind,
        [Parameter(Mandatory)][double]$Duration,
        [Parameter(Mandatory)][double]$Frequency,
        [Parameter(Mandatory)][int]$Seed
    )

    $sampleRate = 22050
    $frameCount = [int]($sampleRate * $Duration)
    $dataBytes = $frameCount * 2
    $random = [System.Random]::new($Seed)
    $stream = [System.IO.File]::Create($Path)
    $writer = [System.IO.BinaryWriter]::new($stream)

    try {
        $writer.Write([System.Text.Encoding]::ASCII.GetBytes('RIFF'))
        $writer.Write([int](36 + $dataBytes))
        $writer.Write([System.Text.Encoding]::ASCII.GetBytes('WAVE'))
        $writer.Write([System.Text.Encoding]::ASCII.GetBytes('fmt '))
        $writer.Write([int]16)
        $writer.Write([int16]1)
        $writer.Write([int16]1)
        $writer.Write([int]$sampleRate)
        $writer.Write([int]($sampleRate * 2))
        $writer.Write([int16]2)
        $writer.Write([int16]16)
        $writer.Write([System.Text.Encoding]::ASCII.GetBytes('data'))
        $writer.Write([int]$dataBytes)

        for ($frame = 0; $frame -lt $frameCount; $frame++) {
            $time = $frame / $sampleRate
            $noise = ($random.NextDouble() * 2.0) - 1.0
            $wave = 0.0

            switch ($Kind) {
                'kick' {
                    $wave = [Math]::Sin(
                        2.0 * [Math]::PI * (
                            $Frequency * $time +
                            42.0 * (1.0 - [Math]::Exp(-$time * 26.0)) / 26.0
                        )
                    ) * [Math]::Exp(-$time * 15.0)
                    if ($time -lt 0.008) {
                        $wave += $noise * 0.16 * (1.0 - ($time / 0.008))
                    }
                }
                '808' {
                    $instantFrequency = $Frequency * (
                        1.0 + 0.7 * [Math]::Exp(-$time * 8.0)
                    )
                    $envelopeRate = if ($Duration -gt 2.0) { 1.65 } else { 3.2 }
                    $wave = (
                        [Math]::Sin(2.0 * [Math]::PI * $instantFrequency * $time) +
                        0.22 * [Math]::Sin(4.0 * [Math]::PI * $instantFrequency * $time)
                    ) * [Math]::Exp(-$time * $envelopeRate)
                }
                'clap' {
                    $bursts = 0.0
                    foreach ($onset in @(0.0, 0.022, 0.047, 0.075)) {
                        if ($time -ge $onset -and $time -lt ($onset + 0.012)) {
                            $bursts += $noise * [Math]::Exp(-($time - $onset) * 55.0)
                        }
                    }
                    $wave = $bursts * [Math]::Exp(-$time * 5.2)
                }
                'clave' {
                    $wave = (
                        0.68 * [Math]::Sin(2.0 * [Math]::PI * $Frequency * $time) +
                        0.32 * $noise
                    ) * [Math]::Exp(-$time * 38.0)
                }
                'timbale' {
                    $wave = (
                        [Math]::Sin(2.0 * [Math]::PI * $Frequency * $time) +
                        0.48 * [Math]::Sin(2.0 * [Math]::PI * $Frequency * 2.31 * $time) +
                        0.2 * [Math]::Sin(2.0 * [Math]::PI * $Frequency * 3.87 * $time)
                    ) * [Math]::Exp(-$time * 7.5)
                }
                'cowbell' {
                    $wave = (
                        [Math]::Sin(2.0 * [Math]::PI * $Frequency * $time) +
                        0.72 * [Math]::Sin(2.0 * [Math]::PI * ($Frequency * 1.506) * $time)
                    ) * [Math]::Exp(-$time * 8.5)
                }
                'shaker' {
                    $pulse = 0.3 + 0.7 * [Math]::Abs(
                        [Math]::Sin(2.0 * [Math]::PI * 12.0 * $time)
                    )
                    $wave = $noise * $pulse * [Math]::Exp(-$time * 7.0)
                }
                default {
                    throw "Tipo de sonido sintético desconocido: $Kind"
                }
            }

            $sampleValue = [int]([Math]::Round(
                [Math]::Max(-1.0, [Math]::Min(1.0, $wave * 0.78)) * 32767.0
            ))
            $writer.Write([int16]$sampleValue)
        }
    }
    finally {
        $writer.Dispose()
        $stream.Dispose()
    }
}

$root = Split-Path -Parent $PSScriptRoot
$assetRoot = Join-Path $root 'assets'
$sk5Directory = Join-Path $assetRoot 'sk5'
$champetaDirectory = Join-Path $assetRoot 'champeta'
$dembowDirectory = Join-Path $assetRoot 'dembow'
$temporaryDirectory = Join-Path ([System.IO.Path]::GetTempPath()) (
    'sampler-perreo-assets-' + [guid]::NewGuid().ToString('N')
)
$archivePath = Join-Path $temporaryDirectory 'SK-5-Drums.zip'

New-Item -ItemType Directory -Force -Path $temporaryDirectory | Out-Null
New-Item -ItemType Directory -Force -Path $sk5Directory, $champetaDirectory, $dembowDirectory | Out-Null

try {
    Invoke-WebRequest `
        -Uri 'https://storage.googleapis.com/www-frequency303-com-data-prod/SK-5-Drums.zip' `
        -OutFile $archivePath `
        -UseBasicParsing

    $archive = [System.IO.Compression.ZipFile]::OpenRead($archivePath)
    try {
        $cc0Samples = [ordered]@{
            'kick.wav' = 'Kick.wav'
            'snare.wav' = 'Snare.wav'
            'hihat.wav' = 'Hat.wav'
            'conga_high.wav' = 'HiBongo.wav'
            'conga_low.wav' = 'LowBongo.wav'
            'laser.wav' = 'LaserGun.wav'
            'dog.wav' = 'Dog.wav'
            'lion.wav' = 'Lion.wav'
        }

        foreach ($sample in $cc0Samples.GetEnumerator()) {
            $entry = $archive.GetEntry("SK-5-Drums/$($sample.Value)")
            if ($null -eq $entry) {
                throw "No se encontró la muestra CC0 esperada: $($sample.Value)"
            }

            $destination = Join-Path $sk5Directory $sample.Key
            $sourceStream = $entry.Open()
            $destinationStream = [System.IO.File]::Create($destination)
            try {
                $sourceStream.CopyTo($destinationStream)
            }
            finally {
                $destinationStream.Dispose()
                $sourceStream.Dispose()
            }

            Assert-WavFile $destination
        }
    }
    finally {
        $archive.Dispose()
    }

    foreach ($directory in @($champetaDirectory, $dembowDirectory)) {
        foreach ($sampleName in @('snare.wav', 'conga_low.wav', 'conga_high.wav')) {
            Copy-Item `
                -LiteralPath (Join-Path $sk5Directory $sampleName) `
                -Destination (Join-Path $directory $sampleName) `
                -Force
        }
    }

    foreach ($sampleName in @(
        'kick.wav',
        'hihat.wav',
        'laser.wav',
        'dog.wav',
        'lion.wav'
    )) {
        Copy-Item `
            -LiteralPath (Join-Path $sk5Directory $sampleName) `
            -Destination (Join-Path $champetaDirectory $sampleName) `
            -Force
    }

    $syntheticSamples = @(
        @{ Name = 'kick-beater.wav'; Kind = 'kick'; Duration = 0.32; Frequency = 110.0 }
        @{ Name = 'kick-tight-beater.wav'; Kind = 'kick'; Duration = 0.18; Frequency = 145.0 }
        @{ Name = '808-c.wav'; Kind = '808'; Duration = 1.4; Frequency = 65.406 }
        @{ Name = '808-f.wav'; Kind = '808'; Duration = 1.4; Frequency = 87.307 }
        @{ Name = '808-g.wav'; Kind = '808'; Duration = 1.4; Frequency = 97.999 }
        @{ Name = '808-long.wav'; Kind = '808'; Duration = 2.4; Frequency = 65.406 }
        @{ Name = 'clap.wav'; Kind = 'clap'; Duration = 0.32; Frequency = 0.0 }
        @{ Name = 'clave.wav'; Kind = 'clave'; Duration = 0.13; Frequency = 1750.0 }
        @{ Name = 'clave-low.wav'; Kind = 'clave'; Duration = 0.16; Frequency = 950.0 }
        @{ Name = 'timbale-low-twin.wav'; Kind = 'timbale'; Duration = 0.55; Frequency = 240.0 }
        @{ Name = 'timbale-high-twin.wav'; Kind = 'timbale'; Duration = 0.48; Frequency = 390.0 }
        @{ Name = 'cowbell.wav'; Kind = 'cowbell'; Duration = 0.48; Frequency = 560.0 }
        @{ Name = 'shaker.wav'; Kind = 'shaker'; Duration = 0.32; Frequency = 0.0 }
    )

    $seed = 713
    foreach ($sample in $syntheticSamples) {
        foreach ($directory in @($champetaDirectory, $dembowDirectory)) {
            $destination = Join-Path $directory $sample.Name
            Write-SyntheticWav `
                -Path $destination `
                -Kind $sample.Kind `
                -Duration $sample.Duration `
                -Frequency $sample.Frequency `
                -Seed $seed
            Assert-WavFile $destination
        }

        $seed++
    }

    Write-Output 'Assets preparados: 8 muestras SK-5 bajo CC0 y muestras sintéticas originales.'
}
finally {
    if (Test-Path -LiteralPath $temporaryDirectory) {
        Remove-Item -LiteralPath $temporaryDirectory -Recurse -Force
    }
}
