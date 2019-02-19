# td-ameritrade-powershell

Powershell functions to help interact with TD Ameritrade's API.

## Prerequisites

An account at TD Ameritrade.

A developers account at TD Ameritrade. (Free for brokerage account holders)

These functions have only been tested on Windows 10 with Powershell 5.1.

## How to use

From a PowerShell prompt, dot source the file and then you can begin calling functions within it.

```powershell
. .\ameritrade.ps1
```

## Features

* New-UserId: Return a new OAuth User Id for use when creating a new app on the TD Ameritrade developer website.

```powershell
PS> . .\ameritrade.ps1
PS> New-UserId
94a127206dd9
```