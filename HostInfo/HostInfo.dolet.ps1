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
    
    function Test-LicenseStatus {
        $result = '-'
        $osVersion = ([Environment]::OSVersion).Version
        switch ($osVersion) {
            {($_.ToString()).StartsWith('5.1')} {
                $productActivation = Get-WmiObject -Class Win32_WindowsProductActivation -Property ActivationRequired -ErrorAction SilentlyContinue
                if ($productActivation) {
                    if($productActivation.ActivationRequired -eq 0) {
                        $result = $true
                    }
                    else {
                        $result = $false
                    }
                }
                break
            }
            default {
                $licensingProduct = Get-WmiObject -Class SoftwareLicensingProduct -Filter "ApplicationID = '55c92734-d682-4d71-983e-d6ec3f16059f'" -Property LicenseStatus -ErrorAction SilentlyContinue

                if ($licensingProduct) {
                    if ($licensingProduct | Where-Object -FilterScript {$_.LicenseStatus-eq 1}) {
                        $result = $true
                    }
                    else {
                        $result = $false
                    }            
                }
            }
        }
        
        $result
    }

    $Result.ReportResults.MachineName = [System.Environment]::MachineName
    $computerSystemModel = (Get-WmiObject -Class Win32_ComputerSystem).Model
    if ($computerSystemModel) {
        $Result.ReportResults.ComputerModel = $computerSystemModel
    }
    $systemEnclosureSerialNumber = (Get-WmiObject -Class Win32_SystemEnclosure).SerialNumber
    if ($systemEnclosureSerialNumber) {
        $Result.ReportResults.ComputerSerialNumber = $systemEnclosureSerialNumber
    }

    $Result.ReportResults.OsCaption = (Get-WmiObject -Class Win32_OperatingSystem).Caption
    $Result.ReportResults.OsVersion = ([Environment]::OSVersion).Version
    $Result.ReportResults.OsLicensed  = Test-LicenseStatus

    #endregion Dolet code
    $Result.Status = $true
}
catch {
    $Result.Status = $false
    $Result.Error = $Error[0]
}

return $Result