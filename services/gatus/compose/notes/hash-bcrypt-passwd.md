# bcrypt password hash creation for gatus security

```bash
htpasswd -bnBC 10 "" yourpassword | tr -d ':\n' | sed 's/^\$2y/\$2a/'
``` 

**or**

```bash
pip install bcrypt
python3 -c "import bcrypt; print(bcrypt.hashpw(b'yourpassword', bcrypt.gensalt()).decode())"
```

**set cost with:**

```bash
python3 -c "import bcrypt; print(bcrypt.hashpw(b'yourpassword', bcrypt.gensalt(rounds=12)).decode())"
```


**convert to base64 with:**

```bash
echo -n "bcrypt_hashhhhhhhhhhhhhhhhhhhhhhhhhhhhhhh" | base64 -w 0
```

