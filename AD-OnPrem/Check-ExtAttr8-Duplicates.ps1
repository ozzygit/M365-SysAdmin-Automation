Get-ADUser -Filter * -Properties extensionAttribute8 -Server $env:LOGONSERVER.TrimStart('\') |
    Where-Object { $_.extensionAttribute8 } |
    Group-Object extensionAttribute8 |
    Where-Object { $_.Count -gt 1 } |
    ForEach-Object {
        foreach ($user in $_.Group) {
            [PSCustomObject]@{
                extensionAttribute8 = $_.Name
                SamAccountName      = $user.SamAccountName
            }
        }
    } |
    Export-Csv -Path (Join-Path ([Environment]::GetFolderPath('MyDocuments')) 'PowerShell-Output\ExtAttr8-Duplicates.csv') -NoTypeInformation
