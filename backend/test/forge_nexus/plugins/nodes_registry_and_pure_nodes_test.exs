defmodule ForgeNexus.Plugins.NodesRegistryAndPureNodesTest do
  use ForgeNexus.DataCase, async: true

  alias ForgeNexus.Plugins.Engine.Context
  alias ForgeNexus.Plugins.Nodes.Registry
  alias ForgeNexus.Plugins.Nodes.Logic.{Compare, Delay, IfElse, Loop, Random, SwitchCase}
  alias ForgeNexus.Plugins.Nodes.Math.{Arithmetic, Functions}

  alias ForgeNexus.Plugins.Nodes.Text.{
    BbcodeRender,
    Contains,
    FormatString,
    Join,
    RegexMatch,
    Split
  }

  defp make_ctx do
    %Context{
      execution_id: Ecto.UUID.generate(),
      flow_id: Ecto.UUID.generate(),
      started_at: DateTime.utc_now()
    }
  end

  describe "Nodes.Registry" do
    test "all_types/0 returns list of registered node schemas and verifies all schemas" do
      types = Registry.all_types()
      assert is_list(types)
      assert length(types) == 259

      {first_type, first_schema} = hd(types)
      assert is_binary(first_type)
      assert is_map(first_schema)
      assert Map.has_key?(first_schema, :type)
      assert Map.has_key?(first_schema, :category)
    end

    test "categories/0 groups registered nodes by category" do
      cats = Registry.categories()
      assert is_map(cats)
      assert Map.has_key?(cats, "logic")
      assert Map.has_key?(cats, "math")
      assert Map.has_key?(cats, "text")
      assert Map.has_key?(cats, "trigger")
    end

    test "count/0 returns accurate count of registered handlers" do
      assert Registry.count() == 259
    end

    test "get_handler/1 returns module on success and error on unknown" do
      assert {:ok, IfElse} = Registry.get_handler("logic/if_else")
      assert {:ok, Contains} = Registry.get_handler("text/contains")
      assert {:error, :unknown_node_type} = Registry.get_handler("unknown/node/type")
    end
  end

  describe "Nodes.Logic.IfElse" do
    test "compares equality, inequality, numbers, contains, regex and handles nested paths" do
      ctx = make_ctx()

      # eq
      assert {:branch, "true", _, _} =
               IfElse.execute(
                 %{"field" => "score", "operator" => "eq", "value" => "100"},
                 %{"score" => 100},
                 ctx
               )

      assert {:branch, "false", _, _} =
               IfElse.execute(
                 %{"field" => "score", "operator" => "eq", "value" => "100"},
                 %{"score" => 50},
                 ctx
               )

      # neq
      assert {:branch, "true", _, _} =
               IfElse.execute(
                 %{"field" => "status", "operator" => "neq", "value" => "banned"},
                 %{"status" => "active"},
                 ctx
               )

      # gt, gte, lt, lte
      assert {:branch, "true", _, _} =
               IfElse.execute(
                 %{"field" => "count", "operator" => "gt", "value" => "10"},
                 %{"count" => 15},
                 ctx
               )

      assert {:branch, "true", _, _} =
               IfElse.execute(
                 %{"field" => "count", "operator" => "gte", "value" => "10"},
                 %{"count" => "10"},
                 ctx
               )

      assert {:branch, "true", _, _} =
               IfElse.execute(
                 %{"field" => "count", "operator" => "lt", "value" => "10"},
                 %{"count" => 5},
                 ctx
               )

      assert {:branch, "true", _, _} =
               IfElse.execute(
                 %{"field" => "count", "operator" => "lte", "value" => "10"},
                 %{"count" => 10},
                 ctx
               )

      # contains
      assert {:branch, "true", _, _} =
               IfElse.execute(
                 %{"field" => "body", "operator" => "contains", "value" => "hello"},
                 %{"body" => "say hello world"},
                 ctx
               )

      assert {:branch, "false", _, _} =
               IfElse.execute(
                 %{"field" => "body", "operator" => "contains", "value" => "bye"},
                 %{"body" => "say hello"},
                 ctx
               )

      assert {:branch, "false", _, _} =
               IfElse.execute(
                 %{"field" => "body", "operator" => "contains", "value" => "bye"},
                 %{"body" => 123},
                 ctx
               )

      # matches
      assert {:branch, "true", _, _} =
               IfElse.execute(
                 %{"field" => "email", "operator" => "matches", "value" => "^.+@.+\\..+$"},
                 %{"email" => "user@example.com"},
                 ctx
               )

      assert {:branch, "false", _, _} =
               IfElse.execute(
                 %{"field" => "email", "operator" => "matches", "value" => "^[0-9]+$"},
                 %{"email" => "abc"},
                 ctx
               )

      assert {:branch, "false", _, _} =
               IfElse.execute(
                 %{"field" => "email", "operator" => "matches", "value" => "[invalid("},
                 %{"email" => "test"},
                 ctx
               )

      # nested path and invalid operator
      inputs = %{"user" => %{"profile" => %{"role" => "admin"}}}

      assert {:branch, "true", _, _} =
               IfElse.execute(
                 %{"field" => "user.profile.role", "operator" => "eq", "value" => "admin"},
                 inputs,
                 ctx
               )

      assert {:branch, "false", _, _} =
               IfElse.execute(
                 %{"field" => "user.missing.role", "operator" => "eq", "value" => "admin"},
                 inputs,
                 ctx
               )

      assert {:branch, "false", _, _} =
               IfElse.execute(
                 %{
                   "field" => "user.profile.role",
                   "operator" => "unknown_op",
                   "value" => "admin"
                 },
                 inputs,
                 ctx
               )

      # schema & config validation
      assert :ok = IfElse.validate_config(%{"field" => "score", "operator" => "eq"})
      assert {:error, _} = IfElse.validate_config(%{})
      assert is_map(IfElse.schema())
    end
  end

  describe "Nodes.Logic.SwitchCase" do
    test "branches to matched port or fallback to default port" do
      ctx = make_ctx()

      config = %{
        "field" => "status",
        "cases" => [
          %{"value" => "pending", "port" => "port_pending"},
          %{"value" => "active", "port" => "port_active"}
        ],
        "default_port" => "port_other"
      }

      assert {:branch, "port_pending", _, _} =
               SwitchCase.execute(config, %{"status" => "pending"}, ctx)

      assert {:branch, "port_active", _, _} =
               SwitchCase.execute(config, %{"status" => "active"}, ctx)

      assert {:branch, "port_other", _, _} =
               SwitchCase.execute(config, %{"status" => "archived"}, ctx)

      # validate_config
      assert :ok = SwitchCase.validate_config(%{"field" => "status", "cases" => []})
      assert {:error, _} = SwitchCase.validate_config(%{})
      assert {:error, _} = SwitchCase.validate_config(%{"field" => "x", "cases" => "not_list"})
      assert is_map(SwitchCase.schema())
    end
  end

  describe "Nodes.Logic.Loop" do
    test "returns items and metadata on list input, error otherwise" do
      ctx = make_ctx()

      assert {:ok, result, _} =
               Loop.execute(%{"source_field" => "tags"}, %{"tags" => ["elixir", "phoenix"]}, ctx)

      assert result.count == 2
      assert result._loop == true

      assert {:error, _, _} =
               Loop.execute(%{"source_field" => "tags"}, %{"tags" => "not_a_list"}, ctx)

      assert :ok = Loop.validate_config(%{"source_field" => "items"})
      assert {:error, _} = Loop.validate_config(%{})
      assert is_map(Loop.schema())
    end
  end

  describe "Nodes.Logic.Random" do
    test "selects branch based on weights" do
      ctx = make_ctx()

      config = %{
        "branches" => ["path_a", "path_b"],
        "weights" => [100, 0]
      }

      assert {:branch, "path_a", _, _} = Random.execute(config, %{}, ctx)

      # Empty branches error
      assert {:error, "No branches configured", _} = Random.execute(%{"branches" => []}, %{}, ctx)

      # validate_config
      assert :ok = Random.validate_config(%{"branches" => ["a", "b"]})
      assert {:error, _} = Random.validate_config(%{"branches" => []})
      assert is_map(Random.schema())
    end
  end

  describe "Nodes.Logic.Delay" do
    test "validates configuration and returns schema" do
      assert :ok = Delay.validate_config(%{"seconds" => 5})
      assert :ok = Delay.validate_config(%{"seconds" => 0})
      assert {:error, _} = Delay.validate_config(%{"seconds" => "five"})
      assert {:error, _} = Delay.validate_config(%{"seconds" => -1})
      assert {:error, _} = Delay.validate_config(%{"seconds" => 15})
      assert is_map(Delay.schema())
    end
  end

  describe "Nodes.Logic.Compare" do
    test "evaluates comparison operators and validates config" do
      ctx = make_ctx()

      assert {:ok, %{result: true}, _} =
               Compare.execute(%{"operator" => "eq"}, %{"a" => 10, "b" => 10}, ctx)

      assert {:ok, %{result: true}, _} =
               Compare.execute(%{"operator" => "neq"}, %{"a" => 10, "b" => 20}, ctx)

      assert {:ok, %{result: true}, _} =
               Compare.execute(%{"operator" => "gt"}, %{"a" => 20, "b" => 10}, ctx)

      assert {:ok, %{result: true}, _} =
               Compare.execute(%{"operator" => "gte"}, %{"a" => "20", "b" => "20"}, ctx)

      assert {:ok, %{result: true}, _} =
               Compare.execute(%{"operator" => "lt"}, %{"a" => "5", "b" => "10"}, ctx)

      assert {:ok, %{result: true}, _} =
               Compare.execute(%{"operator" => "lte"}, %{"a" => 5, "b" => 10}, ctx)

      assert {:ok, %{result: false}, _} =
               Compare.execute(%{"operator" => "unknown"}, %{"a" => 5, "b" => 10}, ctx)

      assert :ok = Compare.validate_config(%{"operator" => "eq"})
      assert {:error, _} = Compare.validate_config(%{"operator" => "invalid"})
      assert is_map(Compare.schema())
    end
  end

  describe "Nodes.Math.Arithmetic" do
    test "performs math operations and handles division by zero" do
      ctx = make_ctx()

      assert {:ok, %{result: 15}, _} =
               Arithmetic.execute(%{"operation" => "add"}, %{"a" => 10, "b" => 5}, ctx)

      assert {:ok, %{result: 5}, _} =
               Arithmetic.execute(%{"operation" => "subtract"}, %{"a" => 10, "b" => 5}, ctx)

      assert {:ok, %{result: 50}, _} =
               Arithmetic.execute(%{"operation" => "multiply"}, %{"a" => 10, "b" => 5}, ctx)

      assert {:ok, %{result: 2.0}, _} =
               Arithmetic.execute(%{"operation" => "divide"}, %{"a" => 10, "b" => 5}, ctx)

      assert {:error, "Division by zero", _} =
               Arithmetic.execute(%{"operation" => "divide"}, %{"a" => 10, "b" => 0}, ctx)

      assert {:error, "Unknown operation: modulo", _} =
               Arithmetic.execute(%{"operation" => "modulo"}, %{"a" => 10, "b" => 2}, ctx)

      assert :ok = Arithmetic.validate_config(%{"operation" => "add"})
      assert {:error, _} = Arithmetic.validate_config(%{"operation" => "pow"})
      assert is_map(Arithmetic.schema())
    end
  end

  describe "Nodes.Math.Functions" do
    test "executes math functions min, max, round, random_number, clamp" do
      ctx = make_ctx()

      assert {:ok, %{result: 5.0}, _} =
               Functions.execute(%{"function" => "min"}, %{"a" => 5, "b" => 10}, ctx)

      assert {:ok, %{result: 10.0}, _} =
               Functions.execute(%{"function" => "max"}, %{"a" => 5, "b" => 10}, ctx)

      assert {:ok, %{result: 3.14}, _} =
               Functions.execute(
                 %{"function" => "round"},
                 %{"value" => 3.14159, "precision" => 2},
                 ctx
               )

      assert {:ok, %{result: 10.0}, _} =
               Functions.execute(
                 %{"function" => "clamp"},
                 %{"value" => 25, "min" => 0, "max" => 10},
                 ctx
               )

      assert {:ok, %{result: num}, _} =
               Functions.execute(
                 %{"function" => "random_number"},
                 %{"min" => 1, "max" => 10},
                 ctx
               )

      assert num >= 1.0 and num <= 10.0

      assert {:error, "Unknown function: invalid", _} =
               Functions.execute(%{"function" => "invalid"}, %{}, ctx)

      assert is_map(Functions.schema())
    end
  end

  describe "Nodes.Text.FormatString" do
    test "interpolates input values into template placeholders" do
      ctx = make_ctx()

      template = "Welcome, {{username}}! You have {{points}} points."
      inputs = %{"username" => "Hero", "points" => 500}

      assert {:ok, %{result: "Welcome, Hero! You have 500 points."}, _} =
               FormatString.execute(%{"template" => template}, inputs, ctx)

      assert :ok = FormatString.validate_config(%{"template" => "test"})
      assert {:error, _} = FormatString.validate_config(%{})
      assert is_map(FormatString.schema())
    end
  end

  describe "Nodes.Text.RegexMatch" do
    test "matches regex pattern with options and returns captures" do
      ctx = make_ctx()

      config = %{"pattern" => "user_(\\d+)", "flags" => "i"}
      inputs = %{"text" => "Welcome user_42"}

      assert {:ok, %{matched: true, captures: ["user_42", "42"]}, _} =
               RegexMatch.execute(config, inputs, ctx)

      assert {:ok, %{matched: false, captures: []}, _} =
               RegexMatch.execute(config, %{"text" => "guest_account"}, ctx)

      assert {:error, "Invalid regex pattern: " <> _, _} =
               RegexMatch.execute(%{"pattern" => "[invalid"}, %{"text" => "abc"}, ctx)

      assert :ok = RegexMatch.validate_config(%{"pattern" => "\\d+"})
      assert {:error, _} = RegexMatch.validate_config(%{"pattern" => "["})
      assert is_map(RegexMatch.schema())
    end
  end

  describe "Nodes.Text.Contains" do
    test "checks substring presence with case sensitivity options" do
      ctx = make_ctx()

      # Case-sensitive
      assert {:ok, %{result: true}, _} =
               Contains.execute(
                 %{"case_sensitive" => true},
                 %{"text" => "ForgeNexus", "search" => "Forge"},
                 ctx
               )

      assert {:ok, %{result: false}, _} =
               Contains.execute(
                 %{"case_sensitive" => true},
                 %{"text" => "ForgeNexus", "search" => "forge"},
                 ctx
               )

      # Case-insensitive
      assert {:ok, %{result: true}, _} =
               Contains.execute(
                 %{"case_sensitive" => false},
                 %{"text" => "ForgeNexus", "search" => "forgenexus"},
                 ctx
               )

      assert :ok = Contains.validate_config(%{})
      assert is_map(Contains.schema())
    end
  end

  describe "Nodes.Text.Split & Join" do
    test "splits string into list and joins list back into string" do
      ctx = make_ctx()

      # Split
      assert {:ok, %{parts: ["apple", "banana", "cherry"]}, _} =
               Split.execute(%{"delimiter" => ","}, %{"text" => "apple,banana,cherry"}, ctx)

      # Join
      assert {:ok, %{result: "apple - banana - cherry"}, _} =
               Join.execute(
                 %{"delimiter" => " - "},
                 %{"parts" => ["apple", "banana", "cherry"]},
                 ctx
               )

      assert :ok = Split.validate_config(%{})
      assert :ok = Join.validate_config(%{})
      assert is_map(Split.schema())
      assert is_map(Join.schema())
    end
  end

  describe "Nodes.Text.BbcodeRender" do
    test "renders BBCode markup into HTML" do
      ctx = make_ctx()

      assert {:ok, %{html: html}, _} =
               BbcodeRender.execute(%{}, %{"text" => "[b]Bold text[/b]"}, ctx)

      assert String.contains?(html, "<strong>Bold text</strong>")

      assert :ok = BbcodeRender.validate_config(%{})
      assert is_map(BbcodeRender.schema())
    end
  end
end
