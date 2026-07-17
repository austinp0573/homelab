#!/bin/sh

# 1. Update repositories and install nginx
apk update
apk add nginx

# 2. Create the web root directory
mkdir -p /var/www/cat-eyes

# 3. Create the responsive HTML/SVG file
cat << 'EOF' > /var/www/cat-eyes/index.html
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Rex</title>
    <style>
        body, html {
            margin: 0;
            padding: 0;
            width: 100%;
            height: 100%;
            background-color: black;
            display: flex;
            justify-content: center;
            align-items: center;
            overflow: hidden;
        }
        .container {
            width: 80%;
            max-width: 600px;
        }
        svg {
            width: 100%;
            height: auto;
        }
    </style>
</head>
<body>
    <div class="container">
        <!-- SVG: Two Cat's Eyes -->
        <svg viewBox="0 0 200 100" xmlns="http://www.w3.org/2000/svg">
            <!-- Left Eye -->
            <ellipse cx="60" cy="50" rx="30" ry="15" fill="yellow" />
            <rect x="58" y="40" width="4" height="20" fill="black" rx="2" />
            <!-- Right Eye -->
            <ellipse cx="140" cy="50" rx="30" ry="15" fill="yellow" />
            <rect x="138" y="40" width="4" height="20" fill="black" rx="2" />
        </svg>
    </div>
</body>
</html>
EOF

# 4. Configure Nginx for minimal resource usage
cat << 'EOF' > /etc/nginx/http.d/default.conf
server {
    listen 80;
    server_name _;

    root /var/www/cat-eyes;
    index index.html;

    location / {
        try_files $uri $uri/ =404;
    }

    # Disable access logs to save disk I/O
    access_log off;
    error_log /var/log/nginx/error.log crit;
}
EOF

# 5. Fix permissions
chown -R nginx:nginx /var/www/cat-eyes

# 6. Enable and start Nginx
rc-update add nginx default
rc-service nginx start