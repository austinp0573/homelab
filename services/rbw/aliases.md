```bash
enc() {
    # 1. Input Validation
    if [ "$#" -ne 1 ]; then
        echo "Error: Exactly one file argument is required." >&2
        echo "Usage: enc <filename>" >&2
        return 1
    fi

    local infile="$1"

    if [ ! -f "$infile" ]; then
        echo "Error: '$infile' is not a valid file or does not exist." >&2
        return 1
    fi

    local outfile="${infile}.age"

    if [ -e "$outfile" ]; then
        echo "Error: Target output file '$outfile' already exists. Aborting to prevent overwrite." >&2
        return 1
    fi

    # 2. Key Acquisition & Validation
    local pubkey
    pubkey=$(rbw get crypt_pu 2>/dev/null)
    if [ -z "$pubkey" ]; then
        echo "Error: Failed to retrieve 'crypt_pu' from rbw. Is your vault locked?" >&2
        return 1
    fi

    # 3. Execution & Destructive Cleanup
    echo "Encrypting '$infile'..."
    if age -r "$pubkey" -o "$outfile" "$infile"; then
        echo "Encryption successful. Shredding original file..."
        shred -u -z -n 3 "$infile"
        echo "Done: '$infile' has been securely destroyed. Result: '$outfile'"
    else
        echo "Critical Error: Encryption failed. Original file preserved." >&2
        return 1
    fi
}

dec() {
    # 1. Input Validation
    if [ "$#" -ne 1 ]; then
        echo "Error: Exactly one file argument is required." >&2
        echo "Usage: dec <filename.age>" >&2
        return 1
    fi

    local infile="$1"

    if [ ! -f "$infile" ]; then
        echo "Error: '$infile' does not exist." >&2
        return 1
    fi

    if [[ "$infile" != *.age ]]; then
        echo "Error: Target file '$infile' must carry a '.age' extension." >&2
        return 1
    fi

    local outfile="${infile%.age}"

    if [ -e "$outfile" ]; then
        echo "Error: Decrypted target file '$outfile' already exists. Aborting." >&2
        return 1
    fi

    # 2. Execution & Destructive Cleanup
    echo "Decrypting '$infile'..."
    if age -d -i <(rbw get crypt_pr 2>/dev/null) -o "$outfile" "$infile"; then
        echo "Decryption successful. Shredding encrypted file..."
        shred -u -z -n 3 "$infile"
        echo "Done: '$infile' has been securely destroyed. Result: '$outfile'"
    else
        echo "Critical Error: Decryption failed. Encrypted file preserved." >&2
        return 1
    fi
}
```