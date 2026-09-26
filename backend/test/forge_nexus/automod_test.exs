defmodule ForgeNexus.AutoModTest do
  use ForgeNexus.DataCase, async: true

  alias ForgeNexus.AutoMod
  alias ForgeNexus.AutoMod.AutoModRule
  alias ForgeNexus.Accounts
  alias ForgeNexus.Cooldowns

  defp create_user do
    unique = System.unique_integer([:positive])

    {:ok, user} =
      Accounts.register_user(%{
        username: "am_u_#{unique}",
        email: "am_u_#{unique}@example.com",
        password: "ValidPassword123!@#"
      })

    user
  end

  defp rule_attrs(attrs) do
    unique = System.unique_integer([:positive])

    Enum.into(attrs, %{
      name: "Keyword Filter #{unique}",
      rule_type: "keyword",
      action: "flag",
      severity: 1,
      is_enabled: true,
      sort_order: 10,
      config: %{"words" => ["badword", "banned"]}
    })
  end

  describe "AutoMod rules CRUD" do
    test "create, get, list, update, and delete rules" do
      attrs = rule_attrs(%{name: "Profanity Rule", sort_order: 2})
      assert {:ok, %AutoModRule{} = rule} = AutoMod.create_rule(attrs)

      assert %AutoModRule{id: id} = AutoMod.get_rule!(rule.id)
      assert id == rule.id

      rules = AutoMod.list_rules()
      assert Enum.any?(rules, &(&1.id == rule.id))

      assert {:ok, updated} = AutoMod.update_rule(rule, %{name: "Updated Profanity"})
      assert updated.name == "Updated Profanity"

      assert {:ok, updated_by_id} = AutoMod.update_rule(rule.id, %{action: "warn"})
      assert updated_by_id.action == "warn"

      assert {:ok, %AutoModRule{}} = AutoMod.delete_rule(rule.id)
      refute Enum.any?(AutoMod.list_rules(), &(&1.id == rule.id))
    end
  end

  describe "check_content/2 and rule evaluations" do
    test "evaluates keyword rules" do
      user = create_user()

      {:ok, rule} =
        AutoMod.create_rule(
          rule_attrs(%{
            rule_type: "keyword",
            config: %{"words" => ["violation", "spammy"]}
          })
        )

      results = AutoMod.check_content("This has no bad content", user)
      assert {^rule, false} = List.keyfind(results, rule, 0)

      results_triggered = AutoMod.check_content("Warning: this has a VIOLATION inside", user)
      assert {^rule, true} = List.keyfind(results_triggered, rule, 0)
    end

    test "evaluates regex rules with valid and invalid patterns" do
      user = create_user()

      {:ok, regex_rule} =
        AutoMod.create_rule(
          rule_attrs(%{
            rule_type: "regex",
            config: %{"pattern" => "\\bfree\\s+crypto\\b"}
          })
        )

      {:ok, bad_regex_rule} =
        AutoMod.create_rule(
          rule_attrs(%{
            rule_type: "regex",
            config: %{"pattern" => "[invalid(regex"}
          })
        )

      results = AutoMod.check_content("Get FREE CRYPTO now!", user)
      assert {^regex_rule, true} = List.keyfind(results, regex_rule, 0)
      assert {^bad_regex_rule, false} = List.keyfind(results, bad_regex_rule, 0)
    end

    test "evaluates spam rules" do
      user = create_user()

      {:ok, spam_rule} =
        AutoMod.create_rule(
          rule_attrs(%{
            rule_type: "spam",
            config: %{"threshold" => 0.4}
          })
        )

      normal_results =
        AutoMod.check_content("Hello everyone, how are you all doing today in the forum?", user)

      assert {^spam_rule, false} = List.keyfind(normal_results, spam_rule, 0)

      # High caps + repetitive spam links
      spammy_content = "BUY NOW BUY NOW BUY NOW http://test.com http://test2.com http://test3.com"
      spam_results = AutoMod.check_content(spammy_content, user)
      assert {^spam_rule, true} = List.keyfind(spam_results, spam_rule, 0)
    end

    test "evaluates rate_limit rules" do
      user = create_user()

      {:ok, rl_rule} =
        AutoMod.create_rule(
          rule_attrs(%{
            rule_type: "rate_limit",
            config: %{"action" => "create_post"}
          })
        )

      # Ready (not on cooldown)
      results = AutoMod.check_content("Regular post", user)
      assert {^rl_rule, false} = List.keyfind(results, rl_rule, 0)

      # Trigger cooldown
      Cooldowns.set_cooldown(user.id, "rate_limit:create_post", 60)

      # Now triggered
      results_cd = AutoMod.check_content("Regular post", user)
      assert {^rl_rule, true} = List.keyfind(results_cd, rl_rule, 0)
    end

    test "evaluates custom or unknown rule types as false" do
      user = create_user()
      {:ok, custom_rule} = AutoMod.create_rule(rule_attrs(%{rule_type: "custom"}))

      results = AutoMod.check_content("Anything", user)
      assert {^custom_rule, false} = List.keyfind(results, custom_rule, 0)
    end
  end

  describe "pure helper functions: keyword_check/2 and spam_score/1" do
    test "keyword_check/2 handles empty content and lists" do
      assert AutoMod.keyword_check("Hello World", ["world"]) == true
      assert AutoMod.keyword_check("Hello World", ["foo", "bar"]) == false
      assert AutoMod.keyword_check("", ["foo"]) == false
    end

    test "spam_score/1 scores caps, links, repetition, and extreme lengths" do
      score_normal =
        AutoMod.spam_score("This is a completely normal post written by a human user.")

      assert score_normal >= 0.0 and score_normal <= 1.0

      # Very short (< 5 chars)
      assert AutoMod.spam_score("Hi") >= 0.1

      # All caps
      score_caps = AutoMod.spam_score("ALL CAPS SHOUTING TEXT HERE NOW")
      assert score_caps > 0.15

      # Repetitive words
      score_rep = AutoMod.spam_score("spam spam spam spam spam spam spam")
      assert score_rep > 0.1
    end
  end
end
