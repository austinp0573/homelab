# How to import totp google authenticator -> yubikey (using yubico-authenticator)

Annoyingly the only way to export codes from **google authenticator** is via qr-code.

With **yubico-authenticator 7.4.0** importing codes can be done by dropping a file containing said qr-code onto the **yubico-authenticator** app.

### extract_otp_secrets method

https://github.com/scito/extract_otp_secrets

git the binary

check it with the sha256

example:

```bash
./extract --txt output_file.txt qr_code.png
```

- **NOTE:** After anything handling secrets like this, once the transfer is completed, ensure your system is completely purged of secrets

```bash
shred -v -n 3 -z -u filename.txt
```