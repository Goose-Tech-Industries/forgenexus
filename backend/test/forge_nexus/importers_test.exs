defmodule ForgeNexus.ImportersTest do
  use ForgeNexus.DataCase, async: false

  alias ForgeNexus.Importer
  alias ForgeNexus.Importer.{Discourse, PhpBB, Progress, VBulletin}
  alias ForgeNexus.Forums.{Category, Forum, Post, Thread}
  alias ForgeNexus.Accounts.User

  defmodule FailingAdapter do
    @behaviour ForgeNexus.Importer.Adapter

    @impl true
    def import_users(_data, _progress_fn), do: {:error, :user_import_crash}

    @impl true
    def import_categories(_data, _progress_fn), do: {:ok, %{}}

    @impl true
    def import_forums(_data, _id_map, _progress_fn), do: {:ok, %{}}

    @impl true
    def import_threads(_data, _id_map, _progress_fn), do: {:error, :thread_import_crash}

    @impl true
    def import_posts(_data, _id_map, _progress_fn), do: {:error, :post_import_crash}
  end

  defmodule RaisingAdapter do
    @behaviour ForgeNexus.Importer.Adapter

    @impl true
    def import_users(_data, _progress_fn), do: raise("Explosion in users")

    @impl true
    def import_categories(_data, _progress_fn), do: {:ok, %{}}

    @impl true
    def import_forums(_data, _id_map, _progress_fn), do: {:ok, %{}}

    @impl true
    def import_threads(_data, _id_map, _progress_fn), do: {:ok, %{}}

    @impl true
    def import_posts(_data, _id_map, _progress_fn), do: {:ok, %{}}
  end

  defp sync_progress do
    _ = :sys.get_state(Progress)
    :ok
  end

  describe "ForgeNexus.Importer.Progress" do
    test "tracks lifecycle, steps, errors, completion, failure, and cancellation" do
      import_id = Ecto.UUID.generate()

      # Unknown ID
      assert {:error, :not_found} = Progress.get_status("unknown-import-id")
      assert Progress.running?("unknown-import-id") == false

      # Start import
      assert :ok = Progress.start_import(import_id)
      sync_progress()
      assert Progress.running?(import_id) == true
      {:ok, status} = Progress.get_status(import_id)
      assert status.status == :running
      assert status.current_step == "initializing"

      # Update progress
      Progress.update(import_id, "importing_users", 5, 10)
      sync_progress()
      {:ok, status} = Progress.get_status(import_id)
      assert status.current_step == "importing_users"
      assert status.processed == 5
      assert status.total == 10
      assert "initializing" in status.steps_completed

      # Update same step does not duplicate in steps_completed
      Progress.update(import_id, "importing_users", 10, 10)
      sync_progress()
      {:ok, status} = Progress.get_status(import_id)
      assert length(Enum.filter(status.steps_completed, &(&1 == "initializing"))) == 1

      # Add error
      Progress.add_error(import_id, "Duplicate user skipped")
      sync_progress()
      {:ok, status} = Progress.get_status(import_id)
      assert length(status.errors) == 1
      assert hd(status.errors).message == "Duplicate user skipped"

      # Complete import
      Progress.complete(import_id, %{users_imported: 10})
      sync_progress()
      {:ok, status} = Progress.get_status(import_id)
      assert status.status == :completed
      assert status.current_step == "done"
      assert status.stats == %{users_imported: 10}
      assert status.completed_at != nil
      assert "importing_users" in status.steps_completed

      # Complete import when current_step was already in steps_completed
      rep_id = Ecto.UUID.generate()
      Progress.start_import(rep_id)
      Progress.update(rep_id, "step_a", 1, 1)
      Progress.update(rep_id, "step_b", 1, 1)
      Progress.update(rep_id, "step_a", 1, 1)
      Progress.complete(rep_id, %{})
      sync_progress()
      {:ok, rep_status} = Progress.get_status(rep_id)
      assert rep_status.status == :completed

      # Fail import
      fail_id = Ecto.UUID.generate()
      Progress.start_import(fail_id)
      Progress.fail(fail_id, "Connection timeout")
      sync_progress()
      {:ok, fail_status} = Progress.get_status(fail_id)
      assert fail_status.status == :failed

      assert Enum.any?(fail_status.errors, fn err ->
               String.contains?(err.message, "Connection timeout")
             end)

      # Cancel import
      cancel_id = Ecto.UUID.generate()
      Progress.start_import(cancel_id)
      Progress.cancel(cancel_id)
      sync_progress()
      {:ok, cancel_status} = Progress.get_status(cancel_id)
      assert cancel_status.status == :cancelled
    end
  end

  describe "ForgeNexus.Importer Orchestrator" do
    test "available_sources, validate_config, and preview" do
      sources = Importer.available_sources()
      assert length(sources) == 3
      source_ids = Enum.map(sources, & &1.id)
      assert "phpbb" in source_ids
      assert "vbulletin" in source_ids
      assert "discourse" in source_ids

      # Validation failures
      assert {:error, "Missing 'source' field"} = Importer.validate_config(%{})

      assert {:error, "Unsupported source: reddit" <> _} =
               Importer.validate_config(%{"source" => "reddit", "data" => %{}})

      assert {:error, "Missing or invalid 'data' field" <> _} =
               Importer.validate_config(%{"source" => "phpbb"})

      assert {:error, "Missing or invalid 'data' field" <> _} =
               Importer.validate_config(%{"source" => "phpbb", "data" => "invalid"})

      # Validation success
      valid_config = %{"source" => "phpbb", "data" => %{"users" => [%{"id" => 1}]}}
      assert :ok = Importer.validate_config(valid_config)

      # Preview
      preview =
        Importer.preview(%{
          "users" => [1, 2],
          "categories" => [1],
          "forums" => [1, 2, 3],
          "threads" => [1],
          "posts" => [1, 2, 3, 4]
        })

      assert preview == %{users: 2, categories: 1, forums: 3, threads: 1, posts: 4}

      # Empty preview defaults
      assert Importer.preview(%{}) == %{users: 0, categories: 0, forums: 0, threads: 0, posts: 0}
    end

    test "get_status and cancel via Importer facade" do
      import_id = Ecto.UUID.generate()
      Progress.start_import(import_id)
      sync_progress()

      assert {:ok, status} = Importer.get_status(import_id)
      assert status.status == :running

      assert :ok = Importer.cancel(import_id)
      sync_progress()
      assert {:ok, cancelled} = Importer.get_status(import_id)
      assert cancelled.status == :cancelled
    end

    test "run_import handles validation failure immediately" do
      assert {:error, "Missing 'source' field"} = Importer.run_import(%{})
    end

    test "run_import with adapter errors triggers Progress error logs" do
      config = %{"source" => "phpbb", "data" => %{}}

      assert {:ok, import_id} =
               Importer.run_import(config, %{adapter: FailingAdapter, async: false})

      sync_progress()

      {:ok, status} = Importer.get_status(import_id)
      assert status.status == :completed
      assert length(status.errors) == 3
      error_messages = Enum.map(status.errors, & &1.message)
      assert Enum.any?(error_messages, fn m -> m =~ "User import failed" end)
      assert Enum.any?(error_messages, fn m -> m =~ "Thread import failed" end)
      assert Enum.any?(error_messages, fn m -> m =~ "Post import failed" end)
    end

    test "run_import defaults to async Task execution and notifies on complete" do
      config = %{
        "source" => "vbulletin",
        "data" => %{
          "users" => [],
          "categories" => [],
          "forums" => [],
          "threads" => [],
          "posts" => []
        }
      }

      assert {:ok, import_id} = Importer.run_import(config, %{notify_pid: self()})
      assert_receive {:import_completed, ^import_id}, 3000

      assert {:ok, status} = Importer.get_status(import_id)
      assert status.status == :completed
    end

    test "run_import with unexpected exception fails and notifies on rescue" do
      config = %{"source" => "phpbb", "data" => %{}}

      assert {:ok, import_id} =
               Importer.run_import(config, %{adapter: RaisingAdapter, notify_pid: self()})

      assert_receive {:import_failed, ^import_id, _reason}, 3000

      assert {:ok, status} = Importer.get_status(import_id)
      assert status.status == :failed
    end
  end

  describe "PhpBB Adapter & Full Pipeline" do
    test "strip_phpbb_bbcode_uids" do
      assert PhpBB.strip_phpbb_bbcode_uids(nil) == ""
      assert PhpBB.strip_phpbb_bbcode_uids("Normal text") == "Normal text"
      assert PhpBB.strip_phpbb_bbcode_uids("[b:1a2b3c]bold text[/b:1a2b3c]") == "[b]bold text[/b]"

      assert PhpBB.strip_phpbb_bbcode_uids("[url=https://example.com:1a2b3c]link[/url:1a2b3c]") ==
               "[url=https://example.com]link[/url]"

      smilie =
        "<!-- s:) --><img src=\"{SMILIES_PATH}/icon_smile.gif\" alt=\":)\" title=\"Smile\" /><!-- s:) -->"

      assert PhpBB.strip_phpbb_bbcode_uids(smilie) == ":)"
    end

    test "end-to-end phpBB import with existing user conflict resolution and duplicate slugs" do
      uid = System.unique_integer([:positive])
      existing_email = "existing_phpbb_#{uid}@example.com"
      existing_username = "existing_phpbb_#{uid}"

      {:ok, existing_user} =
        %User{}
        |> User.registration_changeset(%{
          username: existing_username,
          email: existing_email,
          password: "SecurePass12345!Password"
        })
        |> Repo.insert()

      # Create pre-existing category to trigger slug collision
      {:ok, existing_cat} =
        %Category{}
        |> Category.changeset(%{name: "Gaming Zone", description: "Old cat", position: 1})
        |> Repo.insert()

      # Create pre-existing forum to trigger slug collision
      {:ok, _existing_forum} =
        %Forum{}
        |> Forum.changeset(%{
          name: "General Discussion",
          description: "Old forum",
          position: 1,
          category_id: existing_cat.id
        })
        |> Repo.insert()

      import_data = %{
        "users" => [
          %{
            "source_id" => "u1",
            "username" => "brand_new_phpbb_#{uid}",
            "email" => "brand_new_phpbb_#{uid}@example.com",
            "post_count" => 15,
            "avatar_url" => "https://example.com/avatar.png",
            "joined_at" => "2025-05-10T14:30:00Z"
          },
          %{
            "source_id" => "u2",
            "username" => "different_name_#{uid}",
            "email" => existing_email,
            "post_count" => 20,
            "joined_at" => "not-a-valid-date"
          },
          %{
            "source_id" => "u3",
            "username" => existing_username,
            "email" => "different_email_#{uid}@example.com"
          },
          %{
            "source_id" => "u_bad_join",
            "username" => "phpbb_bad_join_#{uid}",
            "email" => "phpbb_bad_join_#{uid}@example.com",
            "joined_at" => "not-a-valid-date"
          },
          %{
            "source_id" => "u_no_email",
            "username" => existing_username
          },
          %{
            "source_id" => "u_invalid",
            "username" => "x",
            "email" => "bad_user@invalid"
          }
        ],
        "categories" => [
          %{
            "source_id" => "c1",
            "name" => "Gaming Zone",
            "description" => "Duplicate category name",
            "position" => 1
          },
          %{
            "source_id" => "c2",
            "name" => "Unique PhpBB Cat #{uid}",
            "position" => 2
          },
          %{
            "source_id" => "c_invalid",
            "name" => ""
          }
        ],
        "forums" => [
          %{
            "source_id" => "f1",
            "category_source_id" => "c1",
            "name" => "General Discussion",
            "description" => "Duplicate forum name",
            "position" => 1
          },
          %{
            "source_id" => "f2",
            "category_source_id" => "c2",
            "name" => "Unique PhpBB Forum #{uid}",
            "position" => 2
          },
          %{
            "source_id" => "f_orphan",
            "category_source_id" => "nonexistent_cat",
            "name" => "Orphan Forum"
          },
          %{
            "source_id" => "f_invalid",
            "category_source_id" => "c1",
            "name" => ""
          }
        ],
        "threads" => [
          %{
            "source_id" => "t1",
            "forum_source_id" => "f1",
            "user_source_id" => "u1",
            "title" => "First phpBB Thread #{uid}",
            "is_pinned" => true,
            "is_locked" => false,
            "view_count" => 45,
            "created_at" => "2025-06-01T12:00:00Z"
          },
          %{
            "source_id" => "t2_empty",
            "forum_source_id" => "f1",
            "user_source_id" => "u1",
            "title" => "Empty Thread with No Posts #{uid}",
            "created_at" => "not-a-date"
          },
          %{
            "source_id" => "t_orphan",
            "forum_source_id" => "nonexistent_forum",
            "user_source_id" => "u1",
            "title" => "Orphan Thread"
          },
          %{
            "source_id" => "t_invalid",
            "forum_source_id" => "f1",
            "user_source_id" => "u1",
            "title" => ""
          }
        ],
        "posts" => [
          %{
            "source_id" => "p1",
            "thread_source_id" => "t1",
            "user_source_id" => "u1",
            "body" => "Welcome! [b:123]Enjoy[/b:123]",
            "is_first_post" => true,
            "created_at" => "2025-06-01T12:00:00Z"
          },
          %{
            "source_id" => "p2",
            "thread_source_id" => "t1",
            "user_source_id" => "u2",
            "body" => "Reply from matched user [i:456]Italic[/i:456]",
            "is_first_post" => false,
            "created_at" => "not-a-date"
          },
          %{
            "source_id" => "p_orphan",
            "thread_source_id" => "nonexistent_thread",
            "user_source_id" => "u1",
            "body" => "Orphan post"
          },
          %{
            "source_id" => "p_invalid",
            "thread_source_id" => "t1",
            "user_source_id" => "u1",
            "body" => ""
          }
        ]
      }

      config = %{"source" => "phpbb", "data" => import_data}
      assert {:ok, import_id} = Importer.run_import(config, %{async: false})
      sync_progress()

      {:ok, status} = Importer.get_status(import_id)
      assert status.errors == []
      assert status.status == :completed
      assert status.stats.users_imported == 5
      assert status.stats.categories_imported == 2
      assert status.stats.forums_imported == 2
      assert status.stats.threads_imported == 2
      assert status.stats.posts_imported == 2

      # Check counter update on thread and forum
      thread = Repo.get_by!(Thread, title: "First phpBB Thread #{uid}")
      assert thread.reply_count == 1
      assert thread.last_post_user_id == existing_user.id

      forum = Repo.get!(Forum, thread.forum_id)
      assert forum.thread_count >= 2
      assert forum.post_count >= 2
    end
  end

  describe "VBulletin Adapter & Full Pipeline" do
    test "normalize_vbulletin_bbcode" do
      assert VBulletin.normalize_vbulletin_bbcode(nil) == ""

      raw =
        "[QUOTE=moderator;12345]Important announcement[/QUOTE] [HIGHLIGHT]Note[/HIGHLIGHT] [INDENT]Indent[/INDENT] [THREAD=99]Thread link[/THREAD] [POST=88]Post link[/POST] [ATTACH=config]555[/ATTACH]"

      normalized = VBulletin.normalize_vbulletin_bbcode(raw)
      assert normalized =~ "[QUOTE=moderator]"
      assert normalized =~ "[B]Note[/B]"
      assert normalized =~ "Indent"
      assert normalized =~ "Thread link"
      assert normalized =~ "Post link"
      assert normalized =~ "[Attachment]"
    end

    test "end-to-end vBulletin import with options: import_users: false, import_posts: false" do
      uid = System.unique_integer([:positive])

      # First run with users disabled
      import_data_no_users = %{
        "users" => [
          %{
            "source_id" => "u1",
            "username" => "vb_skip_#{uid}",
            "email" => "vb_skip_#{uid}@example.com"
          }
        ],
        "categories" => [
          %{
            "source_id" => "c1",
            "name" => "VB Cat #{uid}",
            "description" => "A cat",
            "position" => 1
          }
        ],
        "forums" => [
          %{
            "source_id" => "f1",
            "category_source_id" => "c1",
            "name" => "VB Forum #{uid}",
            "position" => 1
          }
        ],
        "threads" => [],
        "posts" => []
      }

      config = %{"source" => "vbulletin", "data" => import_data_no_users}
      assert {:ok, id1} = Importer.run_import(config, %{"import_users" => false, :async => false})
      sync_progress()

      {:ok, status1} = Importer.get_status(id1)
      assert status1.status == :completed
      assert status1.stats.users_imported == 0
      assert status1.stats.categories_imported == 1
      assert status1.stats.forums_imported == 1

      # Second run with posts disabled
      import_data_no_posts = %{
        "users" => [
          %{
            "source_id" => "u1",
            "username" => "vb_user_#{uid}",
            "email" => "vb_user_#{uid}@example.com",
            "joined_at" => "2024-03-01T10:00:00Z"
          }
        ],
        "categories" => [
          %{"source_id" => "c1", "name" => "VB Cat 2 #{uid}", "position" => 2}
        ],
        "forums" => [
          %{
            "source_id" => "f1",
            "category_source_id" => "c1",
            "name" => "VB Forum 2 #{uid}",
            "position" => 2
          }
        ],
        "threads" => [
          %{
            "source_id" => "t1",
            "forum_source_id" => "f1",
            "user_source_id" => "u1",
            "title" => "VB Thread #{uid}"
          }
        ],
        "posts" => [
          %{
            "source_id" => "p1",
            "thread_source_id" => "t1",
            "user_source_id" => "u1",
            "body" => "VB Post"
          }
        ]
      }

      config2 = %{"source" => "vbulletin", "data" => import_data_no_posts}

      assert {:ok, id2} =
               Importer.run_import(config2, %{"import_posts" => false, :async => false})

      sync_progress()

      {:ok, status2} = Importer.get_status(id2)
      assert status2.status == :completed
      assert status2.stats.users_imported == 1
      assert status2.stats.threads_imported == 0
      assert status2.stats.posts_imported == 0
    end

    test "end-to-end full vBulletin import with duplicate slugs and invalid fields" do
      uid = System.unique_integer([:positive])
      existing_email = "existing_vb_#{uid}@example.com"
      existing_username = "existing_vb_#{uid}"

      {:ok, _existing_user} =
        %User{}
        |> User.registration_changeset(%{
          username: existing_username,
          email: existing_email,
          password: "SecurePass12345!Password"
        })
        |> Repo.insert()

      {:ok, existing_cat} =
        %Category{}
        |> Category.changeset(%{name: "VB Base Cat #{uid}", position: 1})
        |> Repo.insert()

      {:ok, _existing_forum} =
        %Forum{}
        |> Forum.changeset(%{
          name: "VB Base Forum #{uid}",
          category_id: existing_cat.id,
          position: 1
        })
        |> Repo.insert()

      import_data = %{
        "users" => [
          %{
            "source_id" => "u1",
            "username" => "vb_new_#{uid}",
            "email" => "vb_new_#{uid}@example.com",
            "joined_at" => "2025-01-01T12:00:00Z"
          },
          %{
            "source_id" => "u2",
            "username" => "different_vb_name_#{uid}",
            "email" => existing_email,
            "joined_at" => "not-a-date"
          },
          %{
            "source_id" => "u3",
            "username" => existing_username,
            "email" => "other_vb_email_#{uid}@example.com"
          },
          %{
            "source_id" => "u_bad_join",
            "username" => "vb_bad_join_#{uid}",
            "email" => "vb_bad_join_#{uid}@example.com",
            "joined_at" => "not-a-valid-date"
          },
          %{
            "source_id" => "u_no_email",
            "username" => existing_username
          },
          %{
            "source_id" => "u_invalid",
            "username" => "z",
            "email" => "invalid_user@test"
          }
        ],
        "categories" => [
          %{
            "source_id" => "c1",
            "name" => "VB Base Cat #{uid}",
            "position" => 1
          },
          %{
            "source_id" => "c_invalid",
            "name" => ""
          }
        ],
        "forums" => [
          %{
            "source_id" => "f1",
            "category_source_id" => "c1",
            "name" => "VB Base Forum #{uid}",
            "position" => 1
          },
          %{
            "source_id" => "f_orphan",
            "category_source_id" => "missing_cat",
            "name" => "Orphan"
          },
          %{
            "source_id" => "f_invalid",
            "category_source_id" => "c1",
            "name" => ""
          }
        ],
        "threads" => [
          %{
            "source_id" => "t1",
            "forum_source_id" => "f1",
            "user_source_id" => "u1",
            "title" => "VB Main Thread #{uid}",
            "created_at" => "2025-01-02T12:00:00Z"
          },
          %{
            "source_id" => "t2_empty",
            "forum_source_id" => "f1",
            "user_source_id" => "u1",
            "title" => "VB Thread without Posts #{uid}",
            "created_at" => "not-a-date"
          },
          %{
            "source_id" => "t_orphan",
            "forum_source_id" => "missing_forum",
            "user_source_id" => "u1",
            "title" => "Orphan Thread"
          },
          %{
            "source_id" => "t_invalid",
            "forum_source_id" => "f1",
            "user_source_id" => "u1",
            "title" => ""
          }
        ],
        "posts" => [
          %{
            "source_id" => "p1",
            "thread_source_id" => "t1",
            "user_source_id" => "u1",
            "body" => "[QUOTE=admin;10]Hello[/QUOTE] Post body",
            "created_at" => "2025-01-02T12:00:00Z"
          },
          %{
            "source_id" => "p2",
            "thread_source_id" => "t1",
            "user_source_id" => "u2",
            "body" => "Second post",
            "created_at" => "not-a-date"
          },
          %{
            "source_id" => "p_orphan",
            "thread_source_id" => "missing_thread",
            "user_source_id" => "u1",
            "body" => "Orphan post"
          },
          %{
            "source_id" => "p_invalid",
            "thread_source_id" => "t1",
            "user_source_id" => "u1",
            "body" => ""
          }
        ]
      }

      config = %{"source" => "vbulletin", "data" => import_data}
      assert {:ok, import_id} = Importer.run_import(config, %{async: false})
      sync_progress()

      {:ok, status} = Importer.get_status(import_id)
      assert status.status == :completed
      assert status.stats.users_imported == 5
      assert status.stats.categories_imported == 1
      assert status.stats.forums_imported == 1
      assert status.stats.threads_imported == 2
      assert status.stats.posts_imported == 2
    end
  end

  describe "Discourse Adapter & Full Pipeline" do
    test "markdown_to_bbcode formatting transformations" do
      assert Discourse.markdown_to_bbcode(nil) == ""

      md = """
      # Main Heading
      ## Sub Heading
      ### Minor Heading
      **bold1** and __bold2__
      *italic1* and _italic2_
      ~~strikethrough~~
      ```elixir
      def hello, do: :world
      ```
      Use `inspect(val)` inline.
      [Click here](https://elixir-lang.org)
      ![Logo](https://elixir-lang.org/logo.png)
      > A single quote
      > continuing quote
      Outside quote.
      ---
      - Unordered item 1
      - Unordered item 2
      * Another item 3
      """

      bb = Discourse.markdown_to_bbcode(md)
      assert bb =~ "[B][SIZE=6]Main Heading[/SIZE][/B]"
      assert bb =~ "[B][SIZE=5]Sub Heading[/SIZE][/B]"
      assert bb =~ "[B]Minor Heading[/B]"
      assert bb =~ "[B]bold1[/B]"
      assert bb =~ "[B]bold2[/B]"
      assert bb =~ "[I]italic1[/I]"
      assert bb =~ "[I]italic2[/I]"
      assert bb =~ "[S]strikethrough[/S]"
      assert bb =~ "[CODE]def hello, do: :world"
      assert bb =~ "[/CODE]"
      assert bb =~ "[CODE]inspect(val)[/CODE]"
      assert bb =~ "[URL=https://elixir-lang.org]Click here[/URL]"
      assert bb =~ "[IMG]https://elixir-lang.org/logo.png[/IMG]"
      assert bb =~ "[QUOTE]"
      assert bb =~ "[/QUOTE]"
      assert bb =~ "[HR]"
      assert bb =~ "[LIST]"
      assert bb =~ "[*]Unordered item 1"
      assert bb =~ "[/LIST]"
    end

    test "end-to-end Discourse import with full data, duplicate collisions, and edge cases" do
      uid = System.unique_integer([:positive])
      existing_email = "existing_dc_#{uid}@example.com"
      existing_username = "existing_dc_#{uid}"

      {:ok, _existing_user} =
        %User{}
        |> User.registration_changeset(%{
          username: existing_username,
          email: existing_email,
          password: "SecurePass12345!Password"
        })
        |> Repo.insert()

      {:ok, existing_cat} =
        %Category{}
        |> Category.changeset(%{name: "Discourse Base Cat #{uid}", position: 1})
        |> Repo.insert()

      {:ok, _existing_forum} =
        %Forum{}
        |> Forum.changeset(%{
          name: "Discourse Base Forum #{uid}",
          category_id: existing_cat.id,
          position: 1
        })
        |> Repo.insert()

      discourse_data = %{
        "users" => [
          %{
            "source_id" => "u1",
            "username" => "dc_user_#{uid}",
            "email" => "dc_user_#{uid}@example.com",
            "post_count" => 4,
            "bio" => "Discourse bio content",
            "avatar_url" => "https://example.com/dc.png",
            "joined_at" => "2025-01-15T09:00:00Z"
          },
          %{
            "source_id" => "u2",
            "username" => "diff_dc_name_#{uid}",
            "email" => existing_email,
            "joined_at" => "not-a-date"
          },
          %{
            "source_id" => "u3",
            "username" => existing_username,
            "email" => "diff_dc_email_#{uid}@example.com"
          },
          %{
            "source_id" => "u_bad_join",
            "username" => "dc_bad_join_#{uid}",
            "email" => "dc_bad_join_#{uid}@example.com",
            "joined_at" => "not-a-valid-date"
          },
          %{
            "source_id" => "u_no_email",
            "username" => existing_username
          },
          %{
            "source_id" => "u_invalid",
            "username" => "q",
            "email" => "invalid_dc_email@test"
          }
        ],
        "categories" => [
          %{
            "source_id" => "c1",
            "name" => "Discourse Base Cat #{uid}",
            "description" => "Discourse Category Description",
            "position" => 1
          },
          %{
            "source_id" => "c2",
            "name" => "Unique Discourse Cat #{uid}",
            "position" => 2
          },
          %{
            "source_id" => "c_invalid",
            "name" => ""
          }
        ],
        "forums" => [
          %{
            "source_id" => "f1",
            "category_source_id" => "c1",
            "name" => "Discourse Base Forum #{uid}",
            "description" => "Forum description",
            "position" => 1
          },
          %{
            "source_id" => "f2",
            "category_source_id" => "c2",
            "name" => "Unique Discourse Forum #{uid}",
            "position" => 2
          },
          %{
            "source_id" => "f_orphan",
            "category_source_id" => "missing_cat",
            "name" => "Orphan"
          },
          %{
            "source_id" => "f_invalid",
            "category_source_id" => "c1",
            "name" => ""
          }
        ],
        "threads" => [
          %{
            "source_id" => "t1",
            "forum_source_id" => "f1",
            "user_source_id" => "u1",
            "title" => "Discourse Thread #{uid}",
            "view_count" => 80,
            "created_at" => "2025-02-01T10:00:00Z"
          },
          %{
            "source_id" => "t2_empty",
            "forum_source_id" => "f1",
            "user_source_id" => "u1",
            "title" => "Discourse Empty Thread #{uid}",
            "created_at" => "not-a-date"
          },
          %{
            "source_id" => "t_orphan",
            "forum_source_id" => "missing_forum",
            "user_source_id" => "u1",
            "title" => "Orphan Thread"
          },
          %{
            "source_id" => "t_invalid",
            "forum_source_id" => "f1",
            "user_source_id" => "u1",
            "title" => ""
          }
        ],
        "posts" => [
          %{
            "source_id" => "p1",
            "thread_source_id" => "t1",
            "user_source_id" => "u1",
            "body" => "# Welcome to Discourse\n**Hello** [world](https://example.com)",
            "is_first_post" => true,
            "created_at" => "2025-02-01T10:00:00Z"
          },
          %{
            "source_id" => "p2",
            "thread_source_id" => "t1",
            "user_source_id" => "u2",
            "body" => "Reply post",
            "created_at" => "not-a-date"
          },
          %{
            "source_id" => "p_orphan",
            "thread_source_id" => "missing_thread",
            "user_source_id" => "u1",
            "body" => "Orphan post"
          },
          %{
            "source_id" => "p_invalid",
            "thread_source_id" => "t1",
            "user_source_id" => "u1",
            "body" => ""
          }
        ]
      }

      config = %{"source" => "discourse", "data" => discourse_data}
      assert {:ok, import_id} = Importer.run_import(config, %{async: false})
      sync_progress()

      {:ok, status} = Importer.get_status(import_id)
      assert status.status == :completed
      assert status.stats.users_imported == 5
      assert status.stats.categories_imported == 2
      assert status.stats.forums_imported == 2
      assert status.stats.threads_imported == 2
      assert status.stats.posts_imported == 2

      imported_user = Repo.get_by!(User, username: "dc_user_#{uid}")
      assert imported_user.display_name == "dc_user_#{uid}"

      imported_thread = Repo.get_by!(Thread, title: "Discourse Thread #{uid}")
      assert imported_thread.reply_count == 1

      imported_post =
        Repo.all(
          from p in Post,
            where: p.thread_id == ^imported_thread.id,
            order_by: [asc: p.inserted_at]
        )
        |> hd()

      assert imported_post.body =~ "[B][SIZE=6]Welcome to Discourse[/SIZE][/B]"
      assert imported_post.body_html =~ "<strong>" or imported_post.body_html =~ "Welcome"
    end

    test "handles pipeline error gracefully when unexpected exception occurs" do
      # Malformed categories data (not a list, causing crash in Enum.sort_by)
      config = %{
        "source" => "discourse",
        "data" => %{"categories" => "not_a_list"}
      }

      assert {:ok, import_id} = Importer.run_import(config, %{async: false})
      sync_progress()

      {:ok, status} = Importer.get_status(import_id)
      assert status.status == :failed

      assert Enum.any?(status.errors, fn err -> String.contains?(err.message, "Import failed") end)
    end
  end
end
