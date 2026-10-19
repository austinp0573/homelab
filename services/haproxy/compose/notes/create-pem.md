# create an haproxy valid .pem

```bash
(cat example.com.crt; echo; cat example.com.issuer.crt; echo; cat example.com.key) > example.com.pem
```

In order to use SSL certificates with HAProxy you must concatenate all the related certificate files into one single .pem file.
The order is important:

The Certificate for your domain
The intermediates in ascending order to the Root CA
A Root CA, if any (usually none)
Private Key
So for example if you have:

Your certificate: certificate.crt
Your CA certificates (intermediates): certificate-ca.crt
Your key: certificate.key
you would need to concatenate:

 cat certificate.crt certificate-ca.crt certificate.key > certificate.pem
Keep in mind: sometimes when you concatenate the files the end and begin blocks of two certificates get merged together in one single line.
