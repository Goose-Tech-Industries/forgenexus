defmodule ForgeNexus.Repo.Migrations.ReshapeAchievementsSchema do
  @moduledoc """
  Reshapes the achievements table to match the canonical
  ForgeNexus.Achievements.Achievement schema. Idempotent: tolerates a
  partially-migrated dev DB where some columns were added manually or by
  an aborted prior run.
  """
  use Ecto.Migration

  def up do
    execute """
    DO $$
    BEGIN
      IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='achievements' AND column_name='slug') THEN
        ALTER TABLE achievements ADD COLUMN slug varchar(255);
      END IF;
      IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='achievements' AND column_name='category') THEN
        ALTER TABLE achievements ADD COLUMN category varchar(255);
      END IF;
      IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='achievements' AND column_name='points') THEN
        ALTER TABLE achievements ADD COLUMN points integer NOT NULL DEFAULT 0;
      END IF;
      IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='achievements' AND column_name='badge_id') THEN
        ALTER TABLE achievements ADD COLUMN badge_id uuid;
      END IF;
      IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='achievements' AND column_name='criteria') THEN
        IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='achievements' AND column_name='criteria_metadata') THEN
          ALTER TABLE achievements RENAME COLUMN criteria_metadata TO criteria;
          ALTER TABLE achievements ALTER COLUMN criteria SET NOT NULL;
          ALTER TABLE achievements ALTER COLUMN criteria SET DEFAULT '{}'::jsonb;
        ELSE
          ALTER TABLE achievements ADD COLUMN criteria jsonb NOT NULL DEFAULT '{}'::jsonb;
        END IF;
      END IF;
      IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='achievements' AND column_name='is_hidden') THEN
        ALTER TABLE achievements ADD COLUMN is_hidden boolean NOT NULL DEFAULT false;
      END IF;
      IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='achievements' AND column_name='is_active') THEN
        ALTER TABLE achievements ADD COLUMN is_active boolean NOT NULL DEFAULT true;
      END IF;
      IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='achievements' AND column_name='sort_order') THEN
        IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='achievements' AND column_name='position') THEN
          ALTER TABLE achievements RENAME COLUMN position TO sort_order;
          ALTER TABLE achievements ALTER COLUMN sort_order SET NOT NULL;
          ALTER TABLE achievements ALTER COLUMN sort_order SET DEFAULT 0;
        ELSE
          ALTER TABLE achievements ADD COLUMN sort_order integer NOT NULL DEFAULT 0;
        END IF;
      END IF;
    END $$;
    """

    execute "UPDATE achievements SET slug = lower(regexp_replace(name, '[^a-zA-Z0-9]+', '-', 'g')) WHERE slug IS NULL"
    execute "ALTER TABLE achievements ALTER COLUMN slug SET NOT NULL"
    execute "CREATE UNIQUE INDEX IF NOT EXISTS achievements_slug_index ON achievements (slug)"

    execute """
    DO $$
    BEGIN
      IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='achievements' AND column_name='criteria_type') THEN
        ALTER TABLE achievements DROP COLUMN criteria_type;
      END IF;
      IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='achievements' AND column_name='criteria_value') THEN
        ALTER TABLE achievements DROP COLUMN criteria_value;
      END IF;
    END $$;
    """

    execute """
    DO $$
    BEGIN
      IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='user_achievements' AND column_name='earned_at')
         AND EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='user_achievements' AND column_name='unlocked_at') THEN
        UPDATE user_achievements SET unlocked_at = earned_at WHERE unlocked_at IS NULL;
        ALTER TABLE user_achievements DROP COLUMN earned_at;
      ELSIF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='user_achievements' AND column_name='earned_at') THEN
        ALTER TABLE user_achievements RENAME COLUMN earned_at TO unlocked_at;
      END IF;
    END $$;
    """
  end

  def down do
    execute "ALTER TABLE user_achievements RENAME COLUMN unlocked_at TO earned_at"
    execute "ALTER TABLE achievements ADD COLUMN criteria_type varchar(255)"
    execute "ALTER TABLE achievements ADD COLUMN criteria_value integer DEFAULT 1"
    execute "DROP INDEX IF EXISTS achievements_slug_index"
    execute "ALTER TABLE achievements DROP COLUMN slug"
    execute "ALTER TABLE achievements DROP COLUMN category"
    execute "ALTER TABLE achievements DROP COLUMN points"
    execute "ALTER TABLE achievements DROP COLUMN badge_id"
    execute "ALTER TABLE achievements DROP COLUMN criteria"
    execute "ALTER TABLE achievements DROP COLUMN is_hidden"
    execute "ALTER TABLE achievements DROP COLUMN is_active"
    execute "ALTER TABLE achievements DROP COLUMN sort_order"
  end
end
