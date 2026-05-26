# volt

Fast minimal HTTP client built in Odin.

It started as a small http client and then got out of hand kinda

Versions before `0.3.0` were mostly development testing. `0.4.0` is where the built in HTTP server became real instead of just sitting there for no reason

---

## install dependencies

### linux general

Install a C toolchain, Odin, and curl development libraries.

You need libcurl available at build and runtime.

### gentoo / exherbo-ish

For Gentoo:

```bash
sudo emerge dev-lang/odin net-misc/curl dev-libs/mbedtls
```

For Exherbo, install Odin and curl through your cave. Exact package names may differ depending on your repositories. Sorry for the lack of info here, carry on (i recommend brew for odin on exherbo)

### arch

```bash
sudo pacman -S base-devel clang curl mbedtls
```

### debian ubuntu

```bash
sudo apt install build-essential clang libcurl4-openssl-dev libmbedtls-dev
```

### fedora

```bash
sudo dnf install clang gcc make libcurl-devel mbedtls-devel
```

### solus

```bash
sudo eopkg it -c system.devel curl-devel mbedtls-devel llvm-clang-devel
```

Build Odin from source on Solus if the packaged version is missing or too old.

```bash
git clone https://github.com/odin-lang/Odin.git
cd Odin
make release-native
```

Set environment if needed.

```bash
export ODIN_ROOT="$PWD"
```

Optional install.

```bash
sudo cp odin /usr/local/bin/odin
```

---

## build

From the project directory:

```bash
odin build volt.odin -file -out:volt -extra-linker-flags:"-lcurl"
```

Or if building as a package/directory:

```bash
odin build . -out:volt -extra-linker-flags:"-lcurl"
```

On some weird systems with custom dynamic linker paths, you may need something like:

```bash
odin build volt.odin -file -out:volt -extra-linker-flags:"-Wl,--dynamic-linker=/usr/x86_64-pc-linux-gnu/lib64/ld-linux-x86-64.so.2"
```

If Odin cannot find `base`, `core`, or `vendor`, set `ODIN_ROOT`.

```bash
export ODIN_ROOT="/path/to/Odin"
```

If the linker complains about curl, make sure the curl development package is installed.

If the compiler picks a weird clang, check:

```bash
which clang
```

Usually you want the system one.

---

## usage

Basic GET:

```bash
volt https://example.com
```

HEAD request:

```bash
volt -I https://example.com
```

POST JSON:

```bash
volt -j -d '{"name":"volt"}' https://httpbin.org/post
```

Send a file as the request body:

```bash
volt -X PUT -d @file.bin https://example.com/upload
```

Read request body from stdin:

```bash
cat data.json | volt -j -d @- https://httpbin.org/post
```

Clean output for scripts:

```bash
volt --clean https://example.com/file.txt > file.txt
```

If you pipe internet scripts into a shell, that is between you and whatever demon lives in `/bin/sh`.

Save with remote filename:

```bash
volt -O https://example.com/file.tar.xz
```

Save to a specific file:

```bash
volt -o output.bin https://example.com/file.bin
```

Resume a download:

```bash
volt -O -C https://example.com/file.tar.xz
```

Include response headers:

```bash
volt -i https://example.com
```

Dump headers to a file:

```bash
volt -D headers.txt https://example.com
```

Pretty-print JSON:

```bash
volt --json-pretty https://httpbin.org/json
```

Debug timing:

```bash
volt --debug https://example.com
```

Fail on HTTP errors:

```bash
volt -f https://httpbin.org/status/404
```

Cookies:

```bash
volt -c cookies.txt https://httpbin.org/cookies/set/test/value
volt -b cookies.txt https://httpbin.org/cookies
```

Benchmark:

```bash
volt --bench 50 https://example.com
```

Batch requests from a file:

```bash
volt --batch urls.txt -P 8
```

`urls.txt` can look like this:

```text
https://example.com
https://httpbin.org/get
https://kernel.org
```

Blank lines and lines starting with `#` are ignored.

---

## server mode

`--serve` is real now.

Start a local static file server:

```bash
volt --serve 8080 --serve-dir .
```

Serve on all interfaces:

```bash
volt --serve 8080 --serve-dir public --bind 0.0.0.0
```

Use another port if `8080` is already busy:

```bash
volt --serve 9090 --serve-dir .
```

Health check:

```bash
volt http://127.0.0.1:8080/__volt/health --json-pretty
```

Directory manifest:

```bash
volt http://127.0.0.1:8080/__volt/manifest --json-pretty
```

Echo endpoint:

```bash
volt http://127.0.0.1:8080/__volt/echo --json-pretty
```

SPA fallback:

```bash
volt --serve 8080 --serve-dir . --spa
```

If `index.html` exists, missing paths fall back to it.

```bash
volt http://127.0.0.1:8080/some/fake/path
```

Disable generated directory listings:

```bash
volt --serve 8080 --serve-dir . --no-dir-list
```

Allow uploads:

```bash
volt --serve 8080 --serve-dir . --allow-upload --upload-dir drops
```

Upload a file:

```bash
volt -X PUT -d @test.txt http://127.0.0.1:8080/__volt/upload/test.txt --json-pretty
```

Then check it:

```bash
cat drops/test.txt
```

Change max request size:

```bash
volt --serve 8080 --max-request 67108864
```

That example allows requests up to 64 MB.

---

## server notes

The server is meant for local development, quick file sharing, test uploads, and poking HTTP clients.

It is not trying to be nginx.

Be careful with:

```bash
volt --serve 8080 --serve-dir . --bind 0.0.0.0
```

That exposes the served directory to your network.

If your project has `.git`, secrets, build artifacts, or random cursed files, do not serve the whole repo on a public or untrusted network.

Upload mode is off by default for a reason.

---

## features

Client side:

* GET, POST, PUT, PATCH, DELETE, HEAD, and custom methods
* request bodies from strings, files, or stdin
* custom headers
* JSON mode
* pretty JSON output
* response headers in output
* dump headers to file
* file downloads
* remote filename saving
* resume downloads
* cookies
* redirects
* no-redirect mode
* timeout and connect timeout
* retry support
* rate limiting
* fail-on-HTTP-error mode
* benchmark mode
* real parallel batch mode through libcurl multi
* debug timing breakdown

Server side:

* static file serving
* generated directory listings
* optional directory listing disable
* SPA fallback to `index.html`
* health endpoint
* manifest endpoint
* echo endpoint
* upload endpoint
* configurable bind address
* configurable max request size

---

## notes

Uses libcurl for the client side networking.

Uses Odin `core:net` for the built-in server.

Requires Odin base/core/vendor folders to be available.

If you see errors about `base` or `core` not being found, set `ODIN_ROOT`.

If build fails, check curl development libraries first. It is almost always curl, linker flags, or the wrong compiler being picked.

---

## status

Working HTTP client.

Working tiny HTTP server.

Not pretending to replace curl.

Not pretending to replace nginx.

Just a fast little Odin network tool that does useful stuff without acting like a whole cloud platform.

More features can be added later if they actually earn their keep.

---

## inspired by

[rfetch](https://github.com/Moritisimor/rfetch) by [Moritisimor](https://github.com/Moritisimor)

**This is** ***Volt*** by **[RobertFlexx](https://github.com/RobertFlexx)**
