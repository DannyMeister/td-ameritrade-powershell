function New-UserId {
    [System.Guid]::NewGuid() | %{$_ -replace "-",""} | %{ $_.Substring(0,12) }
}