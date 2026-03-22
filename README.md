# volt

Fast minimal HTTP client built in Odin

prev versions before 0.3.0 were in development testing.

**you're welcome for the uniform comments**
---

## install dependencies

### linux general

install a C toolchain and curl development libraries

### gentoo

```bash
sudo emerge dev-lang/odin net-misc/curl dev-libs/mbedtls
```

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

build odin from source on solus

```bash
git clone https://github.com/odin-lang/Odin.git
cd Odin
make release-native
```

set environment

```bash
export ODIN_ROOT="$PWD"
```

optional install

```bash
sudo cp odin /usr/local/bin/odin
```

---

## build

from project directory

```bash
odin build . -out:volt -extra-linker-flags:"-lcurl"
```

if linker errors happen

```bash
export ODIN_ROOT="/path/to/Odin"
```

on systems with multiple toolchains make sure system clang is used

```bash
which clang
```

should point to /usr/bin/clang

---

## usage

```bash
volt https://example.com
```

post json

```bash
volt -j -d '{"name":"volt"}' https://httpbin.org/post
```

pipe output

```bash
volt --clean https://example.com/script.sh | bash
```

save file

```bash
volt -O https://example.com/file
```

benchmark

```bash
volt --bench 50 https://example.com
```

parallel

```bash
volt -P 4 urls.txt
```

cookies

```bash
volt -c cookies.txt https://httpbin.org/cookies/set/test/value
volt -b cookies.txt https://httpbin.org/cookies
```

---

## notes

uses libcurl for networking

requires odin base core vendor folders available

if you see error about base not found set ODIN_ROOT

if build fails check curl and mbedtls dev packages

---

## status

working http client

features include

get post requests
json support
parallel requests
benchmarking
debug timing
cookies
file downloads

more features can be added later


## inspired by
[rfetch](https://github.com/Moritisimor/rfetch) by [Moritisimor](https://github.com/Moritisimor)

**This is** ***Volt*** by **[RobertFlexx](https://github.com/RobertFlexx)**
