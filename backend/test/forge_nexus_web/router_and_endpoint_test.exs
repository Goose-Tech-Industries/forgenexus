defmodule ForgeNexusWeb.RouterAndEndpointTest do
  use ForgeNexusWeb.ConnCase, async: true

  alias ForgeNexusWeb.Endpoint

  describe "FallbackController and catch-all" do
    test "returns 404 with json error on unmatched api route", %{conn: conn} do
      conn = get(conn, "/api/completely/unknown/endpoint/route")
      assert json_response(conn, 404) == %{"error" => "Not found"}
    end

    test "handles POST, PUT, DELETE to nonexistent api routes", %{conn: conn} do
      conn_post = post(conn, "/api/does-not-exist")
      assert json_response(conn_post, 404) == %{"error" => "Not found"}

      conn_put = put(conn, "/api/does-not-exist")
      assert json_response(conn_put, 404) == %{"error" => "Not found"}

      conn_del = delete(conn, "/api/does-not-exist")
      assert json_response(conn_del, 404) == %{"error" => "Not found"}
    end
  end

  describe "Public and unauthenticated routes" do
    test "GET /api/billing/plans returns 200 with plans catalog", %{conn: conn} do
      conn = get(conn, ~p"/api/billing/plans")
      assert %{"plans" => plans} = json_response(conn, 200)
      assert is_list(plans)
      assert length(plans) > 0
    end

    test "GET /api/health returns health status", %{conn: conn} do
      conn = get(conn, ~p"/api/health")
      assert %{"status" => "ok"} = json_response(conn, 200)
    end
  end

  describe "ForgeNexusWeb.Endpoint" do
    test "endpoint is loaded and has configured child specifications" do
      assert Code.ensure_loaded?(Endpoint)
      assert function_exported?(Endpoint, :start_link, 1)
      assert function_exported?(Endpoint, :config_change, 2)
    end
  end
end
