function Get-WordOfTheDay {
    $uri = "https://random-word-api.herokuapp.com/word"
    $word = Invoke-RestMethod -Method Get -Uri $uri

    Write-Host -Object "The word of the day is: " -ForegroundColor Cyan -NoNewline
    Write-Host -Object $word -ForegroundColor Yellow
}
