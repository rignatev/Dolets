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
    
    function Get-FileHostsContent {
        $result = @{}
    
        $hostsFileContent = Get-Content -Path 'C:\Windows\System32\Drivers\etc\hosts'
            
        foreach ($line in $hostsFileContent) {
            if (-not $line -or $line.StartsWith('#')) {
                continue
            }
                
            # Remove comments
            if ($line -match '#') {
                $line = [regex]::Match($line, '(^.+)#').Groups[1].Value
            }
            # Remove extra whitespaces
            $line = $line.Trim() -replace '\s+', ' '
            
            $array = $line -split ' ' 
            if ($array.Count -ge 1) {
                for ($i = 1; $i -lt $array.Count; $i++) {
                    if (-not $result.Contains($array[$i])) {
                        $null = $result.Add($array[$i], $array[0])
                    }
                }
            }
        }
    
        $result
    }

    #Merge ALL type with current type
    $hostsCollection = [PSCustomObject]($Settings.Custom.HostsTypes.ALL).PsObject.Copy()
    foreach ($property in $Settings.Custom.HostsTypes.$($HostObject.HostType).PSObject.Properties) {
        $hostsNames = $hostsCollection | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name
        if ($hostsNames -contains $property.Name) {
            $hostsCollection.$($property.Name) = $property.Value
        }
        else {
            $hostsCollection | Add-Member -MemberType NoteProperty -Name $property.Name -Value $property.Value
        }
    }

    # Check hosts file records with reference values
    $Result.ReportResults.Result = $true
    $hostsNames = $hostsCollection | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name
    if ($hostsNames) {
        $fileHosts = Get-FileHostsContent
        if ($fileHosts.Count) {
            foreach ($property in $hostsCollection.PSObject.Properties) {
                if (-not $fileHosts.Contains($property.Name) -or ($fileHosts.Contains($property.Name) -and ($fileHosts.$($property.Name) -ne $property.Value)))
                {
                    $Result.ReportResults.Result = $false
                    break
                }
            }        
        }
        else {
            $Result.ReportResults.Result = $false
        }
    }

    $Result.Result = @{
        'From Settings' = $hostsCollection
        'From Host' = $fileHosts
        'Result' = $Result.ReportResults.Result
    }

    #endregion Dolet code
    $Result.Status = $true
}
catch {
    $Result.Status = $false
    $Result.Error = $Error[0]
}

return $Result