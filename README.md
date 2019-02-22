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

### Register an app

Return a new OAuth User Id for use when creating a new app on the TD Ameritrade developer website.  You can skip this step and use an existing user id if you have already

```powershell
New-TdUserId
```

> A265B038D9C0

Register an app with the following values

* Application name: anything you want
* Description: anything you want
* User Id: use the response from `New-TdUserId`.  For example, `A265B038D9C0`
* Redirect URL: `https://localhost:8080/` (I will make this configurable in the future.)

### Login

```powershell
$response = New-TdAuthorizationToken -RedirectUrl "https://localhost:8080/" -ClientId "A265B038D9C0"
```

The script will pop open a browser to the TD Ameritrade login page.  Log in with your brokerage account credentials.

After successful login, the page will redirect to https://localhost:8080 which is being temporarily hosted by the PowerShell command. It will gather the authorization code and make the necessary subsequent request to retrieve the access token and refresh token. The tokens you need to interact with the API are available on the page, and returned in the response to PowerShell.

![redirect page screenshot](/docs/redirect.png)

```powershell
$accessToken = $response.access_token
$refreshToken = $response.refresh_token
```

You may want to save these tokens somewhere easily accessible in the future for your program/automated scripts to use without requiring user interactivity.  Perhaps to an encrypted file via `ConvertFrom-SecureString` and `Set-Content`.

### Call TD Ameritrade API

```powershell
# query Walmart (WMT) stock quote
$apiResponse = Invoke-WebRequest "https://api.tdameritrade.com/v1/marketdata/WMT/quotes" -Headers @{Authorization="Bearer $accessToken"}

# format the info
$apiResponse.Content | ConvertFrom-Json | select -expand WMT
```

![Walmart stock quote response screenshot](/docs/WMT.png)

<sub>Data blurred because the developer agreement says not to share data retrieved by API.</sub>

### Get new access token via refresh token

When the access token expires, you can fetch a new one via the refresh token without having to log in again.

You can look for the following response to any API call to determine your token is expired:

> { "error":"The access token being passed has expired or is invalid." }

Fetch a new access_token with a previously saved refresh token:

```powershell
$response = New-TdAuthorizationToken -RefreshToken $refreshToken -ClientId "A265B038D9C0"
$accessToken = $response.access_token
```

Now your access token is reset and you are ready to make more API calls.