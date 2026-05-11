defmodule ForgeNexus.Repo.Migrations.SeedChatChannels do
  use Ecto.Migration

  def up do
    execute "SELECT 1"
  end

  def down do
    execute "DELETE FROM chat_messages"
    execute "DELETE FROM chat_channel_members"
    execute "DELETE FROM chat_message_reactions"
    execute "DELETE FROM chat_channels"
    execute "DELETE FROM chat_channel_categories"
  end
end
