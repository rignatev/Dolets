
$string = Read-Host -Prompt 'String to encrypt'
$secureString = ConvertTo-SecureString -String $string -AsPlainText -Force
$key = Read-Host -Prompt 'Key'

# Derive secure key
$StringBuilder = New-Object -TypeName System.Text.StringBuilder
[System.Security.Cryptography.HashAlgorithm]::Create('MD5').ComputeHash([System.Text.Encoding]::UTF8.GetBytes($key)) | 
    ForEach-Object -Process {$null = $StringBuilder.Append($_.ToString('x2'))}
$secureKey = ConvertTo-SecureString ($StringBuilder.ToString().Substring(0,16)) -AsPlainText -Force

# Derive encrypted string
$encryptedString = ConvertFrom-SecureString -SecureString $secureString -SecureKey $secureKey
# | Out-File -FilePath 'encryptedPassword.txt'
Set-Content -Path 'EncryptedString.txt' -Value ('String: {0}' -f $string)
Add-Content -Path 'EncryptedString.txt' -Value ('Key: {0}' -f $key)
Add-Content -Path 'EncryptedString.txt' -Value ('Encrypted string:{0}{1}' -f ([System.Environment]::NewLine), $encryptedString)

# Decrypt encrypted string
$secureDecryptedString = ConvertTo-SecureString $encryptedString -SecureKey $secureKey
$decryptedString = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($secureDecryptedString))
Write-Host "Decrypted String: $decryptedString"
