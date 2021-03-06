#; -*- mode: perl;-*-

use Test::Nginx::Socket;
use Cwd qw(cwd);

repeat_each(2);

plan tests => repeat_each() * blocks() * 3;

my $pwd = cwd();

our $HttpConfig = qq{
    lua_package_path "$pwd/lib/?.lua;;";
};

$ENV{TEST_NGINX_RESOLVER} = '8.8.8.8';
$ENV{TEST_NGINX_RIAK_PORT} ||= 8087;

no_long_string();

run_tests();

__DATA__

=== TEST 1: update counter using raw interface
--- http_config eval: $::HttpConfig
--- config
    location /t {
        content_by_lua '
            local riak = require "resty.riak.client"
            local client = riak.new()
            local ok, err = client:connect("127.0.0.1", 8087)
            if not ok then
                ngx.log(ngx.ERR, "connect failed: " .. err)
            end
	    local rc, err = client:set_bucket_props("counters", { allow_mult = 1 })
            ngx.say(rc)
	    rc, err = client:update_counter("counters", "counter", 10)
            ngx.say(rc)
            ngx.say(err)
            client:close()
        ';
    }
--- request
GET /t
--- response_body
true
true
nil
--- no_error_log
[error]




=== TEST 2: update and get a counter using raw interface
--- http_config eval: $::HttpConfig
--- config
    location /t {
        content_by_lua '
            local riak = require "resty.riak.client"
            local client = riak.new()
            local ok, err = client:connect("127.0.0.1", 8087)
            if not ok then
                ngx.log(ngx.ERR, "connect failed: " .. err)
            end
	    local rc, err = client:set_bucket_props("counters", { allow_mult = 1 })
	    rc, err = client:update_counter("counters", "counter", 10)
            rc, err = client:get_counter("counters", "counter")
	    ngx.say(type(rc))
            client:close()
        ';
    }
--- request
GET /t
--- response_body
number
--- no_error_log
[error]




=== TEST 3: update and get a counter using high level interface
--- http_config eval: $::HttpConfig
--- config
    location /t {
        content_by_lua '
            local riak = require "resty.riak"
            local client = riak.new()
            local ok, err = client:connect("127.0.0.1", 8087)
            if not ok then
                ngx.log(ngx.ERR, "connect failed: " .. err)
            end
            local bucket = client:bucket("counters")
            bucket:set_properties({ allow_mult = 1 })
            local counter = bucket:counter("counter")
            counter:decrement()
            local value = counter:value()
            ngx.say(type(value))
            local value = counter:decrement_and_return()
            ngx.say(type(value))
            client:close()
        ';
    }
--- request
GET /t
--- response_body
number
number
--- no_error_log
[error]
