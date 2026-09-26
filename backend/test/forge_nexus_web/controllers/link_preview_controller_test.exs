defmodule ForgeNexusWeb.LinkPreviewControllerTest do
  use ForgeNexusWeb.ConnCase, async: false

  alias ForgeNexus.Accounts
  alias ForgeNexus.Guardian

  defp fresh_conn(conn) do
    b3 = rem(System.unique_integer([:positive]), 250) + 1
    b4 = rem(System.unique_integer([:positive]), 250) + 1
    %{conn | remote_ip: {10, 0, b3, b4}}
  end

  defp create_user do
    unique = System.unique_integer([:positive])

    attrs = %{
      username: "lp_user_#{unique}",
      email: "lp_user_#{unique}@example.com",
      password: "Fn9#xK8$mQ2!wZ7^vL4*",
      display_name: "LinkPreview User #{unique}"
    }

    {:ok, user} = Accounts.register_user(attrs)
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    {:ok, verified} =
      user |> Ecto.Changeset.change(email_verified_at: now) |> ForgeNexus.Repo.update()

    verified
  end

  defp auth_conn(conn, user) do
    {:ok, token, _claims} = Guardian.encode_and_sign(user)

    conn
    |> fresh_conn()
    |> put_req_header("authorization", "Bearer #{token}")
  end

  setup %{conn: conn} do
    user = create_user()
    authed = auth_conn(conn, user)

    Req.default_options(plug: {Req.Test, ForgeNexus.LinkPreview}, retry: false)

    if :ets.whereis(:link_preview_cache) != :undefined do
      :ets.delete_all_objects(:link_preview_cache)
    end

    on_exit(fn ->
      Req.default_options([])

      if :ets.whereis(:link_preview_cache) != :undefined do
        :ets.delete_all_objects(:link_preview_cache)
      end
    end)

    {:ok, conn: authed, unauthed_conn: conn}
  end

  describe "GET /api/link-preview" do
    test "returns 401 when unauthenticated", %{unauthed_conn: conn} do
      conn = fresh_conn(conn) |> get(~p"/api/link-preview", url: "https://example.com")
      assert json_response(conn, 401) == %{"error" => "Authentication required"}
    end

    test "returns 200 with preview map for a valid web url", %{conn: conn} do
      html = """
      <html>
      <head>
        <meta property="og:title" content="Example Domain" />
        <meta property="og:description" content="This domain is for use in documentation." />
      </head>
      </html>
      """

      Req.Test.stub(ForgeNexus.LinkPreview, fn req_conn ->
        Plug.Conn.send_resp(req_conn, 200, html)
      end)

      conn = get(conn, ~p"/api/link-preview", url: "https://example.com")

      assert json_response(conn, 200) == %{
               "preview" => %{
                 "url" => "https://example.com",
                 "title" => "Example Domain",
                 "description" => "This domain is for use in documentation.",
                 "image" => nil,
                 "site_name" => nil
               }
             }
    end

    test "returns 200 with preview: nil when page cannot be resolved", %{conn: conn} do
      Req.Test.stub(ForgeNexus.LinkPreview, fn req_conn ->
        Plug.Conn.send_resp(req_conn, 404, "Not Found")
      end)

      conn = get(conn, ~p"/api/link-preview", url: "https://example.com/notfound")
      assert json_response(conn, 200) == %{"preview" => nil}
    end

    test "returns 400 when url parameter is missing", %{conn: conn} do
      conn = get(conn, ~p"/api/link-preview")
      assert json_response(conn, 400) == %{"error" => "Missing url parameter"}
    end

    test "returns 400 when url is not http or https", %{conn: conn} do
      conn = get(conn, ~p"/api/link-preview", url: "ftp://example.com/file")
      assert json_response(conn, 400) == %{"error" => "Invalid URL. Must be http or https."}

      conn2 = get(conn, ~p"/api/link-preview", url: "not-a-valid-url")
      assert json_response(conn2, 400) == %{"error" => "Invalid URL. Must be http or https."}
    end
  end
end
