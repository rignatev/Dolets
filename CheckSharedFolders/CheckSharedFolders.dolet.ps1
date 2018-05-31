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
    
    function Get-SharePermissions {
        # https://gallery.technet.microsoft.com/scriptcenter/List-Share-Permissions-83f8c419
        Param (
            [Parameter(Mandatory = $true)]
            [string]
            $Share
        )
    
        $objShareSec = Get-WMIObject -Class Win32_LogicalShareSecuritySetting -Filter "name='$Share'"
        if (-not $objShareSec) {
            return $Null
        }
        
        try {  
            $SD = $objShareSec.GetSecurityDescriptor().Descriptor    
            foreach($ace in $SD.DACL) {   
                $UserName = $ace.Trustee.Name      
                If ($ace.Trustee.Domain -ne $Null) {$UserName = "$($ace.Trustee.Domain)\$UserName"}    
                If ($ace.Trustee.Name -eq $Null) {$UserName = $ace.Trustee.SIDString }      
                [Array]$ACL += New-Object Security.AccessControl.FileSystemAccessRule($UserName, $ace.AccessMask, $ace.AceType)  
            }           
        } 
        catch {
            Write-Error "Unable to obtain permissions for $Share"
        }
        
        $ACL  
    }

    function Get-SmbSharesRign {
        $result = @{}
        $shares = Get-WmiObject -Class Win32_Share
        foreach ($share in $shares) {
            $ntfsAcl = $null
            if ($share.Path -and (Test-Path -Path $share.Path)) {
                $ntfsAcl = (Get-Acl -Path $share.Path | Select-Object -ExpandProperty Access)
            }
                
            $newShareHash = @{
                Share = $share
                ShareACL = Get-SharePermissions -Share $share.Name
                NtfsAcl = $ntfsAcl
            }
    
            $result.Add($share.Name, $newShareHash) 
        }
        
        $result
    }

    $nonExistentSharedFolders = @{}
    $referenceSharedFolders = $Settings.Custom.$($HostObject.HostType)
    if ($referenceSharedFolders) {
        $hostSharedFolders = Get-SmbSharesRign
        if ($hostSharedFolders) {
            $Result.ReportResults.Result = $true
            $propertyNames = @(($referenceSharedFolders | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name))
            foreach ($propertyName in $propertyNames) {
                if ($referenceSharedFolders.$propertyName -ne $hostSharedFolders.$propertyName.Share.Path) {
                    $Result.ReportResults.Result = $false
                    $null = $nonExistentSharedFolders.Add($propertyName, $referenceSharedFolders.$propertyName)
                }
            }
        }
        else {
            $Result.ReportResults.Result = $false
        }
    }

    $Result.Result = @{
        'Non-existent Shared Folders' = $nonExistentSharedFolders
        'Host Shared Folders' = $hostSharedFolders
    }
    
    #endregion Dolet code
    $Result.Status = $true
}
catch {
    $Result.Status = $false
    $Result.Error = $Error[0]
}

return $Result