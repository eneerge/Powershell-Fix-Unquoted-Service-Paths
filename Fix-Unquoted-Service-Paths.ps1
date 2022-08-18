$FixIt = 1;
# Preliminary stuff for registry access
  $Type_SZ = [Microsoft.Win32.RegistryValueKind]::String
  $Hive = [Microsoft.Win32.RegistryHive]::LocalMachine
  $KeyPath = "SYSTEM\CurrentControlSet\services"
 
  $ComputerName = $_;
  # hat tip to http://stackoverflow.com/a/19015125 for this newer way of creating a custom object
  $ResultObj = [pscustomobject]@{
    ComputerName = $ComputerName
    Status = "Online"
    SubKey = $null
    Original = $null
    Replacement = $null
  }

$ComputerName = "localhost"
if (Test-Connection -ComputerName $ComputerName -Quiet -Count 2) { 
    # Clear the variable that will hold the registry connection
    $Reg = $null; 
 
    # Open remote registry and if it fails then set the status accordingly
    try { $Reg = [Microsoft.Win32.RegistryKey]::OpenBaseKey($Hive, "Registry64") } catch { $ResultObj.Status = "Error"; $ResultObj }
    
    if ($Reg) {
      # Open the services key
      $Key = $Reg.OpenSubKey($KeyPath, $true)
 
      # Enumerate subkeys; and for each subkey do ...
      foreach ($SubkeyName in $Key.GetSubKeyNames()) {
        # Open the subkey read-only (else we get errors on some keys which we don't have write access to)
        $Subkey = $Key.OpenSubKey($SubkeyName, $false)
    
        # Get value of ImagePath
        $Value = $Subkey.GetValue("ImagePath")
 
        # Match ImagePath to see if it has an exe; if yes, extract the exe path. Note: extract only exe path, not arguments. 
        # If this extracted path doesn't start in quotes and when we split it for spaces we get more than one result, then enclose path in double quotes.
        if ($Value -match ".*\.exe" ) { 
          if (($Matches[0] -notlike '"*') -and (($Matches[0] -split '\s').Count -gt 1)) { 
            $Replacement = '"' + $Matches[0] + '"'
            $NewValue = $Value -replace ".*\.exe",$Replacement
 
            $ResultObj.SubKey = Split-Path -Leaf $SubKey;
            $ResultObj.Original = $Value;
            $ResultObj.Replacement = $NewValue;
        
            $ResultObj
          
            if ($FixIt) {
              # re-open the key with read-write permissions 
              $Subkey = $Key.OpenSubKey($SubkeyName, $true)
              $Subkey.SetValue("ImagePath","$Replacement");
              if ($?) { Write-Host -ForegroundColor Green "Success!" } else { Write-Host -ForegroundColor Red "Something went wrong!" }
            }
          } 
          Clear-Variable Matches
        }
      }
    }
  } else { Write-Error "Unable to connect."; return 1001; }
