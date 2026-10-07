Add-Type -AssemblyName System.Windows.Forms
Set-Location -LiteralPath $PSScriptRoot
$d = New-Object System.Windows.Forms.SaveFileDialog
$d.Filter = 'Recipe files (*.txt)|*.txt|All files (*.*)|*.*'
$d.Title = 'Save recipe'
$d.InitialDirectory = $PSScriptRoot
$d.FileName = 'Prism Powder.txt'
$d.OverwritePrompt = $true
$d.AddExtension = $true
$d.DefaultExt = 'txt'
$out = Join-Path $PSScriptRoot 'save.result'
if ($d.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
  Set-Content -Path $out -Value $d.FileName
} else { Set-Content -Path $out -Value '' }
