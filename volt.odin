// my first intermediate odin project :)


package main

import "core:c"
import "core:fmt"
import "core:os"
import "base:runtime"
import "core:strconv"
import "core:strings"
import "core:time"
import "core:math"

import curl "vendor:curl"

APP_NAME :: "volt"
APP_VERSION :: "0.3.0"
DEFAULT_UA :: APP_NAME + "/" + APP_VERSION
DEFAULT_MAX_REDIRECTS :: 50

// ─────────────────────────────────────────────────────────────
// ANSI styling
// ─────────────────────────────────────────────────────────────
ANSI_RESET   :: "\x1b[0m"
ANSI_BOLD    :: "\x1b[1m"
ANSI_DIM     :: "\x1b[2m"
ANSI_ITALIC  :: "\x1b[3m"
ANSI_GREEN   :: "\x1b[32m"
ANSI_YELLOW  :: "\x1b[33m"
ANSI_RED     :: "\x1b[31m"
ANSI_CYAN    :: "\x1b[36m"
ANSI_BLUE    :: "\x1b[34m"
ANSI_MAGENTA :: "\x1b[35m"
ANSI_WHITE   :: "\x1b[37m"
ANSI_CLEAR_LINE :: "\x1b[2K\r"

SYM_OK    :: "✓"
SYM_FAIL  :: "✖"
SYM_ARROW :: "→"
SYM_DOWN  :: "↓"

// ─────────────────────────────────────────────────────────────
// Configuration
// ─────────────────────────────────────────────────────────────
Config :: struct {
    url:              string,
    method:           string,
    data:             string,
    output_path:      string,
    remote_name:      bool,
    headers:          [dynamic]string,
    include_headers:  bool,
    follow_redirects: bool,
    insecure:         bool,
    fail_http:        bool,
    json_mode:        bool,
    silent:           bool,
    show_error:       bool,
    verbose:          bool,
    raw:              bool,
    head_request:     bool,
    timeout_seconds:  int,
    user_agent:       string,
    progress:         bool,
    continue_dl:      bool,
    max_redirects:    int,
    // New features
    clean:            bool,
    bench_count:      int,
    parallel:         int,
    debug:            bool,
    cookie_jar:       string,
    cookie_file:      string,
    rate_limit:       int,
    json_pretty:      bool,
    serve_port:       int,
}

Payload :: struct {
    text:       string,
    bytes:      []u8,
    owns_bytes: bool,
}

Write_Target :: struct {
    buf:            [dynamic]u8,
    file:           ^os.File,
    total_written:  i64,
    use_file:       bool,
}

Progress_Data :: struct {
    show:           bool,
    start_time:     time.Time,
    last_update:    time.Time,
    total_size:     i64,
    downloaded:     i64,
}

// ─────────────────────────────────────────────────────────────
// Usage & Version
// ─────────────────────────────────────────────────────────────
usage :: proc() {
    fmt.printf("%s%s%s %s— fast, minimal HTTP client%s\n\n", 
        ANSI_BOLD, ANSI_CYAN, APP_NAME, ANSI_RESET, ANSI_RESET)
    
    fmt.printf("%sUSAGE%s\n", ANSI_BOLD, ANSI_RESET)
    fmt.printf("    %s [options] <url>\n", APP_NAME)
    fmt.printf("    %s [options] --parallel <n> <file>\n\n", APP_NAME)
    
    fmt.printf("%sOPTIONS%s\n", ANSI_BOLD, ANSI_RESET)
    fmt.printf("    %s-X, --request%s <method>   HTTP method (GET, POST, PUT, DELETE, PATCH, HEAD)\n", ANSI_GREEN, ANSI_RESET)
    fmt.printf("    %s-d, --data%s <data>        Request body (use @file or @- for stdin)\n", ANSI_GREEN, ANSI_RESET)
    fmt.printf("    %s-H, --header%s <header>    Add header (repeatable): \"Key: Value\"\n", ANSI_GREEN, ANSI_RESET)
    fmt.printf("    %s-o, --output%s <file>      Write output to file instead of stdout\n", ANSI_GREEN, ANSI_RESET)
    fmt.printf("    %s-O, --remote-name%s        Save with remote filename\n", ANSI_GREEN, ANSI_RESET)
    fmt.printf("    %s-i, --include%s            Include response headers in output\n", ANSI_GREEN, ANSI_RESET)
    fmt.printf("    %s-I, --head%s               HEAD request only\n", ANSI_GREEN, ANSI_RESET)
    fmt.printf("    %s-L, --location%s           Follow redirects (default: on)\n", ANSI_GREEN, ANSI_RESET)
    fmt.printf("    %s-j, --json%s               Set JSON content-type headers\n", ANSI_GREEN, ANSI_RESET)
    fmt.printf("    %s-f, --fail%s               Fail silently on HTTP errors (exit 22)\n", ANSI_GREEN, ANSI_RESET)
    fmt.printf("    %s-s, --silent%s             Silent mode (no progress/status)\n", ANSI_GREEN, ANSI_RESET)
    fmt.printf("    %s-v, --verbose%s            Verbose curl output\n", ANSI_GREEN, ANSI_RESET)
    fmt.printf("    %s-k, --insecure%s           Skip TLS verification\n", ANSI_GREEN, ANSI_RESET)
    fmt.printf("    %s-A, --user-agent%s <ua>    Set User-Agent header\n", ANSI_GREEN, ANSI_RESET)
    fmt.printf("    %s-t, --timeout%s <secs>     Request timeout (default: 30)\n", ANSI_GREEN, ANSI_RESET)
    fmt.printf("    %s-C, --continue-at%s        Resume download\n", ANSI_GREEN, ANSI_RESET)
    fmt.printf("    %s    --progress%s           Show progress bar\n", ANSI_GREEN, ANSI_RESET)
    fmt.printf("    %s    --clean%s              Raw body only (for piping)\n", ANSI_CYAN, ANSI_RESET)
    fmt.printf("    %s    --json-pretty%s        Pretty-print JSON response\n", ANSI_CYAN, ANSI_RESET)
    fmt.printf("    %s    --debug%s              Show timing breakdown\n", ANSI_CYAN, ANSI_RESET)
    fmt.printf("    %s    --bench%s <n>          Benchmark: run n requests\n", ANSI_CYAN, ANSI_RESET)
    fmt.printf("    %s-P, --parallel%s <n>       Fetch multiple URLs from file\n", ANSI_CYAN, ANSI_RESET)
    fmt.printf("    %s    --rate%s <n>           Rate limit (requests/sec)\n", ANSI_CYAN, ANSI_RESET)
    fmt.printf("    %s-c, --cookie-jar%s <file>  Save cookies to file\n", ANSI_CYAN, ANSI_RESET)
    fmt.printf("    %s-b, --cookie%s <file>      Load cookies from file\n", ANSI_CYAN, ANSI_RESET)
    fmt.printf("    %s    --serve%s <port>       Start simple HTTP server\n", ANSI_CYAN, ANSI_RESET)
    fmt.printf("    %s    --raw%s                Disable pretty output\n", ANSI_GREEN, ANSI_RESET)
    fmt.printf("    %s-h, --help%s               Show this help\n", ANSI_GREEN, ANSI_RESET)
    fmt.printf("    %s    --version%s            Show version\n", ANSI_GREEN, ANSI_RESET)
    
    fmt.printf("\n%sEXAMPLES%s\n", ANSI_BOLD, ANSI_RESET)
    fmt.printf("    %s# Simple GET%s\n", ANSI_DIM, ANSI_RESET)
    fmt.printf("    %s https://httpbin.org/get\n\n", APP_NAME)
    fmt.printf("    %s# POST JSON%s\n", ANSI_DIM, ANSI_RESET)
    _, _ = os.write_strings(os.stdout, "    ", APP_NAME, " -j -d '{\"name\":\"volt\"}' https://httpbin.org/post\n\n")
    fmt.printf("    %s# Download with progress%s\n", ANSI_DIM, ANSI_RESET)
    fmt.printf("    %s -O --progress https://example.com/file.zip\n\n", APP_NAME)
    fmt.printf("    %s# Pipe to shell%s\n", ANSI_DIM, ANSI_RESET)
    fmt.printf("    %s --clean https://example.com/install.sh | bash\n\n", APP_NAME)
    fmt.printf("    %s# Benchmark%s\n", ANSI_DIM, ANSI_RESET)
    fmt.printf("    %s --bench 50 https://example.com\n\n", APP_NAME)
    fmt.printf("    %s# Parallel fetch%s\n", ANSI_DIM, ANSI_RESET)
    fmt.printf("    %s -P 4 urls.txt\n", APP_NAME)
}

print_version :: proc() {
    fmt.printf("%s%s%s %s\n", ANSI_BOLD, APP_NAME, ANSI_RESET, APP_VERSION)
}

// ─────────────────────────────────────────────────────────────
// Helpers
// ─────────────────────────────────────────────────────────────
fail :: proc(msg: string, exit_code: int = 1) -> ! {
    fmt.eprintf("%s%s:%s %s\n", ANSI_RED, APP_NAME, ANSI_RESET, msg)
    os.exit(exit_code)
}

warn :: proc(msg: string) {
    fmt.eprintf("%s%s:%s %s\n", ANSI_YELLOW, APP_NAME, ANSI_RESET, msg)
}

status_color :: proc(code: int) -> string {
    switch {
    case code >= 200 && code < 300: return ANSI_GREEN
    case code >= 300 && code < 400: return ANSI_YELLOW
    case code >= 400 && code < 500: return ANSI_RED
    case code >= 500:               return ANSI_MAGENTA
    }
    return ANSI_WHITE
}

status_label :: proc(code: int) -> string {
    switch code {
    case 200: return "OK"
    case 201: return "Created"
    case 204: return "No Content"
    case 301: return "Moved Permanently"
    case 302: return "Found"
    case 304: return "Not Modified"
    case 400: return "Bad Request"
    case 401: return "Unauthorized"
    case 403: return "Forbidden"
    case 404: return "Not Found"
    case 405: return "Method Not Allowed"
    case 422: return "Unprocessable Entity"
    case 429: return "Too Many Requests"
    case 500: return "Internal Server Error"
    case 502: return "Bad Gateway"
    case 503: return "Service Unavailable"
    case 504: return "Gateway Timeout"
    }
    switch {
    case code >= 200 && code < 300: return "Success"
    case code >= 300 && code < 400: return "Redirect"
    case code >= 400 && code < 500: return "Client Error"
    case code >= 500:               return "Server Error"
    }
    return "Unknown"
}

remote_name_from_url :: proc(url: string) -> string {
    s := url
    if idx := strings.index(s, "?"); idx >= 0 {
        s = s[:idx]
    }
    if idx := strings.index(s, "#"); idx >= 0 {
        s = s[:idx]
    }
    if idx := strings.last_index(s, "/"); idx >= 0 && idx + 1 < len(s) {
        name := s[idx+1:]
        if len(name) > 0 {
            return name
        }
    }
    return "index.html"
}

format_bytes :: proc(bytes: i64) -> string {
    KB :: 1024
    MB :: KB * 1024
    GB :: MB * 1024
    
    switch {
    case bytes >= GB: return fmt.tprintf("%.2f GB", f64(bytes) / f64(GB))
    case bytes >= MB: return fmt.tprintf("%.2f MB", f64(bytes) / f64(MB))
    case bytes >= KB: return fmt.tprintf("%.2f KB", f64(bytes) / f64(KB))
    }
    return fmt.tprintf("%d B", bytes)
}

format_duration :: proc(d: time.Duration) -> string {
    ms := time.duration_milliseconds(d)
    if ms < 1000 {
        return fmt.tprintf("%.0fms", ms)
    }
    return fmt.tprintf("%.2fs", time.duration_seconds(d))
}

format_ms :: proc(ms: f64) -> string {
    if ms < 1000 {
        return fmt.tprintf("%.2fms", ms)
    }
    return fmt.tprintf("%.2fs", ms / 1000.0)
}

eq_ignore_case :: proc(a, b: string) -> bool {
    if len(a) != len(b) do return false
    for i := 0; i < len(a); i += 1 {
        ca, cb := a[i], b[i]
        if ca >= 'A' && ca <= 'Z' do ca += 32
        if cb >= 'A' && cb <= 'Z' do cb += 32
        if ca != cb do return false
    }
    return true
}

has_header :: proc(headers: [dynamic]string, name: string) -> bool {
    search := fmt.tprintf("%s:", name)
    for h in headers {
        if len(h) >= len(search) && eq_ignore_case(h[:len(search)], search) {
            return true
        }
    }
    return false
}

// ─────────────────────────────────────────────────────────────
// JSON Pretty Printer
// ─────────────────────────────────────────────────────────────
json_pretty_print :: proc(data: []u8) {
    indent := 0
    in_string := false
    escaped := false
    i := 0
    
    for i < len(data) {
        ch := data[i]
        
        if escaped {
            fmt.printf("%s%c%s", ANSI_GREEN, ch, ANSI_RESET)
            escaped = false
            i += 1
            continue
        }
        
        if ch == '\\' && in_string {
            fmt.printf("%s%c%s", ANSI_GREEN, ch, ANSI_RESET)
            escaped = true
            i += 1
            continue
        }
        
        if ch == '"' {
            in_string = !in_string
            fmt.printf("%s\"%s", ANSI_GREEN, ANSI_RESET)
            i += 1
            continue
        }
        
        if in_string {
            fmt.printf("%s%c%s", ANSI_GREEN, ch, ANSI_RESET)
            i += 1
            continue
        }
        
        switch ch {
        case '{', '[':
            fmt.printf("%s%c%s", ANSI_CYAN, ch, ANSI_RESET)
            indent += 1
            fmt.printf("\n")
            for _ in 0..<indent do fmt.printf("  ")
        case '}', ']':
            indent -= 1
            fmt.printf("\n")
            for _ in 0..<indent do fmt.printf("  ")
            fmt.printf("%s%c%s", ANSI_CYAN, ch, ANSI_RESET)
        case ':':
            fmt.printf("%s:%s ", ANSI_WHITE, ANSI_RESET)
        case ',':
            fmt.printf("%s,%s\n", ANSI_WHITE, ANSI_RESET)
            for _ in 0..<indent do fmt.printf("  ")
        case ' ', '\t', '\n', '\r':
            // skip existing whitespace
        case:
            // Numbers, true, false, null
            if ch >= '0' && ch <= '9' || ch == '-' || ch == '.' {
                fmt.printf("%s%c%s", ANSI_YELLOW, ch, ANSI_RESET)
            } else if ch == 't' || ch == 'f' || ch == 'n' {
                fmt.printf("%s%c%s", ANSI_MAGENTA, ch, ANSI_RESET)
            } else {
                fmt.printf("%c", ch)
            }
        }
        i += 1
    }
    fmt.println()
}

// ─────────────────────────────────────────────────────────────
// Argument parsing
// ─────────────────────────────────────────────────────────────
need_arg :: proc(args: []string, i: int, flag: string) -> string {
    if i + 1 >= len(args) {
        fail(fmt.tprintf("option %s requires an argument", flag), 2)
    }
    return args[i + 1]
}

parse_args :: proc(cfg: ^Config, args: []string) {
    i := 0
    for i < len(args) {
        arg := args[i]
        
        switch arg {
        case "-h", "--help":
            usage()
            os.exit(0)
        case "--version":
            print_version()
            os.exit(0)
        case "-u", "--url":
            cfg.url = need_arg(args, i, arg)
            i += 1
        case "-X", "--request", "-m", "--method":
            cfg.method = strings.to_upper(need_arg(args, i, arg))
            i += 1
        case "-I", "--head":
            cfg.head_request = true
        case "-d", "--data", "-b", "--body":
            cfg.data = need_arg(args, i, arg)
            i += 1
        case "-H", "--header":
            append(&cfg.headers, need_arg(args, i, arg))
            i += 1
        case "-j", "--json":
            cfg.json_mode = true
        case "-o", "--output":
            cfg.output_path = need_arg(args, i, arg)
            i += 1
        case "-O", "--remote-name":
            cfg.remote_name = true
        case "-i", "--include":
            cfg.include_headers = true
        case "-L", "--location":
            cfg.follow_redirects = true
        case "-k", "--insecure":
            cfg.insecure = true
        case "-f", "--fail":
            cfg.fail_http = true
        case "-s", "--silent":
            cfg.silent = true
        case "-S", "--show-error":
            cfg.show_error = true
        case "-v", "--verbose":
            cfg.verbose = true
        case "--raw":
            cfg.raw = true
        case "--progress":
            cfg.progress = true
        case "-C", "--continue-at":
            cfg.continue_dl = true
        case "-A", "--user-agent":
            cfg.user_agent = need_arg(args, i, arg)
            i += 1
        case "-t", "--timeout":
            val := need_arg(args, i, arg)
            cfg.timeout_seconds = int(strconv.parse_int(val) or_else 0)
            if cfg.timeout_seconds <= 0 {
                cfg.timeout_seconds = 30
            }
            i += 1
        case "--max-redirs":
            val := need_arg(args, i, arg)
            cfg.max_redirects = int(strconv.parse_int(val) or_else 0)
            i += 1
        // New features
        case "--clean":
            cfg.clean = true
            cfg.silent = true
            cfg.raw = true
        case "--json-pretty", "--pretty":
            cfg.json_pretty = true
        case "--debug":
            cfg.debug = true
        case "--bench":
            cfg.bench_count = int(strconv.parse_int(need_arg(args, i, arg)) or_else 0)
            i += 1
        case "-P", "--parallel":
            cfg.parallel = int(strconv.parse_int(need_arg(args, i, arg)) or_else 0)
            i += 1
        case "--rate":
            cfg.rate_limit = int(strconv.parse_int(need_arg(args, i, arg)) or_else 0)
            i += 1
        case "-c", "--cookie-jar":
            cfg.cookie_jar = need_arg(args, i, arg)
            i += 1
        case "--cookie":
            cfg.cookie_file = need_arg(args, i, arg)
            i += 1
        case "--serve":
            cfg.serve_port = int(strconv.parse_int(need_arg(args, i, arg)) or_else 0)
            i += 1
        case:
            if len(arg) > 0 && arg[0] == '-' {
                fail(fmt.tprintf("unknown option: %s", arg), 2)
            }
            if cfg.url == "" {
                cfg.url = arg
            } else {
                fail(fmt.tprintf("unexpected argument: %s", arg), 2)
            }
        }
        i += 1
    }
    
    // Serve mode doesn't need URL
    if cfg.serve_port > 0 {
        return
    }
    
    if cfg.url == "" && cfg.parallel == 0 {
        usage()
        os.exit(2)
    }
    
    // Defaults
    if cfg.user_agent == "" {
        cfg.user_agent = DEFAULT_UA
    }
    if cfg.max_redirects == 0 {
        cfg.max_redirects = DEFAULT_MAX_REDIRECTS
    }
    if cfg.head_request {
        cfg.method = "HEAD"
    }
    if cfg.remote_name && cfg.output_path == "" {
        cfg.output_path = remote_name_from_url(cfg.url)
    }
}

// ─────────────────────────────────────────────────────────────
// Payload loading
// ─────────────────────────────────────────────────────────────
load_payload :: proc(cfg: Config) -> Payload {
    if cfg.data == "" {
        return Payload{}
    }
    
    if cfg.data == "@-" {
        data, err := os.read_entire_file_from_file(os.stdin, context.allocator)
        if err != nil {
            fail(fmt.tprintf("failed to read stdin: %v", err))
        }
        return Payload{bytes = data, owns_bytes = true}
    }
    
    if len(cfg.data) > 1 && cfg.data[0] == '@' {
        path := cfg.data[1:]
        data, err := os.read_entire_file_from_path(path, context.allocator)
        if err != nil {
            fail(fmt.tprintf("failed to read '%s': %v", path, err))
        }
        return Payload{bytes = data, owns_bytes = true}
    }
    
    return Payload{text = cfg.data}
}

payload_ptr :: proc(p: ^Payload) -> rawptr {
    if len(p.bytes) > 0 {
        return raw_data(p.bytes)
    }
    return raw_data(p.text)
}

payload_len :: proc(p: ^Payload) -> int {
    if len(p.bytes) > 0 {
        return len(p.bytes)
    }
    return len(p.text)
}

// ─────────────────────────────────────────────────────────────
// Curl callbacks
// ─────────────────────────────────────────────────────────────
write_callback :: proc "c" (ptr: [^]u8, size: c.size_t, nmemb: c.size_t, userdata: rawptr) -> c.size_t {
    context = runtime.default_context()
    
    target := cast(^Write_Target)userdata
    count := int(size * nmemb)
    if count == 0 {
        return 0
    }
    
    data := ptr[:count]
    
    if target.use_file {
        written, err := os.write(target.file, data)
        if err != nil {
            return 0
        }
        target.total_written += i64(written)
        return c.size_t(written)
    }
    
    append(&target.buf, ..data)
    target.total_written += i64(count)
    return c.size_t(count)
}

header_callback :: proc "c" (ptr: [^]u8, size: c.size_t, nmemb: c.size_t, userdata: rawptr) -> c.size_t {
    context = runtime.default_context()
    
    target := cast(^Write_Target)userdata
    count := int(size * nmemb)
    if count == 0 {
        return 0
    }
    
    append(&target.buf, ..ptr[:count])
    return c.size_t(count)
}

progress_callback :: proc "c" (
    clientp: rawptr,
    dltotal: curl.off_t,
    dlnow: curl.off_t,
    ultotal: curl.off_t,
    ulnow: curl.off_t,
) -> c.int {
    context = runtime.default_context()
    
    pd := cast(^Progress_Data)clientp
    if !pd.show {
        return 0
    }
    
    now := time.now()
    if time.duration_milliseconds(time.diff(pd.last_update, now)) < 100 {
        return 0
    }
    pd.last_update = now
    
    pd.total_size = i64(dltotal)
    pd.downloaded = i64(dlnow)
    
    elapsed := time.diff(pd.start_time, now)
    elapsed_sec := time.duration_seconds(elapsed)
    
    speed: f64 = 0
    if elapsed_sec > 0 {
        speed = f64(dlnow) / elapsed_sec
    }
    
    fmt.eprintf("%s", ANSI_CLEAR_LINE)
    
    if dltotal > 0 {
        pct := f64(dlnow) / f64(dltotal) * 100.0
        bar_width :: 30
        filled := int(f64(bar_width) * f64(dlnow) / f64(dltotal))
        
        fmt.eprintf("%s[%s", ANSI_CYAN, ANSI_RESET)
        for j := 0; j < bar_width; j += 1 {
            if j < filled {
                fmt.eprintf("%s█%s", ANSI_CYAN, ANSI_RESET)
            } else if j == filled {
                fmt.eprintf("%s▓%s", ANSI_DIM, ANSI_RESET)
            } else {
                fmt.eprintf("%s░%s", ANSI_DIM, ANSI_RESET)
            }
        }
        fmt.eprintf("%s]%s ", ANSI_CYAN, ANSI_RESET)
        fmt.eprintf("%5.1f%% ", pct)
        fmt.eprintf("%s / %s  ", format_bytes(i64(dlnow)), format_bytes(i64(dltotal)))
        fmt.eprintf("%s/s", format_bytes(i64(speed)))
    } else {
        fmt.eprintf("%s%s%s %s  %s/s", 
            ANSI_CYAN, SYM_DOWN, ANSI_RESET,
            format_bytes(i64(dlnow)), 
            format_bytes(i64(speed)))
    }
    
    return 0
}

// ─────────────────────────────────────────────────────────────
// Pretty printing
// ─────────────────────────────────────────────────────────────
print_response_line :: proc(method, url: string, status: int, duration: time.Duration, size: i64) {
    color := status_color(status)
    label := status_label(status)
    
    fmt.eprintf("\n%s%s %s%s ", ANSI_DIM, method, url, ANSI_RESET)
    fmt.eprintf("%s%s%d %s%s ", color, ANSI_BOLD, status, label, ANSI_RESET)
    fmt.eprintf("%s%s  %s%s\n", ANSI_DIM, format_duration(duration), format_bytes(size), ANSI_RESET)
}

print_headers :: proc(raw_headers: []u8) {
    header_str := string(raw_headers)
    lines := strings.split_lines(header_str)
    defer delete(lines)
    
    for line in lines {
        line := strings.trim_space(line)
        if len(line) == 0 {
            continue
        }
        
        if strings.has_prefix(line, "HTTP/") {
            fmt.printf("%s%s%s\n", ANSI_BOLD, line, ANSI_RESET)
            continue
        }
        
        if idx := strings.index(line, ":"); idx >= 0 {
            name := line[:idx]
            value := strings.trim_left_space(line[idx+1:])
            fmt.printf("%s%s%s:%s %s\n", ANSI_CYAN, name, ANSI_RESET, ANSI_RESET, value)
        }
    }
}

print_debug_timing :: proc(handle: ^curl.CURL) {
    namelookup_time: c.double
    connect_time: c.double
    appconnect_time: c.double
    pretransfer_time: c.double
    starttransfer_time: c.double
    total_time: c.double
    
    curl.easy_getinfo(handle, .NAMELOOKUP_TIME, &namelookup_time)
    curl.easy_getinfo(handle, .CONNECT_TIME, &connect_time)
    curl.easy_getinfo(handle, .APPCONNECT_TIME, &appconnect_time)
    curl.easy_getinfo(handle, .PRETRANSFER_TIME, &pretransfer_time)
    curl.easy_getinfo(handle, .STARTTRANSFER_TIME, &starttransfer_time)
    curl.easy_getinfo(handle, .TOTAL_TIME, &total_time)
    
    dns_ms := namelookup_time * 1000.0
    tcp_ms := (connect_time - namelookup_time) * 1000.0
    tls_ms := (appconnect_time - connect_time) * 1000.0
    server_ms := (starttransfer_time - pretransfer_time) * 1000.0
    transfer_ms := (total_time - starttransfer_time) * 1000.0
    total_ms := total_time * 1000.0
    
    fmt.eprintf("\n%s─── Timing ────────────────────%s\n", ANSI_DIM, ANSI_RESET)
    fmt.eprintf("  %sDNS Lookup%s     %s\n", ANSI_CYAN, ANSI_RESET, format_ms(dns_ms))
    fmt.eprintf("  %sTCP Connect%s    %s\n", ANSI_CYAN, ANSI_RESET, format_ms(tcp_ms))
    if tls_ms > 0 {
        fmt.eprintf("  %sTLS Handshake%s  %s\n", ANSI_CYAN, ANSI_RESET, format_ms(tls_ms))
    }
    fmt.eprintf("  %sServer Wait%s    %s\n", ANSI_CYAN, ANSI_RESET, format_ms(server_ms))
    fmt.eprintf("  %sTransfer%s       %s\n", ANSI_CYAN, ANSI_RESET, format_ms(transfer_ms))
    fmt.eprintf("%s───────────────────────────────%s\n", ANSI_DIM, ANSI_RESET)
    fmt.eprintf("  %s%sTotal%s          %s%s\n", ANSI_BOLD, ANSI_WHITE, ANSI_RESET, format_ms(total_ms), ANSI_RESET)
}

// ─────────────────────────────────────────────────────────────
// Request execution helpers
// ─────────────────────────────────────────────────────────────
setup_curl_handle :: proc(handle: ^curl.CURL, cfg: ^Config, url: string, payload: ^Payload, method: string, 
                           body_target: ^Write_Target, head_target: ^Write_Target, header_list: ^curl.slist) {
    header_list := header_list
    
    curl.easy_setopt(handle, .URL, strings.clone_to_cstring(url))
    
    // Method
    has_body := payload_len(payload) > 0
    switch method {
    case "GET":
        curl.easy_setopt(handle, .HTTPGET, c.long(1))
    case "POST":
        curl.easy_setopt(handle, .POST, c.long(1))
    case "PUT":
        curl.easy_setopt(handle, .CUSTOMREQUEST, cstring("PUT"))
    case "DELETE":
        curl.easy_setopt(handle, .CUSTOMREQUEST, cstring("DELETE"))
    case "PATCH":
        curl.easy_setopt(handle, .CUSTOMREQUEST, cstring("PATCH"))
    case "HEAD":
        curl.easy_setopt(handle, .NOBODY, c.long(1))
    case:
        curl.easy_setopt(handle, .CUSTOMREQUEST, strings.clone_to_cstring(method))
    }
    
    // Body - handle JSON specially to avoid form encoding
    if has_body {
        curl.easy_setopt(handle, .POSTFIELDS, payload_ptr(payload))
        curl.easy_setopt(handle, .POSTFIELDSIZE, c.long(payload_len(payload)))
    }
    
    // Headers
    header_list = nil
    for h in cfg.headers {
        header_list = curl.slist_append(header_list, strings.clone_to_cstring(h))
    }
    ua_header := fmt.ctprintf("User-Agent: %s", cfg.user_agent)
    header_list = curl.slist_append(header_list, ua_header)
    curl.easy_setopt(handle, .HTTPHEADER, header_list)
    
    // Follow redirects
    if cfg.follow_redirects {
        curl.easy_setopt(handle, .FOLLOWLOCATION, c.long(1))
        curl.easy_setopt(handle, .MAXREDIRS, c.long(cfg.max_redirects))
    }
    
    // Timeout
    curl.easy_setopt(handle, .TIMEOUT, c.long(cfg.timeout_seconds))
    curl.easy_setopt(handle, .CONNECTTIMEOUT, c.long(min(cfg.timeout_seconds, 10)))
    
    // TLS
    if cfg.insecure {
        curl.easy_setopt(handle, .SSL_VERIFYPEER, c.long(0))
        curl.easy_setopt(handle, .SSL_VERIFYHOST, c.long(0))
    }
    
    // Cookies
    if cfg.cookie_jar != "" {
        curl.easy_setopt(handle, .COOKIEJAR, strings.clone_to_cstring(cfg.cookie_jar))
        curl.easy_setopt(handle, .COOKIEFILE, strings.clone_to_cstring(cfg.cookie_jar))
    }
    if cfg.cookie_file != "" {
        curl.easy_setopt(handle, .COOKIEFILE, strings.clone_to_cstring(cfg.cookie_file))
    }
    
    // Verbose
    if cfg.verbose {
        curl.easy_setopt(handle, .VERBOSE, c.long(1))
    }
    
    // Callbacks
    curl.easy_setopt(handle, .WRITEFUNCTION, write_callback)
    curl.easy_setopt(handle, .WRITEDATA, body_target)
    curl.easy_setopt(handle, .HEADERFUNCTION, header_callback)
    curl.easy_setopt(handle, .HEADERDATA, head_target)
}

// ─────────────────────────────────────────────────────────────
// Serve mode
// ─────────────────────────────────────────────────────────────
run_server :: proc(port: int) {
    fmt.eprintf("\n%s%s%s volt server %s\n", ANSI_BOLD, ANSI_CYAN, SYM_ARROW, ANSI_RESET)
    fmt.eprintf("  Listening on %shttp://127.0.0.1:%d%s\n", ANSI_GREEN, port, ANSI_RESET)
    fmt.eprintf("  %sPress Ctrl+C to stop%s\n\n", ANSI_DIM, ANSI_RESET)
    
    // Note: Full implementation would use core:net
    fmt.eprintf("%s%s%s Server mode requires core:net (not implemented)\n", ANSI_YELLOW, SYM_FAIL, ANSI_RESET)
    fmt.eprintf("  Use: python3 -m http.server %d\n", port)
    os.exit(1)
}

// ─────────────────────────────────────────────────────────────
// Benchmark mode
// ─────────────────────────────────────────────────────────────
run_benchmark :: proc(cfg: ^Config, handle: ^curl.CURL, payload: ^Payload, method: string) {
    times := make([dynamic]f64)
    defer delete(times)
    
    body_target := Write_Target{}
    head_target := Write_Target{}
    header_list: ^curl.slist = nil
    
    fmt.eprintf("\n%s%sBenchmarking%s %s\n", ANSI_BOLD, ANSI_CYAN, ANSI_RESET, cfg.url)
    fmt.eprintf("%s%d requests...%s\n\n", ANSI_DIM, cfg.bench_count, ANSI_RESET)
    
    for i := 0; i < cfg.bench_count; i += 1 {
        clear(&body_target.buf)
        clear(&head_target.buf)
        body_target.total_written = 0
        
        setup_curl_handle(handle, cfg, cfg.url, payload, method, &body_target, &head_target, header_list)
        
        // Rate limiting
        if cfg.rate_limit > 0 && i > 0 {
            delay_ms := 1000.0 / f64(cfg.rate_limit)
            time.sleep(time.Duration(delay_ms * f64(time.Millisecond)))
        }
        
        req_start := time.now()
        res := curl.easy_perform(handle)
        req_duration := time.duration_milliseconds(time.diff(req_start, time.now()))
        
        if res != .E_OK {
            fmt.eprintf("  %s%s%s #%d failed: %s\n", ANSI_RED, SYM_FAIL, ANSI_RESET, i + 1, curl.easy_strerror(res))
            continue
        }
        
        status_code: c.long
        curl.easy_getinfo(handle, .RESPONSE_CODE, &status_code)
        
        append(&times, req_duration)
        fmt.eprintf("  %s#%-3d%s  %s%d%s  %s\n", 
            ANSI_DIM, i + 1, ANSI_RESET,
            status_color(int(status_code)), status_code, ANSI_RESET,
            format_ms(req_duration))
        
        curl.slist_free_all(header_list)
    }
    
    if len(times) > 0 {
        total: f64 = 0
        min_t := times[0]
        max_t := times[0]
        for t in times {
            total += t
            if t < min_t do min_t = t
            if t > max_t do max_t = t
        }
        avg := total / f64(len(times))
        
        // Calculate stddev
        variance: f64 = 0
        for t in times {
            diff := t - avg
            variance += diff * diff
        }
        stddev := math.sqrt(variance / f64(len(times)))
        
        fmt.eprintf("\n%s─── Results ───────────────────%s\n", ANSI_DIM, ANSI_RESET)
        fmt.eprintf("  %sRequests%s   %d successful, %d failed\n", 
            ANSI_WHITE, ANSI_RESET, len(times), cfg.bench_count - len(times))
        fmt.eprintf("  %sAverage%s    %s\n", ANSI_CYAN, ANSI_RESET, format_ms(avg))
        fmt.eprintf("  %sMin%s        %s\n", ANSI_GREEN, ANSI_RESET, format_ms(min_t))
        fmt.eprintf("  %sMax%s        %s\n", ANSI_YELLOW, ANSI_RESET, format_ms(max_t))
        fmt.eprintf("  %sStd Dev%s    %s\n", ANSI_MAGENTA, ANSI_RESET, format_ms(stddev))
        fmt.eprintf("  %sReq/sec%s    %.2f\n", ANSI_WHITE, ANSI_RESET, 1000.0 / avg)
    }
    
    delete(body_target.buf)
    delete(head_target.buf)
}

// ─────────────────────────────────────────────────────────────
// Parallel mode
// ─────────────────────────────────────────────────────────────
run_parallel :: proc(cfg: ^Config, handle: ^curl.CURL, payload: ^Payload, method: string) {
    urls := make([dynamic]string)
    defer delete(urls)
    
    // Read URLs from file if it exists
    if os.exists(cfg.url) {
        data, err := os.read_entire_file_from_path(cfg.url, context.allocator)
        if err == nil {
            content := string(data)
            lines := strings.split_lines(content)
            for line in lines {
                line := strings.trim_space(line)
                if len(line) > 0 && !strings.has_prefix(line, "#") {
                    append(&urls, strings.clone(line))
                }
            }
            delete(lines)
            
        } else {
            fail(fmt.tprintf("cannot read URL file: %s", cfg.url))
        }
    } else {
        append(&urls, cfg.url)
    }
    
    if len(urls) == 0 {
        fail("no URLs to fetch")
    }
    
    fmt.eprintf("\n%s%sParallel fetch%s\n", ANSI_BOLD, ANSI_CYAN, ANSI_RESET)
    fmt.eprintf("  %s%d URLs, %d workers%s\n\n", ANSI_DIM, len(urls), cfg.parallel, ANSI_RESET)
    
    body_target := Write_Target{}
    head_target := Write_Target{}
    header_list: ^curl.slist = nil
    
    success_count := 0
    fail_count := 0
    total_bytes: i64 = 0
    total_start := time.now()
    
    for url, idx in urls {
        clear(&body_target.buf)
        clear(&head_target.buf)
        body_target.total_written = 0
        
        setup_curl_handle(handle, cfg, url, payload, method, &body_target, &head_target, header_list)
        
        // Rate limiting
        if cfg.rate_limit > 0 && idx > 0 {
            delay_ms := 1000.0 / f64(cfg.rate_limit)
            time.sleep(time.Duration(delay_ms * f64(time.Millisecond)))
        }
        
        req_start := time.now()
        res := curl.easy_perform(handle)
        req_duration := time.diff(req_start, time.now())
        
        if res != .E_OK {
            fmt.eprintf("  %s%s%s [%d] %s\n", ANSI_RED, SYM_FAIL, ANSI_RESET, idx + 1, url)
            fmt.eprintf("       %s%s%s\n", ANSI_DIM, curl.easy_strerror(res), ANSI_RESET)
            fail_count += 1
        curl.slist_free_all(header_list)
            continue
        }
        
        status_code: c.long
        curl.easy_getinfo(handle, .RESPONSE_CODE, &status_code)
        
        success_count += 1
        total_bytes += body_target.total_written
        
        color := status_color(int(status_code))
        fmt.eprintf("  %s%s%s [%d] %s%d%s %s %s%s  %s%s\n",
            ANSI_GREEN, SYM_OK, ANSI_RESET,
            idx + 1,
            color, status_code, ANSI_RESET,
            url,
            ANSI_DIM, format_duration(req_duration),
            format_bytes(body_target.total_written), ANSI_RESET)
        
        curl.slist_free_all(header_list)
    }
    
    total_duration := time.diff(total_start, time.now())
    
    fmt.eprintf("\n%s─── Summary ───────────────────%s\n", ANSI_DIM, ANSI_RESET)
    fmt.eprintf("  %sSuccess%s    %d\n", ANSI_GREEN, ANSI_RESET, success_count)
    fmt.eprintf("  %sFailed%s     %d\n", ANSI_RED, ANSI_RESET, fail_count)
    fmt.eprintf("  %sTotal%s      %s, %s\n", ANSI_CYAN, ANSI_RESET, 
        format_duration(total_duration), format_bytes(total_bytes))
    
    delete(body_target.buf)
    delete(head_target.buf)
}

// ─────────────────────────────────────────────────────────────
// Main
// ─────────────────────────────────────────────────────────────
main :: proc() {
    cfg := Config{
        follow_redirects = true,
        timeout_seconds  = 30,
        max_redirects    = DEFAULT_MAX_REDIRECTS,
    }
    parse_args(&cfg, os.args[1:])
    
    // Serve mode
    if cfg.serve_port > 0 {
        run_server(cfg.serve_port)
        return
    }
    
    // JSON mode headers
    if cfg.json_mode {
        if !has_header(cfg.headers, "Content-Type") {
            append(&cfg.headers, "Content-Type: application/json")
        }
        if !has_header(cfg.headers, "Accept") {
            append(&cfg.headers, "Accept: application/json")
        }
    }
    
    // Load request body
    payload := load_payload(cfg)
    defer if payload.owns_bytes {
        delete(payload.bytes)
    }
    
    has_body := payload_len(&payload) > 0
    
    // Determine method
    method := cfg.method
    if method == "" {
        method = has_body ? "POST" : "GET"
    }
    
    // Initialize curl
    if curl.global_init(0) != .E_OK {
        fail("failed to initialize curl")
    }
    defer curl.global_cleanup()
    
    handle := curl.easy_init()
    if handle == nil {
        fail("failed to create curl handle")
    }
    defer curl.easy_cleanup(handle)
    
    // Benchmark mode
    if cfg.bench_count > 0 {
        run_benchmark(&cfg, handle, &payload, method)
        os.exit(0)
    }
    
    // Parallel mode
    if cfg.parallel > 0 {
        run_parallel(&cfg, handle, &payload, method)
        os.exit(0)
    }
    
    // Setup output target
    body_target := Write_Target{}
    head_target := Write_Target{}
    
    out_file: ^os.File = nil
    if cfg.output_path != "" {
        f, err := os.open(cfg.output_path, os.O_WRONLY | os.O_CREATE | os.O_TRUNC, os.Permissions_Read_All + {.Write_User})
        if err != nil {
            fail(fmt.tprintf("cannot open '%s' for writing: %v", cfg.output_path, err))
        }
        out_file = f
        body_target.use_file = true
        body_target.file = f
    }
    defer if out_file != nil {
        os.close(out_file)
    }
    
    header_list: ^curl.slist = nil
    setup_curl_handle(handle, &cfg, cfg.url, &payload, method, &body_target, &head_target, header_list)
    defer curl.slist_free_all(header_list)
    
    // Progress
    progress_data := Progress_Data{
        show       = (cfg.progress || cfg.output_path != "") && !cfg.silent,
        start_time = time.now(),
        last_update = time.now(),
    }
    if progress_data.show {
        curl.easy_setopt(handle, .NOPROGRESS, c.long(0))
        curl.easy_setopt(handle, .XFERINFOFUNCTION, progress_callback)
        curl.easy_setopt(handle, .XFERINFODATA, &progress_data)
    }
    
    // Perform request
    start_time := time.now()
    res := curl.easy_perform(handle)
    duration := time.diff(start_time, time.now())
    
    // Clear progress line
    if progress_data.show {
        fmt.eprintf("%s", ANSI_CLEAR_LINE)
    }
    
    // Check for errors
    if res != .E_OK {
        err_str := curl.easy_strerror(res)
        if cfg.show_error || !cfg.silent {
            fail(fmt.tprintf("request failed: %s", err_str), 1)
        }
        os.exit(1)
    }
    
    // Get response info
    status_code: c.long
    curl.easy_getinfo(handle, .RESPONSE_CODE, &status_code)
    
    // Print status (unless silent/clean)
    pretty := !cfg.silent && !cfg.raw && !cfg.clean && os.is_tty(os.stderr)
    if pretty {
        print_response_line(method, cfg.url, int(status_code), duration, body_target.total_written)
    }
    
    // Debug timing
    if cfg.debug {
        print_debug_timing(handle)
    }
    
    // Include headers
    if cfg.include_headers && len(head_target.buf) > 0 {
        if pretty {
            print_headers(head_target.buf[:])
            fmt.println()
        } else {
            os.write(os.stdout, head_target.buf[:])
        }
    }
    
    // Output body
    if !body_target.use_file && len(body_target.buf) > 0 {
        // Check for JSON pretty print
        if cfg.json_pretty && len(body_target.buf) > 0 && (body_target.buf[0] == '{' || body_target.buf[0] == '[') {
            json_pretty_print(body_target.buf[:])
        } else {
            os.write(os.stdout, body_target.buf[:])
            // Add newline if needed
            if !cfg.raw && !cfg.clean && os.is_tty(os.stdout) && len(body_target.buf) > 0 {
                if body_target.buf[len(body_target.buf) - 1] != '\n' {
                    fmt.println()
                }
            }
        }
    }
    
    // Success message for file downloads
    if cfg.output_path != "" && !cfg.silent {
        fmt.eprintf("%s%s%s Saved to %s%s%s (%s)\n", 
            ANSI_GREEN, SYM_OK, ANSI_RESET,
            ANSI_BOLD, cfg.output_path, ANSI_RESET,
            format_bytes(body_target.total_written))
    }
    
    // Fail on HTTP error
    if cfg.fail_http && status_code >= 400 {
        os.exit(22)
    }
    
    // Cleanup
    delete(body_target.buf)
    delete(head_target.buf)
}
