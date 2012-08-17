Code.require_file "../../../test_helper", __FILE__

defmodule Dynamo.Test.ConnectionTest do
  use ExUnit.Case, async: true

  alias Dynamo.Test.Connection, as: C

  ## Request

  test :version do
    assert conn(:GET, "/").version == { 1, 1 }
  end

  test :method do
    assert conn(:GET, "/").method == :GET
    assert conn(:POST, "/").method == :POST
  end

  test :path do
    assert conn(:GET, "/foo/bar").path_segments == ["foo", "bar"]
    assert conn(:GET, "/").path_segments == []

    assert conn(:GET, "/foo/bar").path == "/foo/bar"
    assert conn(:GET, "/").path == "/"
  end

  test :query_string do
    assert conn(:GET, "/foo/bar").query_string == ""
    assert conn(:GET, "/foo/bar?hello=world&foo=bar").query_string == "hello=world&foo=bar"
  end

  test :params do
    conn = conn(:GET, "/foo/bar?hello=world&foo[name]=bar")

    assert_raise Dynamo.Connection.UnfetchedError, fn ->
      conn.params
    end

    params = conn.fetch(:params).params
    assert params["hello"] == "world"
    assert params["foo"]["name"] == "bar"
  end

  test :req_headers do
    conn = conn(:GET, "/foo/bar")

    assert_raise Dynamo.Connection.UnfetchedError, fn ->
      conn.req_headers
    end

    conn = conn.set_req_header "X-Code", "123456"
    assert conn.fetch(:headers).req_headers["X-Code"] == "123456"

    conn = conn.delete_req_header "X-Code"
    assert conn.fetch(:headers).req_headers["X-Code"] == nil
  end

  test :host do
    conn = conn(:GET, "/foo/bar").fetch(:headers)
    assert conn.req_headers["Host"] == "127.0.0.1"

    conn = conn(:GET, "//example.com:3000/foo/bar").fetch(:headers)
    assert conn.req_headers["Host"] == "example.com:3000"
  end

  ## Cookies

  test :req_cookies do
    conn = conn(:GET, "/").req_cookies(foo: "bar", baz: "bat")
    assert conn.req_cookies["foo"] == "bar"
    assert conn.req_cookies["baz"] == "bat"
    conn
  end

  test :cookies do
    conn = conn(:GET, "/").req_cookies(foo: "bar", baz: "bat").fetch(:cookies)
    assert conn.cookies["foo"] == "bar"
    assert conn.cookies["baz"] == "bat"
    conn
  end

  test :resp_cookies do
    conn = conn(:GET, "/")
    assert conn.resp_cookies == []

    conn = conn.set_cookie(:foo, :bar, path: "/hello")
    assert conn.resp_cookies == [{ "foo", "bar", path: "/hello" }]
  end

  test :req_resp_cookies do
    conn = conn(:GET, "/").req_cookies(foo: "bar", baz: "bat").fetch(:cookies)
    assert conn.cookies["foo"] == "bar"
    assert conn.cookies["baz"] == "bat"

    conn = conn.set_cookie(:foo, :new)
    assert conn.cookies["foo"] == "new"
    assert conn.cookies["baz"] == "bat"

    conn = conn.delete_cookie(:foo)
    assert conn.cookies["foo"] == nil
  end

  ## Misc

  test :assigns do
    conn  = conn(:GET, "/")
    assert conn.assigns == []

    conn = conn.assign :foo, "bar"
    assert conn.assigns == [foo: "bar"]

    conn = conn.assign :foo, "baz"
    assert conn.assigns == [foo: "baz"]
  end

  test :forward_to do
    conn = conn(:GET, "/forward_to/foo/bar/baz")
    assert conn.path_segments == ["forward_to", "foo", "bar", "baz"]

    conn = conn.forward_to [], Foo
    assert conn.path_segments == ["forward_to", "foo", "bar", "baz"]

    conn = conn.forward_to ["foo", "bar", "baz"], Foo

    assert conn.path_info == "/foo/bar/baz"
    assert conn.path_info_segments == ["foo", "bar", "baz"]

    assert conn.path == "/forward_to/foo/bar/baz"
    assert conn.path_segments == ["forward_to", "foo", "bar", "baz"]

    assert conn.script_name == "/forward_to"
    assert conn.script_name_segments == ["forward_to"]

    conn = conn.forward_to ["bar", "baz"], Bar

    assert conn.path_info == "/bar/baz"
    assert conn.path_info_segments == ["bar", "baz"]

    assert conn.path == "/forward_to/foo/bar/baz"
    assert conn.path_segments == ["forward_to", "foo", "bar", "baz"]

    assert conn.script_name == "/forward_to/foo"
    assert conn.script_name_segments == ["forward_to", "foo"]

    conn
  end

  defp conn(verb, path) do
    C.new.req(verb, path)
  end
end