defmodule Sponsorly.Newsletters.Issue do
  use Ecto.Schema
  import Ecto.Changeset

  schema "issues" do
    field :name, :string
    field :due_date, :date
    field :deleted, :boolean, default: false

    belongs_to :newsletter, Sponsorly.Newsletters.Newsletter
    has_one :confirmed_sponsorship, Sponsorly.Sponsorships.ConfirmedSponsorship
    has_many :sponsorships, Sponsorly.Sponsorships.Sponsorship

    timestamps()
  end

  @doc false
  def create_changeset(issue, attrs) do
    issue
    |> cast(attrs, [:due_date, :name, :newsletter_id])
    |> validate_required([:due_date, :name, :newsletter_id])
  end

  def update_changeset(issue, attrs) do
    issue
    |> cast(attrs, [:due_date, :name])
    |> validate_required([:due_date, :name])
  end

  def soft_delete_changeset(issue) do
    change(issue, %{deleted: true})
  end
end
