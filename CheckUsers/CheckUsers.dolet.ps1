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
    
    function Get-LocalUsers
    {
        $result = New-Object -TypeName System.Collections.ArrayList
        $users = Get-WmiObject -Class Win32_UserAccount -Filter  "LocalAccount='True'"
        foreach ($user in $users)
        {
            $null = $result.Add($user.Name)
        }
        
        $result
    }
    
    function Test-LocalCredential {
        [CmdletBinding()]
        Param (
            # User name
            [Parameter(Mandatory = $true, Position = 0)]
            [string]
            $UserName,

            # User password
            [Parameter(Mandatory = $true, Position = 1)]
            [string]
            $Password,

            # Computer name
            [Parameter(Mandatory = $false, Position = 1)]
            [string]
            $ComputerName = $env:COMPUTERNAME
        )

        Add-Type -AssemblyName System.DirectoryServices.AccountManagement
        $DS = New-Object System.DirectoryServices.AccountManagement.PrincipalContext('machine',$ComputerName)
        $DS.ValidateCredentials($UserName, $Password)

    }
    function ConvertFrom-Secret {
        param ([string]$Param1,[string]$Param2)

        try {
            $StringBuilder = New-Object -TypeName System.Text.StringBuilder
            [System.Security.Cryptography.HashAlgorithm]::Create('MD5').ComputeHash([System.Text.Encoding]::UTF8.GetBytes($Param1)) | 
                ForEach-Object -Process {$null = $StringBuilder.Append($_.ToString('x2'))}
            $secureParam1 = ConvertTo-SecureString ($StringBuilder.ToString().Substring(0,16)) -AsPlainText -Force
            $secureParam2 = ConvertTo-SecureString $Param2 -SecureKey $secureParam1
    
            [System.Runtime.InteropServices.Marshal]::PtrToStringAuto([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($secureParam2))
        }
        catch {
            
        }
    }
    
    $doletResult = New-Object -TypeName psobject -Property @{
        ReferenceUsers = $null
        LocalUsers = $null
        Error = $null
    }

    $referenceUsers = $Settings.Custom.$($HostObject.HostType)
    $doletResult.ReferenceUsers = $referenceUsers | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name
    if ($referenceUsers) {
        $users = Get-LocalUsers
        $doletResult.LocalUsers = $users
        if ($users) {
            $Result.ReportResults.Result = $true
            foreach ($user in $referenceUsers.PSObject.Properties) {
                if ($users -notcontains $user.Name) {
                    $Result.ReportResults.Result = $false
                    $doletResult.Error = 'The reference user {0} is missing' -f $user.Name
                    break
                }

                $pass = ConvertFrom-Secret -Param1 $user.Name -Param2 $user.Value
                if (-not $pass) {
                    $Result.ReportResults.Result = 'Fail'
                    $doletResult.Error = 'Cannot decrypt a password for the user {0}' -f $user.Name
                    break
                }

                if (-not (Test-LocalCredential -UserName $user.Name -Password ($pass))) {
                    $Result.ReportResults.Result = $false
                    $doletResult.Error = 'The reference user {0} password does not match' -f $user.Name
                    break
                }

            }
        }
        else {
            $Result.ReportResults.Result = 'Fail'
            $doletResult.Error = 'Cannot get local users list'
        }
    }

    $Result.Result = $doletResult
    #endregion Dolet code
    $Result.Status = $true
}
catch {
    $Result.Status = $false
    $Result.Error = $Error[0]
}

return $Result