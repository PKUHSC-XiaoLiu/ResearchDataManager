[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$script:AppName = 'ResearchData Manager'
$script:AppVersion = '0.1.0'
$script:ConfigDirectory = Join-Path $env:APPDATA 'ResearchDataManager'
$script:ConfigPath = Join-Path $script:ConfigDirectory 'config.json'
$script:ProjectMap = @{}

function Get-DefaultConfig {
    [pscustomobject]@{
        Root = 'D:\ResearchData'
        BackupRoot = ''
        Operator = '刘霄'
        Version = $script:AppVersion
    }
}

function Write-JsonAtomic {
    param(
        [Parameter(Mandatory = $true)]$Value,
        [Parameter(Mandatory = $true)][string]$Path
    )

    $parent = Split-Path -Parent $Path
    if (-not (Test-Path -LiteralPath $parent -PathType Container)) {
        New-Item -ItemType Directory -Path $parent | Out-Null
    }

    $temporary = "$Path.$([guid]::NewGuid().ToString('N')).tmp"
    $Value | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $temporary -Encoding UTF8

    if (Test-Path -LiteralPath $Path -PathType Leaf) {
        $backup = "$Path.$(Get-Date -Format 'yyyyMMdd-HHmmssfff').bak"
        [System.IO.File]::Replace($temporary, $Path, $backup, $true)
    }
    else {
        [System.IO.File]::Move($temporary, $Path)
    }
}

function Write-TextAtomic {
    param(
        [Parameter(Mandatory = $true)][AllowEmptyString()][string]$Text,
        [Parameter(Mandatory = $true)][string]$Path
    )

    $parent = Split-Path -Parent $Path
    if (-not (Test-Path -LiteralPath $parent -PathType Container)) {
        New-Item -ItemType Directory -Path $parent | Out-Null
    }

    $temporary = "$Path.$([guid]::NewGuid().ToString('N')).tmp"
    Set-Content -LiteralPath $temporary -Value $Text -Encoding UTF8

    if (Test-Path -LiteralPath $Path -PathType Leaf) {
        $backup = "$Path.$(Get-Date -Format 'yyyyMMdd-HHmmssfff').bak"
        [System.IO.File]::Replace($temporary, $Path, $backup, $true)
    }
    else {
        [System.IO.File]::Move($temporary, $Path)
    }
}

function Write-CsvAtomic {
    param(
        [Parameter(Mandatory = $true)][AllowEmptyCollection()][object[]]$Records,
        [Parameter(Mandatory = $true)][string]$Path
    )

    $parent = Split-Path -Parent $Path
    if (-not (Test-Path -LiteralPath $parent -PathType Container)) {
        New-Item -ItemType Directory -Path $parent | Out-Null
    }

    $temporary = "$Path.$([guid]::NewGuid().ToString('N')).tmp"
    @($Records) | Export-Csv -LiteralPath $temporary -NoTypeInformation -Encoding UTF8

    if (Test-Path -LiteralPath $Path -PathType Leaf) {
        $backup = "$Path.$(Get-Date -Format 'yyyyMMdd-HHmmssfff').bak"
        [System.IO.File]::Replace($temporary, $Path, $backup, $true)
    }
    else {
        [System.IO.File]::Move($temporary, $Path)
    }
}

function Load-AppConfig {
    if (-not (Test-Path -LiteralPath $script:ConfigPath -PathType Leaf)) {
        $config = Get-DefaultConfig
        Write-JsonAtomic -Value $config -Path $script:ConfigPath
        return $config
    }

    try {
        $loaded = Get-Content -LiteralPath $script:ConfigPath -Raw | ConvertFrom-Json
        $default = Get-DefaultConfig
        foreach ($property in @('Root', 'BackupRoot', 'Operator', 'Version')) {
            if ($null -eq $loaded.PSObject.Properties[$property]) {
                $loaded | Add-Member -NotePropertyName $property -NotePropertyValue $default.$property
            }
        }
        return $loaded
    }
    catch {
        throw "配置文件无法读取：$($script:ConfigPath)`r`n$($_.Exception.Message)"
    }
}

function Save-AppConfig {
    param([Parameter(Mandatory = $true)]$Config)
    $Config.Version = $script:AppVersion
    Write-JsonAtomic -Value $Config -Path $script:ConfigPath
}

function Get-SafeRootPath {
    param([Parameter(Mandatory = $true)][string]$Path)

    if ([string]::IsNullOrWhiteSpace($Path)) {
        throw 'ResearchData根目录不能为空。'
    }
    if (-not [System.IO.Path]::IsPathRooted($Path)) {
        throw "必须使用绝对路径，例如 D:\ResearchData。当前输入：$Path"
    }

    $fullPath = [System.IO.Path]::GetFullPath($Path).TrimEnd('\')
    $driveRoot = [System.IO.Path]::GetPathRoot($fullPath).TrimEnd('\')
    if ($fullPath -eq $driveRoot) {
        throw '不能直接使用磁盘根目录，请使用D:\ResearchData之类的专用目录。'
    }
    if (Test-Path -LiteralPath $fullPath -PathType Leaf) {
        throw "目标路径已经被同名文件占用：$fullPath"
    }
    return $fullPath
}

function Ensure-Directory {
    param([Parameter(Mandatory = $true)][string]$Path)
    if (Test-Path -LiteralPath $Path) {
        if (-not (Test-Path -LiteralPath $Path -PathType Container)) {
            throw "文件阻挡了所需目录：$Path"
        }
        return
    }
    New-Item -ItemType Directory -Path $Path | Out-Null
}

function Ensure-ResearchRoot {
    param([Parameter(Mandatory = $true)][string]$Root)

    $Root = Get-SafeRootPath -Path $Root
    $paths = @(
        '',
        '00_Inbox',
        '00_Inbox\Instrument_Export',
        '00_Inbox\External_Data',
        '00_Inbox\To_Be_Classified',
        '01_Projects',
        '02_SharedResources',
        '02_SharedResources\01_GeneralProtocols',
        '02_SharedResources\02_Primers',
        '02_SharedResources\03_Antibodies',
        '02_SharedResources\04_siRNA_shRNA',
        '02_SharedResources\05_CellLines',
        '02_SharedResources\06_GeneSets',
        '02_SharedResources\07_ReferenceGenomes',
        '02_SharedResources\08_PublicDatasets_Index',
        '02_SharedResources\09_Software_Documentation',
        '03_Templates',
        '03_Templates\01_Project_Template',
        '03_Templates\02_Experiment_Template',
        '03_Templates\03_Analysis_Template',
        '03_Templates\04_Figure_Template',
        '03_Templates\05_Forms',
        '04_Automation',
        '04_Automation\Scripts',
        '04_Automation\Config',
        '04_Automation\Logs',
        '04_Automation\Documentation',
        '05_SystemRecords',
        '90_Transfer',
        '90_Transfer\To_Instrument',
        '90_Transfer\To_Collaborator',
        '90_Transfer\From_Collaborator',
        '90_Transfer\Temporary_Export',
        '99_ArchiveIndex',
        '99_ArchiveIndex\Project_Manifests',
        '99_ArchiveIndex\Restore_Test_Records'
    )

    foreach ($relative in $paths) {
        $path = if ($relative -eq '') { $Root } else { Join-Path $Root $relative }
        Ensure-Directory -Path $path
    }
}

function Get-ProjectRegisterPath {
    Join-Path $script:Config.Root '05_SystemRecords\Project_Register.csv'
}

function Get-ExperimentRegisterPath {
    Join-Path $script:Config.Root '05_SystemRecords\Experiment_Master_Register.csv'
}

function Write-AppLog {
    param(
        [Parameter(Mandatory = $true)][string]$Operation,
        [Parameter(Mandatory = $true)][string]$Message,
        [ValidateSet('INFO', 'WARNING', 'ERROR')][string]$Level = 'INFO'
    )

    try {
        $logPath = Join-Path $script:Config.Root '04_Automation\Logs\ResearchDataManager_Log.csv'
        Ensure-Directory -Path (Split-Path -Parent $logPath)
        $record = [pscustomobject]@{
            Timestamp = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')
            Level = $Level
            Operation = $Operation
            Operator = $script:Config.Operator
            Message = $Message
        }
        if (Test-Path -LiteralPath $logPath -PathType Leaf) {
            $record | Export-Csv -LiteralPath $logPath -Append -NoTypeInformation -Encoding UTF8
        }
        else {
            $record | Export-Csv -LiteralPath $logPath -NoTypeInformation -Encoding UTF8
        }
    }
    catch {
        # Logging must never hide the primary operation result.
    }
}

function Get-Projects {
    $records = @()
    $registerPath = Get-ProjectRegisterPath
    if (Test-Path -LiteralPath $registerPath -PathType Leaf) {
        $records = @(Import-Csv -LiteralPath $registerPath)
    }

    $knownFolders = @{}
    foreach ($record in $records) {
        if (-not [string]::IsNullOrWhiteSpace($record.FolderName)) {
            $knownFolders[$record.FolderName.ToLowerInvariant()] = $true
        }
    }

    $projectsRoot = Join-Path $script:Config.Root '01_Projects'
    if (Test-Path -LiteralPath $projectsRoot -PathType Container) {
        foreach ($folder in @(Get-ChildItem -LiteralPath $projectsRoot -Directory -ErrorAction SilentlyContinue)) {
            if (-not $knownFolders.ContainsKey($folder.Name.ToLowerInvariant())) {
                $inferredCode = ($folder.Name -split '[_-]')[0].ToUpperInvariant()
                $records += [pscustomobject]@{
                    ProjectCode = $inferredCode
                    FolderName = $folder.Name
                    ProjectName = $folder.Name
                    Description = 'Existing folder; not yet registered'
                    Confidentiality = 'P1'
                    CreatedAt = ''
                    Path = $folder.FullName
                    Status = 'ACTIVE'
                }
            }
        }
    }

    @($records | Sort-Object ProjectCode, FolderName)
}

function Get-ProjectByCode {
    param([Parameter(Mandatory = $true)][string]$ProjectCode)
    $project = @(Get-Projects | Where-Object { $_.ProjectCode -ieq $ProjectCode })
    if ($project.Count -eq 0) {
        throw "找不到项目：$ProjectCode"
    }
    if ($project.Count -gt 1) {
        throw "项目代码不唯一，请先在项目登记表中处理：$ProjectCode"
    }
    return $project[0]
}

function New-ProjectSkeleton {
    param([Parameter(Mandatory = $true)][string]$ProjectRoot)

    $relativePaths = @(
        '',
        '00_Project_Admin',
        '01_Protocols',
        '02_Experiments',
        '03_Integrated_Analysis',
        '04_Figures',
        '04_Figures\Working_Figures',
        '04_Figures\Manuscript_Main',
        '04_Figures\Manuscript_Supplementary',
        '04_Figures\Presentation',
        '05_Manuscript',
        '06_Presentations',
        '99_Archive'
    )
    foreach ($relative in $relativePaths) {
        $path = if ($relative -eq '') { $ProjectRoot } else { Join-Path $ProjectRoot $relative }
        Ensure-Directory -Path $path
    }
}

function New-ResearchProject {
    param(
        [Parameter(Mandatory = $true)][string]$ProjectCode,
        [Parameter(Mandatory = $true)][string]$FolderName,
        [Parameter(Mandatory = $true)][string]$ProjectName,
        [string]$Description = '',
        [ValidateSet('P0', 'P1', 'P2')][string]$Confidentiality = 'P1'
    )

    $ProjectCode = $ProjectCode.Trim().ToUpperInvariant()
    $FolderName = $FolderName.Trim()
    $ProjectName = $ProjectName.Trim()

    if ($ProjectCode -notmatch '^[A-Z][A-Z0-9_]{1,11}$') {
        throw '项目代码必须为2–12位大写字母、数字或下划线，并以字母开头，例如IDH2。'
    }
    if ($FolderName -notmatch '^[A-Za-z0-9][A-Za-z0-9._-]{1,63}$') {
        throw '项目文件夹名称必须为2–64位ASCII字母、数字、点、下划线或短横线。'
    }
    if ([string]::IsNullOrWhiteSpace($ProjectName)) {
        throw '项目名称不能为空。'
    }
    if (@(Get-Projects | Where-Object { $_.ProjectCode -ieq $ProjectCode }).Count -gt 0) {
        throw "项目代码已经存在：$ProjectCode"
    }

    $projectRoot = Join-Path $script:Config.Root (Join-Path '01_Projects' $FolderName)
    if (Test-Path -LiteralPath $projectRoot) {
        throw "项目文件夹已经存在：$projectRoot"
    }

    New-ProjectSkeleton -ProjectRoot $projectRoot
    $record = [pscustomobject]@{
        ProjectCode = $ProjectCode
        FolderName = $FolderName
        ProjectName = $ProjectName
        Description = $Description.Trim()
        Confidentiality = $Confidentiality
        CreatedAt = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')
        Path = $projectRoot
        Status = 'ACTIVE'
    }

    $records = @(Get-Projects | Where-Object { $_.Description -ne 'Existing folder; not yet registered' })
    $records += $record
    Write-CsvAtomic -Records $records -Path (Get-ProjectRegisterPath)

    $readme = @"
# $ProjectName

- Project code: $ProjectCode
- Folder name: $FolderName
- Confidentiality: $Confidentiality
- Created: $($record.CreatedAt)
- Owner: $($script:Config.Operator)

## Description

$Description
"@
    Write-TextAtomic -Text $readme -Path (Join-Path $projectRoot '00_Project_Admin\PROJECT_README.md')
    Write-AppLog -Operation 'CREATE_PROJECT' -Message "$ProjectCode | $projectRoot"
    return $record
}

function Get-Experiments {
    param([string]$ProjectCode = '')

    $records = @()
    $registerPath = Get-ExperimentRegisterPath
    if (Test-Path -LiteralPath $registerPath -PathType Leaf) {
        $records = @(Import-Csv -LiteralPath $registerPath)
    }

    $knownIds = @{}
    foreach ($record in $records) {
        $knownIds[$record.ExpID.ToLowerInvariant()] = $true
    }

    foreach ($project in @(Get-Projects)) {
        if (-not [string]::IsNullOrWhiteSpace($ProjectCode) -and $project.ProjectCode -ine $ProjectCode) {
            continue
        }
        $experimentRoot = Join-Path $project.Path '02_Experiments'
        if (-not (Test-Path -LiteralPath $experimentRoot -PathType Container)) {
            continue
        }
        foreach ($folder in @(Get-ChildItem -LiteralPath $experimentRoot -Directory -ErrorAction SilentlyContinue)) {
            if (-not $knownIds.ContainsKey($folder.Name.ToLowerInvariant())) {
                $records += [pscustomobject]@{
                    ExpID = $folder.Name
                    ProjectCode = $project.ProjectCode
                    Date = ''
                    Assay = ''
                    Objective = ''
                    Notebook = ''
                    Groups = ''
                    BiologicalReplicates = ''
                    TechnicalReplicates = ''
                    Confidentiality = $project.Confidentiality
                    Status = 'UNREGISTERED'
                    CreatedAt = ''
                    Path = $folder.FullName
                }
            }
        }
    }

    if (-not [string]::IsNullOrWhiteSpace($ProjectCode)) {
        $records = @($records | Where-Object { $_.ProjectCode -ieq $ProjectCode })
    }
    @($records | Sort-Object CreatedAt, ExpID -Descending)
}

function Get-ExperimentById {
    param([Parameter(Mandatory = $true)][string]$ExpID)
    $matches = @(Get-Experiments | Where-Object { $_.ExpID -ieq $ExpID })
    if ($matches.Count -eq 0) {
        throw "找不到实验：$ExpID"
    }
    if ($matches.Count -gt 1) {
        throw "实验编号不唯一：$ExpID"
    }
    return $matches[0]
}

function ConvertTo-AssayToken {
    param([Parameter(Mandatory = $true)][string]$Assay)
    $token = [regex]::Replace($Assay.Trim(), '[^A-Za-z0-9]', '')
    if ([string]::IsNullOrWhiteSpace($token)) {
        throw '实验类型必须至少包含一个英文字母或数字。'
    }
    if ($token.Length -gt 18) {
        $token = $token.Substring(0, 18)
    }
    return $token
}

function New-ExperimentPackage {
    param(
        [Parameter(Mandatory = $true)][string]$ProjectCode,
        [Parameter(Mandatory = $true)][datetime]$Date,
        [Parameter(Mandatory = $true)][string]$Assay,
        [Parameter(Mandatory = $true)][string]$Objective,
        [Parameter(Mandatory = $true)][string]$Notebook,
        [string]$Groups = '',
        [int]$BiologicalReplicates = 1,
        [int]$TechnicalReplicates = 1,
        [ValidateSet('P0', 'P1', 'P2')][string]$Confidentiality = 'P1'
    )

    if ([string]::IsNullOrWhiteSpace($Objective)) { throw '实验目的不能为空。' }
    if ([string]::IsNullOrWhiteSpace($Notebook)) { throw '纸质记录本位置不能为空。' }

    $project = Get-ProjectByCode -ProjectCode $ProjectCode
    $assayToken = ConvertTo-AssayToken -Assay $Assay
    $prefix = "$($project.ProjectCode)-$($Date.ToString('yyyyMMdd'))-$assayToken-"
    $existingNumbers = @()
    foreach ($existing in @(Get-Experiments -ProjectCode $project.ProjectCode)) {
        if ($existing.ExpID -match ('^' + [regex]::Escape($prefix) + '(\d+)$')) {
            $existingNumbers += [int]$Matches[1]
        }
    }
    $nextNumber = if ($existingNumbers.Count -eq 0) { 1 } else { ($existingNumbers | Measure-Object -Maximum).Maximum + 1 }
    $expId = $prefix + $nextNumber.ToString('00')
    $experimentRoot = Join-Path $project.Path (Join-Path '02_Experiments' $expId)
    if (Test-Path -LiteralPath $experimentRoot) {
        throw "实验目录已经存在：$experimentRoot"
    }

    $directories = @(
        '', '01_Design', '02_RawData', '02_RawData\L0_Native', '02_RawData\L1_Export',
        '03_ProcessedData', '04_Analysis', '05_Results', '99_Notes'
    )
    foreach ($relative in $directories) {
        $path = if ($relative -eq '') { $experimentRoot } else { Join-Path $experimentRoot $relative }
        Ensure-Directory -Path $path
    }

    $createdAt = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')
    $record = [pscustomobject]@{
        ExpID = $expId
        ProjectCode = $project.ProjectCode
        Date = $Date.ToString('yyyy-MM-dd')
        Assay = $Assay.Trim()
        Objective = $Objective.Trim()
        Notebook = $Notebook.Trim()
        Groups = $Groups.Trim()
        BiologicalReplicates = $BiologicalReplicates
        TechnicalReplicates = $TechnicalReplicates
        Confidentiality = $Confidentiality
        Status = 'PLANNED'
        CreatedAt = $createdAt
        Path = $experimentRoot
    }

    $readme = @"
# Experiment README

- ExpID: $expId
- Project: $($project.ProjectCode)
- Status: PLANNED
- Confidentiality: $Confidentiality
- Date: $($Date.ToString('yyyy-MM-dd'))
- Operator: $($script:Config.Operator)
- Notebook: $Notebook
- Assay: $Assay
- Objective: $Objective
- Groups: $Groups
- Biological replicates: $BiologicalReplicates
- Technical replicates: $TechnicalReplicates

## Raw data

尚未导入。

## Processing and QC

待填写。

## Main result

待填写。

## Next step

待填写。
"@
    Write-TextAtomic -Text $readme -Path (Join-Path $experimentRoot '00_README.md')
    Write-JsonAtomic -Value $record -Path (Join-Path $experimentRoot 'Experiment.json')
    Write-TextAtomic -Text 'SampleID,Group,BiologicalReplicate,TechnicalReplicate,Notes' -Path (Join-Path $experimentRoot '01_Design\Sample_Sheet.csv')
    Write-TextAtomic -Text 'Timestamp,Input,Operation,Parameters,Output,QC,Notes' -Path (Join-Path $experimentRoot '04_Analysis\Processing_Log.csv')
    Write-TextAtomic -Text 'Timestamp,SampleOrEvent,Problem,Evidence,Action,Impact,ClosedAt' -Path (Join-Path $experimentRoot '99_Notes\Exception_Log.csv')

    $records = @(Get-Experiments | Where-Object { $_.Status -ne 'UNREGISTERED' })
    $records += $record
    Write-CsvAtomic -Records $records -Path (Get-ExperimentRegisterPath)
    Write-AppLog -Operation 'CREATE_EXPERIMENT' -Message "$expId | $experimentRoot"
    return $record
}

function Set-ExperimentStatus {
    param(
        [Parameter(Mandatory = $true)][string]$ExpID,
        [ValidateSet('PLANNED', 'IN_PROGRESS', 'RAW_COMPLETE', 'PROCESSING', 'ANALYZED', 'ARCHIVED')]
        [Parameter(Mandatory = $true)][string]$Status
    )

    $experiment = Get-ExperimentById -ExpID $ExpID
    $records = @(Get-Experiments | Where-Object { $_.Status -ne 'UNREGISTERED' })
    $found = $false
    foreach ($record in $records) {
        if ($record.ExpID -ieq $ExpID) {
            $record.Status = $Status
            $found = $true
        }
    }
    if (-not $found) {
        $experiment.Status = $Status
        $records += $experiment
    }
    Write-CsvAtomic -Records $records -Path (Get-ExperimentRegisterPath)

    $metadataPath = Join-Path $experiment.Path 'Experiment.json'
    if (Test-Path -LiteralPath $metadataPath -PathType Leaf) {
        $metadata = Get-Content -LiteralPath $metadataPath -Raw | ConvertFrom-Json
        $metadata.Status = $Status
        Write-JsonAtomic -Value $metadata -Path $metadataPath
    }
    Write-AppLog -Operation 'UPDATE_STATUS' -Message "$ExpID | $Status"
}

function Get-SafeNameToken {
    param([Parameter(Mandatory = $true)][string]$Value)
    $safe = [regex]::Replace($Value, '[^A-Za-z0-9._-]', '_').Trim([char[]]@('_', '.', '-'))
    if ([string]::IsNullOrWhiteSpace($safe)) { $safe = 'RawData' }
    if ($safe.Length -gt 60) { $safe = $safe.Substring(0, 60) }
    return $safe
}

function Get-UniqueDirectoryPath {
    param([Parameter(Mandatory = $true)][string]$BasePath)
    if (-not (Test-Path -LiteralPath $BasePath)) { return $BasePath }
    for ($i = 2; $i -le 999; $i++) {
        $candidate = "$BasePath-$($i.ToString('00'))"
        if (-not (Test-Path -LiteralPath $candidate)) { return $candidate }
    }
    throw "无法生成唯一导入目录：$BasePath"
}

function Get-SourceFiles {
    param([Parameter(Mandatory = $true)][string]$SourcePath)

    if (Test-Path -LiteralPath $SourcePath -PathType Leaf) {
        $file = Get-Item -LiteralPath $SourcePath
        return @([pscustomobject]@{ File = $file; RelativePath = $file.Name })
    }
    if (Test-Path -LiteralPath $SourcePath -PathType Container) {
        $root = (Get-Item -LiteralPath $SourcePath).FullName.TrimEnd('\')
        $items = @()
        foreach ($file in @(Get-ChildItem -LiteralPath $root -File -Recurse -Force)) {
            $relative = $file.FullName.Substring($root.Length).TrimStart([char[]]@('\', '/'))
            $items += [pscustomobject]@{ File = $file; RelativePath = $relative }
        }
        return $items
    }
    throw "源路径不存在：$SourcePath"
}

function Invoke-ProgressCallback {
    param(
        [scriptblock]$Callback,
        [int]$Completed,
        [int]$Total,
        [string]$Message
    )
    if ($null -ne $Callback) {
        $percent = if ($Total -le 0) { 0 } else { [math]::Min(100, [int](100 * $Completed / $Total)) }
        & $Callback $percent $Message
    }
}

function Test-IndependentBackupPath {
    param(
        [Parameter(Mandatory = $true)][string]$Root,
        [Parameter(Mandatory = $true)][string]$BackupRoot
    )
    $rootFull = [System.IO.Path]::GetFullPath($Root).TrimEnd('\')
    $backupFull = [System.IO.Path]::GetFullPath($BackupRoot).TrimEnd('\')
    if ($backupFull -ieq $rootFull -or $backupFull.StartsWith($rootFull + '\', [System.StringComparison]::OrdinalIgnoreCase)) {
        throw '备份目录不能位于ResearchData工作目录内部。'
    }
    $rootDrive = [System.IO.Path]::GetPathRoot($rootFull)
    $backupDrive = [System.IO.Path]::GetPathRoot($backupFull)
    if ($rootDrive -ieq $backupDrive -and -not $rootFull.StartsWith('\\')) {
        throw '备份目录与工作目录位于同一磁盘，不能作为独立备份。请选择其他磁盘或NAS。'
    }
}

function Import-RawData {
    param(
        [Parameter(Mandatory = $true)][string]$ExpID,
        [Parameter(Mandatory = $true)][string]$SourcePath,
        [ValidateSet('L0_Native', 'L1_Export')][string]$Level,
        [string]$Instrument = '',
        [string]$Notes = '',
        [bool]$SetReadOnly = $true,
        [bool]$CreateBackup = $false,
        [bool]$MarkRawComplete = $false,
        [scriptblock]$ProgressCallback = $null
    )

    $experiment = Get-ExperimentById -ExpID $ExpID
    $project = Get-ProjectByCode -ProjectCode $experiment.ProjectCode
    $sourceItem = Get-Item -LiteralPath $SourcePath -ErrorAction Stop
    $sourceFull = $sourceItem.FullName.TrimEnd('\')
    $targetBase = Join-Path $experiment.Path (Join-Path '02_RawData' $Level)
    Ensure-Directory -Path $targetBase

    $targetBaseFull = [System.IO.Path]::GetFullPath($targetBase).TrimEnd('\')
    if ($targetBaseFull.StartsWith($sourceFull + '\', [System.StringComparison]::OrdinalIgnoreCase) -or
        $sourceFull.StartsWith($targetBaseFull + '\', [System.StringComparison]::OrdinalIgnoreCase)) {
        throw '源路径与目标原始数据目录相互包含，可能造成递归复制，请选择仪器或临时接收目录中的源数据。'
    }

    $sourceFiles = @(Get-SourceFiles -SourcePath $sourceFull)
    if ($sourceFiles.Count -eq 0) {
        throw '源路径中没有可导入的文件。'
    }
    $sourceBytes = ($sourceFiles | ForEach-Object { $_.File.Length } | Measure-Object -Sum).Sum

    try {
        $destinationDrive = New-Object System.IO.DriveInfo ([System.IO.Path]::GetPathRoot($targetBaseFull))
        if ($destinationDrive.IsReady -and $destinationDrive.AvailableFreeSpace -lt ($sourceBytes + 104857600)) {
            throw "目标磁盘空间不足。所需至少约$([math]::Round(($sourceBytes + 104857600) / 1GB, 2)) GB。"
        }
    }
    catch [System.ArgumentException] {
        # Network paths may not expose DriveInfo; copy will provide the authoritative result.
    }

    $sourceName = if ($sourceItem.PSIsContainer) { $sourceItem.Name } else { $sourceItem.BaseName }
    $importName = "$(Get-Date -Format 'yyyyMMdd-HHmmss')_$(Get-SafeNameToken -Value $sourceName)"
    $importRoot = Get-UniqueDirectoryPath -BasePath (Join-Path $targetBase $importName)
    Ensure-Directory -Path $importRoot

    $backupEnabled = $CreateBackup -and -not [string]::IsNullOrWhiteSpace($script:Config.BackupRoot)
    if ($CreateBackup -and -not $backupEnabled) {
        throw '尚未在“设置”中填写独立备份目录。'
    }
    if ($backupEnabled) {
        Test-IndependentBackupPath -Root $script:Config.Root -BackupRoot $script:Config.BackupRoot
    }

    $totalUnits = $sourceFiles.Count * 3
    if ($backupEnabled) { $totalUnits += $sourceFiles.Count * 2 }
    $completed = 0
    $manifest = @()

    try {
        foreach ($entry in $sourceFiles) {
            $sourceFile = $entry.File
            $relative = $entry.RelativePath
            Invoke-ProgressCallback -Callback $ProgressCallback -Completed $completed -Total $totalUnits -Message "计算源文件校验值：$relative"
            $sourceHash = (Get-FileHash -LiteralPath $sourceFile.FullName -Algorithm SHA256).Hash
            $completed++

            $destinationFile = Join-Path $importRoot $relative
            Ensure-Directory -Path (Split-Path -Parent $destinationFile)
            Invoke-ProgressCallback -Callback $ProgressCallback -Completed $completed -Total $totalUnits -Message "复制：$relative"
            Copy-Item -LiteralPath $sourceFile.FullName -Destination $destinationFile
            $completed++

            Invoke-ProgressCallback -Callback $ProgressCallback -Completed $completed -Total $totalUnits -Message "校验目标文件：$relative"
            $destinationHash = (Get-FileHash -LiteralPath $destinationFile -Algorithm SHA256).Hash
            $completed++
            $match = $sourceHash -eq $destinationHash
            $manifest += [pscustomobject]@{
                RelativePath = $relative
                SizeBytes = $sourceFile.Length
                SourceSHA256 = $sourceHash
                DestinationSHA256 = $destinationHash
                Match = $match
            }
            if (-not $match) {
                throw "复制校验失败：$relative"
            }
        }
    }
    catch {
        $failure = [pscustomobject]@{
            Status = 'IMPORT_FAILED'
            ExpID = $ExpID
            SourcePath = $sourceFull
            DestinationPath = $importRoot
            Error = $_.Exception.Message
            Timestamp = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')
        }
        Write-JsonAtomic -Value $failure -Path (Join-Path $importRoot 'IMPORT_FAILED.json')
        Write-AppLog -Operation 'IMPORT_RAW_DATA' -Level 'ERROR' -Message "$ExpID | $($_.Exception.Message) | $importRoot"
        throw
    }

    $manifestPath = Join-Path $importRoot 'manifest_sha256.csv'
    Write-CsvAtomic -Records $manifest -Path $manifestPath

    if ($SetReadOnly) {
        foreach ($entry in $manifest) {
            $path = Join-Path $importRoot $entry.RelativePath
            $attributes = [System.IO.File]::GetAttributes($path)
            [System.IO.File]::SetAttributes($path, ($attributes -bor [System.IO.FileAttributes]::ReadOnly))
        }
    }

    $backupVerified = $false
    $backupPath = ''
    $backupError = ''
    if ($backupEnabled) {
        try {
            $backupPath = Join-Path $script:Config.BackupRoot '01_Projects'
            $backupPath = Join-Path $backupPath $project.FolderName
            $backupPath = Join-Path $backupPath '02_Experiments'
            $backupPath = Join-Path $backupPath $ExpID
            $backupPath = Join-Path $backupPath '02_RawData'
            $backupPath = Join-Path $backupPath $Level
            $backupPath = Join-Path $backupPath $importName
            if (Test-Path -LiteralPath $backupPath) {
                throw "备份目标已经存在：$backupPath"
            }
            Ensure-Directory -Path $backupPath
            foreach ($entry in $manifest) {
                $primaryFile = Join-Path $importRoot $entry.RelativePath
                $backupFile = Join-Path $backupPath $entry.RelativePath
                Ensure-Directory -Path (Split-Path -Parent $backupFile)
                Invoke-ProgressCallback -Callback $ProgressCallback -Completed $completed -Total $totalUnits -Message "备份：$($entry.RelativePath)"
                Copy-Item -LiteralPath $primaryFile -Destination $backupFile
                $completed++
                Invoke-ProgressCallback -Callback $ProgressCallback -Completed $completed -Total $totalUnits -Message "校验备份：$($entry.RelativePath)"
                $backupHash = (Get-FileHash -LiteralPath $backupFile -Algorithm SHA256).Hash
                $completed++
                if ($backupHash -ne $entry.SourceSHA256) {
                    throw "备份校验失败：$($entry.RelativePath)"
                }
            }
            Write-CsvAtomic -Records $manifest -Path (Join-Path $backupPath 'manifest_sha256.csv')
            $backupVerified = $true
        }
        catch {
            $backupError = $_.Exception.Message
            Write-AppLog -Operation 'BACKUP_RAW_DATA' -Level 'ERROR' -Message "$ExpID | $backupError"
        }
    }

    $summary = [pscustomobject]@{
        Status = $(if ($backupEnabled -and -not $backupVerified) { 'IMPORTED_BACKUP_FAILED' } else { 'IMPORTED_AND_VERIFIED' })
        ExpID = $ExpID
        ProjectCode = $experiment.ProjectCode
        Level = $Level
        Instrument = $Instrument.Trim()
        Notes = $Notes.Trim()
        Operator = $script:Config.Operator
        ImportedAt = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')
        SourcePath = $sourceFull
        DestinationPath = $importRoot
        FileCount = $sourceFiles.Count
        TotalBytes = $sourceBytes
        HashAlgorithm = 'SHA256'
        AllHashesMatch = $true
        ReadOnlyApplied = $SetReadOnly
        BackupRequested = $CreateBackup
        BackupVerified = $backupVerified
        BackupPath = $backupPath
        BackupError = $backupError
    }
    Write-JsonAtomic -Value $summary -Path (Join-Path $importRoot 'Import_Summary.json')
    if ($backupVerified) {
        Write-JsonAtomic -Value $summary -Path (Join-Path $backupPath 'Import_Summary.json')
    }

    $localLogPath = Join-Path $experiment.Path '02_RawData\RawData_Import_Log.csv'
    if (Test-Path -LiteralPath $localLogPath -PathType Leaf) {
        $summary | Export-Csv -LiteralPath $localLogPath -Append -NoTypeInformation -Encoding UTF8
    }
    else {
        $summary | Export-Csv -LiteralPath $localLogPath -NoTypeInformation -Encoding UTF8
    }

    if ($MarkRawComplete -and (-not $CreateBackup -or $backupVerified)) {
        Set-ExperimentStatus -ExpID $ExpID -Status 'RAW_COMPLETE'
    }
    Write-AppLog -Operation 'IMPORT_RAW_DATA' -Message "$ExpID | $Level | $($sourceFiles.Count) files | $importRoot"
    Invoke-ProgressCallback -Callback $ProgressCallback -Completed $totalUnits -Total $totalUnits -Message '导入完成。'
    return $summary
}

function Test-ExperimentPackage {
    param([Parameter(Mandatory = $true)][string]$ExpID)

    $experiment = Get-ExperimentById -ExpID $ExpID
    $checks = New-Object System.Collections.ArrayList
    function Add-Check([string]$Level, [string]$Item, [bool]$Pass, [string]$Detail) {
        [void]$checks.Add([pscustomobject]@{
            Result = $(if ($Pass) { 'PASS' } elseif ($Level -eq 'Required') { 'FAIL' } else { 'WARN' })
            Level = $Level
            Item = $Item
            Detail = $Detail
        })
    }

    Add-Check 'Required' 'Experiment folder' (Test-Path -LiteralPath $experiment.Path -PathType Container) $experiment.Path
    Add-Check 'Required' '00_README.md' (Test-Path -LiteralPath (Join-Path $experiment.Path '00_README.md') -PathType Leaf) '实验说明'
    Add-Check 'Required' '01_Design' (Test-Path -LiteralPath (Join-Path $experiment.Path '01_Design') -PathType Container) '设计与样品表'
    Add-Check 'Required' 'L0/L1 raw folders' ((Test-Path -LiteralPath (Join-Path $experiment.Path '02_RawData\L0_Native') -PathType Container) -and (Test-Path -LiteralPath (Join-Path $experiment.Path '02_RawData\L1_Export') -PathType Container)) '原始数据分层目录'

    $rawFiles = @(Get-ChildItem -LiteralPath (Join-Path $experiment.Path '02_RawData') -File -Recurse -ErrorAction SilentlyContinue | Where-Object { $_.Name -notin @('manifest_sha256.csv', 'Import_Summary.json', 'RawData_Import_Log.csv', 'IMPORT_FAILED.json') })
    Add-Check 'Required' 'Raw data present' ($rawFiles.Count -gt 0) "$($rawFiles.Count) files"
    $manifests = @(Get-ChildItem -LiteralPath (Join-Path $experiment.Path '02_RawData') -Filter 'manifest_sha256.csv' -File -Recurse -ErrorAction SilentlyContinue)
    Add-Check 'Required' 'SHA256 manifest' ($manifests.Count -gt 0) "$($manifests.Count) manifest(s)"
    Add-Check 'Required' 'Experiment metadata' (Test-Path -LiteralPath (Join-Path $experiment.Path 'Experiment.json') -PathType Leaf) 'Experiment.json'
    Add-Check 'Recommended' 'Processed data' (@(Get-ChildItem -LiteralPath (Join-Path $experiment.Path '03_ProcessedData') -File -Recurse -ErrorAction SilentlyContinue).Count -gt 0) 'L2/L3 outputs'
    Add-Check 'Recommended' 'Analysis files' (@(Get-ChildItem -LiteralPath (Join-Path $experiment.Path '04_Analysis') -File -Recurse -ErrorAction SilentlyContinue).Count -gt 1) 'Scripts and processing log'
    Add-Check 'Recommended' 'Results' (@(Get-ChildItem -LiteralPath (Join-Path $experiment.Path '05_Results') -File -Recurse -ErrorAction SilentlyContinue).Count -gt 0) 'QC, tables and figures'

    if (-not [string]::IsNullOrWhiteSpace($script:Config.BackupRoot)) {
        $project = Get-ProjectByCode -ProjectCode $experiment.ProjectCode
        $backupExperiment = Join-Path $script:Config.BackupRoot (Join-Path '01_Projects' (Join-Path $project.FolderName (Join-Path '02_Experiments' $ExpID)))
        Add-Check 'Recommended' 'Independent backup' (Test-Path -LiteralPath $backupExperiment -PathType Container) $backupExperiment
    }
    else {
        Add-Check 'Recommended' 'Independent backup' $false '尚未配置备份目录'
    }
    return @($checks)
}

function Open-InExplorer {
    param([Parameter(Mandatory = $true)][string]$Path)
    if (-not (Test-Path -LiteralPath $Path)) { throw "路径不存在：$Path" }
    Start-Process -FilePath 'explorer.exe' -ArgumentList @($Path)
}

function Show-ErrorMessage {
    param([Parameter(Mandatory = $true)][string]$Message)
    [System.Windows.Forms.MessageBox]::Show($Message, $script:AppName, 'OK', 'Error') | Out-Null
}

function Show-InfoMessage {
    param([Parameter(Mandatory = $true)][string]$Message)
    [System.Windows.Forms.MessageBox]::Show($Message, $script:AppName, 'OK', 'Information') | Out-Null
}

function New-UiLabel {
    param($Parent, [string]$Text, [int]$X, [int]$Y, [int]$Width = 120, [int]$Height = 24)
    $control = New-Object System.Windows.Forms.Label
    $control.Text = $Text
    $control.Location = New-Object System.Drawing.Point($X, $Y)
    $control.Size = New-Object System.Drawing.Size($Width, $Height)
    $control.TextAlign = 'MiddleLeft'
    $Parent.Controls.Add($control)
    return $control
}

function New-UiTextBox {
    param($Parent, [int]$X, [int]$Y, [int]$Width = 260, [int]$Height = 26, [bool]$Multiline = $false)
    $control = New-Object System.Windows.Forms.TextBox
    $control.Location = New-Object System.Drawing.Point($X, $Y)
    $control.Size = New-Object System.Drawing.Size($Width, $Height)
    $control.Multiline = $Multiline
    if ($Multiline) { $control.ScrollBars = 'Vertical' }
    $Parent.Controls.Add($control)
    return $control
}

function New-UiButton {
    param($Parent, [string]$Text, [int]$X, [int]$Y, [int]$Width = 110, [int]$Height = 32)
    $control = New-Object System.Windows.Forms.Button
    $control.Text = $Text
    $control.Location = New-Object System.Drawing.Point($X, $Y)
    $control.Size = New-Object System.Drawing.Size($Width, $Height)
    $control.FlatStyle = 'System'
    $Parent.Controls.Add($control)
    return $control
}

function New-UiComboBox {
    param($Parent, [int]$X, [int]$Y, [int]$Width = 260, [bool]$Editable = $false)
    $control = New-Object System.Windows.Forms.ComboBox
    $control.Location = New-Object System.Drawing.Point($X, $Y)
    $control.Size = New-Object System.Drawing.Size($Width, 28)
    $control.DropDownStyle = if ($Editable) { 'DropDown' } else { 'DropDownList' }
    $Parent.Controls.Add($control)
    return $control
}

function New-UiGrid {
    param($Parent, [int]$X, [int]$Y, [int]$Width, [int]$Height)
    $control = New-Object System.Windows.Forms.DataGridView
    $control.Location = New-Object System.Drawing.Point($X, $Y)
    $control.Size = New-Object System.Drawing.Size($Width, $Height)
    $control.ReadOnly = $true
    $control.AllowUserToAddRows = $false
    $control.AllowUserToDeleteRows = $false
    $control.SelectionMode = 'FullRowSelect'
    $control.MultiSelect = $false
    $control.AutoSizeColumnsMode = 'Fill'
    $control.RowHeadersVisible = $false
    $control.BackgroundColor = [System.Drawing.Color]::White
    $Parent.Controls.Add($control)
    return $control
}

function Set-GridRecords {
    param($Grid, [object[]]$Records)
    $arrayList = New-Object System.Collections.ArrayList
    foreach ($record in @($Records)) { [void]$arrayList.Add($record) }
    $Grid.DataSource = $null
    $Grid.DataSource = $arrayList
}

function Get-SelectedProjectFromCombo {
    param($Combo)
    if ($null -eq $Combo.SelectedItem) { throw '请先选择项目。' }
    $key = [string]$Combo.SelectedItem
    if (-not $script:ProjectMap.ContainsKey($key)) { throw '项目列表已变化，请刷新后重新选择。' }
    return $script:ProjectMap[$key]
}

function Refresh-ProjectCombos {
    $projects = @(Get-Projects)
    $script:ProjectMap = @{}
    $combos = @($script:ExpProjectCombo, $script:ImportProjectCombo, $script:ValidateProjectCombo)
    foreach ($combo in $combos) { $combo.Items.Clear() }
    foreach ($project in $projects) {
        $display = "$($project.ProjectCode) | $($project.ProjectName)"
        $script:ProjectMap[$display] = $project
        foreach ($combo in $combos) { [void]$combo.Items.Add($display) }
    }
    foreach ($combo in $combos) {
        if ($combo.Items.Count -gt 0 -and $combo.SelectedIndex -lt 0) { $combo.SelectedIndex = 0 }
    }
}

function Refresh-ExperimentCombo {
    param($ProjectCombo, $ExperimentCombo)
    $ExperimentCombo.Items.Clear()
    if ($null -eq $ProjectCombo.SelectedItem) { return }
    try {
        $project = Get-SelectedProjectFromCombo -Combo $ProjectCombo
        foreach ($experiment in @(Get-Experiments -ProjectCode $project.ProjectCode)) {
            [void]$ExperimentCombo.Items.Add($experiment.ExpID)
        }
        if ($ExperimentCombo.Items.Count -gt 0) { $ExperimentCombo.SelectedIndex = 0 }
    }
    catch { }
}

function Refresh-Dashboard {
    $projects = @(Get-Projects)
    $experiments = @(Get-Experiments)
    $script:DashboardProjectCount.Text = [string]$projects.Count
    $script:DashboardExperimentCount.Text = [string]$experiments.Count
    $script:DashboardRawCount.Text = [string]@($experiments | Where-Object { $_.Status -eq 'RAW_COMPLETE' }).Count
    $script:DashboardAnalyzedCount.Text = [string]@($experiments | Where-Object { $_.Status -in @('ANALYZED', 'ARCHIVED') }).Count

    Set-GridRecords -Grid $script:ProjectGrid -Records @($projects | Select-Object ProjectCode, ProjectName, Confidentiality, Status, Path)
    Set-GridRecords -Grid $script:ExperimentGrid -Records @($experiments | Select-Object -First 30 ExpID, ProjectCode, Assay, Date, Status, Path)
    $script:RootPathLabel.Text = "Root: $($script:Config.Root)"
}

function Refresh-AllViews {
    Refresh-ProjectCombos
    Refresh-ExperimentCombo -ProjectCombo $script:ImportProjectCombo -ExperimentCombo $script:ImportExperimentCombo
    Refresh-ExperimentCombo -ProjectCombo $script:ValidateProjectCombo -ExperimentCombo $script:ValidateExperimentCombo
    Refresh-Dashboard
}

function Build-MainForm {
    Add-Type -AssemblyName System.Windows.Forms
    Add-Type -AssemblyName System.Drawing
    [System.Windows.Forms.Application]::EnableVisualStyles()

    $form = New-Object System.Windows.Forms.Form
    $form.Text = "$($script:AppName) v$($script:AppVersion)"
    $form.StartPosition = 'CenterScreen'
    $form.Size = New-Object System.Drawing.Size(1160, 830)
    $form.MinimumSize = New-Object System.Drawing.Size(1050, 760)
    $form.Font = New-Object System.Drawing.Font('Microsoft YaHei UI', 9)
    $form.BackColor = [System.Drawing.Color]::FromArgb(246, 248, 251)

    $title = New-UiLabel -Parent $form -Text 'ResearchData Manager' -X 22 -Y 15 -Width 350 -Height 30
    $title.Font = New-Object System.Drawing.Font('Microsoft YaHei UI', 16, [System.Drawing.FontStyle]::Bold)
    $title.ForeColor = [System.Drawing.Color]::FromArgb(31, 77, 120)
    $script:RootPathLabel = New-UiLabel -Parent $form -Text '' -X 24 -Y 47 -Width 760 -Height 24
    $script:RootPathLabel.ForeColor = [System.Drawing.Color]::DimGray
    $script:openRootButton = New-UiButton -Parent $form -Text '打开ResearchData' -X 880 -Y 22 -Width 135 -Height 34
    $script:refreshButton = New-UiButton -Parent $form -Text '刷新' -X 1025 -Y 22 -Width 90 -Height 34

    $tabs = New-Object System.Windows.Forms.TabControl
    $tabs.Location = New-Object System.Drawing.Point(18, 78)
    $tabs.Size = New-Object System.Drawing.Size(1105, 680)
    $form.Controls.Add($tabs)

    $dashboardTab = New-Object System.Windows.Forms.TabPage
    $dashboardTab.Text = '总览'
    $projectTab = New-Object System.Windows.Forms.TabPage
    $projectTab.Text = '新增项目'
    $experimentTab = New-Object System.Windows.Forms.TabPage
    $experimentTab.Text = '新建实验'
    $importTab = New-Object System.Windows.Forms.TabPage
    $importTab.Text = '原始数据入库'
    $validateTab = New-Object System.Windows.Forms.TabPage
    $validateTab.Text = '检查与状态'
    $settingsTab = New-Object System.Windows.Forms.TabPage
    $settingsTab.Text = '设置'
    [void]$tabs.TabPages.AddRange(@($dashboardTab, $projectTab, $experimentTab, $importTab, $validateTab, $settingsTab))

    # Dashboard
    New-UiLabel -Parent $dashboardTab -Text '项目数' -X 35 -Y 25 -Width 120 | Out-Null
    $script:DashboardProjectCount = New-UiLabel -Parent $dashboardTab -Text '0' -X 35 -Y 52 -Width 120 -Height 42
    $script:DashboardProjectCount.Font = New-Object System.Drawing.Font('Segoe UI', 22, [System.Drawing.FontStyle]::Bold)
    New-UiLabel -Parent $dashboardTab -Text '实验数' -X 220 -Y 25 -Width 120 | Out-Null
    $script:DashboardExperimentCount = New-UiLabel -Parent $dashboardTab -Text '0' -X 220 -Y 52 -Width 120 -Height 42
    $script:DashboardExperimentCount.Font = New-Object System.Drawing.Font('Segoe UI', 22, [System.Drawing.FontStyle]::Bold)
    New-UiLabel -Parent $dashboardTab -Text '原始数据完成' -X 405 -Y 25 -Width 130 | Out-Null
    $script:DashboardRawCount = New-UiLabel -Parent $dashboardTab -Text '0' -X 405 -Y 52 -Width 120 -Height 42
    $script:DashboardRawCount.Font = New-Object System.Drawing.Font('Segoe UI', 22, [System.Drawing.FontStyle]::Bold)
    New-UiLabel -Parent $dashboardTab -Text '已分析/归档' -X 590 -Y 25 -Width 130 | Out-Null
    $script:DashboardAnalyzedCount = New-UiLabel -Parent $dashboardTab -Text '0' -X 590 -Y 52 -Width 120 -Height 42
    $script:DashboardAnalyzedCount.Font = New-Object System.Drawing.Font('Segoe UI', 22, [System.Drawing.FontStyle]::Bold)
    New-UiLabel -Parent $dashboardTab -Text '项目' -X 30 -Y 115 -Width 100 | Out-Null
    $script:ProjectGrid = New-UiGrid -Parent $dashboardTab -X 30 -Y 142 -Width 1020 -Height 190
    New-UiLabel -Parent $dashboardTab -Text '最近实验' -X 30 -Y 352 -Width 100 | Out-Null
    $script:ExperimentGrid = New-UiGrid -Parent $dashboardTab -X 30 -Y 380 -Width 1020 -Height 220

    # Project creation
    New-UiLabel -Parent $projectTab -Text '项目代码*' -X 35 -Y 30 | Out-Null
    $script:projectCodeText = New-UiTextBox -Parent $projectTab -X 165 -Y 30 -Width 250
    New-UiLabel -Parent $projectTab -Text '文件夹名称*' -X 35 -Y 72 | Out-Null
    $script:projectFolderText = New-UiTextBox -Parent $projectTab -X 165 -Y 72 -Width 360
    New-UiLabel -Parent $projectTab -Text '项目名称*' -X 35 -Y 114 | Out-Null
    $script:projectNameText = New-UiTextBox -Parent $projectTab -X 165 -Y 114 -Width 520
    New-UiLabel -Parent $projectTab -Text '保密等级' -X 35 -Y 156 | Out-Null
    $script:projectConfCombo = New-UiComboBox -Parent $projectTab -X 165 -Y 156 -Width 140
    [void]$projectConfCombo.Items.AddRange(@('P0', 'P1', 'P2'))
    $projectConfCombo.SelectedItem = 'P1'
    New-UiLabel -Parent $projectTab -Text '项目说明' -X 35 -Y 198 | Out-Null
    $script:projectDescriptionText = New-UiTextBox -Parent $projectTab -X 165 -Y 198 -Width 700 -Height 150 -Multiline $true
    $script:createProjectButton = New-UiButton -Parent $projectTab -Text '创建项目' -X 165 -Y 370 -Width 130 -Height 38
    $script:openProjectsButton = New-UiButton -Parent $projectTab -Text '打开项目目录' -X 310 -Y 370 -Width 130 -Height 38
    $projectHelp = New-UiLabel -Parent $projectTab -Text '示例：代码 IDH2；文件夹 IDH2_BreastCancer；项目名称 IDH2乳腺癌。创建后会同时写入项目登记表。' -X 35 -Y 440 -Width 950 -Height 40
    $projectHelp.ForeColor = [System.Drawing.Color]::DimGray

    # Experiment creation
    New-UiLabel -Parent $experimentTab -Text '项目*' -X 35 -Y 28 | Out-Null
    $script:ExpProjectCombo = New-UiComboBox -Parent $experimentTab -X 170 -Y 28 -Width 390
    New-UiLabel -Parent $experimentTab -Text '实验日期*' -X 35 -Y 70 | Out-Null
    $script:expDatePicker = New-Object System.Windows.Forms.DateTimePicker
    $expDatePicker.Location = New-Object System.Drawing.Point(170, 70)
    $expDatePicker.Size = New-Object System.Drawing.Size(190, 28)
    $expDatePicker.Format = 'Custom'
    $expDatePicker.CustomFormat = 'yyyy-MM-dd'
    $experimentTab.Controls.Add($expDatePicker)
    New-UiLabel -Parent $experimentTab -Text '实验类型*' -X 35 -Y 112 | Out-Null
    $script:expAssayCombo = New-UiComboBox -Parent $experimentTab -X 170 -Y 112 -Width 250 -Editable $true
    [void]$expAssayCombo.Items.AddRange(@('qPCR', 'WB', 'CCK8', 'IF', 'Flow', 'RNAseq', 'CUTTag', 'ChIPqPCR', 'Migration', 'Invasion'))
    New-UiLabel -Parent $experimentTab -Text '实验目的*' -X 35 -Y 154 | Out-Null
    $script:expObjectiveText = New-UiTextBox -Parent $experimentTab -X 170 -Y 154 -Width 760
    New-UiLabel -Parent $experimentTab -Text '纸质记录位置*' -X 35 -Y 196 | Out-Null
    $script:expNotebookText = New-UiTextBox -Parent $experimentTab -X 170 -Y 196 -Width 390
    New-UiLabel -Parent $experimentTab -Text '样品/分组' -X 35 -Y 238 | Out-Null
    $script:expGroupsText = New-UiTextBox -Parent $experimentTab -X 170 -Y 238 -Width 760 -Height 80 -Multiline $true
    New-UiLabel -Parent $experimentTab -Text '生物学重复' -X 35 -Y 342 | Out-Null
    $script:expBioNumeric = New-Object System.Windows.Forms.NumericUpDown
    $expBioNumeric.Location = New-Object System.Drawing.Point(170, 342)
    $expBioNumeric.Size = New-Object System.Drawing.Size(90, 28)
    $expBioNumeric.Minimum = 1
    $expBioNumeric.Maximum = 999
    $expBioNumeric.Value = 3
    $experimentTab.Controls.Add($expBioNumeric)
    New-UiLabel -Parent $experimentTab -Text '技术重复' -X 300 -Y 342 | Out-Null
    $script:expTechNumeric = New-Object System.Windows.Forms.NumericUpDown
    $expTechNumeric.Location = New-Object System.Drawing.Point(420, 342)
    $expTechNumeric.Size = New-Object System.Drawing.Size(90, 28)
    $expTechNumeric.Minimum = 1
    $expTechNumeric.Maximum = 999
    $expTechNumeric.Value = 3
    $experimentTab.Controls.Add($expTechNumeric)
    New-UiLabel -Parent $experimentTab -Text '保密等级' -X 550 -Y 342 | Out-Null
    $script:expConfCombo = New-UiComboBox -Parent $experimentTab -X 670 -Y 342 -Width 140
    [void]$expConfCombo.Items.AddRange(@('P0', 'P1', 'P2'))
    $expConfCombo.SelectedItem = 'P1'
    $script:createExperimentButton = New-UiButton -Parent $experimentTab -Text '创建实验数据包' -X 170 -Y 405 -Width 160 -Height 40
    $script:openExperimentsButton = New-UiButton -Parent $experimentTab -Text '打开Experiments' -X 345 -Y 405 -Width 150 -Height 40
    $expHelp = New-UiLabel -Parent $experimentTab -Text '系统自动生成ExpID、标准目录、README、Experiment.json、样品表、处理日志及异常记录。' -X 35 -Y 480 -Width 900 -Height 40
    $expHelp.ForeColor = [System.Drawing.Color]::DimGray

    # Raw import
    New-UiLabel -Parent $importTab -Text '项目*' -X 25 -Y 22 | Out-Null
    $script:ImportProjectCombo = New-UiComboBox -Parent $importTab -X 150 -Y 22 -Width 350
    New-UiLabel -Parent $importTab -Text '实验编号*' -X 540 -Y 22 | Out-Null
    $script:ImportExperimentCombo = New-UiComboBox -Parent $importTab -X 665 -Y 22 -Width 380
    New-UiLabel -Parent $importTab -Text '源数据路径*' -X 25 -Y 66 | Out-Null
    $script:importSourceText = New-UiTextBox -Parent $importTab -X 150 -Y 66 -Width 650
    $script:browseFolderButton = New-UiButton -Parent $importTab -Text '选择文件夹' -X 815 -Y 63 -Width 105
    $script:browseFileButton = New-UiButton -Parent $importTab -Text '选择单文件' -X 930 -Y 63 -Width 105
    New-UiLabel -Parent $importTab -Text '数据层级*' -X 25 -Y 110 | Out-Null
    $script:importLevelCombo = New-UiComboBox -Parent $importTab -X 150 -Y 110 -Width 270
    [void]$importLevelCombo.Items.AddRange(@('L0_Native', 'L1_Export'))
    $importLevelCombo.SelectedIndex = 0
    New-UiLabel -Parent $importTab -Text '仪器/来源' -X 455 -Y 110 | Out-Null
    $script:importInstrumentText = New-UiTextBox -Parent $importTab -X 575 -Y 110 -Width 330
    New-UiLabel -Parent $importTab -Text '备注' -X 25 -Y 154 | Out-Null
    $script:importNotesText = New-UiTextBox -Parent $importTab -X 150 -Y 154 -Width 755 -Height 60 -Multiline $true
    $script:readOnlyCheck = New-Object System.Windows.Forms.CheckBox
    $readOnlyCheck.Text = '导入后将原始文件设为只读'
    $readOnlyCheck.Location = New-Object System.Drawing.Point(150, 232)
    $readOnlyCheck.Size = New-Object System.Drawing.Size(240, 26)
    $readOnlyCheck.Checked = $true
    $importTab.Controls.Add($readOnlyCheck)
    $script:backupCheck = New-Object System.Windows.Forms.CheckBox
    $backupCheck.Text = '同时复制并校验独立备份'
    $backupCheck.Location = New-Object System.Drawing.Point(405, 232)
    $backupCheck.Size = New-Object System.Drawing.Size(235, 26)
    $importTab.Controls.Add($backupCheck)
    $script:rawCompleteCheck = New-Object System.Windows.Forms.CheckBox
    $rawCompleteCheck.Text = '导入成功后标记RAW_COMPLETE'
    $rawCompleteCheck.Location = New-Object System.Drawing.Point(655, 232)
    $rawCompleteCheck.Size = New-Object System.Drawing.Size(270, 26)
    $importTab.Controls.Add($rawCompleteCheck)
    $script:importButton = New-UiButton -Parent $importTab -Text '复制、校验并入库' -X 150 -Y 278 -Width 165 -Height 40
    $script:openImportExperimentButton = New-UiButton -Parent $importTab -Text '打开实验目录' -X 330 -Y 278 -Width 130 -Height 40
    $script:importProgress = New-Object System.Windows.Forms.ProgressBar
    $importProgress.Location = New-Object System.Drawing.Point(150, 336)
    $importProgress.Size = New-Object System.Drawing.Size(755, 24)
    $importTab.Controls.Add($importProgress)
    $script:importLogText = New-UiTextBox -Parent $importTab -X 150 -Y 378 -Width 755 -Height 190 -Multiline $true
    $importLogText.ReadOnly = $true
    $importLogText.BackColor = [System.Drawing.Color]::White

    # Validation
    New-UiLabel -Parent $validateTab -Text '项目*' -X 30 -Y 25 | Out-Null
    $script:ValidateProjectCombo = New-UiComboBox -Parent $validateTab -X 155 -Y 25 -Width 350
    New-UiLabel -Parent $validateTab -Text '实验编号*' -X 540 -Y 25 | Out-Null
    $script:ValidateExperimentCombo = New-UiComboBox -Parent $validateTab -X 665 -Y 25 -Width 380
    $script:validateButton = New-UiButton -Parent $validateTab -Text '执行完整性检查' -X 155 -Y 72 -Width 150 -Height 38
    $script:openValidatedExperimentButton = New-UiButton -Parent $validateTab -Text '打开实验目录' -X 320 -Y 72 -Width 130 -Height 38
    New-UiLabel -Parent $validateTab -Text '状态' -X 500 -Y 78 -Width 70 | Out-Null
    $script:statusCombo = New-UiComboBox -Parent $validateTab -X 560 -Y 74 -Width 180
    [void]$statusCombo.Items.AddRange(@('PLANNED', 'IN_PROGRESS', 'RAW_COMPLETE', 'PROCESSING', 'ANALYZED', 'ARCHIVED'))
    $script:updateStatusButton = New-UiButton -Parent $validateTab -Text '更新状态' -X 755 -Y 72 -Width 110 -Height 38
    $script:validationGrid = New-UiGrid -Parent $validateTab -X 30 -Y 135 -Width 1020 -Height 440

    # Settings
    New-UiLabel -Parent $settingsTab -Text 'ResearchData根目录' -X 35 -Y 38 -Width 170 | Out-Null
    $script:settingsRootText = New-UiTextBox -Parent $settingsTab -X 215 -Y 38 -Width 650
    $settingsRootText.Text = $script:Config.Root
    $script:browseRootButton = New-UiButton -Parent $settingsTab -Text '选择' -X 880 -Y 35 -Width 90
    New-UiLabel -Parent $settingsTab -Text '独立备份目录' -X 35 -Y 88 -Width 170 | Out-Null
    $script:settingsBackupText = New-UiTextBox -Parent $settingsTab -X 215 -Y 88 -Width 650
    $settingsBackupText.Text = $script:Config.BackupRoot
    $script:browseBackupButton = New-UiButton -Parent $settingsTab -Text '选择' -X 880 -Y 85 -Width 90
    New-UiLabel -Parent $settingsTab -Text '操作者' -X 35 -Y 138 -Width 170 | Out-Null
    $script:settingsOperatorText = New-UiTextBox -Parent $settingsTab -X 215 -Y 138 -Width 300
    $settingsOperatorText.Text = $script:Config.Operator
    $script:saveSettingsButton = New-UiButton -Parent $settingsTab -Text '保存设置' -X 215 -Y 195 -Width 120 -Height 38
    $script:repairStructureButton = New-UiButton -Parent $settingsTab -Text '创建/修复基础目录' -X 350 -Y 195 -Width 160 -Height 38
    $script:openLogsButton = New-UiButton -Parent $settingsTab -Text '打开日志目录' -X 525 -Y 195 -Width 130 -Height 38
    $settingsNote = New-UiLabel -Parent $settingsTab -Text '备份目录必须位于其他磁盘或NAS，不能位于D:\ResearchData内部或同一块D盘。修改根目录后程序会立即切换并创建必要的基础目录。' -X 35 -Y 265 -Width 970 -Height 60
    $settingsNote.ForeColor = [System.Drawing.Color]::DimGray

    # Global events
    $openRootButton.Add_Click({
        try { Open-InExplorer -Path $script:Config.Root } catch { Show-ErrorMessage $_.Exception.Message }
    })
    $refreshButton.Add_Click({
        try { Refresh-AllViews } catch { Show-ErrorMessage $_.Exception.Message }
    })

    $projectCodeText.Add_Leave({
        if ([string]::IsNullOrWhiteSpace($projectFolderText.Text)) {
            $projectFolderText.Text = $projectCodeText.Text.Trim().ToUpperInvariant()
        }
    })
    $createProjectButton.Add_Click({
        try {
            $folderName = if ([string]::IsNullOrWhiteSpace($projectFolderText.Text)) { $projectCodeText.Text.Trim().ToUpperInvariant() } else { $projectFolderText.Text }
            $record = New-ResearchProject -ProjectCode $projectCodeText.Text -FolderName $folderName -ProjectName $projectNameText.Text -Description $projectDescriptionText.Text -Confidentiality ([string]$projectConfCombo.SelectedItem)
            Show-InfoMessage "项目创建成功：$($record.ProjectCode)`r`n$($record.Path)"
            $projectCodeText.Clear(); $projectFolderText.Clear(); $projectNameText.Clear(); $projectDescriptionText.Clear()
            Refresh-AllViews
        }
        catch { Show-ErrorMessage $_.Exception.Message }
    })
    $openProjectsButton.Add_Click({
        try { Open-InExplorer -Path (Join-Path $script:Config.Root '01_Projects') } catch { Show-ErrorMessage $_.Exception.Message }
    })

    $createExperimentButton.Add_Click({
        try {
            $project = Get-SelectedProjectFromCombo -Combo $script:ExpProjectCombo
            $record = New-ExperimentPackage -ProjectCode $project.ProjectCode -Date $expDatePicker.Value -Assay $expAssayCombo.Text -Objective $expObjectiveText.Text -Notebook $expNotebookText.Text -Groups $expGroupsText.Text -BiologicalReplicates ([int]$expBioNumeric.Value) -TechnicalReplicates ([int]$expTechNumeric.Value) -Confidentiality ([string]$expConfCombo.SelectedItem)
            Show-InfoMessage "实验数据包创建成功：$($record.ExpID)`r`n$($record.Path)"
            $expObjectiveText.Clear(); $expNotebookText.Clear(); $expGroupsText.Clear()
            Refresh-AllViews
        }
        catch { Show-ErrorMessage $_.Exception.Message }
    })
    $openExperimentsButton.Add_Click({
        try {
            $project = Get-SelectedProjectFromCombo -Combo $script:ExpProjectCombo
            Open-InExplorer -Path (Join-Path $project.Path '02_Experiments')
        }
        catch { Show-ErrorMessage $_.Exception.Message }
    })

    $script:ImportProjectCombo.Add_SelectedIndexChanged({ Refresh-ExperimentCombo -ProjectCombo $script:ImportProjectCombo -ExperimentCombo $script:ImportExperimentCombo })
    $script:ValidateProjectCombo.Add_SelectedIndexChanged({ Refresh-ExperimentCombo -ProjectCombo $script:ValidateProjectCombo -ExperimentCombo $script:ValidateExperimentCombo })

    $browseFolderButton.Add_Click({
        $dialog = New-Object System.Windows.Forms.FolderBrowserDialog
        $dialog.Description = '选择需要入库的原始数据文件夹'
        if ($dialog.ShowDialog() -eq 'OK') { $importSourceText.Text = $dialog.SelectedPath }
    })
    $browseFileButton.Add_Click({
        $dialog = New-Object System.Windows.Forms.OpenFileDialog
        $dialog.Title = '选择需要入库的单个原始数据文件'
        $dialog.Filter = 'All files (*.*)|*.*'
        if ($dialog.ShowDialog() -eq 'OK') { $importSourceText.Text = $dialog.FileName }
    })
    $openImportExperimentButton.Add_Click({
        try {
            if ($null -eq $script:ImportExperimentCombo.SelectedItem) { throw '请先选择实验。' }
            $experiment = Get-ExperimentById -ExpID ([string]$script:ImportExperimentCombo.SelectedItem)
            Open-InExplorer -Path $experiment.Path
        }
        catch { Show-ErrorMessage $_.Exception.Message }
    })
    $importButton.Add_Click({
        try {
            if ($null -eq $script:ImportExperimentCombo.SelectedItem) { throw '请先选择实验。' }
            if ([string]::IsNullOrWhiteSpace($importSourceText.Text)) { throw '请选择源数据路径。' }
            $importButton.Enabled = $false
            $importProgress.Value = 0
            $importLogText.Clear()
            $progressHandler = {
                param($Percent, $Message)
                $importProgress.Value = [math]::Max(0, [math]::Min(100, $Percent))
                $importLogText.AppendText("$(Get-Date -Format 'HH:mm:ss')  $Message`r`n")
                $importLogText.SelectionStart = $importLogText.TextLength
                $importLogText.ScrollToCaret()
                [System.Windows.Forms.Application]::DoEvents()
            }
            $summary = Import-RawData -ExpID ([string]$script:ImportExperimentCombo.SelectedItem) -SourcePath $importSourceText.Text -Level ([string]$importLevelCombo.SelectedItem) -Instrument $importInstrumentText.Text -Notes $importNotesText.Text -SetReadOnly $readOnlyCheck.Checked -CreateBackup $backupCheck.Checked -MarkRawComplete $rawCompleteCheck.Checked -ProgressCallback $progressHandler
            if ($summary.BackupRequested -and -not $summary.BackupVerified) {
                Show-ErrorMessage "主数据已成功导入并校验，但独立备份失败：`r`n$($summary.BackupError)`r`n主数据位置：$($summary.DestinationPath)"
            }
            else {
                Show-InfoMessage "原始数据入库成功。`r`n文件数：$($summary.FileCount)`r`n位置：$($summary.DestinationPath)"
            }
            Refresh-AllViews
        }
        catch {
            $importLogText.AppendText("ERROR  $($_.Exception.Message)`r`n")
            Show-ErrorMessage $_.Exception.Message
        }
        finally {
            $importButton.Enabled = $true
        }
    })

    $validateButton.Add_Click({
        try {
            if ($null -eq $script:ValidateExperimentCombo.SelectedItem) { throw '请先选择实验。' }
            $expId = [string]$script:ValidateExperimentCombo.SelectedItem
            $checks = @(Test-ExperimentPackage -ExpID $expId)
            Set-GridRecords -Grid $validationGrid -Records $checks
            $experiment = Get-ExperimentById -ExpID $expId
            if ($statusCombo.Items.Contains($experiment.Status)) { $statusCombo.SelectedItem = $experiment.Status }
        }
        catch { Show-ErrorMessage $_.Exception.Message }
    })
    $openValidatedExperimentButton.Add_Click({
        try {
            if ($null -eq $script:ValidateExperimentCombo.SelectedItem) { throw '请先选择实验。' }
            $experiment = Get-ExperimentById -ExpID ([string]$script:ValidateExperimentCombo.SelectedItem)
            Open-InExplorer -Path $experiment.Path
        }
        catch { Show-ErrorMessage $_.Exception.Message }
    })
    $updateStatusButton.Add_Click({
        try {
            if ($null -eq $script:ValidateExperimentCombo.SelectedItem -or $null -eq $statusCombo.SelectedItem) { throw '请选择实验和目标状态。' }
            Set-ExperimentStatus -ExpID ([string]$script:ValidateExperimentCombo.SelectedItem) -Status ([string]$statusCombo.SelectedItem)
            Show-InfoMessage '实验状态已更新。'
            Refresh-AllViews
        }
        catch { Show-ErrorMessage $_.Exception.Message }
    })

    $browseRootButton.Add_Click({
        $dialog = New-Object System.Windows.Forms.FolderBrowserDialog
        $dialog.Description = '选择ResearchData根目录'
        if ($dialog.ShowDialog() -eq 'OK') { $settingsRootText.Text = $dialog.SelectedPath }
    })
    $browseBackupButton.Add_Click({
        $dialog = New-Object System.Windows.Forms.FolderBrowserDialog
        $dialog.Description = '选择独立备份目录（其他磁盘或NAS）'
        if ($dialog.ShowDialog() -eq 'OK') { $settingsBackupText.Text = $dialog.SelectedPath }
    })
    $saveSettingsButton.Add_Click({
        try {
            $newRoot = Get-SafeRootPath -Path $settingsRootText.Text
            if (-not [string]::IsNullOrWhiteSpace($settingsBackupText.Text)) {
                Test-IndependentBackupPath -Root $newRoot -BackupRoot $settingsBackupText.Text
            }
            $script:Config.Root = $newRoot
            $script:Config.BackupRoot = $settingsBackupText.Text.Trim()
            $script:Config.Operator = $settingsOperatorText.Text.Trim()
            if ([string]::IsNullOrWhiteSpace($script:Config.Operator)) { throw '操作者不能为空。' }
            Save-AppConfig -Config $script:Config
            Ensure-ResearchRoot -Root $script:Config.Root
            Show-InfoMessage '设置已保存。'
            Refresh-AllViews
        }
        catch { Show-ErrorMessage $_.Exception.Message }
    })
    $repairStructureButton.Add_Click({
        try {
            Ensure-ResearchRoot -Root $script:Config.Root
            Show-InfoMessage '基础目录已检查并补全；已有内容未被修改。'
            Refresh-AllViews
        }
        catch { Show-ErrorMessage $_.Exception.Message }
    })
    $openLogsButton.Add_Click({
        try { Open-InExplorer -Path (Join-Path $script:Config.Root '04_Automation\Logs') } catch { Show-ErrorMessage $_.Exception.Message }
    })

    $form.Add_Shown({
        try { Refresh-AllViews } catch { Show-ErrorMessage $_.Exception.Message }
    })
    return $form
}

try {
    Add-Type -AssemblyName System.Windows.Forms
    Add-Type -AssemblyName System.Drawing
    $script:Config = Load-AppConfig
    $script:Config.Root = Get-SafeRootPath -Path $script:Config.Root

    if (-not (Test-Path -LiteralPath $script:Config.Root -PathType Container)) {
        $choice = [System.Windows.Forms.MessageBox]::Show(
            "ResearchData目录不存在：`r`n$($script:Config.Root)`r`n`r`n是否现在创建基础目录？",
            $script:AppName,
            'YesNo',
            'Question'
        )
        if ($choice -ne 'Yes') { return }
    }
    Ensure-ResearchRoot -Root $script:Config.Root
    Write-AppLog -Operation 'APP_START' -Message "Version $($script:AppVersion)"
    $mainForm = Build-MainForm
    [void]$mainForm.ShowDialog()
}
catch {
    try {
        [System.Windows.Forms.MessageBox]::Show($_.Exception.Message, $script:AppName, 'OK', 'Error') | Out-Null
    }
    catch {
        Write-Error $_.Exception.Message
    }
    exit 1
}
