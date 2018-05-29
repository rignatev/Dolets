param (
    # PSObject with Dolet settings
    [Parameter(Mandatory=$true, Position=0)]
    [psobject]
    $Settings,

    # PSObject with Dolet result
    [Parameter(Mandatory=$true, Position=1)]
    [psobject]
    $Result,

    # PSObject with Host data
    [Parameter(Mandatory=$true, Position=2)]
    [psobject]
    $HostObject
)
$Version = '1.0'

try {
    if ($Version -ne $Settings.Version) {
        throw 'Dolet version and Settings version do not match'
    }
    #region Dolet code
    
    $null = New-PSDrive -Name 'HKCR' -PSProvider Registry -Root 'HKEY_CLASSES_ROOT' 
    $rawOfficeVersion = (Get-ItemProperty -Path HKCR:\Word.Application\CurVer -ErrorAction SilentlyContinue).'(default)'
    Remove-PSDrive -Name 'HKCR'

    if ($rawOfficeVersion) {
        $propertyNames = @(($Settings.Custom.WordVersions | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name))
        if ($propertyNames -contains $rawOfficeVersion) {
            $Result.ReportResults.Version = $Settings.Custom.WordVersions.$rawOfficeVersion
        }
        else {
            $Result.ReportResults.Version = 'Not in the list'
        }
    }
    else {
        $Result.ReportResults.Version = 'Not installed'
    }
    
    $Result.Result = $rawOfficeVersion

    #endregion Dolet code
    $Result.Status = $true
}
catch {
    $Result.Status = $false
    $Result.Error = $Error[0]
}

return $Result