@echo off && goto PreCheck
<# コマンドプロンプト----------------------------------
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
<# バッファーサイズの調整 #>
# WindowSize の既定値を変数に格納
$defaultWS = $host.UI.RawUI.WindowSize

# BufferSize を 140 に変更
(Get-Host).UI.RawUI.BufferSize `
   = New-Object "System.Management.Automation.Host.Size" (140,$host.UI.RawUI.BufferSize.Height)

# WindowSize は既定値に設定
$host.UI.RawUI.WindowSize = $defaultWS


<# 0 #>
# すでに設定されているアダプターの確認
$0VMName = (Read-Host アダプターを追加するVM名を入力してください)

# セットしたVMが存在するか確認
$VMall = Get-VM
$VMalls = $VMall.Name | Out-String -Stream
# 条件分岐
if ($VMalls.Contains("$0VMName"))
  {Write-Host プロセスを進めます} `
Else `
  {# 入力された値が 不適合
   Write-Host 入力された文字が不適切です。処理を中断します。
   Write-Host "続行するには何かキーを押してください..."
   $host.UI.RawUI.ReadKey() | Out-Null
   exit
   } 

# すでに設定されているアダプターの削除
$ErrorActionPreference = 'Stop'
try {
    Remove-VMGpuPartitionAdapter -VMName "$0VMName"
    ""
    Write-Host "このVMに設定されていたGPU-Partitionが削除されました"
} catch {
    ""
    Write-Host "このVMにGPU-Partitionは設定されていません"
}
$ErrorActionPreference = "Continue"


<# 1 #>
# ユーザーから入力を受け付けて入力内容を $percent に格納
""
Write-Host "※整数値を入力してください"
[int]$1percentMIN =(Read-Host "MIN：分割する最小の量を入力してください（%:  0～100）")
[int]$1percentMAX =(Read-Host "MAX：分割する最大の量を入力してください（%:MIN～100）")
[int]$1percentOPT =(Read-Host "OPT：分割する最適の量を入力してください（%:MIN～MAX）")

# 条件分岐
if (($1percentMIN -ge 0) -and
    ($1percentMIN -le 100) -and

    ($1percentMAX -ge 1) -and
    ($1percentMAX -ge ($1percentMIN)) -and
    ($1percentMAX -le 100) -and

    ($1percentOPT -ge 1) -and
    ($1percentOPT -ge $1percentMIN) -and
    ($1percentOPT -le ($1percentMAX))){
	# 処理（if,elseそれぞれ何かしら必要）
    Write-Host プロセスを進めます
}Else{
    # 入力された数字が 不適合
    Write-Host 入力された文字が不適切です。処理を中断します。
    Write-Host "続行するには何かキーを押してください..."
    $host.UI.RawUI.ReadKey() | Out-Null
    exit
}


<# 2 #>
# インスタンスパス、GPU名、変数等を取得する

[int]$Count = (Get-VMHostPartitionableGpu).Count

# 接続されている GPU の数で分岐
If($Count -ge 2) {
   (Get-VMHostPartitionableGpu).Name `
      | ForEach-Object `
           -Begin { 
              # 変数を初期化
              Remove-Variable Add, Sub, End 2>${NULL}
              # 変数を宣言、準備、設定
              $Space = ($Host.UI.RawUI.WindowSize.Width - 11)
              [Array]$Sub = [System.Management.Automation.Host.ChoiceDescription]::new("(&整数を入力)", "説明")
              $Name_HashTable = [Ordered]@{}
              [int]$Num = 1
             } `
           -Process { 
             # PnP Util で使えるように調整
              $InsID = ($_ -split '\\?\',0,'Simplematch' -split '#{')[1].Replace('#','\')
              Set-Variable "2InsID$Num" "$InsID"
             # PnP Util から GPU名 を取得
              $GPUName = (Get-PnpDevice -InstanceId $InsID).FriendlyName
              Set-Variable "Name$Num" "$GPUName"
             # PromptForChoice の選択肢を準備
              $One = "$GPUName(&$Num)"
              $CRLF = $One.PadRight($Space)+"`b"
              [Array]$Add = [System.Management.Automation.Host.ChoiceDescription]::new("$CRLF", "$_")
             # ループの最後とそれ以外で分岐
              If($Num -ne $Count)
                {$Sub = @($Sub;$Add)}
              Else 
                {$CRLF = $One.PadRight($Space*2)+"`b"
                 $Sub = @($Sub;[System.Management.Automation.Host.ChoiceDescription]::new("$CRLF", "$_`r`n`b"))}
             # GPU-P 用のインスタンスパスを格納
              $Name_HashTable.Add("$Num","$_")
              $Num += 1
             } `
           -End { 
             # おまかせの選択肢の追加
              [Array]$End = [System.Management.Automation.Host.ChoiceDescription]::new("指定しない(&$Num)`r`n`b", "システムに任せます。`r`n`r`n`b")
              $Sub = @($Sub;$End)
             }

  # PromptForChoice で実行するものを設定
   1..($Num-1) | ForEach-Object `
                    -Begin { $Options = @('{') } `
                    -Process { 
                       $Arg1 = (Get-Variable "Name$_").Value
                       $Arg2 = $Name_HashTable["$_"]
                       $Options += "$_ `{Write-Host `"$Arg1 が選択されました`" ;`$AGPUName = `"$Arg1`" ;`$2gpuNAME = `"$Arg2`" ;break `};" 
                      } `
                    -End { $Options += @('}') }
  # 選択肢を画面表示
   $Result = $Host.UI.PromptForChoice("【確認】","--番号を選び、入力してください--`r`n　",$Sub,$Num)
  # 選択に応じたコマンドを実行
   If($Result -ne $Num) {
      . ([Scriptblock]::Create("switch ($Result) $Options"))
   }
}

# GPU が1つ 又は おまかせ にした場合に実行する
If(!($Count -ge 2) -OR ($Result -eq $Num)) {
   Write-Host "GPUを引数にセットします"
   $2gpuNAME `
      = ( Get-VMHostPartitionableGpu `
             | Select-Object Name `
             | Get-Member -Membertype NoteProperty `
             | Select-Object Definition `
             | Format-Table -AutoSize -Wrap `
             | Out-String -Stream `
             | Select-String string `
         )  -replace "string Name="

   # GPU名を取得
   $2InsID = ($2gpuNAME -split '\\?\',0,'Simplematch' -split '#{')[1].Replace('#','\')
   $AGPUName = (Get-PnpDevice -InstanceId $2InsID).FriendlyName
}

# 取得した内容を表示
""
Write-Host (@"
$0VMName に
GPU : $2gpuNAME
（※$AGPUName）
を GPU-Partition として適用します
"@)
""


<# 3 #>
# Get-VMHostPartitionableGpuから割り当てられるGPUの総量を取得
$3gpuAvailableVRAM = Get-VMHostPartitionableGpu | Out-String -Stream | Select-String AvailableVRAM
$3gpuAvailableEncode = Get-VMHostPartitionableGpu | Out-String -Stream | Select-String AvailableEncode
$3gpuAvailableDecode = Get-VMHostPartitionableGpu | Out-String -Stream | Select-String AvailableDecode
$3gpuAvailableCompute = Get-VMHostPartitionableGpu | Out-String -Stream | Select-String AvailableCompute

# GPUの各総量を数値としてそれぞれ格納
$3gpuAvailableVRAMA = [int]($3gpuAvailableVRAM -replace "[a-zA-Z]" -replace '[" *"]' -replace ":")
$3gpuAvailableEncodeA = [decimal]($3gpuAvailableEncode -replace "[a-zA-Z]" -replace '[" *"]' -replace ":")
$3gpuAvailableDecodeA = [int]($3gpuAvailableDecode -replace "[a-zA-Z]" -replace '[" *"]' -replace ":")
$3gpuAvailableComputeA = [int]($3gpuAvailableCompute -replace "[a-zA-Z]" -replace '[" *"]' -replace ":")


<# 4 #>
# LOG の保存先ディレクトリを作成
$DIRpath=$SptDirPATH.TrimEnd('\') + "\LOG"
if ( -not ( Test-Path -Path "$DIRpath" )){ New-Item "$DIRpath" -ItemType Directory > $null }
Get-Date | Out-String -Stream | ?{$_ -ne ""} | Out-File "$DIRpath\GPU-P_log.txt" -Append -Force


<# 5 #>
# パーティション分割値を求める
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


# 計算結果を表示する
$5VRAMdisplay = [pscustomobject]([ordered]@{"------VRAM------" = ""; MIN = " $VRAMdivideMIN"; OPT = " $VRAMdivideOPT"; MAX = " $VRAMdivideMAX"; Available = " $3gpuAvailableVRAMA";})
$5ENCODEdisplay = [pscustomobject]([ordered]@{"-----Encode-----" = ""; MIN = " $ENCODEdivideMIN"; OPT = " $ENCODEdivideOPT"; MAX = " $ENCODEdivideMAX"; Available = " $3gpuAvailableEncodeA";})
$5DECODEdisplay = [pscustomobject]([ordered]@{"-----Decode-----" = ""; MIN = " $DECODEdivideMIN"; OPT = " $DECODEdivideOPT"; MAX = " $DECODEdivideMAX"; Available = " $3gpuAvailableDecodeA";})
$5COMPUTEdisplay = [pscustomobject]([ordered]@{"-----Compute----" = ""; MIN = " $COMPUTEdivideMIN"; OPT = " $COMPUTEdivideOPT"; MAX = " $COMPUTEdivideMAX"; Available = " $3gpuAvailableComputeA";})

""
Write-Host "# confimation"

Write-Output "VM  : $0VMName"  | Out-File "$DIRpath\GPU-P_log.txt" -Append
Write-Output "GPU : $GPUName" | Out-File "$DIRpath\GPU-P_log.txt" -Append
Write-Output "Instance ID A : $2InsID" | Out-File "$DIRpath\GPU-P_log.txt" -Append
Write-Output "Instance ID B : $2gpuNAME" | Out-File "$DIRpath\GPU-P_log.txt" -Append

$5VRAMdisplay | Out-String -Stream | ?{$_ -ne ""} | Tee-Object -FilePath "$DIRpath\GPU-P_log.txt" -Append
$5ENCODEdisplay | Out-String -Stream | ?{$_ -ne ""} | Tee-Object -FilePath "$DIRpath\GPU-P_log.txt" -Append
$5DECODEdisplay | Out-String -Stream | ?{$_ -ne ""} | Tee-Object -FilePath "$DIRpath\GPU-P_log.txt" -Append
$5COMPUTEdisplay | Out-String -Stream | ?{$_ -ne ""} | Tee-Object -FilePath "$DIRpath\GPU-P_log.txt" -Append

""
Write-Host "※ログの出力先は `"$DIRpath\GPU-P_log.txt`""

Write-Output "" | Out-File "$DIRpath\GPU-P_log.txt" -Append -Force
Write-Output "" | Out-File "$DIRpath\GPU-P_log.txt" -Append -Force


<# 6 #>
# 実行するか確認
$title = "【確認】"
$message = @"
上記の通りにGPUPartitionをセットします。
この操作を実行しますか?
"@

$tChoiceDescription = "System.Management.Automation.Host.ChoiceDescription"
$tOptions = @(
    New-Object $tChoiceDescription ("はい(&Yes)",     "この操作を実行し、次のステップへ進みます。")
    New-Object $tChoiceDescription ("いいえ(&No)",    "この操作をキャンセルし、中断します。")
)

$tResult = $host.ui.PromptForChoice($title, $message, $tOptions, 0)
switch ($tResult)
  {
    0 {"「はい」が選ばれました。"; break}
    1 {"「中断」が選ばれました。"; break}
  }

if ($tResult -ne 0) { exit }


<# 7 #>
# GPU-P.Adapterを追加する
If(!($Count -ge 2) -OR ($Result -eq $Num)) {
   # システムが指定
   Add-VMGpuPartitionAdapter -VMName "$0VMName"
}Else{
   # GPUを指定する場合
   Add-VMGpuPartitionAdapter -VMName "$0VMName" -InstancePath "$2gpuNAME"
}

# 追加したアダプターを設定する
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
# CPU Write-Combiningの有効化
Set-VM -GuestControlledCacheTypes $true -VMName "$0VMName"

# MMIO領域の構成
Set-VM -LowMemoryMappedIoSpace 1Gb -VMName "$0VMName"
Set-VM -HighMemoryMappedIoSpace 33280Mb -VMName "$0VMName"


<# 9 #>
# 確認（ = Get-VMGpuPartitionAdapter "$0VMName" -verbose ）
Get-VMGpuPartitionAdapter -VMName "$0VMName"

# 終了メッセージ
Write-Host "すべてのプロセスは終了しました"
####################################
###            FINISH            ###
####################################
  Write-Host "---Script Finish---"
  Write-Host "画面を閉じるには何かキーを押してください..."
  $host.UI.RawUI.ReadKey() | Out-Null
  EXIT
