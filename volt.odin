package main

import "core:c"
import "core:fmt"
import "core:math"
import "core:net"
import "core:os"
import "base:runtime"
import "core:strconv"
import "core:strings"
import "core:time"

import curl "vendor:curl"

APP_NAME    :: "volt"
APP_VERSION :: "0.4.0"
DEFAULT_UA  :: APP_NAME + "/" + APP_VERSION

DEFAULT_TIMEOUT         :: 30
DEFAULT_CONNECT_TIMEOUT :: 10
DEFAULT_MAX_REDIRECTS   :: 50
DEFAULT_PARALLEL        :: 4

ANSI_RESET      :: "\x1b[0m"
ANSI_BOLD       :: "\x1b[1m"
ANSI_DIM        :: "\x1b[2m"
ANSI_RED        :: "\x1b[31m"
ANSI_GREEN      :: "\x1b[32m"
ANSI_YELLOW     :: "\x1b[33m"
ANSI_BLUE       :: "\x1b[34m"
ANSI_MAGENTA    :: "\x1b[35m"
ANSI_CYAN       :: "\x1b[36m"
ANSI_WHITE      :: "\x1b[37m"
ANSI_CLEAR_LINE :: "\x1b[2K\r"

SYM_OK   :: "✓"
SYM_FAIL :: "✖"
SYM_WARN :: "!"
SYM_GET  :: "↓"

Config :: struct {
	url:                string,
	method:             string,
	data:               string,
	headers:            [dynamic]string,
	output_path:        string,
	remote_name:        bool,
	include_headers:    bool,
	dump_headers_path:  string,
	json_pretty:        bool,
	clean:              bool,
	raw:                bool,
	follow_redirects:   bool,
	max_redirects:      int,
	insecure:           bool,
	fail_http:          bool,
	verbose:            bool,
	silent:             bool,
	show_error:         bool,
	debug:              bool,
	progress:           bool,
	json_mode:          bool,
	head_request:       bool,
	user_agent:         string,
	timeout_seconds:    int,
	connect_timeout:    int,
	retry_count:        int,
	retry_delay_ms:     int,
	limit_rate_bps:     i64,
	resume:             bool,
	cookie_jar:         string,
	cookie_file:        string,
	bench_count:        int,
	batch_file:         string,
	parallel:           int,
	serve_port:         int,
	serve_bind:         string,
	serve_dir:          string,
	serve_allow_upload: bool,
	serve_upload_dir:   string,
	serve_spa:          bool,
	serve_dir_list:     bool,
	serve_max_request:  int,
}

Payload :: struct {
	text:       string,
	bytes:      []u8,
	owns_bytes: bool,
}

Write_Target :: struct {
	buf:           [dynamic]u8,
	file:          ^os.File,
	use_file:      bool,
	discard:       bool,
	total_written: i64,
}

Progress_Data :: struct {
	show:        bool,
	start_time:  time.Time,
	last_update: time.Time,
}

Timing_Info :: struct {
	namelookup_ms:    f64,
	connect_ms:       f64,
	tls_ms:           f64,
	server_wait_ms:   f64,
	transfer_ms:      f64,
	total_ms:         f64,
	redirect_count:   int,
	downloaded_bytes: i64,
	speed_bps:        i64,
}

Request_Result :: struct {
	ok:        bool,
	curl_code: curl.code,
	status:    int,
	duration:  time.Duration,
	bytes:     i64,
	timing:    Timing_Info,
}

Batch_Job :: struct {
	url:      string,
	handle:   ^curl.CURL,
	headers:  ^curl.slist,
	body:     Write_Target,
	head:     Write_Target,
	start:    time.Time,
	duration: time.Duration,
	result:   curl.code,
	status:   int,
	done:     bool,
}

usage :: proc() {
	fmt.printf(
		"%s%s%s %s— fast minimal HTTP client%s\n\n",
		ANSI_BOLD,
		ANSI_CYAN,
		APP_NAME,
		ANSI_RESET,
		ANSI_RESET,
	)

	fmt.printf("%sUSAGE%s\n", ANSI_BOLD, ANSI_RESET)
	fmt.printf("    %s [options] <url>\n", APP_NAME)
	fmt.printf("    %s --batch urls.txt [-P n]\n", APP_NAME)
	fmt.printf("    %s --bench 100 <url>\n", APP_NAME)
	fmt.printf("    %s --serve 8080 [--serve-dir .] [--bind 0.0.0.0]\n\n", APP_NAME)

	fmt.printf("%sREQUEST%s\n", ANSI_BOLD, ANSI_RESET)
	fmt.printf("    %s-X, --request%s <method>       HTTP method\n", ANSI_GREEN, ANSI_RESET)
	fmt.printf("    %s-d, --data%s <data>            Request body; use @file or @-\n", ANSI_GREEN, ANSI_RESET)
	fmt.printf("    %s-H, --header%s <header>        Add request header; repeatable\n", ANSI_GREEN, ANSI_RESET)
	fmt.printf("    %s-j, --json%s                   Add JSON Content-Type and Accept headers\n", ANSI_GREEN, ANSI_RESET)
	fmt.printf("    %s-I, --head%s                   HEAD request\n", ANSI_GREEN, ANSI_RESET)
	fmt.printf("    %s-A, --user-agent%s <ua>        Set User-Agent\n\n", ANSI_GREEN, ANSI_RESET)

	fmt.printf("%sOUTPUT%s\n", ANSI_BOLD, ANSI_RESET)
	fmt.printf("    %s-o, --output%s <file>          Write body to file\n", ANSI_GREEN, ANSI_RESET)
	fmt.printf("    %s-O, --remote-name%s            Save with filename from URL\n", ANSI_GREEN, ANSI_RESET)
	fmt.printf("    %s-C, --continue-at%s            Resume output file download\n", ANSI_GREEN, ANSI_RESET)
	fmt.printf("    %s-i, --include%s                Include response headers in stdout\n", ANSI_GREEN, ANSI_RESET)
	fmt.printf("    %s-D, --dump-headers%s <file>    Write response headers to file\n", ANSI_GREEN, ANSI_RESET)
	fmt.printf("    %s    --json-pretty%s            Pretty-print JSON response\n", ANSI_CYAN, ANSI_RESET)
	fmt.printf("    %s    --clean%s                  Body only; good for scripts/pipes\n", ANSI_CYAN, ANSI_RESET)
	fmt.printf("    %s    --raw%s                    Disable extra newline/status formatting\n\n", ANSI_GREEN, ANSI_RESET)

	fmt.printf("%sNETWORK%s\n", ANSI_BOLD, ANSI_RESET)
	fmt.printf("    %s-L, --location%s               Follow redirects; default on\n", ANSI_GREEN, ANSI_RESET)
	fmt.printf("    %s    --no-location%s            Do not follow redirects\n", ANSI_GREEN, ANSI_RESET)
	fmt.printf("    %s    --max-redirs%s <n>         Max redirects; default %d\n", ANSI_GREEN, ANSI_RESET, DEFAULT_MAX_REDIRECTS)
	fmt.printf("    %s-k, --insecure%s               Disable TLS verification\n", ANSI_GREEN, ANSI_RESET)
	fmt.printf("    %s-f, --fail%s                   Exit 22 on HTTP >= 400 without printing body\n", ANSI_GREEN, ANSI_RESET)
	fmt.printf("    %s-t, --timeout%s <sec>          Total timeout; default %d\n", ANSI_GREEN, ANSI_RESET, DEFAULT_TIMEOUT)
	fmt.printf("    %s    --connect-timeout%s <sec>  Connect timeout; default %d\n", ANSI_GREEN, ANSI_RESET, DEFAULT_CONNECT_TIMEOUT)
	fmt.printf("    %s    --retry%s <n>              Retry transient failures\n", ANSI_CYAN, ANSI_RESET)
	fmt.printf("    %s    --retry-delay%s <ms>       Delay between retries\n", ANSI_CYAN, ANSI_RESET)
	fmt.printf("    %s    --limit-rate%s <bytes/s>   Limit download/upload rate\n", ANSI_CYAN, ANSI_RESET)
	fmt.printf("    %s-c, --cookie-jar%s <file>      Save cookies\n", ANSI_CYAN, ANSI_RESET)
	fmt.printf("    %s-b, --cookie%s <file>          Load cookies\n\n", ANSI_CYAN, ANSI_RESET)

	fmt.printf("%sMODES%s\n", ANSI_BOLD, ANSI_RESET)
	fmt.printf("    %s    --bench%s <n>              Benchmark n requests\n", ANSI_CYAN, ANSI_RESET)
	fmt.printf("    %s    --batch%s <file>           Read URLs from file\n", ANSI_CYAN, ANSI_RESET)
	fmt.printf("    %s-P, --parallel%s <n>           Parallel transfers for --batch\n", ANSI_CYAN, ANSI_RESET)
	fmt.printf("    %s    --serve%s <port>           Serve files over HTTP\n", ANSI_CYAN, ANSI_RESET)
	fmt.printf("    %s    --bind%s <addr>            Server bind address; default 127.0.0.1\n", ANSI_CYAN, ANSI_RESET)
	fmt.printf("    %s    --serve-dir%s <dir>        Directory to serve; default .\n", ANSI_CYAN, ANSI_RESET)
	fmt.printf("    %s    --allow-upload%s           Enable PUT/POST uploads to /__volt/upload/<name>\n", ANSI_CYAN, ANSI_RESET)
	fmt.printf("    %s    --upload-dir%s <dir>       Upload destination; default ./uploads\n", ANSI_CYAN, ANSI_RESET)
	fmt.printf("    %s    --spa%s                    Fallback missing paths to index.html\n", ANSI_CYAN, ANSI_RESET)
	fmt.printf("    %s    --no-dir-list%s            Disable generated directory listings\n", ANSI_CYAN, ANSI_RESET)
	fmt.printf("    %s    --max-request%s <bytes>    Max server request size; default 16777216\n\n", ANSI_CYAN, ANSI_RESET)

	fmt.printf("%sMISC%s\n", ANSI_BOLD, ANSI_RESET)
	fmt.printf("    %s-s, --silent%s                 No progress/status\n", ANSI_GREEN, ANSI_RESET)
	fmt.printf("    %s-S, --show-error%s             Show errors even when silent\n", ANSI_GREEN, ANSI_RESET)
	fmt.printf("    %s-v, --verbose%s                libcurl verbose output\n", ANSI_GREEN, ANSI_RESET)
	fmt.printf("    %s    --debug%s                  Timing breakdown\n", ANSI_CYAN, ANSI_RESET)
	fmt.printf("    %s    --progress%s               Show progress meter\n", ANSI_CYAN, ANSI_RESET)
	fmt.printf("    %s-h, --help%s                   Show help\n", ANSI_GREEN, ANSI_RESET)
	fmt.printf("    %s    --version%s                Show version\n\n", ANSI_GREEN, ANSI_RESET)

	fmt.printf("%sEXAMPLES%s\n", ANSI_BOLD, ANSI_RESET)
	fmt.printf("    %s https://httpbin.org/get\n", APP_NAME)
	_, _ = os.write_strings(
		os.stdout,
		"    ",
		APP_NAME,
		" -j -d '{\"name\":\"volt\"}' https://httpbin.org/post\n",
	)
	fmt.printf("    %s -O --progress https://example.com/file.tar.xz\n", APP_NAME)
	fmt.printf("    %s --clean https://example.com/install.sh > install.sh\n", APP_NAME)
	fmt.printf("    %s --bench 50 https://example.com\n", APP_NAME)
	fmt.printf("    %s --batch urls.txt -P 8\n", APP_NAME)
	fmt.printf("    %s --serve 8080 --serve-dir public --bind 0.0.0.0\n", APP_NAME)
	fmt.printf("    %s --serve 8080 --allow-upload --upload-dir drops\n", APP_NAME)
}

print_version :: proc() {
	fmt.printf("%s %s\n", APP_NAME, APP_VERSION)
}

fail :: proc(msg: string, code: int = 1) -> ! {
	fmt.eprintf("%s%s:%s %s\n", ANSI_RED, APP_NAME, ANSI_RESET, msg)
	os.exit(code)
}

warn :: proc(msg: string) {
	fmt.eprintf("%s%s:%s %s\n", ANSI_YELLOW, APP_NAME, ANSI_RESET, msg)
}

need_arg :: proc(args: []string, i: int, flag: string) -> string {
	if i + 1 >= len(args) do fail(fmt.tprintf("option %s requires an argument", flag), 2)
	return args[i + 1]
}

parse_positive_int :: proc(s, name: string) -> int {
	n := int(strconv.parse_int(s) or_else -1)
	if n < 0 do fail(fmt.tprintf("%s must be a positive integer", name), 2)
	return n
}

parse_positive_i64 :: proc(s, name: string) -> i64 {
	n := strconv.parse_int(s) or_else -1
	if n < 0 do fail(fmt.tprintf("%s must be a positive integer", name), 2)
	return i64(n)
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

		case "-d", "--data", "--body":
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

		case "-C", "--continue-at":
			cfg.resume = true

		case "-i", "--include":
			cfg.include_headers = true

		case "-D", "--dump-headers":
			cfg.dump_headers_path = need_arg(args, i, arg)
			i += 1

		case "--json-pretty", "--pretty":
			cfg.json_pretty = true

		case "--clean":
			cfg.clean = true
			cfg.silent = true
			cfg.raw = true

		case "--raw":
			cfg.raw = true

		case "-L", "--location":
			cfg.follow_redirects = true

		case "--no-location":
			cfg.follow_redirects = false

		case "--max-redirs":
			cfg.max_redirects = parse_positive_int(need_arg(args, i, arg), "--max-redirs")
			i += 1

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

		case "--debug":
			cfg.debug = true

		case "--progress":
			cfg.progress = true

		case "-A", "--user-agent":
			cfg.user_agent = need_arg(args, i, arg)
			i += 1

		case "-t", "--timeout":
			cfg.timeout_seconds = parse_positive_int(need_arg(args, i, arg), "--timeout")
			i += 1

		case "--connect-timeout":
			cfg.connect_timeout = parse_positive_int(need_arg(args, i, arg), "--connect-timeout")
			i += 1

		case "--retry":
			cfg.retry_count = parse_positive_int(need_arg(args, i, arg), "--retry")
			i += 1

		case "--retry-delay":
			cfg.retry_delay_ms = parse_positive_int(need_arg(args, i, arg), "--retry-delay")
			i += 1

		case "--limit-rate":
			cfg.limit_rate_bps = parse_positive_i64(need_arg(args, i, arg), "--limit-rate")
			i += 1

		case "-c", "--cookie-jar":
			cfg.cookie_jar = need_arg(args, i, arg)
			i += 1

		case "-b", "--cookie":
			cfg.cookie_file = need_arg(args, i, arg)
			i += 1

		case "--bench":
			cfg.bench_count = parse_positive_int(need_arg(args, i, arg), "--bench")
			i += 1

		case "--batch":
			cfg.batch_file = need_arg(args, i, arg)
			i += 1

		case "-P", "--parallel":
			cfg.parallel = parse_positive_int(need_arg(args, i, arg), "--parallel")
			i += 1

		case "--serve":
			cfg.serve_port = parse_positive_int(need_arg(args, i, arg), "--serve")
			i += 1

		case "--bind":
			cfg.serve_bind = need_arg(args, i, arg)
			i += 1

		case "--serve-dir":
			cfg.serve_dir = need_arg(args, i, arg)
			i += 1

		case "--allow-upload":
			cfg.serve_allow_upload = true

		case "--upload-dir":
			cfg.serve_upload_dir = need_arg(args, i, arg)
			i += 1

		case "--spa":
			cfg.serve_spa = true

		case "--no-dir-list":
			cfg.serve_dir_list = false

		case "--max-request":
			cfg.serve_max_request = parse_positive_int(need_arg(args, i, arg), "--max-request")
			i += 1

		case:
			if len(arg) > 0 && arg[0] == '-' do fail(fmt.tprintf("unknown option: %s", arg), 2)
			if cfg.url == "" {
				cfg.url = arg
			} else {
				fail(fmt.tprintf("unexpected argument: %s", arg), 2)
			}
		}
		i += 1
	}

	if cfg.user_agent == "" do cfg.user_agent = DEFAULT_UA
	if cfg.timeout_seconds <= 0 do cfg.timeout_seconds = DEFAULT_TIMEOUT
	if cfg.connect_timeout <= 0 do cfg.connect_timeout = DEFAULT_CONNECT_TIMEOUT
	if cfg.max_redirects <= 0 do cfg.max_redirects = DEFAULT_MAX_REDIRECTS
	if cfg.parallel <= 0 do cfg.parallel = DEFAULT_PARALLEL
	if cfg.retry_delay_ms <= 0 do cfg.retry_delay_ms = 250
	if cfg.serve_bind == "" do cfg.serve_bind = "127.0.0.1"
	if cfg.serve_dir == "" do cfg.serve_dir = "."
	if cfg.serve_upload_dir == "" do cfg.serve_upload_dir = "uploads"
	if cfg.serve_max_request <= 0 do cfg.serve_max_request = 16 * 1024 * 1024
	if cfg.head_request do cfg.method = "HEAD"
	if cfg.remote_name && cfg.output_path == "" && cfg.url != "" do cfg.output_path = remote_name_from_url(cfg.url)
	if cfg.serve_port <= 0 && cfg.batch_file == "" && cfg.url == "" {
		usage()
		os.exit(2)
	}
}

status_color :: proc(code: int) -> string {
	switch {
	case code >= 200 && code < 300:
		return ANSI_GREEN
	case code >= 300 && code < 400:
		return ANSI_YELLOW
	case code >= 400 && code < 500:
		return ANSI_RED
	case code >= 500:
		return ANSI_MAGENTA
	}
	return ANSI_WHITE
}

status_label :: proc(code: int) -> string {
	switch code {
	case 100:
		return "Continue"
	case 101:
		return "Switching Protocols"
	case 200:
		return "OK"
	case 201:
		return "Created"
	case 202:
		return "Accepted"
	case 204:
		return "No Content"
	case 206:
		return "Partial Content"
	case 301:
		return "Moved Permanently"
	case 302:
		return "Found"
	case 303:
		return "See Other"
	case 304:
		return "Not Modified"
	case 307:
		return "Temporary Redirect"
	case 308:
		return "Permanent Redirect"
	case 400:
		return "Bad Request"
	case 401:
		return "Unauthorized"
	case 403:
		return "Forbidden"
	case 404:
		return "Not Found"
	case 405:
		return "Method Not Allowed"
	case 409:
		return "Conflict"
	case 422:
		return "Unprocessable Entity"
	case 429:
		return "Too Many Requests"
	case 500:
		return "Internal Server Error"
	case 502:
		return "Bad Gateway"
	case 503:
		return "Service Unavailable"
	case 504:
		return "Gateway Timeout"
	}

	switch {
	case code >= 200 && code < 300:
		return "Success"
	case code >= 300 && code < 400:
		return "Redirect"
	case code >= 400 && code < 500:
		return "Client Error"
	case code >= 500:
		return "Server Error"
	}
	return "HTTP"
}

format_bytes :: proc(n: i64) -> string {
	KB :: i64(1024)
	MB :: KB * 1024
	GB :: MB * 1024
	TB :: GB * 1024

	switch {
	case n >= TB:
		return fmt.tprintf("%.2f TB", f64(n) / f64(TB))
	case n >= GB:
		return fmt.tprintf("%.2f GB", f64(n) / f64(GB))
	case n >= MB:
		return fmt.tprintf("%.2f MB", f64(n) / f64(MB))
	case n >= KB:
		return fmt.tprintf("%.2f KB", f64(n) / f64(KB))
	}
	return fmt.tprintf("%d B", n)
}

format_ms :: proc(ms: f64) -> string {
	if ms < 1000.0 do return fmt.tprintf("%.2fms", ms)
	return fmt.tprintf("%.2fs", ms / 1000.0)
}

format_duration :: proc(d: time.Duration) -> string {
	return format_ms(f64(time.duration_milliseconds(d)))
}

remote_name_from_url :: proc(url: string) -> string {
	s := url
	if idx := strings.index(s, "?"); idx >= 0 do s = s[:idx]
	if idx := strings.index(s, "#"); idx >= 0 do s = s[:idx]
	if idx := strings.last_index(s, "/"); idx >= 0 && idx + 1 < len(s) {
		name := s[idx + 1:]
		if len(name) > 0 do return name
	}
	return "index.html"
}

eq_ignore_case :: proc(a, b: string) -> bool {
	if len(a) != len(b) do return false

	for i := 0; i < len(a); i += 1 {
		ca := a[i]
		cb := b[i]

		if ca >= 'A' && ca <= 'Z' do ca += 32
		if cb >= 'A' && cb <= 'Z' do cb += 32
		if ca != cb do return false
	}

	return true
}

has_header :: proc(headers: [dynamic]string, name: string) -> bool {
	prefix := fmt.tprintf("%s:", name)
	for h in headers {
		if len(h) >= len(prefix) && eq_ignore_case(h[:len(prefix)], prefix) do return true
	}
	return false
}

valid_url :: proc(url: string) -> bool {
	return strings.has_prefix(url, "http://") || strings.has_prefix(url, "https://")
}

is_retryable_status :: proc(status: int) -> bool {
	return status == 408 || status == 409 || status == 425 || status == 429 || status >= 500
}

load_payload :: proc(cfg: ^Config) -> Payload {
	if cfg.data == "" do return Payload{}

	if cfg.data == "@-" {
		data, err := os.read_entire_file_from_file(os.stdin, context.allocator)
		if err != nil do fail(fmt.tprintf("failed to read stdin: %v", err))
		return Payload{bytes = data, owns_bytes = true}
	}

	if len(cfg.data) > 1 && cfg.data[0] == '@' {
		path := cfg.data[1:]
		data, err := os.read_entire_file_from_path(path, context.allocator)
		if err != nil do fail(fmt.tprintf("failed to read '%s': %v", path, err))
		return Payload{bytes = data, owns_bytes = true}
	}

	return Payload{text = cfg.data}
}

payload_ptr :: proc(p: ^Payload) -> rawptr {
	if len(p.bytes) > 0 do return raw_data(p.bytes)
	return raw_data(p.text)
}

payload_len :: proc(p: ^Payload) -> int {
	if len(p.bytes) > 0 do return len(p.bytes)
	return len(p.text)
}

json_pretty_print :: proc(data: []u8) {
	indent := 0
	in_string := false
	escaped := false

	for ch, i in data {
		_ = i

		if escaped {
			fmt.printf("%s%c%s", ANSI_GREEN, ch, ANSI_RESET)
			escaped = false
			continue
		}

		if ch == '\\' && in_string {
			fmt.printf("%s%c%s", ANSI_GREEN, ch, ANSI_RESET)
			escaped = true
			continue
		}

		if ch == '"' {
			in_string = !in_string
			fmt.printf("%s\"%s", ANSI_GREEN, ANSI_RESET)
			continue
		}

		if in_string {
			fmt.printf("%s%c%s", ANSI_GREEN, ch, ANSI_RESET)
			continue
		}

		switch ch {
		case '{', '[':
			fmt.printf("%s%c%s", ANSI_CYAN, ch, ANSI_RESET)
			indent += 1
			fmt.println()
			for _ in 0..<indent do fmt.printf("  ")

		case '}', ']':
			indent -= 1
			if indent < 0 do indent = 0
			fmt.println()
			for _ in 0..<indent do fmt.printf("  ")
			fmt.printf("%s%c%s", ANSI_CYAN, ch, ANSI_RESET)

		case ':':
			fmt.printf("%s:%s ", ANSI_WHITE, ANSI_RESET)

		case ',':
			fmt.printf("%s,%s\n", ANSI_WHITE, ANSI_RESET)
			for _ in 0..<indent do fmt.printf("  ")

		case ' ', '\t', '\n', '\r':

		case:
			if (ch >= '0' && ch <= '9') || ch == '-' || ch == '.' {
				fmt.printf("%s%c%s", ANSI_YELLOW, ch, ANSI_RESET)
			} else if ch == 't' || ch == 'f' || ch == 'n' {
				fmt.printf("%s%c%s", ANSI_MAGENTA, ch, ANSI_RESET)
			} else {
				fmt.printf("%c", ch)
			}
		}
	}

	fmt.println()
}

write_callback :: proc "c" (
	ptr: [^]u8,
	size: c.size_t,
	nmemb: c.size_t,
	userdata: rawptr,
) -> c.size_t {
	context = runtime.default_context()

	target := cast(^Write_Target)userdata
	count := int(size * nmemb)
	if count <= 0 do return 0

	data := ptr[:count]

	if target.discard {
		target.total_written += i64(count)
		return c.size_t(count)
	}

	if target.use_file {
		written, err := os.write(target.file, data)
		if err != nil do return 0
		target.total_written += i64(written)
		return c.size_t(written)
	}

	append(&target.buf, ..data)
	target.total_written += i64(count)
	return c.size_t(count)
}

header_callback :: proc "c" (
	ptr: [^]u8,
	size: c.size_t,
	nmemb: c.size_t,
	userdata: rawptr,
) -> c.size_t {
	context = runtime.default_context()

	target := cast(^Write_Target)userdata
	count := int(size * nmemb)
	if count <= 0 do return 0

	if !target.discard do append(&target.buf, ..ptr[:count])
	target.total_written += i64(count)
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

	_ = ultotal
	_ = ulnow

	pd := cast(^Progress_Data)clientp
	if !pd.show do return 0

	now := time.now()
	if time.duration_milliseconds(time.diff(pd.last_update, now)) < 80 do return 0
	pd.last_update = now

	elapsed := time.diff(pd.start_time, now)
	elapsed_s := time.duration_seconds(elapsed)
	speed: f64 = 0
	if elapsed_s > 0 do speed = f64(dlnow) / elapsed_s

	fmt.eprintf("%s", ANSI_CLEAR_LINE)

	if dltotal > 0 {
		pct := f64(dlnow) / f64(dltotal) * 100.0
		bar_width :: 32
		filled := int(f64(bar_width) * f64(dlnow) / f64(dltotal))

		fmt.eprintf("%s[%s", ANSI_CYAN, ANSI_RESET)
		for i := 0; i < bar_width; i += 1 {
			if i < filled {
				fmt.eprintf("%s█%s", ANSI_CYAN, ANSI_RESET)
			} else if i == filled {
				fmt.eprintf("%s▓%s", ANSI_DIM, ANSI_RESET)
			} else {
				fmt.eprintf("%s░%s", ANSI_DIM, ANSI_RESET)
			}
		}

		fmt.eprintf(
			"%s]%s %5.1f%% %s / %s  %s/s",
			ANSI_CYAN,
			ANSI_RESET,
			pct,
			format_bytes(i64(dlnow)),
			format_bytes(i64(dltotal)),
			format_bytes(i64(speed)),
		)
	} else {
		fmt.eprintf(
			"%s%s%s %s  %s/s",
			ANSI_CYAN,
			SYM_GET,
			ANSI_RESET,
			format_bytes(i64(dlnow)),
			format_bytes(i64(speed)),
		)
	}

	return 0
}

build_header_list :: proc(cfg: ^Config) -> ^curl.slist {
	list: ^curl.slist = nil

	for h in cfg.headers do list = curl.slist_append(list, strings.clone_to_cstring(h))
	if !has_header(cfg.headers, "User-Agent") do list = curl.slist_append(list, fmt.ctprintf("User-Agent: %s", cfg.user_agent))

	return list
}

setup_handle :: proc(
	handle: ^curl.CURL,
	cfg: ^Config,
	url: string,
	method: string,
	payload: ^Payload,
	body_target: ^Write_Target,
	header_target: ^Write_Target,
	progress_data: ^Progress_Data = nil,
	resume_from: i64 = 0,
) -> ^curl.slist {
	curl.easy_setopt(handle, .URL, strings.clone_to_cstring(url))
	curl.easy_setopt(handle, .USERAGENT, strings.clone_to_cstring(cfg.user_agent))
	curl.easy_setopt(handle, .NOSIGNAL, c.long(1))
	curl.easy_setopt(handle, .ACCEPT_ENCODING, cstring(""))

	has_body := payload_len(payload) > 0

	switch method {
	case "GET":
		curl.easy_setopt(handle, .HTTPGET, c.long(1))
	case "POST":
		curl.easy_setopt(handle, .POST, c.long(1))
	case "HEAD":
		curl.easy_setopt(handle, .NOBODY, c.long(1))
	case:
		curl.easy_setopt(handle, .CUSTOMREQUEST, strings.clone_to_cstring(method))
	}

	if has_body {
		curl.easy_setopt(handle, .POSTFIELDS, payload_ptr(payload))
		curl.easy_setopt(handle, .POSTFIELDSIZE_LARGE, curl.off_t(payload_len(payload)))
		if method == "GET" do curl.easy_setopt(handle, .CUSTOMREQUEST, cstring("GET"))
	}

	headers := build_header_list(cfg)
	if headers != nil do curl.easy_setopt(handle, .HTTPHEADER, headers)

	if cfg.follow_redirects {
		curl.easy_setopt(handle, .FOLLOWLOCATION, c.long(1))
		curl.easy_setopt(handle, .MAXREDIRS, c.long(cfg.max_redirects))
		curl.easy_setopt(handle, .AUTOREFERER, c.long(1))
	}

	curl.easy_setopt(handle, .TIMEOUT, c.long(cfg.timeout_seconds))
	curl.easy_setopt(handle, .CONNECTTIMEOUT, c.long(cfg.connect_timeout))

	if cfg.insecure {
		curl.easy_setopt(handle, .SSL_VERIFYPEER, c.long(0))
		curl.easy_setopt(handle, .SSL_VERIFYHOST, c.long(0))
	}

	if cfg.cookie_jar != "" {
		curl.easy_setopt(handle, .COOKIEJAR, strings.clone_to_cstring(cfg.cookie_jar))
		curl.easy_setopt(handle, .COOKIEFILE, strings.clone_to_cstring(cfg.cookie_jar))
	}

	if cfg.cookie_file != "" do curl.easy_setopt(handle, .COOKIEFILE, strings.clone_to_cstring(cfg.cookie_file))

	if cfg.limit_rate_bps > 0 {
		curl.easy_setopt(handle, .MAX_RECV_SPEED_LARGE, curl.off_t(cfg.limit_rate_bps))
		curl.easy_setopt(handle, .MAX_SEND_SPEED_LARGE, curl.off_t(cfg.limit_rate_bps))
	}

	if resume_from > 0 do curl.easy_setopt(handle, .RESUME_FROM_LARGE, curl.off_t(resume_from))
	if cfg.verbose do curl.easy_setopt(handle, .VERBOSE, c.long(1))

	curl.easy_setopt(handle, .WRITEFUNCTION, write_callback)
	curl.easy_setopt(handle, .WRITEDATA, body_target)
	curl.easy_setopt(handle, .HEADERFUNCTION, header_callback)
	curl.easy_setopt(handle, .HEADERDATA, header_target)

	if progress_data != nil && progress_data.show {
		curl.easy_setopt(handle, .NOPROGRESS, c.long(0))
		curl.easy_setopt(handle, .XFERINFOFUNCTION, progress_callback)
		curl.easy_setopt(handle, .XFERINFODATA, progress_data)
	} else {
		curl.easy_setopt(handle, .NOPROGRESS, c.long(1))
	}

	return headers
}

get_timing :: proc(handle: ^curl.CURL) -> Timing_Info {
	namelookup_time: c.double
	connect_time: c.double
	appconnect_time: c.double
	pretransfer_time: c.double
	starttransfer_time: c.double
	total_time: c.double
	redirect_count: c.long
	downloaded: curl.off_t
	speed: curl.off_t

	curl.easy_getinfo(handle, .NAMELOOKUP_TIME, &namelookup_time)
	curl.easy_getinfo(handle, .CONNECT_TIME, &connect_time)
	curl.easy_getinfo(handle, .APPCONNECT_TIME, &appconnect_time)
	curl.easy_getinfo(handle, .PRETRANSFER_TIME, &pretransfer_time)
	curl.easy_getinfo(handle, .STARTTRANSFER_TIME, &starttransfer_time)
	curl.easy_getinfo(handle, .TOTAL_TIME, &total_time)
	curl.easy_getinfo(handle, .REDIRECT_COUNT, &redirect_count)
	curl.easy_getinfo(handle, .SIZE_DOWNLOAD_T, &downloaded)
	curl.easy_getinfo(handle, .SPEED_DOWNLOAD_T, &speed)

	dns_ms := namelookup_time * 1000.0
	tcp_ms := (connect_time - namelookup_time) * 1000.0
	tls_ms := (appconnect_time - connect_time) * 1000.0
	wait_ms := (starttransfer_time - pretransfer_time) * 1000.0
	xfer_ms := (total_time - starttransfer_time) * 1000.0

	if tcp_ms < 0 do tcp_ms = 0
	if tls_ms < 0 do tls_ms = 0
	if wait_ms < 0 do wait_ms = 0
	if xfer_ms < 0 do xfer_ms = 0

	return Timing_Info{
		namelookup_ms    = dns_ms,
		connect_ms       = tcp_ms,
		tls_ms           = tls_ms,
		server_wait_ms   = wait_ms,
		transfer_ms      = xfer_ms,
		total_ms         = total_time * 1000.0,
		redirect_count   = int(redirect_count),
		downloaded_bytes = i64(downloaded),
		speed_bps        = i64(speed),
	}
}

print_timing :: proc(t: Timing_Info) {
	fmt.eprintf("\n%s─── Timing ─────────────────────%s\n", ANSI_DIM, ANSI_RESET)
	fmt.eprintf("  %sDNS%s           %s\n", ANSI_CYAN, ANSI_RESET, format_ms(t.namelookup_ms))
	fmt.eprintf("  %sTCP%s           %s\n", ANSI_CYAN, ANSI_RESET, format_ms(t.connect_ms))
	if t.tls_ms > 0 do fmt.eprintf("  %sTLS%s           %s\n", ANSI_CYAN, ANSI_RESET, format_ms(t.tls_ms))
	fmt.eprintf("  %sServer Wait%s   %s\n", ANSI_CYAN, ANSI_RESET, format_ms(t.server_wait_ms))
	fmt.eprintf("  %sTransfer%s      %s\n", ANSI_CYAN, ANSI_RESET, format_ms(t.transfer_ms))
	fmt.eprintf("  %sRedirects%s     %d\n", ANSI_CYAN, ANSI_RESET, t.redirect_count)
	fmt.eprintf("  %sSpeed%s         %s/s\n", ANSI_CYAN, ANSI_RESET, format_bytes(t.speed_bps))
	fmt.eprintf("%s────────────────────────────────%s\n", ANSI_DIM, ANSI_RESET)
	fmt.eprintf("  %sTotal%s         %s\n", ANSI_BOLD, ANSI_RESET, format_ms(t.total_ms))
}

print_response_line :: proc(method, url: string, status: int, duration: time.Duration, size: i64) {
	color := status_color(status)
	label := status_label(status)

	fmt.eprintf("\n%s%s %s%s ", ANSI_DIM, method, url, ANSI_RESET)
	fmt.eprintf("%s%s%d %s%s ", color, ANSI_BOLD, status, label, ANSI_RESET)
	fmt.eprintf("%s%s  %s%s\n", ANSI_DIM, format_duration(duration), format_bytes(size), ANSI_RESET)
}

print_headers_pretty :: proc(raw_headers: []u8) {
	header_str := string(raw_headers)
	lines := strings.split_lines(header_str)
	defer delete(lines)

	for line in lines {
		trimmed := strings.trim_space(line)
		if len(trimmed) == 0 do continue

		if strings.has_prefix(trimmed, "HTTP/") {
			fmt.printf("%s%s%s\n", ANSI_BOLD, trimmed, ANSI_RESET)
			continue
		}

		if idx := strings.index(trimmed, ":"); idx >= 0 {
			name := trimmed[:idx]
			value := strings.trim_left_space(trimmed[idx + 1:])
			fmt.printf("%s%s%s: %s\n", ANSI_CYAN, name, ANSI_RESET, value)
		} else {
			fmt.println(trimmed)
		}
	}
}

write_file_all :: proc(path: string, data: []u8) {
	f, err := os.open(path, os.O_WRONLY | os.O_CREATE | os.O_TRUNC, os.Permissions_Read_All + {.Write_User})
	if err != nil do fail(fmt.tprintf("cannot open '%s': %v", path, err))
	defer os.close(f)

	written, werr := os.write(f, data)
	if werr != nil || written != len(data) do fail(fmt.tprintf("failed writing '%s'", path))
}

file_size_or_zero :: proc(path: string) -> i64 {
	fi, err := os.stat(path, context.allocator)
	if err != nil do return 0
	defer os.file_info_delete(fi, context.allocator)
	return fi.size
}

open_output_file :: proc(path: string, resume: bool) -> (^os.File, i64) {
	resume_from: i64 = 0
	flags := os.O_WRONLY | os.O_CREATE

	if resume {
		resume_from = file_size_or_zero(path)
		flags |= os.O_APPEND
	} else {
		flags |= os.O_TRUNC
	}

	f, err := os.open(path, flags, os.Permissions_Read_All + {.Write_User})
	if err != nil do fail(fmt.tprintf("cannot open '%s' for writing: %v", path, err))
	return f, resume_from
}

perform_once :: proc(
	cfg: ^Config,
	url: string,
	method: string,
	payload: ^Payload,
	write_to_file: bool,
	discard_body: bool = false,
) -> (Request_Result, Write_Target, Write_Target) {
	if !valid_url(url) do fail("URL must start with http:// or https://", 2)

	handle := curl.easy_init()
	if handle == nil do fail("failed to create curl handle")
	defer curl.easy_cleanup(handle)

	body := Write_Target{discard = discard_body}
	head := Write_Target{}
	out_file: ^os.File = nil
	resume_from: i64 = 0

	if write_to_file && cfg.output_path != "" {
		out_file, resume_from = open_output_file(cfg.output_path, cfg.resume)
		body.use_file = true
		body.file = out_file
	}
	defer if out_file != nil do os.close(out_file)

	progress_data := Progress_Data{
		show        = (cfg.progress || write_to_file) && !cfg.silent,
		start_time  = time.now(),
		last_update = time.now(),
	}

	headers := setup_handle(handle, cfg, url, method, payload, &body, &head, &progress_data, resume_from)
	defer if headers != nil do curl.slist_free_all(headers)

	start := time.now()
	res := curl.easy_perform(handle)
	duration := time.diff(start, time.now())

	if progress_data.show do fmt.eprintf("%s", ANSI_CLEAR_LINE)

	status_code: c.long
	curl.easy_getinfo(handle, .RESPONSE_CODE, &status_code)
	timing := get_timing(handle)

	result := Request_Result{
		ok        = res == .E_OK,
		curl_code = res,
		status    = int(status_code),
		duration  = duration,
		bytes     = body.total_written,
		timing    = timing,
	}

	return result, body, head
}

run_single :: proc(cfg: ^Config, method: string, payload: ^Payload) -> int {
	final_result: Request_Result
	final_body := Write_Target{}
	final_head := Write_Target{}
	attempts := cfg.retry_count + 1

	for attempt := 0; attempt < attempts; attempt += 1 {
		if attempt > 0 && !cfg.silent {
			fmt.eprintf(
				"%s%s%s retry %d/%d after %dms\n",
				ANSI_YELLOW,
				SYM_WARN,
				ANSI_RESET,
				attempt,
				cfg.retry_count,
				cfg.retry_delay_ms,
			)
			time.sleep(time.Duration(f64(cfg.retry_delay_ms) * f64(time.Millisecond)))
		}

		result, body, head := perform_once(cfg, cfg.url, method, payload, cfg.output_path != "")
		final_result = result
		final_body = body
		final_head = head

		retry := false
		if result.curl_code != .E_OK {
			retry = attempt < cfg.retry_count
		} else if is_retryable_status(result.status) {
			retry = attempt < cfg.retry_count
		}

		if !retry do break
		delete(body.buf)
		delete(head.buf)
	}

	defer delete(final_body.buf)
	defer delete(final_head.buf)

	if final_result.curl_code != .E_OK {
		if cfg.show_error || !cfg.silent do fail(fmt.tprintf("request failed: %s", curl.easy_strerror(final_result.curl_code)), 1)
		return 1
	}

	if cfg.fail_http && final_result.status >= 400 {
		if cfg.show_error || !cfg.silent do fmt.eprintf(
			"%s%s:%s HTTP %d %s\n",
			ANSI_RED,
			APP_NAME,
			ANSI_RESET,
			final_result.status,
			status_label(final_result.status),
		)
		return 22
	}

	pretty := !cfg.silent && !cfg.raw && !cfg.clean && os.is_tty(os.stderr)
	if pretty do print_response_line(method, cfg.url, final_result.status, final_result.duration, final_result.bytes)
	if cfg.debug do print_timing(final_result.timing)
	if cfg.dump_headers_path != "" && len(final_head.buf) > 0 do write_file_all(cfg.dump_headers_path, final_head.buf[:])

	if cfg.include_headers && len(final_head.buf) > 0 {
		if pretty {
			print_headers_pretty(final_head.buf[:])
			fmt.println()
		} else {
			os.write(os.stdout, final_head.buf[:])
		}
	}

	if cfg.output_path == "" && len(final_body.buf) > 0 {
		if cfg.json_pretty && (final_body.buf[0] == '{' || final_body.buf[0] == '[') {
			json_pretty_print(final_body.buf[:])
		} else {
			os.write(os.stdout, final_body.buf[:])
			if !cfg.raw && !cfg.clean && os.is_tty(os.stdout) && final_body.buf[len(final_body.buf) - 1] != '\n' do fmt.println()
		}
	}

	if cfg.output_path != "" && !cfg.silent do fmt.eprintf(
		"%s%s%s saved %s%s%s (%s)\n",
		ANSI_GREEN,
		SYM_OK,
		ANSI_RESET,
		ANSI_BOLD,
		cfg.output_path,
		ANSI_RESET,
		format_bytes(final_result.bytes),
	)

	if final_result.status >= 400 do return 1
	return 0
}

run_benchmark :: proc(cfg: ^Config, method: string, payload: ^Payload) -> int {
	if !valid_url(cfg.url) do fail("URL must start with http:// or https://", 2)

	times := make([dynamic]f64)
	defer delete(times)

	failures := 0

	fmt.eprintf("\n%s%sBenchmarking%s %s\n", ANSI_BOLD, ANSI_CYAN, ANSI_RESET, cfg.url)
	fmt.eprintf("%s%d requests%s\n\n", ANSI_DIM, cfg.bench_count, ANSI_RESET)

	quiet_cfg := cfg^
	quiet_cfg.silent = true
	quiet_cfg.progress = false
	quiet_cfg.debug = false

	for i := 0; i < cfg.bench_count; i += 1 {
		result, body, head := perform_once(&quiet_cfg, cfg.url, method, payload, false, true)
		delete(body.buf)
		delete(head.buf)

		if result.curl_code != .E_OK {
			failures += 1
			fmt.eprintf("  %s%s%s #%d failed: %s\n", ANSI_RED, SYM_FAIL, ANSI_RESET, i + 1, curl.easy_strerror(result.curl_code))
			continue
		}

		ms := f64(time.duration_milliseconds(result.duration))
		append(&times, ms)

		fmt.eprintf(
			"  %s#%-4d%s %s%d%s %s\n",
			ANSI_DIM,
			i + 1,
			ANSI_RESET,
			status_color(result.status),
			result.status,
			ANSI_RESET,
			format_ms(ms),
		)
	}

	if len(times) == 0 {
		fmt.eprintf("\n%sall requests failed%s\n", ANSI_RED, ANSI_RESET)
		return 1
	}

	total: f64 = 0
	min_t := times[0]
	max_t := times[0]

	for t in times {
		total += t
		if t < min_t do min_t = t
		if t > max_t do max_t = t
	}

	avg := total / f64(len(times))

	variance: f64 = 0
	for t in times {
		diff := t - avg
		variance += diff * diff
	}

	stddev := math.sqrt(variance / f64(len(times)))

	fmt.eprintf("\n%s─── Results ────────────────────%s\n", ANSI_DIM, ANSI_RESET)
	fmt.eprintf("  %sRequests%s    %d ok, %d failed\n", ANSI_WHITE, ANSI_RESET, len(times), failures)
	fmt.eprintf("  %sAverage%s     %s\n", ANSI_CYAN, ANSI_RESET, format_ms(avg))
	fmt.eprintf("  %sMin%s         %s\n", ANSI_GREEN, ANSI_RESET, format_ms(min_t))
	fmt.eprintf("  %sMax%s         %s\n", ANSI_YELLOW, ANSI_RESET, format_ms(max_t))
	fmt.eprintf("  %sStd Dev%s     %s\n", ANSI_MAGENTA, ANSI_RESET, format_ms(stddev))
	fmt.eprintf("  %sReq/sec%s     %.2f\n", ANSI_WHITE, ANSI_RESET, 1000.0 / avg)

	if failures > 0 do return 1
	return 0
}

load_urls_file :: proc(path: string) -> [dynamic]string {
	data, err := os.read_entire_file_from_path(path, context.allocator)
	if err != nil do fail(fmt.tprintf("cannot read URL file '%s': %v", path, err))
	defer delete(data)

	urls := make([dynamic]string)
	lines := strings.split_lines(string(data))
	defer delete(lines)

	for line in lines {
		trimmed := strings.trim_space(line)
		if len(trimmed) == 0 do continue
		if strings.has_prefix(trimmed, "#") do continue
		append(&urls, strings.clone(trimmed))
	}

	return urls
}

find_job_by_handle :: proc(jobs: []Batch_Job, h: ^curl.CURL) -> int {
	for job, idx in jobs {
		if job.handle == h do return idx
	}
	return -1
}

cleanup_job :: proc(job: ^Batch_Job) {
	if job.headers != nil do curl.slist_free_all(job.headers)
	if job.handle != nil do curl.easy_cleanup(job.handle)
	delete(job.body.buf)
	delete(job.head.buf)
}

run_batch :: proc(cfg: ^Config, method: string, payload: ^Payload) -> int {
	urls := load_urls_file(cfg.batch_file)
	defer {
		for u in urls do delete(u)
		delete(urls)
	}

	if len(urls) == 0 do fail("batch file has no URLs")
	for u in urls {
		if !valid_url(u) do fail(fmt.tprintf("invalid URL in batch file: %s", u), 2)
	}

	multi := curl.multi_init()
	if multi == nil do fail("failed to create curl multi handle")
	defer curl.multi_cleanup(multi)

	curl.multi_setopt(multi, .MAX_TOTAL_CONNECTIONS, c.long(cfg.parallel))
	curl.multi_setopt(multi, .MAX_HOST_CONNECTIONS, c.long(cfg.parallel))

	jobs := make([]Batch_Job, len(urls))
	defer {
		for i in 0..<len(jobs) do cleanup_job(&jobs[i])
		delete(jobs)
	}

	quiet_cfg := cfg^
	quiet_cfg.progress = false
	quiet_cfg.debug = false

	for url, i in urls {
		h := curl.easy_init()
		if h == nil do fail("failed to create curl handle for batch job")

		jobs[i].url = url
		jobs[i].handle = h
		jobs[i].body.discard = true
		jobs[i].head.discard = true
		jobs[i].start = time.now()

		headers := setup_handle(h, &quiet_cfg, url, method, payload, &jobs[i].body, &jobs[i].head, nil, 0)
		jobs[i].headers = headers

		mres := curl.multi_add_handle(multi, h)
		if mres != .OK do fail(fmt.tprintf("curl multi add failed: %s", curl.multi_strerror(mres)))
	}

	fmt.eprintf("\n%s%sBatch%s %d URLs, %d parallel\n\n", ANSI_BOLD, ANSI_CYAN, ANSI_RESET, len(urls), cfg.parallel)

	running: i32 = 0
	mres := curl.multi_perform(multi, &running)
	if mres != .OK && mres != .CALL_MULTI_PERFORM do fail(fmt.tprintf("curl multi perform failed: %s", curl.multi_strerror(mres)))

	completed := 0
	success := 0
	failed := 0
	total_bytes: i64 = 0
	start_all := time.now()

	for completed < len(jobs) {
		numfds: i32 = 0
		curl.multi_poll(multi, cast([^]curl.waitfd)nil, 0, 1000, &numfds)

		mres = curl.multi_perform(multi, &running)
		if mres != .OK && mres != .CALL_MULTI_PERFORM do fail(fmt.tprintf("curl multi perform failed: %s", curl.multi_strerror(mres)))

		for {
			msgs_left: i32 = 0
			msg := curl.multi_info_read(multi, &msgs_left)
			if msg == nil do break

			if msg.msg == .DONE {
				idx := find_job_by_handle(jobs[:], msg.easy_handle)
				if idx < 0 do continue

				job := &jobs[idx]
				if job.done do continue

				job.done = true
				job.result = msg.data.result
				job.duration = time.diff(job.start, time.now())

				status_code: c.long
				curl.easy_getinfo(job.handle, .RESPONSE_CODE, &status_code)
				job.status = int(status_code)

				total_bytes += job.body.total_written
				completed += 1

				ok := job.result == .E_OK && (!cfg.fail_http || job.status < 400)

				if ok {
					success += 1
					fmt.eprintf(
						"  %s%s%s %-4d %s%d%s %-9s %s%s%s %s\n",
						ANSI_GREEN,
						SYM_OK,
						ANSI_RESET,
						idx + 1,
						status_color(job.status),
						job.status,
						ANSI_RESET,
						format_duration(job.duration),
						ANSI_DIM,
						format_bytes(job.body.total_written),
						ANSI_RESET,
						job.url,
					)
				} else {
					failed += 1

					if job.result != .E_OK {
						fmt.eprintf(
							"  %s%s%s %-4d curl %-8s %s%s%s\n",
							ANSI_RED,
							SYM_FAIL,
							ANSI_RESET,
							idx + 1,
							format_duration(job.duration),
							ANSI_DIM,
							job.url,
							ANSI_RESET,
						)
						fmt.eprintf("       %s%s%s\n", ANSI_DIM, curl.easy_strerror(job.result), ANSI_RESET)
					} else {
						fmt.eprintf(
							"  %s%s%s %-4d %s%d%s %-9s %s%s%s %s\n",
							ANSI_RED,
							SYM_FAIL,
							ANSI_RESET,
							idx + 1,
							status_color(job.status),
							job.status,
							ANSI_RESET,
							format_duration(job.duration),
							ANSI_DIM,
							format_bytes(job.body.total_written),
							ANSI_RESET,
							job.url,
						)
					}
				}

				curl.multi_remove_handle(multi, job.handle)
			}
		}
	}

	total_dur := time.diff(start_all, time.now())

	fmt.eprintf("\n%s─── Summary ────────────────────%s\n", ANSI_DIM, ANSI_RESET)
	fmt.eprintf("  %sSuccess%s     %d\n", ANSI_GREEN, ANSI_RESET, success)
	fmt.eprintf("  %sFailed%s      %d\n", ANSI_RED, ANSI_RESET, failed)
	fmt.eprintf("  %sTotal%s       %s, %s\n", ANSI_CYAN, ANSI_RESET, format_duration(total_dur), format_bytes(total_bytes))

	if failed > 0 do return 1
	return 0
}

Http_Request :: struct {
	method:         string,
	target:         string,
	path:           string,
	query:          string,
	version:        string,
	content_length: int,
	body:           []u8,
}

append_str :: proc(buf: ^[dynamic]u8, text: string) {
	if len(text) > 0 do append(buf, ..raw_data(text)[:len(text)])
}

server_send_str :: proc(sock: net.TCP_Socket, text: string) -> bool {
	if len(text) == 0 do return true
	_, err := net.send_tcp(sock, raw_data(text)[:len(text)])
	return err == nil
}

server_send_bytes :: proc(sock: net.TCP_Socket, data: []u8) -> bool {
	if len(data) == 0 do return true
	_, err := net.send_tcp(sock, data)
	return err == nil
}

http_reason :: proc(code: int) -> string {
	switch code {
	case 200:
		return "OK"
	case 201:
		return "Created"
	case 204:
		return "No Content"
	case 400:
		return "Bad Request"
	case 403:
		return "Forbidden"
	case 404:
		return "Not Found"
	case 405:
		return "Method Not Allowed"
	case 413:
		return "Payload Too Large"
	case 500:
		return "Internal Server Error"
	}
	return status_label(code)
}

server_header :: proc(code: int, content_type: string, length: int, extra: string = "") -> string {
	return fmt.tprintf(
		"HTTP/1.1 %d %s\r\nServer: %s/%s\r\nContent-Type: %s\r\nContent-Length: %d\r\nConnection: close\r\nX-Volt: tiny-server\r\n%s\r\n",
		code,
		http_reason(code),
		APP_NAME,
		APP_VERSION,
		content_type,
		length,
		extra,
	)
}

server_send_response :: proc(
	sock: net.TCP_Socket,
	code: int,
	content_type: string,
	body: []u8,
	extra: string = "",
) {
	header := server_header(code, content_type, len(body), extra)
	server_send_str(sock, header)
	server_send_bytes(sock, body)
}

server_send_text :: proc(
	sock: net.TCP_Socket,
	code: int,
	content_type: string,
	body: string,
	extra: string = "",
) {
	header := server_header(code, content_type, len(body), extra)
	server_send_str(sock, header)
	server_send_str(sock, body)
}

server_send_error :: proc(sock: net.TCP_Socket, code: int, msg: string) {
	body := make([dynamic]u8)
	defer delete(body)

	append_str(&body, "{\"ok\":false,\"status\":")
	append_str(&body, fmt.tprintf("%d", code))
	append_str(&body, ",\"error\":\"")
	json_escape_to(&body, msg)
	append_str(&body, "\"}\n")

	server_send_response(sock, code, "application/json; charset=utf-8", body[:])
}

hex_value :: proc(ch: u8) -> (int, bool) {
	if ch >= '0' && ch <= '9' do return int(ch - '0'), true
	if ch >= 'a' && ch <= 'f' do return int(ch - 'a') + 10, true
	if ch >= 'A' && ch <= 'F' do return int(ch - 'A') + 10, true
	return 0, false
}

percent_decode_simple :: proc(text: string) -> (string, bool) {
	out := make([dynamic]u8, context.temp_allocator)
	i := 0

	for i < len(text) {
		ch := text[i]

		if ch == '%' {
			if i + 2 >= len(text) do return "", false

			hi, ok1 := hex_value(text[i + 1])
			lo, ok2 := hex_value(text[i + 2])
			if !ok1 || !ok2 do return "", false

			append(&out, u8((hi << 4) | lo))
			i += 3
			continue
		}

		if ch == '+' {
			append(&out, u8(' '))
		} else {
			append(&out, ch)
		}

		i += 1
	}

	return string(out[:]), true
}

is_path_bad :: proc(text: string) -> bool {
	if strings.contains(text, "..") do return true
	if strings.contains(text, "\\") do return true
	for ch in text {
		if ch < 32 do return true
	}
	return false
}

join_path2 :: proc(a, b: string) -> string {
	if b == "" || b == "." do return a
	if strings.has_suffix(a, "/") do return fmt.tprintf("%s%s", a, b)
	return fmt.tprintf("%s/%s", a, b)
}

server_path_from_url :: proc(root, path: string) -> (string, bool) {
	decoded, ok := percent_decode_simple(path)
	if !ok do return "", false

	rel := decoded
	for strings.has_prefix(rel, "/") {
		rel = rel[1:]
	}

	if rel == "" do rel = "."
	if is_path_bad(rel) do return "", false

	return join_path2(root, rel), true
}

server_mime :: proc(path: string) -> string {
	lower := strings.to_lower(path, context.temp_allocator)

	switch {
	case strings.has_suffix(lower, ".html") || strings.has_suffix(lower, ".htm"):
		return "text/html; charset=utf-8"
	case strings.has_suffix(lower, ".css"):
		return "text/css; charset=utf-8"
	case strings.has_suffix(lower, ".js") || strings.has_suffix(lower, ".mjs"):
		return "text/javascript; charset=utf-8"
	case strings.has_suffix(lower, ".json"):
		return "application/json; charset=utf-8"
	case strings.has_suffix(lower, ".txt") || strings.has_suffix(lower, ".log"):
		return "text/plain; charset=utf-8"
	case strings.has_suffix(lower, ".png"):
		return "image/png"
	case strings.has_suffix(lower, ".jpg") || strings.has_suffix(lower, ".jpeg"):
		return "image/jpeg"
	case strings.has_suffix(lower, ".gif"):
		return "image/gif"
	case strings.has_suffix(lower, ".webp"):
		return "image/webp"
	case strings.has_suffix(lower, ".svg"):
		return "image/svg+xml"
	case strings.has_suffix(lower, ".wasm"):
		return "application/wasm"
	case strings.has_suffix(lower, ".pdf"):
		return "application/pdf"
	case strings.has_suffix(lower, ".zip"):
		return "application/zip"
	}

	return "application/octet-stream"
}

html_escape_to :: proc(buf: ^[dynamic]u8, text: string) {
	for ch in text {
		switch ch {
		case '&':
			append_str(buf, "&amp;")
		case '<':
			append_str(buf, "&lt;")
		case '>':
			append_str(buf, "&gt;")
		case '"':
			append_str(buf, "&quot;")
		case:
			append(buf, u8(ch))
		}
	}
}

json_escape_to :: proc(buf: ^[dynamic]u8, text: string) {
	for ch in text {
		switch ch {
		case '\\':
			append_str(buf, "\\\\")
		case '"':
			append_str(buf, "\\\"")
		case '\n':
			append_str(buf, "\\n")
		case '\r':
			append_str(buf, "\\r")
		case '\t':
			append_str(buf, "\\t")
		case:
			append(buf, u8(ch))
		}
	}
}

request_content_length_from_header :: proc(header_text: string) -> int {
	lines := strings.split_lines(header_text)
	defer delete(lines)

	for line in lines {
		trimmed := strings.trim_space(line)
		if idx := strings.index(trimmed, ":"); idx >= 0 {
			name := strings.trim_space(trimmed[:idx])
			value := strings.trim_space(trimmed[idx + 1:])
			if eq_ignore_case(name, "Content-Length") do return int(strconv.parse_int(value) or_else 0)
		}
	}

	return 0
}

parse_http_request :: proc(raw: []u8, header_end: int) -> (Http_Request, bool) {
	header_text := string(raw[:header_end])
	lines := strings.split_lines(header_text)
	defer delete(lines)

	if len(lines) == 0 do return Http_Request{}, false

	first := strings.trim_space(lines[0])
	sp1 := strings.index(first, " ")
	if sp1 < 0 do return Http_Request{}, false

	rest := strings.trim_left_space(first[sp1 + 1:])
	sp2 := strings.index(rest, " ")
	if sp2 < 0 do return Http_Request{}, false

	method := first[:sp1]
	target := rest[:sp2]
	version := strings.trim_space(rest[sp2 + 1:])

	path := target
	query := ""
	if q := strings.index(target, "?"); q >= 0 {
		path = target[:q]
		query = target[q + 1:]
	}

	content_length := request_content_length_from_header(header_text)
	body_start := header_end + 4
	body: []u8 = nil

	if body_start < len(raw) {
		body = raw[body_start:]
		if content_length > 0 && len(body) > content_length do body = body[:content_length]
	}

	return Http_Request{
		method         = method,
		target         = target,
		path           = path,
		query          = query,
		version        = version,
		content_length = content_length,
		body           = body,
	}, true
}

server_read_request :: proc(sock: net.TCP_Socket, max_request: int) -> (Http_Request, [dynamic]u8, bool) {
	raw := make([dynamic]u8)
	chunk := make([]u8, 8192)
	defer delete(chunk)

	header_end := -1
	content_length := 0

	for {
		n, err := net.recv_tcp(sock, chunk)
		if err != nil do return Http_Request{}, raw, false
		if n <= 0 do return Http_Request{}, raw, false

		append(&raw, ..chunk[:n])

		if len(raw) > max_request do return Http_Request{}, raw, false

		if header_end < 0 {
			if idx := strings.index(string(raw[:]), "\r\n\r\n"); idx >= 0 {
				header_end = idx
				content_length = request_content_length_from_header(string(raw[:header_end]))
				if header_end + 4 + content_length > max_request do return Http_Request{}, raw, false
			}
		}

		if header_end >= 0 && len(raw) >= header_end + 4 + content_length do break
	}

	req, ok := parse_http_request(raw[:], header_end)
	return req, raw, ok
}

server_send_file :: proc(sock: net.TCP_Socket, path: string, method: string) {
	fi, stat_err := os.stat(path, context.temp_allocator)
	if stat_err != nil {
		server_send_error(sock, 404, "not found")
		return
	}
	defer os.file_info_delete(fi, context.temp_allocator)

	if fi.type != .Regular {
		server_send_error(sock, 403, "not a regular file")
		return
	}

	extra := fmt.tprintf("Last-Modified: %v\r\n", fi.modification_time)
	header := server_header(200, server_mime(path), int(fi.size), extra)
	server_send_str(sock, header)

	if method == "HEAD" do return

	f, err := os.open(path)
	if err != nil do return
	defer os.close(f)

	buf := make([]u8, 64 * 1024)
	defer delete(buf)

	for {
		n, rerr := os.read(f, buf)
		if n > 0 {
			if !server_send_bytes(sock, buf[:n]) do break
		}
		if rerr != nil || n <= 0 do break
	}
}

server_send_directory_listing :: proc(sock: net.TCP_Socket, req_path, fs_path: string) {
	infos, err := os.read_directory_by_path(fs_path, 0, context.allocator)
	if err != nil {
		server_send_error(sock, 403, "directory not readable")
		return
	}
	defer os.file_info_slice_delete(infos, context.allocator)

	body := make([dynamic]u8)
	defer delete(body)

	append_str(&body, "<!doctype html><html><head><meta charset=\"utf-8\"><meta name=\"viewport\" content=\"width=device-width,initial-scale=1\"><title>volt directory</title><style>body{font-family:system-ui,sans-serif;margin:2rem;max-width:900px}a{text-decoration:none}table{width:100%;border-collapse:collapse}td{padding:.35rem;border-bottom:1px solid #ddd}.dim{color:#777}</style></head><body><h1>volt directory: ")
	html_escape_to(&body, req_path)
	append_str(&body, "</h1><p class=\"dim\">Endpoints: <code>/__volt/health</code>, <code>/__volt/manifest</code>, <code>/__volt/echo</code></p><table><tr><td><a href=\"../\">../</a></td><td></td></tr>")

	base := req_path
	if !strings.has_suffix(base, "/") do base = fmt.tprintf("%s/", base)

	for info in infos {
		if info.name == "." || info.name == ".." do continue

		suffix := ""
		if info.type == .Directory do suffix = "/"

		href := fmt.tprintf("%s%s%s", base, info.name, suffix)

		append_str(&body, "<tr><td><a href=\"")
		html_escape_to(&body, href)
		append_str(&body, "\">")
		html_escape_to(&body, info.name)
		append_str(&body, suffix)
		append_str(&body, "</a></td><td class=\"dim\">")

		if info.type == .Regular {
			append_str(&body, format_bytes(info.size))
		} else {
			append_str(&body, "dir")
		}

		append_str(&body, "</td></tr>")
	}

	append_str(&body, "</table></body></html>\n")
	server_send_response(sock, 200, "text/html; charset=utf-8", body[:])
}

server_send_manifest :: proc(sock: net.TCP_Socket, root: string) {
	infos, err := os.read_directory_by_path(root, 0, context.allocator)
	if err != nil {
		server_send_error(sock, 500, "cannot read manifest")
		return
	}
	defer os.file_info_slice_delete(infos, context.allocator)

	body := make([dynamic]u8)
	defer delete(body)

	append_str(&body, "{\"ok\":true,\"root\":\"")
	json_escape_to(&body, root)
	append_str(&body, "\",\"files\":[]")

	if len(infos) > 0 {
		clear(&body)
		append_str(&body, "{\"ok\":true,\"root\":\"")
		json_escape_to(&body, root)
		append_str(&body, "\",\"files\":[")

		first := true
		for info in infos {
			if info.name == "." || info.name == ".." do continue

			if !first do append_str(&body, ",")
			first = false

			kind := "other"
			if info.type == .Regular do kind = "file"
			if info.type == .Directory do kind = "dir"

			append_str(&body, "{\"name\":\"")
			json_escape_to(&body, info.name)
			append_str(&body, "\",\"type\":\"")
			append_str(&body, kind)
			append_str(&body, "\",\"size\":")
			append_str(&body, fmt.tprintf("%d", info.size))
			append_str(&body, "}")
		}

		append_str(&body, "]")
	}

	append_str(&body, "}\n")
	server_send_response(sock, 200, "application/json; charset=utf-8", body[:])
}

server_send_echo :: proc(sock: net.TCP_Socket, req: Http_Request) {
	body := make([dynamic]u8)
	defer delete(body)

	append_str(&body, "{\"ok\":true,\"method\":\"")
	json_escape_to(&body, req.method)
	append_str(&body, "\",\"target\":\"")
	json_escape_to(&body, req.target)
	append_str(&body, "\",\"path\":\"")
	json_escape_to(&body, req.path)
	append_str(&body, "\",\"query\":\"")
	json_escape_to(&body, req.query)
	append_str(&body, "\",\"body_bytes\":")
	append_str(&body, fmt.tprintf("%d", len(req.body)))
	append_str(&body, "}\n")

	server_send_response(sock, 200, "application/json; charset=utf-8", body[:])
}

server_handle_upload :: proc(sock: net.TCP_Socket, cfg: ^Config, req: Http_Request) {
	prefix :: "/__volt/upload/"

	if !cfg.serve_allow_upload {
		server_send_error(sock, 403, "uploads disabled")
		return
	}

	if !strings.has_prefix(req.path, prefix) {
		server_send_error(sock, 404, "upload path must be /__volt/upload/<name>")
		return
	}

	name := req.path[len(prefix):]
	decoded, ok := percent_decode_simple(name)
	if !ok || decoded == "" || strings.contains(decoded, "/") || is_path_bad(decoded) {
		server_send_error(sock, 400, "bad upload name")
		return
	}

	if !os.exists(cfg.serve_upload_dir) {
		mkerr := os.make_directory_all(cfg.serve_upload_dir)
		if mkerr != nil {
			server_send_error(sock, 500, "cannot create upload directory")
			return
		}
	}

	out_path := join_path2(cfg.serve_upload_dir, decoded)
	f, err := os.open(out_path, os.O_WRONLY | os.O_CREATE | os.O_TRUNC, os.Permissions_Read_All + {.Write_User})
	if err != nil {
		server_send_error(sock, 500, "cannot write upload")
		return
	}
	defer os.close(f)

	written, werr := os.write(f, req.body)
	if werr != nil || written != len(req.body) {
		server_send_error(sock, 500, "upload write failed")
		return
	}

	body := make([dynamic]u8)
	defer delete(body)

	append_str(&body, "{\"ok\":true,\"saved\":\"")
	json_escape_to(&body, out_path)
	append_str(&body, "\",\"bytes\":")
	append_str(&body, fmt.tprintf("%d", written))
	append_str(&body, "}\n")

	server_send_response(sock, 201, "application/json; charset=utf-8", body[:])
}

server_handle_static :: proc(sock: net.TCP_Socket, cfg: ^Config, req: Http_Request) {
	fs_path, ok := server_path_from_url(cfg.serve_dir, req.path)
	if !ok {
		server_send_error(sock, 403, "unsafe path")
		return
	}

	if os.is_directory(fs_path) {
		index_path := join_path2(fs_path, "index.html")
		if os.is_file(index_path) {
			server_send_file(sock, index_path, req.method)
			return
		}

		if cfg.serve_dir_list {
			server_send_directory_listing(sock, req.path, fs_path)
			return
		}

		server_send_error(sock, 403, "directory listing disabled")
		return
	}

	if os.is_file(fs_path) {
		server_send_file(sock, fs_path, req.method)
		return
	}

	if cfg.serve_spa {
		index_path := join_path2(cfg.serve_dir, "index.html")
		if os.is_file(index_path) {
			server_send_file(sock, index_path, req.method)
			return
		}
	}

	server_send_error(sock, 404, "not found")
}

server_handle_client :: proc(
	sock: net.TCP_Socket,
	peer: net.Endpoint,
	cfg: ^Config,
	start_time: time.Time,
) {
	defer net.close(sock)

	req, raw, ok := server_read_request(sock, cfg.serve_max_request)
	defer delete(raw)

	if !ok {
		server_send_error(sock, 400, "bad request or request too large")
		return
	}

	fmt.eprintf("%sserve%s %s %s from %v\n", ANSI_CYAN, ANSI_RESET, req.method, req.target, peer)

	if req.path == "/__volt/health" {
		uptime_ms := time.duration_milliseconds(time.diff(start_time, time.now()))
		body := make([dynamic]u8)
		defer delete(body)

		append_str(&body, "{\"ok\":true,\"app\":\"")
		json_escape_to(&body, APP_NAME)
		append_str(&body, "\",\"version\":\"")
		json_escape_to(&body, APP_VERSION)
		append_str(&body, "\",\"uptime_ms\":")
		append_str(&body, fmt.tprintf("%.0f", uptime_ms))
		append_str(&body, "}\n")

		server_send_response(sock, 200, "application/json; charset=utf-8", body[:])
		return
	}

	if req.path == "/__volt/manifest" {
		server_send_manifest(sock, cfg.serve_dir)
		return
	}

	if req.path == "/__volt/echo" {
		server_send_echo(sock, req)
		return
	}

	if req.method == "POST" || req.method == "PUT" {
		if strings.has_prefix(req.path, "/__volt/upload/") {
			server_handle_upload(sock, cfg, req)
			return
		}

		server_send_error(sock, 405, "write requests only allowed at /__volt/upload/<name>")
		return
	}

	if req.method != "GET" && req.method != "HEAD" {
		server_send_error(sock, 405, "method not allowed")
		return
	}

	server_handle_static(sock, cfg, req)
}

run_server :: proc(cfg: ^Config) -> int {
	bind_addr := net.IP4_Loopback

	switch cfg.serve_bind {
	case "0.0.0.0", "*", "any":
		bind_addr = net.IP4_Any

	case "127.0.0.1", "localhost":
		bind_addr = net.IP4_Loopback

	case:
		parsed, ok := net.parse_ip4_address(cfg.serve_bind)
		if ok {
			bind_addr = parsed
		} else {
			warn(fmt.tprintf("could not parse bind address '%s', using 127.0.0.1", cfg.serve_bind))
			bind_addr = net.IP4_Loopback
		}
	}

	endpoint := net.Endpoint{address = bind_addr, port = cfg.serve_port}
	listener, err := net.listen_tcp(endpoint)
	if err != nil {
		fmt.eprintf(
			"%s%s:%s failed to listen on %s:%d: %v\n",
			ANSI_RED,
			APP_NAME,
			ANSI_RESET,
			cfg.serve_bind,
			cfg.serve_port,
			err,
		)
		return 1
	}
	defer net.close(listener)

	if !os.exists(cfg.serve_dir) || !os.is_directory(cfg.serve_dir) {
		fmt.eprintf(
			"%s%s:%s serve directory does not exist or is not a directory: %s\n",
			ANSI_RED,
			APP_NAME,
			ANSI_RESET,
			cfg.serve_dir,
		)
		return 1
	}

	start_time := time.now()

	fmt.eprintf("\n%s%s%s%s serving %s%s%s\n", ANSI_BOLD, ANSI_CYAN, APP_NAME, ANSI_RESET, ANSI_BOLD, cfg.serve_dir, ANSI_RESET)
	fmt.eprintf("  url:        %shttp://%s:%d/%s\n", ANSI_GREEN, cfg.serve_bind, cfg.serve_port, ANSI_RESET)
	fmt.eprintf("  health:     %shttp://%s:%d/__volt/health%s\n", ANSI_GREEN, cfg.serve_bind, cfg.serve_port, ANSI_RESET)
	fmt.eprintf("  manifest:   %shttp://%s:%d/__volt/manifest%s\n", ANSI_GREEN, cfg.serve_bind, cfg.serve_port, ANSI_RESET)
	if cfg.serve_allow_upload do fmt.eprintf(
		"  uploads:    %shttp://%s:%d/__volt/upload/<name>%s -> %s\n",
		ANSI_GREEN,
		cfg.serve_bind,
		cfg.serve_port,
		ANSI_RESET,
		cfg.serve_upload_dir,
	)
	fmt.eprintf("  bind:       %s:%d\n", cfg.serve_bind, cfg.serve_port)
	fmt.eprintf("  max req:    %s\n", format_bytes(i64(cfg.serve_max_request)))
	fmt.eprintf("  stop:       Ctrl+C\n\n")

	for {
		client, peer, aerr := net.accept_tcp(listener)
		if aerr != nil {
			fmt.eprintf("%saccept:%s %v\n", ANSI_YELLOW, ANSI_RESET, aerr)
			continue
		}
		server_handle_client(client, peer, cfg, start_time)
	}

	return 0
}

app_main :: proc() -> int {
	cfg := Config{
		follow_redirects = true,
		timeout_seconds  = DEFAULT_TIMEOUT,
		connect_timeout  = DEFAULT_CONNECT_TIMEOUT,
		max_redirects    = DEFAULT_MAX_REDIRECTS,
		parallel         = DEFAULT_PARALLEL,
		serve_dir_list   = true,
	}

	parse_args(&cfg, os.args[1:])
	defer delete(cfg.headers)

	if cfg.serve_port > 0 do return run_server(&cfg)

	if cfg.json_mode {
		if !has_header(cfg.headers, "Content-Type") do append(&cfg.headers, "Content-Type: application/json")
		if !has_header(cfg.headers, "Accept") do append(&cfg.headers, "Accept: application/json")
	}

	payload := load_payload(&cfg)
	defer if payload.owns_bytes do delete(payload.bytes)

	method := cfg.method
	if method == "" do method = payload_len(&payload) > 0 ? "POST" : "GET"

	if curl.global_init(0) != .E_OK do fail("failed to initialize curl")
	defer curl.global_cleanup()

	if cfg.batch_file != "" do return run_batch(&cfg, method, &payload)
	if cfg.bench_count > 0 do return run_benchmark(&cfg, method, &payload)
	return run_single(&cfg, method, &payload)
}

main :: proc() {
	os.exit(app_main())
}