function New-TdUserId {
    [System.Guid]::NewGuid() | %{$_ -replace "-",""} | %{ $_.Substring(0,12).ToUpper() }
}

function New-TdAuthorizationToken {
    Param(
        # Redirect URL for the app
        [Parameter(Mandatory=$false)]
        [string]
        $RedirectUrl,
        
        # OAuth client id for the app
        [Parameter(Mandatory=$true)]
        [string]
        $ClientId,

        #Refresh token which will be used to retrieve a new access token instead of logging in
        [Parameter(Mandatory=$false)]
        [string]
        $RefreshToken
    )

    Add-Type -AssemblyName System.Web

    $tokenUrl = "https://api.tdameritrade.com/v1/oauth2/token"

    if (-Not ($PSBoundParameters.ContainsKey('RefreshToken'))){

        if (-Not ($PSBoundParameters.ContainsKey('RedirectUrl'))){
            throw "Must provide either -RefreshToken or -RedirectUrl"
        }

        $Parameters = @{
            response_type = 'code'
            redirect_uri = $RedirectUrl
            client_id = "$ClientId@AMER.OAUTHAP"
        }

        $query = ($Parameters.Keys | %{ "$($_)=$([System.Uri]::EscapeDataString($Parameters[$_]))"}) -join "&"


        # Root CA
        $rootCert = New-SelfSignedCertificate -CertStoreLocation cert:\CurrentUser\My -DnsName "RootCA" -keyusage CertSign,CRLSign -TextExtension @("2.5.29.37={text}1.3.6.1.5.5.7.3.2,1.3.6.1.5.5.7.3.1,1.3.6.1.5.5.7.3.4,1.3.6.1.5.5.7.3.3,1.3.6.1.5.5.7.3.8,1.3.6.1.5.5.7.3.1","2.5.29.19={critical}{text}ca=TRUE")
        [System.Security.SecureString]$rootcertPassword = ConvertTo-SecureString -String "password" -Force -AsPlainText
        [String]$rootCertPath = Join-Path -Path 'cert:\CurrentUser\My\' -ChildPath "$($rootcert.Thumbprint)"
        Export-PfxCertificate -Cert $rootCertPath -FilePath 'RootCA.pfx' -Password $rootcertPassword | Out-Null
        Export-Certificate -Cert $rootCertPath -FilePath 'RootCA.crt' | Out-Null
        # ssl cert
        $testCert = New-SelfSignedCertificate -CertStoreLocation Cert:\LocalMachine\My -DnsName "localhost" -KeyExportPolicy Exportable -KeyLength 2048 -KeyUsage DigitalSignature,KeyEncipherment -textextension @("2.5.29.37={text}1.3.6.1.5.5.7.3.1") -Signer $rootCert
        [String]$testCertPath = Join-Path -Path 'cert:\LocalMachine\My\' -ChildPath "$($testCert.Thumbprint)"
        # import CA into trusted root
        Import-PfxCertificate -FilePath "$PWD\RootCA.pfx" -CertStoreLocation Cert:\LocalMachine\Root -Confirm:$false -Password $rootcertPassword | Out-Null

        # remove CA from My
        Remove-Item -Force "cert:\CurrentUser\My\$($rootCert.Thumbprint)" | Out-Null

        $appid = [System.Guid]::NewGuid().Guid
        $hash = $testCert.Thumbprint
        netsh http delete sslcert hostnameport=localhost:8080 | Out-Null
        netsh http add sslcert hostnameport=localhost:8080 certhash=$hash appid=`{$appid`} certstorename=my | Out-Null

        $listener = New-Object -TypeName System.Net.HttpListener
        $listener.Prefixes.Add("https://localhost:8080/")
        $listener.Start()

        Write-Host "Launching browser.  Please log in to TD Ameritrade with your brokerage account credentials."
        start "https://auth.tdameritrade.com/auth?$query"

        $task = $listener.GetContextAsync();
        while( -not $context )
        {
            if( $task.Wait(500) )
            {
                $context = $task.Result
            }
            sleep -Milliseconds 100;
        }
        $redirectRequestUrl = $context.Request.Url

        $content = [System.Text.Encoding]::UTF8.GetBytes("
        <!doctype html>
        <html lang='en'>
            <head>
                <meta charset=""utf-8"">
                <meta name=""viewport"" content=""width=device-width, initial-scale=1, shrink-to-fit=no"">
                <link rel=""stylesheet"" href=""https://stackpath.bootstrapcdn.com/bootstrap/4.3.1/css/bootstrap.min.css"" integrity=""sha384-ggOyR0iXCbMQv3Xipma34MD+dH/1fQ784/j6cY/iJTQUOhcWr7x9JvoRxT2MZw1T"" crossorigin=""anonymous"">
                <title>TD Ameritrade Login Redirect Landing Page</title>
            </head>
            <body>
                <div class=""container"">
                    <div class=""jumbotron container"">
                        <h1 class=""display-4"">TD Ameritrade API Login Redirect Page</h1>
                        <p class=""lead"">Served locally by temporary web host in PowerShell.</p>
                    </div>
                    <div class=""card mb-3"">
                        <h5 class=""card-header"">Recieved the following request from TD Ameritrade login</h5>
                        <div class=""card-body"">
                            <pre><code>$($redirectRequestUrl.AbsoluteUri)</code></pre>
                        </div>
                    </div>")
        $context.Response.ContentType = "text/html"
        $context.Response.OutputStream.Write($content, 0, $content.Length)


        $code = [System.Web.HttpUtility]::ParseQueryString($redirectRequestUrl.Query)['code']

        $tokenParameters = @{
            grant_type = 'authorization_code'
            access_type = 'offline'
            code = $code
            client_id = "$ClientId@AMER.OAUTHAP"
            redirect_uri = $RedirectUrl
        }

        $refreshTokenResponse = Invoke-WebRequest -ContentType "application/x-www-form-urlencoded" -UseBasicParsing -Uri $tokenUrl -Method Post -body $tokenParameters

        $outputValue = $refreshTokenResponse.Content | ConvertFrom-Json

        $content = [System.Text.Encoding]::UTF8.GetBytes("
                    <div class=""card mb-3"">
                        <h5 class=""card-header"">Retrieved access token and refresh token</h5>
                        <div class=""card-body"">
                            <p class=""card-text"">This content was also provided in the return value of the powershell function</p>
                            <pre><code>$($refreshTokenResponse.Content)</code></pre>
                        </div>
                    </div>
                    <div class=""card mb-3"">
                        <h5 class=""card-header"">Your current Authorization header for API requests</h5>
                        <div class=""card-body"">
                            <pre><code>Authorization : Bearer $($outputValue.access_token)</code></pre>
                        </div>
                    </div>
                </div>
                <script src=""https://code.jquery.com/jquery-3.3.1.slim.min.js"" integrity=""sha384-q8i/X+965DzO0rT7abK41JStQIAqVgRVzpbzo5smXKp4YfRvH+8abtTE1Pi6jizo"" crossorigin=""anonymous""></script>
                <script src=""https://cdnjs.cloudflare.com/ajax/libs/popper.js/1.14.7/umd/popper.min.js"" integrity=""sha384-UO2eT0CpHqdSJQ6hJty5KVphtPhzWj9WO1clHTMGa3JDZwrnQq4sF86dIHNDz0W1"" crossorigin=""anonymous""></script>
                <script src=""https://stackpath.bootstrapcdn.com/bootstrap/4.3.1/js/bootstrap.min.js"" integrity=""sha384-JjSmVgyd0p3pXB1rRibZUAYoIIy6OrQ6VrjIEaFf/nJGzIxFDsf4x0xIM+B07jRM"" crossorigin=""anonymous""></script>
            </body>
        </html>")

        $context.Response.OutputStream.Write($content, 0, $content.Length)
        $context.Response.OutputStream.Close()
        $context.Response.Close();
        sleep -Seconds 5

        $listener.Stop()
        $listener.Close()
        $listener.Dispose()
    }
    else {
        $tokenParameters = @{
            grant_type = 'refresh_token'
            refresh_token = $RefreshToken
            client_id = "$ClientId@AMER.OAUTHAP"
        }

        $refreshTokenResponse = Invoke-WebRequest -ContentType "application/x-www-form-urlencoded" -UseBasicParsing -Uri $tokenUrl -Method Post -body $tokenParameters
    }

    return $refreshTokenResponse.Content | ConvertFrom-Json
}
