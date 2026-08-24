[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [ValidatePattern('^[A-Z][A-Z0-9]+-[0-9]+$')]
    [string]$StoryKey,

    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string[]]$SourcePath,

    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string[]]$TestClass,

    [string]$TargetOrg = 'orgfarm-be325a30c4-dev-ed',

    [string]$VerificationFile,

    [ValidateRange(1, 120)]
    [int]$WaitMinutes = 30
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$deliveryProjectRoot = [System.IO.Path]::GetFullPath(
    (Join-Path -Path $PSScriptRoot -ChildPath '..')
)
$deliveryProjectFile = Join-Path -Path $deliveryProjectRoot -ChildPath 'sfdx-project.json'

if (-not (Test-Path -LiteralPath $deliveryProjectFile -PathType Leaf)) {
    throw "Salesforce project file not found: $deliveryProjectFile"
}

$deliverySfCommand = Get-Command -Name 'sf.cmd' -ErrorAction SilentlyContinue
if ($null -eq $deliverySfCommand) {
    throw 'Salesforce CLI sf.cmd was not found on PATH.'
}

function Resolve-DeliveryPath {
    param(
        [Parameter(Mandatory)]
        [string]$Path,

        [Parameter(Mandatory)]
        [ValidateSet('Leaf', 'Container', 'Any')]
        [string]$ExpectedType
    )

    $candidatePath = if ([System.IO.Path]::IsPathRooted($Path)) {
        $Path
    } else {
        Join-Path -Path $deliveryProjectRoot -ChildPath $Path
    }

    $resolvedPath = [System.IO.Path]::GetFullPath($candidatePath)
    $projectRootPrefix = $deliveryProjectRoot.TrimEnd(
        [System.IO.Path]::DirectorySeparatorChar,
        [System.IO.Path]::AltDirectorySeparatorChar
    ) + [System.IO.Path]::DirectorySeparatorChar
    $isProjectRoot = $resolvedPath.Equals(
        $deliveryProjectRoot,
        [System.StringComparison]::OrdinalIgnoreCase
    )
    $isInsideProject = $resolvedPath.StartsWith(
        $projectRootPrefix,
        [System.StringComparison]::OrdinalIgnoreCase
    )
    if (-not $isProjectRoot -and -not $isInsideProject) {
        throw "Path must remain inside the Salesforce project: $Path"
    }

    if (-not (Test-Path -LiteralPath $resolvedPath)) {
        throw "Path does not exist: $resolvedPath"
    }
    if ($ExpectedType -ne 'Any' -and -not (Test-Path -LiteralPath $resolvedPath -PathType $ExpectedType)) {
        throw "Path is not a $ExpectedType path: $resolvedPath"
    }

    return $resolvedPath
}

function Invoke-DeliverySfJson {
    param(
        [Parameter(Mandatory)]
        [string[]]$Arguments
    )

    $previousErrorActionPreference = $ErrorActionPreference
    try {
        $ErrorActionPreference = 'Continue'
        $rawOutput = & $deliverySfCommand.Source @Arguments 2>$null | Out-String
        $commandExitCode = $LASTEXITCODE
    } finally {
        $ErrorActionPreference = $previousErrorActionPreference
    }

    try {
        $jsonOutput = $rawOutput | ConvertFrom-Json
    } catch {
        throw "Salesforce CLI did not return valid JSON. Exit code: $commandExitCode"
    }

    return [PSCustomObject]@{
        ExitCode = $commandExitCode
        Json = $jsonOutput
        Raw = $rawOutput
    }
}

function Get-DeliveryJobId {
    param(
        [Parameter(Mandatory)]
        [object]$CommandResult
    )

    $resultProperty = $CommandResult.Json.PSObject.Properties['result']
    if ($null -ne $resultProperty) {
        $idProperty = $resultProperty.Value.PSObject.Properties['id']
        if ($null -ne $idProperty) {
            return [string]$idProperty.Value
        }
    }

    $jobIdMatch = [regex]::Match(
        $CommandResult.Raw,
        '0Af[a-zA-Z0-9]{15}'
    )
    if ($jobIdMatch.Success) {
        return $jobIdMatch.Value
    }

    return $null
}

$orgResult = Invoke-DeliverySfJson -Arguments @(
    'org', 'display',
    '--target-org', $TargetOrg,
    '--json'
)
if ($orgResult.ExitCode -ne 0 -or $orgResult.Json.status -ne 0) {
    throw "Unable to access Salesforce org '$TargetOrg'."
}

$resolvedSourcePaths = @(
    foreach ($path in $SourcePath) {
        Resolve-DeliveryPath -Path $path -ExpectedType 'Any'
    }
)

$deployArguments = @(
    'project', 'deploy', 'start',
    '--target-org', $TargetOrg,
    '--test-level', 'RunSpecifiedTests',
    '--wait', [string]$WaitMinutes,
    '--json'
)
foreach ($path in $resolvedSourcePaths) {
    $deployArguments += @('--source-dir', $path)
}
foreach ($className in $TestClass) {
    $deployArguments += @('--tests', $className)
}

$deployStart = Invoke-DeliverySfJson -Arguments $deployArguments
$deploymentId = Get-DeliveryJobId -CommandResult $deployStart
if ([string]::IsNullOrWhiteSpace($deploymentId)) {
    throw 'Salesforce deployment did not return a deployment ID.'
}

$deployReportCall = Invoke-DeliverySfJson -Arguments @(
    'project', 'deploy', 'report',
    '--target-org', $TargetOrg,
    '--job-id', $deploymentId,
    '--wait', [string]$WaitMinutes,
    '--json'
)
$deployReport = $deployReportCall.Json.result
if ($null -eq $deployReport) {
    throw "Salesforce deployment report was unavailable for $deploymentId."
}

$testResult = $deployReport.details.runTestResult
$coverageResults = @(
    foreach ($coverage in @($testResult.codeCoverage)) {
        $coveredLocations = $coverage.numLocations - $coverage.numLocationsNotCovered
        $coveragePercent = if ($coverage.numLocations -eq 0) {
            100
        } else {
            [math]::Round(($coveredLocations / $coverage.numLocations) * 100, 2)
        }

        [ordered]@{
            name = $coverage.name
            coveredPercent = $coveragePercent
            uncoveredLocations = $coverage.numLocationsNotCovered
        }
    }
)

$verificationResult = [ordered]@{
    requested = -not [string]::IsNullOrWhiteSpace($VerificationFile)
    success = $null
    compileProblem = $null
    exceptionMessage = $null
}

if ($deployReport.success -and $verificationResult.requested) {
    $resolvedVerificationFile = Resolve-DeliveryPath -Path $VerificationFile -ExpectedType 'Leaf'
    $verificationCall = Invoke-DeliverySfJson -Arguments @(
        'apex', 'run',
        '--target-org', $TargetOrg,
        '--file', $resolvedVerificationFile,
        '--json'
    )
    $verificationResult.success = [bool]$verificationCall.Json.result.success
    $verificationResult.compileProblem = $verificationCall.Json.result.compileProblem
    $verificationResult.exceptionMessage = $verificationCall.Json.result.exceptionMessage
}

$componentFailures = @(
    foreach ($failure in @($deployReport.details.componentFailures)) {
        [ordered]@{
            component = $failure.fullName
            file = $failure.fileName
            line = $failure.lineNumber
            problem = $failure.problem
        }
    }
)
$testFailures = @(
    foreach ($failure in @($testResult.failures)) {
        [ordered]@{
            class = $failure.name
            method = $failure.methodName
            message = $failure.message
        }
    }
)

$deliverySummary = [ordered]@{
    storyKey = $StoryKey
    targetOrg = $TargetOrg
    deploymentId = $deploymentId
    deploymentStatus = $deployReport.status
    deploymentSuccess = [bool]$deployReport.success
    components = [ordered]@{
        deployed = $deployReport.numberComponentsDeployed
        total = $deployReport.numberComponentsTotal
        errors = $deployReport.numberComponentErrors
        failures = $componentFailures
    }
    tests = [ordered]@{
        run = $testResult.numTestsRun
        failures = $testResult.numFailures
        methods = @($testResult.successes | ForEach-Object { "$($_.name).$($_.methodName)" })
        failureDetails = $testFailures
        coverage = $coverageResults
    }
    verification = $verificationResult
}

$deliverySummary | ConvertTo-Json -Depth 10

$verificationFailed = $verificationResult.requested -and -not $verificationResult.success
if (-not $deployReport.success -or $verificationFailed) {
    exit 1
}
