@echo off && goto PreCheck
<# Command Prompt --------------------------------------
  :PreCheck
     setlocal
       for /f "tokens=3 delims=\ " %%A in ('whoami /groups^|find "Mandatory Label"') do set LEVEL=%%A
       if not "%LEVEL%"=="High"  goto GETadmin
     goto Excute
  :GETadmin
     endlocal
     echo "%~nx0": elevating self
     echo    Are you OK ?
     del "%temp%\getadmin.vbs"                                    2>NUL
       set vbs=%temp%\getadmin.vbs
       echo Set UAC = CreateObject^("Shell.Application"^)          >> "%vbs%"
       echo Dim stCmd                                              >> "%vbs%"
       echo stCmd = "/c """"%~s0"" " ^& "%~dp0" ^& Chr(34)         >> "%vbs%"
       echo UAC.ShellExecute "cmd.exe", stCmd, "", "runas", 1      >> "%vbs%"
       pause
       "%temp%\getadmin.vbs"
     del "%temp%\getadmin.vbs"
     goto :eof
  :Excute
     endlocal
     set "Dir=%~1"
     powershell -NoProfile -ExecutionPolicy Unrestricted "$s=[scriptblock]::create((gc \""%~f0"\"|?{$_.readcount -gt 1})-join\"`n\");&$s" "'%Dir%'" &exit /b
-------------------------------------------------------#>
  Param([string] $SptDirPATH)
  write-host "Script Start......`($SptDirPATH`)"
####################################
###   Powershell Script HERE!!   ###
####################################
<# Buffer size adjustment #>
# Stores the default WindowSize value in a variable
$defaultWS = $host.UI.RawUI.WindowSize

# Change BufferSize to 140
(Get-Host).UI.RawUI.BufferSize `
   = New-Object "System.Management.Automation.Host.Size" (140,$host.UI.RawUI.BufferSize.Height)

# WindowSize is set to default value
$host.UI.RawUI.WindowSize = $defaultWS


<# 0 #>
# Checking adapters already set up
$0VMName = (Read-Host "Enter the name of the VM to which you want to add the adapter")

# Check whether the set VM exists
$VMall = Get-VM
$VMalls = $VMall.Name | Out-String -Stream
# conditional branch
if ($VMalls.Contains("$0VMName"))
  {Write-Host "Proceeding with the process"} `
Else `
  {# Input value does not match
   Write-Host "Incorrect characters entered. Processing will be aborted."
   Write-Host "Press any key to continue..."
   $host.UI.RawUI.ReadKey() | Out-Null
   exit
   } 

# Delete already configured adapters
$ErrorActionPreference = 'Stop'
try {
    Remove-VMGpuPartitionAdapter -VMName "$0VMName"
    ""
    Write-Host "GPU-Partition configured for this VM has been removed"
} catch {
    ""
    Write-Host "GPU-Partition is not set for this VM"
}
$ErrorActionPreference = "Continue"


<# 1 #>
# Accept input from user and store input in $percent
""
Write-Host "Please enter an integer value"
[int]$1percentMIN = (Read-Host "MIN: Enter the smallest amount to be divided (%:  0～100)")
[int]$1percentMAX = (Read-Host "MAX: Enter the maximum  amount to be divided (%:MIN～100)")
[int]$1percentOPT = (Read-Host "OPT: Enter the optimal  amount to be divided (%:MIN～MAX)")

# conditional branch
if (($1percentMIN -ge 0) -and
    ($1percentMIN -le 100) -and

    ($1percentMAX -ge 1) -and
    ($1percentMAX -ge ($1percentMIN)) -and
    ($1percentMAX -le 100) -and

    ($1percentOPT -ge 1) -and
    ($1percentOPT -ge $1percentMIN) -and
    ($1percentOPT -le ($1percentMAX))){

    Write-Host "Proceeding with the process"
}Else{
    # Number entered does not match.
    Write-Host "Incorrect characters entered. Processing will be aborted."
    Write-Host "Press any key to continue..."
    $host.UI.RawUI.ReadKey() | Out-Null
    exit
}


<# 2 #>
# Get GPU instance path from Get-VMHostPartitionableGpu

[int]$Count = (Get-VMHostPartitionableGpu).Count

# Get GPU name
If($Count -ge 2) {
   (Get-VMHostPartitionableGpu).Name `
      | ForEach-Object `
           -Begin { 
              # Initialize variables
              Remove-Variable Add, Sub, End 2>${NULL}
              # Variables (Declare, Prepare, and Set)
              $Space = ($Host.UI.RawUI.WindowSize.Width - 11)
              [Array]$Sub = [System.Management.Automation.Host.ChoiceDescription]::new("(&Enter an integer)", "Description.")
              $Name_HashTable = [Ordered]@{}
              [int]$Num = 1
             } `
           -Process { 
             # Adjusted for use with PnP Util
              $InsID = ($_ -split '\\?\',0,'Simplematch' -split '#{')[1].Replace('#','\')
              Set-Variable "2InsID$Num" "$InsID"
             # Get GPU name from PnP Util
              $GPUName = (Get-PnpDevice -InstanceId $InsID).FriendlyName
              Set-Variable "Name$Num" "$GPUName"
             # Prepare "PromptForChoice" choices
              $One = "$GPUName(&$Num)"
              $CRLF = $One.PadRight($Space)+"`b"
              [Array]$Add = [System.Management.Automation.Host.ChoiceDescription]::new("$CRLF", "$_")
             # Branching between the end of the loop and the rest of the loop
              If($Num -ne $Count)
                {$Sub = @($Sub;$Add)}
              Else 
                {$CRLF = $One.PadRight($Space*2)+"`b"
                 $Sub = @($Sub;[System.Management.Automation.Host.ChoiceDescription]::new("$CRLF", "$_`r`n`b"))}
             # Stores instance paths for GPU-P
              $Name_HashTable.Add("$Num","$_")
              $Num += 1
             } `
           -End { 
             # Adding the option of leaving it up to system
              [Array]$End = [System.Management.Automation.Host.ChoiceDescription]::new("Not specified(&$Num)`r`n`b", "Let the system do the work.`r`n`r`n`b")
              $Sub = @($Sub;$End)
             }

  # Set what to execute in PromptForChoice
   1..($Num-1) | ForEach-Object `
                    -Begin { $Options = @('{') } `
                    -Process { 
                       $Arg1 = (Get-Variable "Name$_").Value
                       $Arg2 = $Name_HashTable["$_"]
                       $Options += "$_ `{Write-Host `"$Arg1 is selected`" ;`$AGPUName = `"$Arg1`" ;`$2gpuNAME = `"$Arg2`" ;break `};" 
                      } `
                    -End { $Options += @('}') }
  # Display choices on screen
   $Result = $Host.UI.PromptForChoice("'Confirmation'","--Please select a number and enter it--`r`n`b",$Sub,$Num)
  # Execute commands according to selection
   If($Result -ne $Num) {
      . ([Scriptblock]::Create("switch ($Result) $Options"))
   }
}

# Execute when one GPU or leave it to the GPU
If(!($Count -ge 2) -OR ($Result -eq $Num)) {
   Write-Host "Set the GPU as an argument"
   $2gpuNAME `
      = ( Get-VMHostPartitionableGpu `
             | Select-Object Name `
             | Get-Member -Membertype NoteProperty `
             | Select-Object Definition `
             | Format-Table -AutoSize -Wrap `
             | Out-String -Stream `
             | Select-String string `
         )  -replace "string Name="

   # Get GPU name
   $2InsID = ($2gpuNAME -split '\\?\',0,'Simplematch' -split '#{')[1].Replace('#','\')
   $AGPUName = (Get-PnpDevice -InstanceId $2InsID).FriendlyName
}

# Display acquired content
""
Write-Host (@"
$0VMName to
GPU : $2gpuNAME
 ($AGPUName)
As a GPU-Partition
"@)
""


<# 3 #>
# Get the total amount of GPUs allocated from Get-VMHostPartitionableGpu
$3gpuAvailableVRAM = Get-VMHostPartitionableGpu | Out-String -Stream | Select-String AvailableVRAM
$3gpuAvailableEncode = Get-VMHostPartitionableGpu | Out-String -Stream | Select-String AvailableEncode
$3gpuAvailableDecode = Get-VMHostPartitionableGpu | Out-String -Stream | Select-String AvailableDecode
$3gpuAvailableCompute = Get-VMHostPartitionableGpu | Out-String -Stream | Select-String AvailableCompute

# Stores each total amount of GPUs as a numerical value, respectively
$3gpuAvailableVRAMA = [int]($3gpuAvailableVRAM -replace "[a-zA-Z]" -replace '[" *"]' -replace ":")
$3gpuAvailableEncodeA = [decimal]($3gpuAvailableEncode -replace "[a-zA-Z]" -replace '[" *"]' -replace ":")
$3gpuAvailableDecodeA = [int]($3gpuAvailableDecode -replace "[a-zA-Z]" -replace '[" *"]' -replace ":")
$3gpuAvailableComputeA = [int]($3gpuAvailableCompute -replace "[a-zA-Z]" -replace '[" *"]' -replace ":")


<# 4 #>
# Create a directory to store LOG
$DIRpath=$SptDirPATH.TrimEnd('\') + "\LOG"
if ( -not ( Test-Path -Path "$DIRpath" )){ New-Item "$DIRpath" -ItemType Directory > $null }
Get-Date | Out-String -Stream | ?{$_ -ne ""} | Out-File "$DIRpath\GPU-P_log.txt" -Append -Force


<# 5 #>
# Find the partitioning value
$VRAMdivideMIN = [Math]::Round($($3gpuAvailableVRAMA * ($1percentMIN / 100)),0)
$VRAMdivideMAX = [Math]::Round($($3gpuAvailableVRAMA * ($1percentMAX / 100)),0)
$VRAMdivideOPT = [Math]::Round($($3gpuAvailableVRAMA * ($1percentOPT / 100)),0)

$ENCODEdivideMIN = [Math]::Round($($3gpuAvailableEncodeA * ($1percentMIN / 100)),0)
$ENCODEdivideMAX = [Math]::Round($($3gpuAvailableEncodeA * ($1percentMAX / 100)),0)
$ENCODEdivideOPT = [Math]::Round($($3gpuAvailableEncodeA * ($1percentOPT / 100)),0)

$DECODEdivideMIN = [Math]::Round($($3gpuAvailableDecodeA * ($1percentMIN / 100)),0)
$DECODEdivideMAX = [Math]::Round($($3gpuAvailableDecodeA * ($1percentMAX / 100)),0)
$DECODEdivideOPT = [Math]::Round($($3gpuAvailableDecodeA * ($1percentOPT / 100)),0)

$COMPUTEdivideMIN = [Math]::Round($($3gpuAvailableComputeA * ($1percentMIN / 100)),0)
$COMPUTEdivideMAX = [Math]::Round($($3gpuAvailableComputeA * ($1percentMAX / 100)),0)
$COMPUTEdivideOPT = [Math]::Round($($3gpuAvailableComputeA * ($1percentOPT / 100)),0)


# Organize calculation results
$5VRAMdisplay = [pscustomobject]([ordered]@{"------VRAM------" = ""; MIN = " $VRAMdivideMIN"; OPT = " $VRAMdivideOPT"; MAX = " $VRAMdivideMAX"; Available = " $3gpuAvailableVRAMA";})
$5ENCODEdisplay = [pscustomobject]([ordered]@{"-----Encode-----" = ""; MIN = " $ENCODEdivideMIN"; OPT = " $ENCODEdivideOPT"; MAX = " $ENCODEdivideMAX"; Available = " $3gpuAvailableEncodeA";})
$5DECODEdisplay = [pscustomobject]([ordered]@{"-----Decode-----" = ""; MIN = " $DECODEdivideMIN"; OPT = " $DECODEdivideOPT"; MAX = " $DECODEdivideMAX"; Available = " $3gpuAvailableDecodeA";})
$5COMPUTEdisplay = [pscustomobject]([ordered]@{"-----Compute----" = ""; MIN = " $COMPUTEdivideMIN"; OPT = " $COMPUTEdivideOPT"; MAX = " $COMPUTEdivideMAX"; Available = " $3gpuAvailableComputeA";})

""
Write-Host "# confimation"

Write-Output "VM  : $0VMName"  | Out-File "$DIRpath\GPU-P_log.txt" -Append
Write-Output "GPU : $AGPUName" | Out-File "$DIRpath\GPU-P_log.txt" -Append
Write-Output "Instance ID A : $2InsID" | Out-File "$DIRpath\GPU-P_log.txt" -Append
Write-Output "Instance ID B : $2gpuNAME" | Out-File "$DIRpath\GPU-P_log.txt" -Append

$5VRAMdisplay | Out-String -Stream | ?{$_ -ne ""} | Tee-Object -FilePath "$DIRpath\GPU-P_log.txt" -Append
$5ENCODEdisplay | Out-String -Stream | ?{$_ -ne ""} | Tee-Object -FilePath "$DIRpath\GPU-P_log.txt" -Append
$5DECODEdisplay | Out-String -Stream | ?{$_ -ne ""} | Tee-Object -FilePath "$DIRpath\GPU-P_log.txt" -Append
$5COMPUTEdisplay | Out-String -Stream | ?{$_ -ne ""} | Tee-Object -FilePath "$DIRpath\GPU-P_log.txt" -Append

""
Write-Host "*Logs are output to `"$DIRpath\GPU-P_log.txt`""

Write-Output "" | Out-File "$DIRpath\GPU-P_log.txt" -Append -Force
Write-Output "" | Out-File "$DIRpath\GPU-P_log.txt" -Append -Force


<# 6 #>
# Check to see if it runs
$title = "'Confirmation'"
$message = @"
Set GPUPartition as above.
Do you want to perform this operation?
"@

$tChoiceDescription = "System.Management.Automation.Host.ChoiceDescription"
$tOptions = @(
    New-Object $tChoiceDescription ("Yes(&Yes)", "Perform this operation and proceed to the next step.")
    New-Object $tChoiceDescription ("No(&No)", "Cancel and abort this operation.")
)

$tResult = $host.ui.PromptForChoice($title, $message, $tOptions, 0)
switch ($tResult)
  {
    0 {"'Yes' was selected."; break}
    1 {"'No' was selected."; break}
  }

if ($tResult -ne 0) { exit }


<# 7 #>
# Add GPU-P.Adapter
If(!($Count -ge 2) -OR ($Result -eq $Num)) {
   # Specified by system
   Add-VMGpuPartitionAdapter -VMName "$0VMName"
}Else{
   # When specifying a GPU
   Add-VMGpuPartitionAdapter -VMName "$0VMName" -InstancePath "$2gpuNAME"
}

# Configure the added adapter
#VRAM
Set-VMGpuPartitionAdapter -VMName "$0VMName" -MinPartitionVRAM $VRAMdivideMIN
Set-VMGpuPartitionAdapter -VMName "$0VMName" -MaxPartitionVRAM $VRAMdivideMAX
Set-VMGpuPartitionAdapter -VMName "$0VMName" -OptimalPartitionVRAM $VRAMdivideOPT

#Encode
Set-VMGpuPartitionAdapter -VMName "$0VMName" -MinPartitionEncode $ENCODEdivideMIN
Set-VMGpuPartitionAdapter -VMName "$0VMName" -MaxPartitionEncode $ENCODEdivideMAX
Set-VMGpuPartitionAdapter -VMName "$0VMName" -OptimalPartitionEncode $ENCODEdivideOPT

#Decode
Set-VMGpuPartitionAdapter -VMName "$0VMName" -MinPartitionDecode $DECODEdivideMIN
Set-VMGpuPartitionAdapter -VMName "$0VMName" -MaxPartitionDecode $DECODEdivideMAX
Set-VMGpuPartitionAdapter -VMName "$0VMName" -OptimalPartitionDecode $DECODEdivideOPT

#Compute
Set-VMGpuPartitionAdapter -VMName "$0VMName" -MinPartitionCompute $COMPUTEdivideMIN
Set-VMGpuPartitionAdapter -VMName "$0VMName" -MaxPartitionCompute $COMPUTEdivideMAX
Set-VMGpuPartitionAdapter -VMName "$0VMName" -OptimalPartitionCompute $COMPUTEdivideOPT


<# 8 #>
# Enable CPU Write-Combining
Set-VM -GuestControlledCacheTypes $true -VMName "$0VMName"

# MMIO area configuration
Set-VM -LowMemoryMappedIoSpace 1Gb -VMName "$0VMName"
Set-VM -HighMemoryMappedIoSpace 33280Mb -VMName "$0VMName"


<# 9 #>
# Confirmation（= Get-VMGpuPartitionAdapter "$0VMName" -verbose ）
Get-VMGpuPartitionAdapter -VMName "$0VMName"

# Closing message
Write-Host "All processes have been completed"
####################################
###            FINISH            ###
####################################
  Write-Host "---Script Finish---"
  Write-Host "Press any key to close the screen..."
  $host.UI.RawUI.ReadKey() | Out-Null
  EXIT
