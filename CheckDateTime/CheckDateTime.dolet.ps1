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
    
    <#
    https://icookservers.wordpress.com/2014/09/12/windows-ntp-server-cookbook/
    HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\W32Time\Parameters\NtpServer
    Set the value to: 0.pool.ntp.org,0x01 1.pool.ntp.org,0x01 2.pool.ntp.org,0x02 (these are free public NTP servers on the Internet) or your preferred external NTP servers. Make sure you maintain a white space between servers.
    The "0x01" flag indicate sync time with external server in special interval configured in "SpecialPollInterval" registry value.
    Value "0x08" means - use client mode association while sync time to external time source.
    Value "0x09" means - use special interval + client mode association to external time source. This is a good value when your machine sync time to an external time source.
    Value "0x02" means - use this as UseAsFallbackOnly time source - if primary is not available then sync to this server.
    Value "0xa" means - UseAsFallbackOnly + client mode association.
    #>

    function Get-TimeDelta {
        Param (
            [Parameter(Mandatory = $true)]
            [string]
            $ComputerName
        )

        process {
            $result = w32tm /stripchart /computer:$ComputerName /dataonly /samples:1
            $errText = $result -match '0x800'
            if ($errText) {
                return $false
            }
        
            # Useful resource with regex https://regex101.com/
            # Find delta in the line number 4
            $result = [float]([regex]::Match($result[3], ',\s([+|-]\d+.\d+?)\D*$').Groups[1].Value)
            $result
        }
    }

    # Use value for All if setting for HostType is missing
    if (-not ($Settings.Custom.HostsTypes.($HostObject.HostType).NtpServers)) {
        $null = ($Settings.Custom.HostsTypes).PSObject.Properties.Remove($HostObject.HostType)
        $Settings.Custom.HostsTypes | Add-Member -MemberType NoteProperty -Name $HostObject.HostType -Value $Settings.Custom.HostsTypes.ALL
    }

    # Get local data
    $ntpServers = (Get-ItemProperty -Path HKLM:SYSTEM\CurrentControlSet\Services\W32Time\Parameters).NtpServer
    $ativeTimeBias = (Get-ItemProperty -Path HKLM:SYSTEM\CurrentControlSet\Control\TimeZoneInformation).ActiveTimeBias
    $timeDelta = Get-TimeDelta -ComputerName $Settings.Custom.NtpServer

    # Fill ReportResults
    # Check NtpServers
    $Result.ReportResults.NtpServer = $false
    if ($ntpServers -match ($Settings.Custom.HostsTypes.($HostObject.HostType).NtpServers)) {
        $Result.ReportResults.NtpServer = $true
    }

    # Check TimeZone
    if ($ativeTimeBias) {
        $Result.ReportResults.TimeZone = $false
        if ($Settings.Custom.ActiveTimeBias -contains $ativeTimeBias) {
            $Result.ReportResults.TimeZone = $true
        }
    }
    else {
        $Result.ReportResults.TimeZone = 'Fail'
    }

    # Check TimeDelta
    if ($timeDelta) {
        if ([math]::Abs($timeDelta) -lt $Settings.Custom.MaxTimeDeltaSecond) {
            $Result.ReportResults.TimeDelta = $true
        }
        else {
            $Result.ReportResults.TimeDelta = $false
        }   
    }
    else {
        $Result.ReportResults.TimeDelta = 'Fail'
    }

    # Fill Result
    $Result.Result = [PSCustomObject]@{
        'NtpServers' = $ntpServers
        'ActiveTimeBias' = $ativeTimeBias
        'TimeDelta' = $timeDelta
        'DateTime' = Get-Date
    }
    
    #endregion Dolet code
    $Result.Status = $true
}
catch {
    $Result.Status = $false
    $Result.Error = $Error[0]
}

return $Result