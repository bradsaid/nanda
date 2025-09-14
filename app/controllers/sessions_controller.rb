class SessionsController < ApplicationController


  def new
    @return_to = params[:return_to].presence || stored_return_to
  end

  def create
    user = User.find_by(email_address: params[:email])
    if user&.authenticate(params[:password])
      reset_session                         # session fixation safety
      session[:user_id] = user.id           # persist login
      Current.user = user                   # make it available immediately

      redirect_to(after_login_path, notice: "Signed in")
    else
      redirect_to new_session_path(return_to: params[:return_to]), alert: "Invalid email or password"
    end
  end

  def destroy
    reset_session
    Current.user = nil
    redirect_to root_path, notice: "Signed out"
  end

  private

  # Prefer explicit param, else stored location, else admin root.
  def after_login_path
    params[:return_to].presence || stored_return_to || admin_root_path
  end

  # Optional: stash a return location (set this when you block access)
  def stored_return_to
    session.delete(:return_to)
  end
end
