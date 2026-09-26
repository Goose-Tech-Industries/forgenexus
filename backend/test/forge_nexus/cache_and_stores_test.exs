defmodule ForgeNexus.CacheAndStoresTest do
  use ExUnit.Case, async: false

  alias ForgeNexus.{Cache, StatsCache, SettingsCache, RateLimiter, RateLimitCleaner}

  describe "ForgeNexus.Cache" do
    setup do
      Cache.flush()
      :ok
    end

    test "puts and gets value without TTL (infinite)" do
      assert Cache.put("key_inf", "value_1") == {:ok, true}
      assert Cache.get("key_inf") == {:ok, "value_1"}
    end

    test "puts and gets value with positive TTL" do
      assert Cache.put("key_ttl", %{foo: "bar"}, ttl_ms: 10_000) == {:ok, true}
      assert Cache.get("key_ttl") == {:ok, %{foo: "bar"}}
    end

    test "puts with non-integer or negative TTL defaults to infinity" do
      assert Cache.put("key_invalid_ttl", 123, ttl_ms: -5) == {:ok, true}
      assert Cache.get("key_invalid_ttl") == {:ok, 123}

      assert Cache.put("key_nil_ttl", 456, ttl_ms: nil) == {:ok, true}
      assert Cache.get("key_nil_ttl") == {:ok, 456}
    end

    test "evicts expired key lazily on get" do
      # Insert an expired entry directly into the ETS table
      past = System.monotonic_time(:millisecond) - 500
      :ets.insert(Cache, {"key_expired", "old_val", past})

      assert Cache.get("key_expired") == {:ok, nil}
      assert :ets.lookup(Cache, "key_expired") == []
    end

    test "returns {:ok, nil} for missing key" do
      assert Cache.get("non_existent_key_xyz") == {:ok, nil}
    end

    test "deletes a key" do
      Cache.put("to_delete", "val")
      assert Cache.get("to_delete") == {:ok, "val"}

      assert Cache.delete("to_delete") == :ok
      assert Cache.get("to_delete") == {:ok, nil}
    end

    test "flushes all keys" do
      Cache.put("k1", 1)
      Cache.put("k2", 2)

      assert Cache.flush() == :ok
      assert Cache.get("k1") == {:ok, nil}
      assert Cache.get("k2") == {:ok, nil}
    end

    test "handle_info(:sweep) deletes expired items" do
      past = System.monotonic_time(:millisecond) - 100
      future = System.monotonic_time(:millisecond) + 100_000

      :ets.insert(Cache, {"sweep_expired", "old", past})
      :ets.insert(Cache, {"sweep_active", "live", future})

      # Trigger handle_info directly
      {:noreply, %{}} = Cache.handle_info(:sweep, %{})

      assert :ets.lookup(Cache, "sweep_expired") == []
      assert [{_, "live", _}] = :ets.lookup(Cache, "sweep_active")
    end
  end

  describe "ForgeNexus.StatsCache" do
    test "puts, gets, and lists all precomputed stats" do
      StatsCache.put("total_members", 1500)
      StatsCache.put("total_threads", 420)

      assert StatsCache.get("total_members") == 1500
      assert StatsCache.get("total_threads") == 420
      assert StatsCache.get("non_existent", :fallback) == :fallback
      assert StatsCache.get("non_existent_default_nil") == nil

      all = StatsCache.all()
      assert is_map(all)
      assert all["total_members"] == 1500
      assert all["total_threads"] == 420
    end
  end

  describe "ForgeNexus.SettingsCache" do
    test "gets value, calling loader_fn on cache miss and reusing on hit" do
      SettingsCache.invalidate_all()
      ref = :counters.new(1, [:atomics])

      loader = fn ->
        :counters.add(ref, 1, 1)
        "computed_setting_#{:counters.get(ref, 1)}"
      end

      # First call: cache miss, executes loader
      val1 = SettingsCache.get("site_title", loader)
      assert val1 == "computed_setting_1"

      # Second call: cache hit, loader NOT called
      val2 = SettingsCache.get("site_title", loader)
      assert val2 == "computed_setting_1"

      # Invalidate specific key
      assert SettingsCache.invalidate("site_title") == true

      # Third call: cache miss again, increments counter
      val3 = SettingsCache.get("site_title", loader)
      assert val3 == "computed_setting_2"

      # Invalidate all
      assert SettingsCache.invalidate_all() == true
      val4 = SettingsCache.get("site_title", loader)
      assert val4 == "computed_setting_3"
    end
  end

  describe "ForgeNexus.RateLimiter" do
    test "enforces limits on create_thread and records actions" do
      user_id = "user_rl_#{System.unique_integer([:positive])}"

      # Allowed initially
      assert RateLimiter.check_rate(user_id, :create_thread) == :ok

      # Record 5 actions (limit is 5)
      for _ <- 1..5 do
        assert RateLimiter.record_action(user_id, :create_thread) == :ok
      end

      # Exceeds limit
      assert RateLimiter.check_rate(user_id, :create_thread) == {:error, :rate_limited}
    end

    test "enforces limits on create_post (limit 20)" do
      user_id = "user_post_rl_#{System.unique_integer([:positive])}"

      assert RateLimiter.check_rate(user_id, :create_post) == :ok

      for _ <- 1..20 do
        RateLimiter.record_action(user_id, :create_post)
      end

      assert RateLimiter.check_rate(user_id, :create_post) == {:error, :rate_limited}
    end

    test "handle_info(:cleanup) prunes timestamps older than 600 seconds" do
      now = System.system_time(:second)
      old_ts = now - 700
      fresh_ts = now - 100

      key_old = {"user_old", :create_thread}
      key_mixed = {"user_mixed", :create_thread}

      :ets.insert(:forge_nexus_rate_limiter, {key_old, [old_ts]})
      :ets.insert(:forge_nexus_rate_limiter, {key_mixed, [old_ts, fresh_ts]})

      {:noreply, %{table: :forge_nexus_rate_limiter}} =
        RateLimiter.handle_info(:cleanup, %{table: :forge_nexus_rate_limiter})

      assert :ets.lookup(:forge_nexus_rate_limiter, key_old) == []
      assert [{^key_mixed, [^fresh_ts]}] = :ets.lookup(:forge_nexus_rate_limiter, key_mixed)
    end
  end

  describe "ForgeNexus.RateLimitCleaner" do
    test "handle_info(:cleanup) calls RateLimit plug cleanup_expired" do
      {:noreply, %{}} = RateLimitCleaner.handle_info(:cleanup, %{})
    end
  end
end
