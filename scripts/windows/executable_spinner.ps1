$spinnerFrames = "⠋", "⠙", "⠸", "⠴", "⠦", "⠧", "⠇", "⠏"
$processList = @("notepad", "calc")  # Replace with your own process names
Read-Host -Prompt "Press Enter to exit"

foreach ($item in $processList) {
    $status = "[ ] $item"
    Write-Host "`r$status" -NoNewline

    $i = 0
    while (Get-Process -Name $item -ErrorAction SilentlyContinue) {
        $spinner = $spinnerFrames[$i % $spinnerFrames.Length]
        $status = "[$spinner] $item"
        Write-Host "`r$status" -NoNewline
        Start-Sleep -Seconds 3
        $i++
    }

    Write-Host "`r[✔] $item"  # Replace spinner with checkmark
	Read-Host -Prompt "Press Enter to exit"
}
