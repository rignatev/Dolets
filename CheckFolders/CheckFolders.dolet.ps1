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

    function Get-Folders
    {
        Param
        (
            [Parameter(Mandatory = $true)]
            [string[]]
            $Folders
        )
        
        $result = @{}
    
        foreach ($folder in $Folders)
        {
            if (Test-Path -Path $folder)
            {
                $result.Add($folder,(Get-Acl -Path $folder | Select-Object -ExpandProperty Access))
            }
        }
        
        $result
    }

    $nonExistentFolders = New-Object -TypeName System.Collections.ArrayList
    $referenceFolders = $Settings.Custom.$($HostObject.HostType)
    if ($referenceFolders)
    {
        $folders = Get-Folders -Folders $referenceFolders
        if ($folders)
        {
            $Result.ReportResults.Result = $true
            foreach ($item in $referenceFolders)
            {
                if (-not $folders.$item)
                {
                    $Result.ReportResults.Result = $false
                    $nonExistentFolders.Add($item)
                }
            }
        }
        else
        {
            $Result.ReportResults.Result = $false
            $nonExistentFolders = $referenceFolders
        }
    }

    $Result.Result = @{
        'Non-existent Folders' = $nonExistentFolders
        'Found Folders' = $folders
    }

    #endregion Dolet code
    $Result.Status = $true
}
catch {
    $Result.Status = $false
    $Result.Error = $Error[0]
}

return $Result