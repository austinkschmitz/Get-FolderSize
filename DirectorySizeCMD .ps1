Param
(
    [Parameter(Mandatory = $true,
    ValueFromPipeline = $true,
        Position = 0)]
    $TgtFolder
)



$TgtFolder = $TgtFolder.Trim("'")
$TgtFolder = $TgtFolder.Trim('"')

$Script:RegexMachineName = [regex]"(A|D|E|H|M|R|T|S|W){1}(D|L|R){1}[A-Z]{4}\d{6}(NN|KT|NR|TR|KP|)(\.NADSUSEA\.NADS\.NAVY\.MIL|\.NADSUSWE\.NADS\.NAVY\.MIL|\.NMCI-ISF\.COM|\.PACOM\.MIL|)"
$Script:RegexIPAddress = [regex]"\b(?:[0-9]{1,3}\.){3}[0-9]{1,3}\b"
$Script:Machine = $null
$Script:Regex = [regex]"(k|g|m|b)"
$Script:Machine = ([regex]::Match($TgtFolder, $Script:RegexMachineName)).Value
$Script:IPAddress = ([regex]::Match($TgtFolder, $Script:RegexIPAddress)).Value
$Script:TGT = $null



if ($Script:Machine.Length -gt 5) {
    $Script:TGT = New-PSSession -ComputerName $Script:Machine -Name 'TGTMachine'
}
else {
    $Script:TGT = $false
}

function Get-FolderSize {
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        $Path,
        [ValidateSet("KB", "MB", "GB")]
        $Units = "MB"
    )
    if ( (Test-Path $Path) -and (Get-Item $Path).PSIsContainer ) {

        $cDst = "C:AIPAIP\"

        if ($Script:TGT) {
            $robo_test = Invoke-Command -Session $Script:TGT  -ScriptBlock { param($Path, $cDst) robocopy "$Path" "$cDst" /L /Xj /R:0 /NP /E /NFL /NDL /MT:256 } -ArgumentList $Path, $cDst
        }
        else {
            $robo_test = robocopy "$Path" "$cDst" /L /Xj /R:0 /NP /E /NFL /NDL /MT:256
        }

        $robo_results = $robo_test -match '^(?= *?\b(Total|Dirs|Files|Times|Bytes)\b)((?!    Files).)*$'

        $row = ((($robo_results[3]) -split "\s+")[3]) + ((($robo_results[3]) -split "\s+")[4])
        $files = [int]((($robo_results[2]) -split "\s+")[3])
        $StringSize = [regex]::Match($row, $Script:Regex)
        $NumberSize = $Row.Trim($StringSize.Value)
        switch ($StringSize.Value) {
            k { $StringSize = "KB" }
            g { $StringSize = "GB" }
            m { $StringSize = "MB" }
            default { $StringSize = "bytes" }
        }

        $results = [PSCustomObject]@{ Folder = $Path ; Size = $NumberSize ; bytes = $StringSize }
        return $results

    }
}


function Add-TGTFolder ($NewTGTFolder) {
    $Rez = @()

    $TgtFolder = Get-ChildItem $NewTGTFolder

    foreach ($tgtFolders in $TgtFolder) {
        $Rez += Get-FolderSize -Path $tgtFolders.FullName -Units MB
    }
    Return $Rez
}


$Rezults = Add-TGTFolder -NewTGTFolder $TgtFolder

$foo = @{'Folder' = $TgtFolder }
while ($null -ne $foo) {
    $foo = $Rezults | Out-GridView -PassThru -Title $foo.Folder
    $Rezults = Add-TGTFolder -NewTGTFolder $foo.Folder
}


if ($Script:TGT) {
    Remove-PSSession -Name 'TGTMachine'
}