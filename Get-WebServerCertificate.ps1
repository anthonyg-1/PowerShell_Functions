function Get-WebServerCertificate([string]$TargetHost, [int]$Port = 443, [int]$Timeout = 30) {
    [bool]$opensslFound = $null -ne (Get-Command -CommandType Application -Name "openssl" -ErrorAction SilentlyContinue)

    $cryptographicExceptionMessage = "Unable to establish TLS session with the following host: {0}." -f $TargetHost
    $CryptographicException = [System.Security.Cryptography.CryptographicException]::new($cryptographicExceptionMessage)

    if ($opensslFound) {
        # Build target host and part for connect argument for openssl:
        $targetHostAndPort = "{0}:{1}" -f $TargetHost, $Port

        try {
            # Get the cert:
            $openSslResult = "Q" | openssl s_client -connect $targetHostAndPort 2>$null

            # Parse the relevant base64 cert resulting from openssl:
            $beginString = "BEGIN CERTIFICATE"
            $endString = "END CERTIFICATE"
            $base64CertString = (($openSslResult -join "").Split($beginString)[1].Split($endString)[0]).Replace("-", "")

            # Convert the base64 string to a byte array to be fed to the X509Certificate2 constructor:
            [byte[]]$certBytes = [System.Convert]::FromBase64String($base64CertString)

            # Instantiate the certificate from the deserialized byte array:
            $tlsCert = [System.Security.Cryptography.X509Certificates.X509Certificate2]::new($certBytes)

            # return the TLS cert:
            return $tlsCert
        }
        catch {
            throw $CryptographicException
        }
    }
    else {
        $getCertScriptBlock = {
            [System.Net.Sockets.TcpClient]$tcpClient = $null
            [System.Net.Security.SslStream]$sslStream = $null
            [System.Security.Cryptography.X509Certificates.X509Certificate2]$sslCert = $null

            try {
                $tcpClient = [System.Net.Sockets.TcpClient]::new($using:TargetHost, $using:Port)
                $callback = { param($certSender, $cert, $chain, $errors) return $true }
                $sslStream = [System.Net.Security.SslStream]::new($tcpClient.GetStream(), $false, $callback)

                $sslStream.AuthenticateAsClient($using:TargetHost)

                $sslCert = [System.Security.Cryptography.X509Certificates.X509Certificate2]::new($sslStream.RemoteCertificate)

                if ($null -ne $sslStream) {
                    $sslStream.Close()
                    $sslStream.Dispose()
                }

                if ($null -ne $tcpClient) {
                    $tcpClient.Close()
                    $tcpClient.Dispose()
                }

                Write-Output -InputObject $sslCert
            }
            catch {
                throw $CryptographicException
            }
        }

        $getCertJobResult = $null
        try {
            $certRetrievalJob = Start-Job -ScriptBlock $getCertScriptBlock

            Wait-Job -Job $certRetrievalJob -Timeout $Timeout | Out-Null

            if ((Get-Job -Id $certRetrievalJob.Id).State -ne "Failed") {
                $getCertJobResult = Receive-Job -Job $certRetrievalJob
            }

            Remove-Job -Job $certRetrievalJob -Force
        }
        finally {
            Get-Job | Where-Object -Property State -eq "Failed" | Remove-Job -Force | Out-Null
        }

        if ($null -ne $getCertJobResult) {
            return $getCertJobResult
        }
        else {
            throw $CryptographicException
        }
    }
}
