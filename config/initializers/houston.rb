# if Rails.env.production?
# else
  APN = Houston::Client.development
  APN.passphrase = ENV['APN_CERTIFICATE_PASSPHRASE']
  APN.certificate = '-----BEGIN CERTIFICATE-----
MIIFfDCCBGSgAwIBAgIIRcz0ELdfRx0wDQYJKoZIhvcNAQEFBQAwgZYxCzAJBgNV
BAYTAlVTMRMwEQYDVQQKDApBcHBsZSBJbmMuMSwwKgYDVQQLDCNBcHBsZSBXb3Js
ZHdpZGUgRGV2ZWxvcGVyIFJlbGF0aW9uczFEMEIGA1UEAww7QXBwbGUgV29ybGR3
aWRlIERldmVsb3BlciBSZWxhdGlvbnMgQ2VydGlmaWNhdGlvbiBBdXRob3JpdHkw
HhcNMTQwNzE4MTIyMzMwWhcNMTUwNzE4MTIyMzMwWjB8MRwwGgYKCZImiZPyLGQB
AQwMY29tLndpc3IuaW9zMTowOAYDVQQDDDFBcHBsZSBEZXZlbG9wbWVudCBJT1Mg
UHVzaCBTZXJ2aWNlczogY29tLndpc3IuaW9zMRMwEQYDVQQLDApQSzVROUU3M0o3
MQswCQYDVQQGEwJVUzCCASIwDQYJKoZIhvcNAQEBBQADggEPADCCAQoCggEBAJo6
HdtEyKD13AcLNoByusGbCmi+lAV5vq1wui0clqgBrpYMQDU0W3lJCW/mrekBww27
rUMKi1TmuYfJGibaXkMJ4kZ5zvcLHWUI/XfyyNLKpxdF9V+/ilFD/StH1Rmo8jNL
4CRnKVMg2YBdqaY5/np12jnQGYTzCu6qHyivRA+957RAmyEKWwkrvcswyLBF3+mP
fIFXN+eWLn09wWWm6Tlo4Q4st3drt0eORu7VkF9vJRtUdXQjtnOAbUJ4Jfk6T1C2
wB4ubDVJWCOfnIWfrymDdZgW+omXQC9TZSioyNwMWJU1zwCrKtBmWJUJkCMJND70
XSsfmRwyRqmKvjPKzWcCAwEAAaOCAeUwggHhMB0GA1UdDgQWBBQ9JzFhZ/zNCmXc
ddWpbGaf/9+P4TAJBgNVHRMEAjAAMB8GA1UdIwQYMBaAFIgnFwmpthhgi+zruvZH
WcVSVKO3MIIBDwYDVR0gBIIBBjCCAQIwgf8GCSqGSIb3Y2QFATCB8TCBwwYIKwYB
BQUHAgIwgbYMgbNSZWxpYW5jZSBvbiB0aGlzIGNlcnRpZmljYXRlIGJ5IGFueSBw
YXJ0eSBhc3N1bWVzIGFjY2VwdGFuY2Ugb2YgdGhlIHRoZW4gYXBwbGljYWJsZSBz
dGFuZGFyZCB0ZXJtcyBhbmQgY29uZGl0aW9ucyBvZiB1c2UsIGNlcnRpZmljYXRl
IHBvbGljeSBhbmQgY2VydGlmaWNhdGlvbiBwcmFjdGljZSBzdGF0ZW1lbnRzLjAp
BggrBgEFBQcCARYdaHR0cDovL3d3dy5hcHBsZS5jb20vYXBwbGVjYS8wTQYDVR0f
BEYwRDBCoECgPoY8aHR0cDovL2RldmVsb3Blci5hcHBsZS5jb20vY2VydGlmaWNh
dGlvbmF1dGhvcml0eS93d2RyY2EuY3JsMAsGA1UdDwQEAwIHgDATBgNVHSUEDDAK
BggrBgEFBQcDAjAQBgoqhkiG92NkBgMBBAIFADANBgkqhkiG9w0BAQUFAAOCAQEA
SbwoXlZeF6ujmy5rX5JTtNBRw109EGjjIMznxaqV0/xUaUypQ45O5QFbgaEZN0MX
edqplLCMDX3bFacaEAop6Wt84zDR00yGqRSvyw8zKR8QEOvE8bV31RZ8UE7UJ3Ow
kAcrRGqUA7niPqsNzUULEsMgxaPUC+chI549FDQSVLhHHeBawaAfnjOn9FS2EH3c
v1qRun3bQdWwMmciWAxNEeh0y4DLaVN1ndBYgi9FcxR+x+HwVr/sMF93ZhJxM/6c
fwSD28O5jpe8XYbrit80NDE92G4hoYsFBULEh1SfU2MJF5egYYHupUvUGhaJHhep
n1SpRrGWfO/6NGXQdXBdHQ==
-----END CERTIFICATE-----
Bag Attributes
    friendlyName: WisrPush
    localKeyID: 3D 27 31 61 67 FC CD 0A 65 DC 75 D5 A9 6C 66 9F FF DF 8F E1
Key Attributes: <No Attributes>
-----BEGIN RSA PRIVATE KEY-----
Proc-Type: 4,ENCRYPTED
DEK-Info: DES-EDE3-CBC,E819B5F3B4F66D56

hHIBe0zewPZMKWAXb9sMF1cI3ZIC1wmcDQYgPJHnfFngO8ykSiszY0IjhNxdxnAG
7WOSx06clQB9XEkUlBgxwf/jG+bB/S1eGujZunaZpPcMCHlKiOuAOwdtxbTZhBe9
12VgrsCYeCXduaElALspXco3+BlYKlhKGDMZGx5JH0g5kbBZ9rDi2K48KFsUiiHm
Xl7gKfpztvg8BK8ZJaOAp+C7b8CfrojYD5JK5DdOr1NLxCwf/p4uvgIOygb4mn56
hlXDS+GR3YCSV1+ouB4+wtrrgH2sp0+H+ioOHIFubyBkHJApwtVJ7YSi0U3ngmwV
w1oSbIBmdFqwbmjrDpM2bIve/xm7WEOdgHqdidpNAcWhZNZ9l2Phy3fJxduQf48l
PvdFGQ5++G5dTxhwuq9MSrZ/QbxIakFIjSStSFZVrWpj57hIeLYBtq1xo0GjxhT0
ds75UEygzUOMMEYWzl52et/L+ZADoAj/bHDSHqrjHfBLEU1UgGUHvW9Uumayv0/s
aolWbseyT+wKqjN2Se90B7tt9d6uUJJ8eE/miIGJbAoWGB3qLdR3TE0oWL4nqEEH
fEOQIF5zJQbTpKUgFeiupPD+MsxpV/Nk8nz3BsXSaUrLfSkLb+ipQAxQvfXpPl2W
sPjFMUn6jfPGOSE5rkLdNM1b5p3duzyPQzsX4WalQKrJ9V3Nc4/XaDe6ocKpBDRh
h9NAaMGCYIP9SLPwfn13ij81UEOMij0UE5m+q1fnPkq7bJmCR+SXPECACeSFNGQL
DxFBPZrjXduoJjZUqZlW6UIhcSXq47cj4mnCmx+UV2lJtcmF9oWBeq/nSfYIEbVf
z4SWE7loCXn+iMqJUKmqwz6Llf0tpP89dhHsfxnWFao1C7YH8BXWXkdx2er8Lqxn
eLXp8vKf+BJPCHut8wFK6H7jLe53KJoBqAWqmwpB1ggmcWJczZatycb2LBp7P2r3
1ryZMZfwNcbMEhgxRpiS/zOZOIO7ksG0j/GfDUwnS/5ODQLbceMrSp2Mq5JAsyPC
XbvViSwJcDw/vRhBGEuyRjlQxiIoM8jvDkRJBNFk40XZvCRD9ys7FTW0YMpqoaI3
CF6Fw8CGeUBsoRKezFkZe+EYDStwjk+yVlzxDBHzXjCTPj/jZA1M/DHou6eBKI8x
WZfYHX9zXrkabu6LbSCjO5cwmQLudADx/6zWRSIjCWlXlVa0XDTHA/r7K12unUNW
dXlDVndpiM+tYpSy/agqwCNuJHdXK9UEhUJ4DI8iP3clrPu9/FUMGf2R+piSrBot
A924ZHRCOCXVUHvFs+g4sceygMlNGmC95JGMlw2TbdDS144+sBSNCSVIfZLUzFrh
HcH/4wJepPbRK2ZASFX4pwziUOFxrLj9TorBydHGnUzeWObaJCEdnWnKw5WZY/0+
k9DJ2Bpry1clSmMD8dp+WU6mnFdQIF9bdKR77kZjleHBZm82rb9S2tmdercsw6Ap
EbUaV5kv9+Bwy234tkewn/1VkHxl6bZL5kG3nsFihotGYpIo0P2v5yYPPg06tXb8
aIpQrQhA+2NSYfS5QPU5ECk5/wVEZ6ZrWWD1Rt+a+a8mtU6W9hdpebnaWSIBSwwE
-----END RSA PRIVATE KEY-----'
# end