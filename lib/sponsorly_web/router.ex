defmodule SponsorlyWeb.Router do
  use SponsorlyWeb, :router

  import SponsorlyWeb.UserAuth

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_flash
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug :fetch_current_user
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  pipeline :user do
    plug :require_authenticated_user
    plug :check_if_onboarded
  end

  scope "/", SponsorlyWeb do
    pipe_through :browser

    get "/", PageController, :index
  end

  scope "/", SponsorlyWeb do
    pipe_through [:browser, :user]

    resources "/newsletters", NewsletterController do
      resources "/issues", IssueController
    end

    resources "/sponsorships", SponsorshipController
    resources "/confirmed_sponsorships", ConfirmedSponsorshipController, only: [:create, :delete, :edit, :update]
  end

  scope "/", SponsorlyWeb do
    pipe_through [:browser, :require_authenticated_user]

    get "/users/onboard", UserOnboardingController, :edit
    put "/users/onboard", UserOnboardingController, :update
  end

  scope "/", SponsorlyWeb do
    pipe_through [:browser]

    get "/sponsor/:user_slug", NewsletterController, :slug_index
    get "/sponsor/:user_slug/:newsletter_slug", IssueController, :slug_index
  end

  # Other scopes may use custom stacks.
  # scope "/api", SponsorlyWeb do
  #   pipe_through :api
  # end

  # Enables LiveDashboard only for development
  #
  # If you want to use the LiveDashboard in production, you should put
  # it behind authentication and allow only admins to access it.
  # If your application does not have an admins-only section yet,
  # you can use Plug.BasicAuth to set up some basic authentication
  # as long as you are also using SSL (which you should anyway).
  if Mix.env() in [:dev, :test] do
    import Phoenix.LiveDashboard.Router

    scope "/" do
      pipe_through :browser
      live_dashboard "/dashboard", metrics: SponsorlyWeb.Telemetry
    end
  end

  ## Authentication routes

  scope "/", SponsorlyWeb do
    pipe_through [:browser, :redirect_if_user_is_authenticated]

    get "/users/register", UserRegistrationController, :new
    post "/users/register", UserRegistrationController, :create
    get "/users/log_in", UserSessionController, :new
    post "/users/log_in", UserSessionController, :create
    get "/users/reset_password", UserResetPasswordController, :new
    post "/users/reset_password", UserResetPasswordController, :create
    get "/users/reset_password/:token", UserResetPasswordController, :edit
    put "/users/reset_password/:token", UserResetPasswordController, :update
  end

  scope "/", SponsorlyWeb do
    pipe_through [:browser, :user]

    get "/users/settings", UserSettingsController, :edit
    put "/users/settings", UserSettingsController, :update
    get "/users/settings/confirm_email/:token", UserSettingsController, :confirm_email
  end

  scope "/", SponsorlyWeb do
    pipe_through [:browser]

    delete "/users/log_out", UserSessionController, :delete
    get "/users/confirm", UserConfirmationController, :new
    post "/users/confirm", UserConfirmationController, :create
    get "/users/confirm/:token", UserConfirmationController, :confirm
  end
end
