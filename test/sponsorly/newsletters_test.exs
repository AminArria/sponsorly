defmodule Sponsorly.NewslettersTest do
  use Sponsorly.DataCase, async: true

  alias Sponsorly.Newsletters

  describe "newsletters" do
    alias Sponsorly.Newsletters.Newsletter

    @invalid_attrs %{interval_days: nil, name: nil, sponsor_before_days: nil, sponsor_in_days: nil}

    test "list_newsletters/1 returns all newsletters of user" do
      newsletter = insert(:newsletter) |> unload_assocs([:user])
      insert(:newsletter)

      assert Newsletters.list_newsletters(newsletter.user_id) == [newsletter]
    end

    test "list_newsletters_of_slug/1 returns all newsletters of a user slug" do
      user = insert(:confirmed_user)
      newsletter = insert(:newsletter, user: user) |> unload_assocs([:user])
      insert(:newsletter)

      assert Newsletters.list_newsletters_of_slug(user.slug) == [newsletter]
    end

    test "get_newsletter!/2 returns the newsletter with given id of user" do
      newsletter = insert(:newsletter) |> unload_assocs([:user])
      other_user = insert(:confirmed_user)

      assert Newsletters.get_newsletter!(newsletter.user_id, newsletter.id) == newsletter
      assert_raise Ecto.NoResultsError, fn ->
        Newsletters.get_newsletter!(newsletter.user_id, other_user.id)
      end
    end

    test "get_newsletter_by_slugs!/2 returns the newsletter with given user slug and newsletter slug" do
      user = insert(:confirmed_user)
      other_user = insert(:confirmed_user)
      newsletter = insert(:newsletter, user: user) |> unload_assocs([:user])

      assert Newsletters.get_newsletter_by_slugs!(user.slug, newsletter.slug) == newsletter
      assert_raise Ecto.NoResultsError, fn ->
        Newsletters.get_newsletter_by_slugs!(other_user.slug, newsletter.slug)
      end
    end

    test "create_newsletter/1 with valid data creates a newsletter" do
      next_issue_at = DateTime.utc_now() |> DateTime.add(24 * 60 * 60)
      attrs = params_with_assocs(:newsletter, next_issue_at: next_issue_at)
      assert {:ok, %Newsletter{} = newsletter} = Newsletters.create_newsletter(attrs)
      assert newsletter.interval_days == newsletter.interval_days
      assert newsletter.name == newsletter.name
      assert newsletter.slug == newsletter.slug
      assert newsletter.sponsor_before_days == newsletter.sponsor_before_days
      assert newsletter.sponsor_in_days == newsletter.sponsor_in_days
      assert newsletter.user_id == newsletter.user_id
    end

    test "create_newsletter/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Newsletters.create_newsletter(@invalid_attrs)
    end

    test "update_newsletter/2 with valid data updates the newsletter" do
      original_newsletter = insert(:newsletter)
      attrs = params_with_assocs(:newsletter)
      assert {:ok, %Newsletter{} = newsletter} = Newsletters.update_newsletter(original_newsletter, attrs)
      assert newsletter.interval_days == attrs.interval_days
      assert newsletter.name == attrs.name
      assert newsletter.slug == attrs.slug
      assert newsletter.sponsor_before_days == attrs.sponsor_before_days
      assert newsletter.sponsor_in_days == attrs.sponsor_in_days
      # Can't change user_id
      assert original_newsletter.user_id != attrs.user_id
      assert newsletter.user_id == original_newsletter.user_id
    end

    test "update_newsletter/2 with invalid data returns error changeset" do
      newsletter = insert(:newsletter) |> unload_assocs([:user])
      assert {:error, %Ecto.Changeset{}} = Newsletters.update_newsletter(newsletter, @invalid_attrs)
      assert newsletter == Newsletters.get_newsletter!(newsletter.user_id, newsletter.id)
    end

    test "soft_delete_newsletter/1 soft deletes the newsletter" do
      newsletter = insert(:newsletter)
      assert {:ok, %Newsletter{deleted: true}} = Newsletters.soft_delete_newsletter(newsletter)
      refute Newsletters.list_newsletters(newsletter.user_id) == [newsletter]
      assert_raise Ecto.NoResultsError, fn -> Newsletters.get_newsletter!(newsletter.user_id, newsletter.id) end
    end

    test "change_newsletter/1 returns a newsletter changeset" do
      newsletter = build(:newsletter)
      assert %Ecto.Changeset{} = Newsletters.change_newsletter(newsletter)
    end

    test "create_newsletter/1 creates associated issues based on :next_issue_at, :interval_days, and :sponsor_in_days" do
      next_issue_at = DateTime.utc_now() |> DateTime.add(24 * 60 * 60)
      attrs = params_with_assocs(:newsletter, next_issue_at: next_issue_at)
      max_sponsor_at = DateTime.add(next_issue_at, attrs.sponsor_in_days * 24 * 60 * 60)
      {:ok, newsletter} = Newsletters.create_newsletter(attrs)

      [next_issue | issues] = Newsletters.list_issues(newsletter.id)

      assert check_datetime(next_issue.due_at, next_issue_at)

      Enum.reduce(issues, {1, next_issue_at}, fn issue, {issues_seen, last_issue_at} ->
        next_at =
          last_issue_at
          |> DateTime.add(attrs.interval_days * 24 * 60 * 60)
          |> DateTime.truncate(:second)

        assert issue.due_at == next_at
        assert DateTime.compare(max_sponsor_at, issue.due_at) == :gt

        {issues_seen + 1, next_at}
      end)
    end

    test "slug of a newsletter must be unique for a user" do
      newsletter = insert(:newsletter_with_next_issue)
      same_user_new_newsletter_attrs = params_for(:newsletter_with_next_issue, user_id: newsletter.user_id, slug: newsletter.slug)

      {:error, changeset} = Newsletters.create_newsletter(same_user_new_newsletter_attrs)
      assert "has already been taken" in errors_on(changeset).slug
    end
  end

  describe "issues" do
    alias Sponsorly.Newsletters.Issue

    @invalid_attrs %{due_at: nil}

    test "list_issues/2 returns all issues for a newsletter" do
      issue = insert(:issue) |> unload_assocs([:newsletter])
      insert(:issue)

      assert Newsletters.list_issues(issue.newsletter_id) == [issue]
    end

    test "list_issues_of_slugs/2 returns all issues of a user slug and a newsletter slug" do
      newsletter = insert(:newsletter)
      other_newsletter = insert(:newsletter, user: newsletter.user)
      issue = insert(:issue, newsletter: newsletter) |> unload_assocs([:newsletter])
      insert(:issue, newsletter: other_newsletter)

      assert Newsletters.list_issues_of_slugs(newsletter.user.slug, newsletter.slug) == [issue]
    end

    test "list_issues_of_slugs/2 returns only issues pending publishing (due_at > today)" do
      newsletter = insert(:newsletter)
      issue = insert(:issue, newsletter: newsletter) |> unload_assocs([:newsletter])
      insert(:issue, newsletter: newsletter, due_at: DateTime.add(DateTime.utc_now(), -24 * 60 * 60))

      assert Newsletters.list_issues_of_slugs(newsletter.user.slug, newsletter.slug) == [issue]
    end

    test "list_issues_of_slugs/2 returns issues ordered by most recent due_at" do
      newsletter = insert(:newsletter)
      issue1 = insert(:issue, newsletter: newsletter) |> unload_assocs([:newsletter])
      issue2 = insert(:issue, newsletter: newsletter, due_at: DateTime.add(issue1.due_at, 1 * 24 * 60 * 60)) |> unload_assocs([:newsletter])
      issue3 = insert(:issue, newsletter: newsletter, due_at: DateTime.add(issue1.due_at, 3 * 24 * 60 * 60)) |> unload_assocs([:newsletter])

      assert Newsletters.list_issues_of_slugs(newsletter.user.slug, newsletter.slug) == [issue1, issue2, issue3]
    end

    test "get_issue!/2 returns the issue of a newsletter with given id" do
      issue = insert(:issue) |> unload_assocs([:newsletter])
      other_newsletter = insert(:newsletter)

      assert Newsletters.get_issue!(issue.newsletter_id, issue.id) == issue
      assert_raise Ecto.NoResultsError, fn ->
        Newsletters.get_newsletter!(issue.newsletter_id, other_newsletter.id)
      end
    end

    test "create_issue/1 with valid data creates a issue" do
      attrs = params_with_assocs(:issue)
      assert {:ok, %Issue{} = issue} = Newsletters.create_issue(attrs)
      assert check_datetime(issue.due_at, attrs.due_at)
      assert issue.name == attrs.name
      assert issue.newsletter_id == attrs.newsletter_id
    end

    test "create_issue/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Newsletters.create_issue(@invalid_attrs)
    end

    test "update_issue/2 with valid data updates the issue" do
      original_issue = insert(:issue)
      attrs = params_with_assocs(:issue)
      assert {:ok, %Issue{} = issue} = Newsletters.update_issue(original_issue, attrs)
      assert check_datetime(issue.due_at, attrs.due_at)
      assert issue.name == attrs.name
      # Can't change newsletter
      assert issue.newsletter_id == original_issue.newsletter_id
    end

    test "update_issue/2 with invalid data returns error changeset" do
      issue = insert(:issue) |> unload_assocs([:newsletter])
      assert {:error, %Ecto.Changeset{}} = Newsletters.update_issue(issue, @invalid_attrs)
      assert issue == Newsletters.get_issue!(issue.newsletter_id, issue.id)
    end

    test "soft_delete_issue/1 soft deletes the issue" do
      issue = insert(:issue)
      assert {:ok, %Issue{deleted: true}} = Newsletters.soft_delete_issue(issue)
      assert_raise Ecto.NoResultsError, fn -> Newsletters.get_issue!(issue.newsletter_id, issue.id) end
      refute Newsletters.list_issues(issue.newsletter_id) == [issue]
    end

    test "change_issue/1 returns a issue changeset" do
      issue = insert(:issue)
      assert %Ecto.Changeset{} = Newsletters.change_issue(issue)
    end
  end
end
