defmodule ForgeNexusWeb.ContactController do
  use ForgeNexusWeb, :controller

  alias ForgeNexus.Emails
  alias ForgeNexus.Mailer

  require Logger

  def create(conn, %{"name" => name, "email" => email, "subject" => subject, "message" => message})
      when is_binary(name) and is_binary(email) and is_binary(subject) and is_binary(message) do
    # Validate fields
    cond do
      String.trim(name) == "" or String.trim(email) == "" or String.trim(subject) == "" or String.trim(message) == "" ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{error: "All fields are required"})

      not String.contains?(email, "@") ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{error: "Invalid email address"})

      String.length(message) > 5000 ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{error: "Message is too long (max 5000 characters)"})

      true ->
        # Try to send email, fall back to logging
        try do
          contact_email = Emails.contact_form_email(name, email, subject, message)
          Mailer.deliver(contact_email)
        rescue
          _ ->
            Logger.info("Contact form submission: name=#{name}, email=#{email}, subject=#{subject}, message=#{message}")
        end

        conn
        |> put_status(:ok)
        |> json(%{message: "Your message has been sent. We'll get back to you soon!"})
    end
  end

  def create(conn, _params) do
    conn
    |> put_status(:unprocessable_entity)
    |> json(%{error: "Missing required fields: name, email, subject, message"})
  end
end
