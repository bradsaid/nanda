module Admin
  class PasswordsController < BaseController
    def edit
    end

    def update
      unless @current_admin.authenticate(params[:current_password])
        flash.now[:alert] = "Current password is incorrect."
        return render :edit, status: :unprocessable_entity
      end

      # has_secure_password ignores a blank password on update, so an empty
      # form would otherwise report success and change nothing.
      if params[:password].blank?
        flash.now[:alert] = "Please enter a new password."
        return render :edit, status: :unprocessable_entity
      end

      if @current_admin.update(password_params)
        redirect_to admin_root_path, notice: "Password updated."
      else
        flash.now[:alert] = @current_admin.errors.full_messages.to_sentence.presence || "Could not update password."
        render :edit, status: :unprocessable_entity
      end
    end

    private

    def password_params
      params.permit(:password, :password_confirmation)
    end
  end
end
