# Applying a confirmed email change. Lives outside the forum gate so the link
# in the email works regardless of whether the forum is open.
class EmailChangesController < ApplicationController
  def show
    user = User.find_by_token_for(:email_change, params[:token])

    if user.nil? || user.pending_email_address.blank?
      redirect_to root_path, alert: "That confirmation link is invalid or has expired." and return
    end

    # The address could have been claimed by someone else between the request
    # and the click.
    if User.where.not(id: user.id).exists?(email_address: user.pending_email_address)
      user.update(pending_email_address: nil)
      redirect_to root_path, alert: "That address is now in use by another account." and return
    end

    user.apply_pending_email!
    redirect_to new_session_path, notice: "Your email address has been updated. Please sign in with it."
  end
end
