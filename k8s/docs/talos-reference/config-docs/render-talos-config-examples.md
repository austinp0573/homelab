A fresh clone contains the reference pages, but **does not contain a complete website setup**. The YAML examples are embedded in Markdown that uses Hugo formatting. To browse them, install Hugo, supply a minimal HTML layout, and start its local server.

Run this complete procedure.

1. Install the tools and clone the repository:

   ```bash
   sudo apt update
   sudo apt install git hugo

   git clone --depth 1 https://github.com/siderolabs/talos.git
   cd talos
   ```

2. Create a minimal local website configuration:

   ```bash
   mkdir -p _out/reference/layouts/_default

   cat > _out/reference/hugo.toml <<'EOF'
   baseURL = 'http://127.0.0.1:1313/'
   title = 'Talos configuration reference'
   refLinksErrorLevel = 'WARNING'

   [markup.goldmark.renderer]
   unsafe = true
   EOF
   ```

   `unsafe = true` enables the HTML already present in the reference, including expandable examples. The warning setting allows links to guides that are absent from this repository.

3. Create the HTML layout used to display each page and list the available references:

   ```bash
   cat > _out/reference/layouts/_default/single.html <<'EOF'
   <!doctype html>
   <html lang="en">
   <head>
     <meta charset="utf-8">
     <meta name="viewport" content="width=device-width, initial-scale=1">
     <title>{{ .Title }}</title>
     <style>
       body { font: 16px/1.5 sans-serif; margin: 2rem; }
       table { border-collapse: collapse; width: 100%; }
       th, td { border: 1px solid #bbb; padding: .5rem; text-align: left; vertical-align: top; }
       pre { overflow: auto; padding: 1rem; background: #eee; }
       summary { cursor: pointer; }
     </style>
   </head>
   <body>
     <a href="/">All references</a>
     <h1>{{ .Title }}</h1>
     {{ .TableOfContents }}
     {{ .Content }}
     {{ if not .IsPage }}
       <ul>
       {{ range .Site.RegularPages.ByTitle }}
         <li><a href="{{ .RelPermalink }}">{{ .Title }}</a></li>
       {{ end }}
       </ul>
     {{ end }}
   </body>
   </html>
   EOF

   cp _out/reference/layouts/_default/single.html \
      _out/reference/layouts/_default/list.html
   ```

4. Start the renderer from the repository root:

   ```bash
   hugo server \
       --source "$PWD/_out/reference" \
       --contentDir "$PWD/website/content" \
       --bind 127.0.0.1 \
       --port 1313 \
       --renderToDisk
   ```

   Open **http://127.0.0.1:1313/**. Select a configuration type to see its rendered YAML examples and field documentation.

Hugo reads the existing pages under `website/content/`, processes their formatting, and inserts the resulting HTML into the layout you created. `--renderToDisk` also saves the generated site under `_out/reference/public/`.

You do **not** need `make docs`, Go, or a Talos build. The reference content is already in the clone. After this initial setup, repeat only step 4 to browse it again. Everything works offline once the tools and repository are downloaded.
